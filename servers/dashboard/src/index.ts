#!/usr/bin/env node
/**
 * BP Dashboard MCP Server
 *
 * Provides real-time monitoring and control for autonomous loop execution.
 * Exposes resources for reading state and tools for pause/resume control.
 *
 * Resources:
 *   - bp://dashboard/status - Overall loop status
 *   - bp://dashboard/circuit-breaker - Circuit Breaker state
 *   - bp://dashboard/dual-gate - Dual-Gate exit conditions
 *   - bp://dashboard/metrics - Phase metrics
 *   - bp://dashboard/rate-limit - API rate limit tracking
 *   - bp://dashboard/history - Recent iteration history
 *   - bp://dashboard/all - Complete dashboard snapshot
 *
 * Tools:
 *   - pause-loop - Pause autonomous execution
 *   - resume-loop - Resume paused execution
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { readFileSync, existsSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

// =============================================================================
// CONSTANTS
// =============================================================================

const SESSION_DIR = process.env.PRP_SESSION_DIR || ".prp-session";
const MIME_TYPE_JSON = "application/json";

// State file names (DRY: single source of truth)
const STATE_FILES = {
  LOOP_STATE: "loop-state.json",
  CIRCUIT_BREAKER: "circuit-breaker.json",
  DUAL_GATE: "dual-gate.json",
  METRICS: "metrics.json",
  RATE_LIMIT: "rate-limit.json",
  PHASE_STATUS_LOG: "phase-status.log",
} as const;

// =============================================================================
// LOGGING
// =============================================================================

// CRITICAL: Use console.error for logging (console.log breaks JSON-RPC)
function log(message: string): void {
  console.error(`[bp-dashboard] ${message}`);
}

// =============================================================================
// STATE FILE OPERATIONS
// =============================================================================

/**
 * Safely read a JSON state file
 */
function readState<T>(filename: string): T | null {
  const path = join(SESSION_DIR, filename);
  if (!existsSync(path)) {
    return null;
  }
  try {
    const content = readFileSync(path, "utf-8");
    return JSON.parse(content) as T;
  } catch (error) {
    log(`Error reading ${filename}: ${error}`);
    return null;
  }
}

/**
 * Safely write a JSON state file
 */
function writeState(filename: string, data: unknown): boolean {
  const path = join(SESSION_DIR, filename);
  try {
    // Ensure directory exists
    if (!existsSync(SESSION_DIR)) {
      mkdirSync(SESSION_DIR, { recursive: true });
    }
    writeFileSync(path, JSON.stringify(data, null, 2));
    return true;
  } catch (error) {
    log(`Error writing ${filename}: ${error}`);
    return false;
  }
}

/**
 * Read last N blocks from phase-status.log
 */
function readStatusHistory(count: number = 5): string[] {
  const path = join(SESSION_DIR, STATE_FILES.PHASE_STATUS_LOG);
  if (!existsSync(path)) {
    return [];
  }
  try {
    const content = readFileSync(path, "utf-8");
    const blocks = content.split("---END_PRP_PHASE_STATUS---")
      .filter(block => block.trim().length > 0)
      .map(block => block.trim());
    return blocks.slice(-count);
  } catch (error) {
    log(`Error reading ${STATE_FILES.PHASE_STATUS_LOG}: ${error}`);
    return [];
  }
}

// =============================================================================
// TIME UTILITIES
// =============================================================================

const MINUTES_IN_HOUR = 60;
const HOURS_IN_DAY = 24;
const MS_PER_MINUTE = 60000;
const MS_PER_SECOND = 1000;

/**
 * Calculate human-readable time ago string
 */
function timeAgo(isoTimestamp: string | null): string {
  if (!isoTimestamp) return "never";
  const then = new Date(isoTimestamp);
  const now = new Date();
  const diffMs = now.getTime() - then.getTime();
  const diffMins = Math.floor(diffMs / MS_PER_MINUTE);

  if (diffMins < 1) return "just now";
  if (diffMins < MINUTES_IN_HOUR) return `${diffMins}m ago`;
  const diffHours = Math.floor(diffMins / MINUTES_IN_HOUR);
  if (diffHours < HOURS_IN_DAY) return `${diffHours}h ago`;
  const diffDays = Math.floor(diffHours / HOURS_IN_DAY);
  return `${diffDays}d ago`;
}

/**
 * Calculate human-readable time remaining string
 */
function formatTimeRemaining(targetTime: Date): string | null {
  const now = new Date();
  const diffMs = targetTime.getTime() - now.getTime();
  if (diffMs <= 0) return null;

  const mins = Math.floor(diffMs / MS_PER_MINUTE);
  const secs = Math.floor((diffMs % MS_PER_MINUTE) / MS_PER_SECOND);
  return `${mins}m ${secs}s`;
}

// =============================================================================
// RESPONSE BUILDERS (DRY: Extract common patterns)
// =============================================================================

type StateData = Record<string, unknown>;

/**
 * Build a resource response with JSON content
 */
function buildResourceResponse(uri: URL, data: unknown) {
  return {
    contents: [{
      uri: uri.href,
      mimeType: MIME_TYPE_JSON,
      text: JSON.stringify(data),
    }],
  };
}

/**
 * Build a tool success response
 */
function buildToolSuccess(message: string) {
  return {
    content: [{
      type: "text" as const,
      text: message,
    }],
  };
}

/**
 * Build a tool error response
 */
function buildToolError(message: string) {
  return {
    isError: true,
    content: [{
      type: "text" as const,
      text: message,
    }],
  };
}

// Create MCP Server
const server = new McpServer({
  name: "bp-dashboard",
  version: "1.0.0",
}, {
  capabilities: {
    resources: { subscribe: true },
    tools: {},
  },
});

// ============================================================================
// RESOURCES
// ============================================================================

// Resource: Overall Status
server.resource(
  "dashboard-status",
  "bp://dashboard/status",
  async (uri) => {
    const loopState = readState<StateData>(STATE_FILES.LOOP_STATE);

    if (!loopState) {
      return buildResourceResponse(uri, {
        status: "idle",
        message: "No active session",
      });
    }

    return buildResourceResponse(uri, {
      session_id: loopState.session_id,
      prp_file: loopState.prp_file,
      status: loopState.status,
      current_phase: loopState.current_phase,
      current_iteration: loopState.current_iteration,
      last_activity: loopState.last_activity,
      last_activity_ago: timeAgo(loopState.last_activity as string),
      phases_completed: loopState.phases_completed,
    });
  }
);

// Resource: Circuit Breaker
server.resource(
  "circuit-breaker",
  "bp://dashboard/circuit-breaker",
  async (uri) => {
    const cbState = readState<StateData>(STATE_FILES.CIRCUIT_BREAKER);

    return buildResourceResponse(uri, cbState || {
      state: "CLOSED",
      no_progress_count: 0,
      same_error_count: 0,
      message: "No Circuit Breaker state (session may not exist)",
    });
  }
);

// Resource: Dual-Gate
server.resource(
  "dual-gate",
  "bp://dashboard/dual-gate",
  async (uri) => {
    const dgState = readState<StateData>(STATE_FILES.DUAL_GATE);

    return buildResourceResponse(uri, dgState || {
      phase: null,
      gate_1: { satisfied: false },
      gate_2: { satisfied: false },
      can_exit: false,
      message: "No Dual-Gate state",
    });
  }
);

// Resource: Metrics
server.resource(
  "metrics",
  "bp://dashboard/metrics",
  async (uri) => {
    const metrics = readState<StateData>(STATE_FILES.METRICS);

    return buildResourceResponse(uri, metrics || {
      current_phase: null,
      phases: {},
      message: "No metrics available",
    });
  }
);

// Resource: Rate Limit
server.resource(
  "rate-limit",
  "bp://dashboard/rate-limit",
  async (uri) => {
    const rateState = readState<StateData>(STATE_FILES.RATE_LIMIT);

    if (!rateState) {
      return buildResourceResponse(uri, {
        hourly: { calls_made: 0, limit: 100 },
        anthropic_5h: { detected: false },
        status: "unknown",
        message: "No rate limit state",
      });
    }

    // Calculate time until reset using extracted utility
    const hourly = rateState.hourly as StateData | undefined;
    const nextReset = hourly?.next_reset as string | undefined;
    const resetIn = nextReset ? formatTimeRemaining(new Date(nextReset)) : null;

    return buildResourceResponse(uri, {
      ...rateState,
      reset_in: resetIn,
    });
  }
);

// Resource: History
server.resource(
  "history",
  "bp://dashboard/history",
  async (uri) => {
    const history = readStatusHistory(10);

    return buildResourceResponse(uri, {
      count: history.length,
      entries: history,
    });
  }
);

// Resource: All (Complete Snapshot)
server.resource(
  "all",
  "bp://dashboard/all",
  async (uri) => {
    // Read all state files in parallel conceptually (all sync operations)
    const loopState = readState<StateData>(STATE_FILES.LOOP_STATE);
    const cbState = readState<StateData>(STATE_FILES.CIRCUIT_BREAKER);
    const dgState = readState<StateData>(STATE_FILES.DUAL_GATE);
    const metrics = readState<StateData>(STATE_FILES.METRICS);
    const rateState = readState<StateData>(STATE_FILES.RATE_LIMIT);
    const history = readStatusHistory(5);

    return buildResourceResponse(uri, {
      timestamp: new Date().toISOString(),
      session: loopState || { status: "idle" },
      circuit_breaker: cbState || { state: "CLOSED" },
      dual_gate: dgState,
      metrics: metrics,
      rate_limit: rateState,
      recent_history: history,
    });
  }
);

// ============================================================================
// TOOLS
// ============================================================================

// Tool: Pause Loop
server.tool(
  "pause-loop",
  "Pause the autonomous loop execution",
  {
    reason: z.string().optional().describe("Reason for pausing"),
  },
  async ({ reason }) => {
    const state = readState<StateData>(STATE_FILES.LOOP_STATE);

    if (!state) {
      return buildToolError("No active session to pause");
    }

    if (state.status === "paused") {
      return buildToolSuccess("Session is already paused");
    }

    if (state.status === "completed") {
      return buildToolError("Cannot pause completed session");
    }

    // Update state
    const pauseReason = reason || "Manual pause via MCP";
    state.status = "paused";
    state.pause_reason = pauseReason;
    state.paused_at = new Date().toISOString();

    if (!writeState(STATE_FILES.LOOP_STATE, state)) {
      return buildToolError("Failed to update session state");
    }

    log(`Loop paused: ${pauseReason}`);
    return buildToolSuccess(`Loop paused successfully. Reason: ${pauseReason}`);
  }
);

// Tool: Resume Loop
server.tool(
  "resume-loop",
  "Resume a paused autonomous loop execution",
  {},
  async () => {
    const state = readState<StateData>(STATE_FILES.LOOP_STATE);

    if (!state) {
      return buildToolError("No session to resume");
    }

    if (state.status !== "paused") {
      return buildToolSuccess(`Session is not paused (current status: ${state.status})`);
    }

    // Check Circuit Breaker - prevent resume if OPEN
    const cbState = readState<StateData>(STATE_FILES.CIRCUIT_BREAKER);
    if (cbState && cbState.state === "OPEN") {
      return buildToolError(`Cannot resume: Circuit Breaker is OPEN. Reason: ${cbState.open_reason}`);
    }

    // Update state
    state.status = "running";
    state.pause_reason = null;
    state.resumed_at = new Date().toISOString();

    if (!writeState(STATE_FILES.LOOP_STATE, state)) {
      return buildToolError("Failed to update session state");
    }

    log("Loop resumed");
    return buildToolSuccess("Loop resumed successfully. Note: The loop-controller agent must be running to continue execution.");
  }
);

// ============================================================================
// SERVER STARTUP
// ============================================================================

async function main() {
  log("Starting BP Dashboard MCP Server...");

  const transport = new StdioServerTransport();
  await server.connect(transport);

  log("BP Dashboard MCP Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
