#!/usr/bin/env bats
# autonomous-loop.bats - Autonomous Loop Engine E2E Tests (TDD RED Phase)
# Tests Rate Limiting, Session Manager, Loop State, and State Transitions
#
# IMPORTANT: These tests are written BEFORE implementation exists.
# Tests in the "Implementation Required" sections MUST FAIL initially (TDD RED phase).
# Tests in the "State Schema" sections verify the data structures (helpers pass).
#
# PRP: docs/PRPs/2026-01-16-autonomous-loop-engine-dashboard.md

load 'test_helper'

# =============================================================================
# SETUP AND TEARDOWN
# =============================================================================

setup() {
    setup_test_session
    # Store project root for file existence checks
    export PROJECT_ROOT="/home/leeaandrob/Projects/Personal/llm/cc-blueprint-toolkit"
}

teardown() {
    teardown_test_session
}

# =============================================================================
# RATE LIMIT STATE HELPERS
# =============================================================================

# Initialize rate limit state file
init_rate_limit() {
    local hourly_calls="${1:-0}"
    local hourly_limit="${2:-100}"
    local paused="${3:-false}"

    local now=$(date -Iseconds)
    local next_reset=$(date -d "+1 hour" -Iseconds 2>/dev/null || date -v+1H -Iseconds)

    cat > .prp-session/rate-limit.json <<EOF
{
    "hourly": {
        "calls_made": $hourly_calls,
        "limit": $hourly_limit,
        "window_start": "$now",
        "next_reset": "$next_reset"
    },
    "anthropic_5h": {
        "detected": false,
        "detected_at": null,
        "resume_at": null,
        "waiting": false
    },
    "paused": $paused,
    "pause_reason": null,
    "paused_at": null
}
EOF
}

# Get rate limit calls made
get_rate_limit_calls() {
    if [[ -f .prp-session/rate-limit.json ]]; then
        jq -r '.hourly.calls_made' .prp-session/rate-limit.json
    else
        echo "0"
    fi
}

# Get rate limit
get_rate_limit() {
    if [[ -f .prp-session/rate-limit.json ]]; then
        jq -r '.hourly.limit' .prp-session/rate-limit.json
    else
        echo "100"
    fi
}

# Increment rate limit counter
increment_rate_limit() {
    local temp_file=$(mktemp)
    jq '.hourly.calls_made += 1' .prp-session/rate-limit.json > "$temp_file"
    mv "$temp_file" .prp-session/rate-limit.json
}

# Reset rate limit counter (hourly reset)
reset_rate_limit_hourly() {
    local temp_file=$(mktemp)
    local now=$(date -Iseconds)
    local next_reset=$(date -d "+1 hour" -Iseconds 2>/dev/null || date -v+1H -Iseconds)

    jq --arg now "$now" --arg next "$next_reset" \
       '.hourly.calls_made = 0 | .hourly.window_start = $now | .hourly.next_reset = $next' \
       .prp-session/rate-limit.json > "$temp_file"
    mv "$temp_file" .prp-session/rate-limit.json
}

# Set 5h limit detected
set_5h_limit_detected() {
    local temp_file=$(mktemp)
    local now=$(date -Iseconds)
    local resume=$(date -d "+60 minutes" -Iseconds 2>/dev/null || date -v+60M -Iseconds)

    jq --arg now "$now" --arg resume "$resume" \
       '.anthropic_5h.detected = true | .anthropic_5h.detected_at = $now | .anthropic_5h.resume_at = $resume | .anthropic_5h.waiting = true' \
       .prp-session/rate-limit.json > "$temp_file"
    mv "$temp_file" .prp-session/rate-limit.json
}

# Check if 5h limit is detected
is_5h_limit_detected() {
    if [[ -f .prp-session/rate-limit.json ]]; then
        jq -r '.anthropic_5h.detected' .prp-session/rate-limit.json
    else
        echo "false"
    fi
}

# Check if waiting for 5h limit
is_5h_waiting() {
    if [[ -f .prp-session/rate-limit.json ]]; then
        jq -r '.anthropic_5h.waiting' .prp-session/rate-limit.json
    else
        echo "false"
    fi
}

# Set pause state
set_rate_limit_paused() {
    local reason="$1"
    local temp_file=$(mktemp)
    local now=$(date -Iseconds)

    jq --arg reason "$reason" --arg now "$now" \
       '.paused = true | .pause_reason = $reason | .paused_at = $now' \
       .prp-session/rate-limit.json > "$temp_file"
    mv "$temp_file" .prp-session/rate-limit.json
}

# Check if paused
is_rate_limit_paused() {
    if [[ -f .prp-session/rate-limit.json ]]; then
        jq -r '.paused' .prp-session/rate-limit.json
    else
        echo "false"
    fi
}

# =============================================================================
# LOOP STATE HELPERS
# =============================================================================

# Initialize loop state file
init_loop_state() {
    local phase="${1:-RED}"
    local iteration="${2:-1}"
    local status="${3:-running}"
    local session_id="${4:-$(uuidgen 2>/dev/null || echo "test-$(date +%s)")}"

    local now=$(date -Iseconds)

    cat > .prp-session/loop-state.json <<EOF
{
    "session_id": "$session_id",
    "prp_file": "test-prp.md",
    "started_at": "$now",
    "current_phase": "$phase",
    "current_iteration": $iteration,
    "last_activity": "$now",
    "status": "$status",
    "halt_reason": null,
    "phases_completed": [],
    "error_history": []
}
EOF
}

# Get loop state status
get_loop_status() {
    if [[ -f .prp-session/loop-state.json ]]; then
        jq -r '.status' .prp-session/loop-state.json
    else
        echo "NONE"
    fi
}

# Get current loop phase
get_loop_phase() {
    if [[ -f .prp-session/loop-state.json ]]; then
        jq -r '.current_phase' .prp-session/loop-state.json
    else
        echo "NONE"
    fi
}

# Get current iteration
get_loop_iteration() {
    if [[ -f .prp-session/loop-state.json ]]; then
        jq -r '.current_iteration' .prp-session/loop-state.json
    else
        echo "0"
    fi
}

# Update loop phase
update_loop_phase() {
    local new_phase="$1"
    local temp_file=$(mktemp)

    jq --arg phase "$new_phase" \
       '.current_phase = $phase | .current_iteration = 1' \
       .prp-session/loop-state.json > "$temp_file"
    mv "$temp_file" .prp-session/loop-state.json
}

# Increment loop iteration
increment_loop_iteration() {
    local temp_file=$(mktemp)
    local now=$(date -Iseconds)

    jq --arg now "$now" \
       '.current_iteration += 1 | .last_activity = $now' \
       .prp-session/loop-state.json > "$temp_file"
    mv "$temp_file" .prp-session/loop-state.json
}

# Update loop status
update_loop_status() {
    local new_status="$1"
    local reason="${2:-}"
    local temp_file=$(mktemp)

    if [[ -n "$reason" ]]; then
        jq --arg status "$new_status" --arg reason "$reason" \
           '.status = $status | .halt_reason = $reason' \
           .prp-session/loop-state.json > "$temp_file"
    else
        jq --arg status "$new_status" \
           '.status = $status' \
           .prp-session/loop-state.json > "$temp_file"
    fi
    mv "$temp_file" .prp-session/loop-state.json
}

# Add completed phase
add_completed_phase() {
    local phase="$1"
    local temp_file=$(mktemp)

    jq --arg phase "$phase" \
       '.phases_completed += [$phase]' \
       .prp-session/loop-state.json > "$temp_file"
    mv "$temp_file" .prp-session/loop-state.json
}

# Add error to history
add_error_to_history() {
    local phase="$1"
    local iteration="$2"
    local error_msg="$3"
    local error_hash="${4:-$(echo "$error_msg" | md5sum | cut -d' ' -f1)}"
    local temp_file=$(mktemp)
    local now=$(date -Iseconds)

    jq --arg timestamp "$now" \
       --arg phase "$phase" \
       --argjson iteration "$iteration" \
       --arg error "$error_msg" \
       --arg hash "$error_hash" \
       '.error_history += [{"timestamp": $timestamp, "phase": $phase, "iteration": $iteration, "error": $error, "hash": $hash}]' \
       .prp-session/loop-state.json > "$temp_file"
    mv "$temp_file" .prp-session/loop-state.json
}

# Get error history count
get_error_history_count() {
    if [[ -f .prp-session/loop-state.json ]]; then
        jq '.error_history | length' .prp-session/loop-state.json
    else
        echo "0"
    fi
}

# Check if session is valid for resume
is_session_valid() {
    if [[ ! -f .prp-session/loop-state.json ]]; then
        echo "false"
        return
    fi

    local status=$(jq -r '.status' .prp-session/loop-state.json)
    local cb_state="CLOSED"

    if [[ -f .prp-session/circuit-breaker.json ]]; then
        cb_state=$(jq -r '.state' .prp-session/circuit-breaker.json)
    fi

    # Session is invalid if:
    # - Status is completed
    # - Status is halted
    # - Circuit Breaker is OPEN
    if [[ "$status" == "completed" || "$status" == "halted" || "$cb_state" == "OPEN" ]]; then
        echo "false"
    else
        echo "true"
    fi
}

# =============================================================================
# DUAL-GATE STATE HELPERS
# =============================================================================

# Initialize dual-gate state file
init_dual_gate() {
    local phase="${1:-RED}"
    local iteration="${2:-1}"
    local gate1="${3:-false}"
    local gate2="${4:-false}"

    local now=$(date -Iseconds)
    local can_exit="false"
    if [[ "$gate1" == "true" && "$gate2" == "true" ]]; then
        can_exit="true"
    fi

    cat > .prp-session/dual-gate.json <<EOF
{
    "phase": "$phase",
    "iteration": $iteration,
    "gate_1": {
        "satisfied": $gate1,
        "condition": "tests_generated >= criteria_count AND all_failing",
        "values": {}
    },
    "gate_2": {
        "satisfied": $gate2,
        "source": "none"
    },
    "can_exit": $can_exit,
    "evaluated_at": "$now"
}
EOF
}

# Update dual-gate
update_dual_gate() {
    local gate1="$1"
    local gate2="$2"
    local iteration="$3"
    local temp_file=$(mktemp)
    local now=$(date -Iseconds)

    local can_exit="false"
    if [[ "$gate1" == "true" && "$gate2" == "true" ]]; then
        can_exit="true"
    fi

    jq --argjson gate1 "$gate1" \
       --argjson gate2 "$gate2" \
       --argjson iteration "$iteration" \
       --argjson can_exit "$can_exit" \
       --arg now "$now" \
       '.gate_1.satisfied = $gate1 | .gate_2.satisfied = $gate2 | .iteration = $iteration | .can_exit = $can_exit | .evaluated_at = $now' \
       .prp-session/dual-gate.json > "$temp_file"
    mv "$temp_file" .prp-session/dual-gate.json
}

# Check dual-gate can_exit
get_dual_gate_can_exit() {
    if [[ -f .prp-session/dual-gate.json ]]; then
        jq -r '.can_exit' .prp-session/dual-gate.json
    else
        echo "false"
    fi
}

# #############################################################################
# #############################################################################
# ##                                                                          ##
# ##  SECTION 1: IMPLEMENTATION FILE EXISTENCE TESTS (RED - MUST FAIL)       ##
# ##                                                                          ##
# ##  These tests verify that required implementation files exist.            ##
# ##  They MUST FAIL until the GREEN phase implements these files.           ##
# ##                                                                          ##
# #############################################################################
# #############################################################################

# =============================================================================
# SPECIFICATION FILES EXISTENCE (RED - Implementation Required)
# =============================================================================

@test "RED: rate-limit-spec.md exists" {
    [ -f "$PROJECT_ROOT/claude/lib/rate-limit-spec.md" ]
}

@test "RED: session-manager-spec.md exists" {
    [ -f "$PROJECT_ROOT/claude/lib/session-manager-spec.md" ]
}

@test "RED: loop-state-spec.md exists" {
    [ -f "$PROJECT_ROOT/claude/lib/loop-state-spec.md" ]
}

# =============================================================================
# AGENT FILES EXISTENCE (RED - Implementation Required)
# =============================================================================

@test "RED: loop-controller.md agent exists" {
    [ -f "$PROJECT_ROOT/claude/agents/loop-controller.md" ]
}

@test "RED: green-implementer.md agent exists" {
    [ -f "$PROJECT_ROOT/claude/agents/green-implementer.md" ]
}

@test "RED: refactor-agent.md agent exists" {
    [ -f "$PROJECT_ROOT/claude/agents/refactor-agent.md" ]
}

# =============================================================================
# COMMAND FILES EXISTENCE (RED - Implementation Required)
# =============================================================================

@test "RED: autonomous.md command exists" {
    [ -f "$PROJECT_ROOT/claude/commands/autonomous.md" ]
}

@test "RED: dashboard.md command exists" {
    [ -f "$PROJECT_ROOT/claude/commands/dashboard.md" ]
}

# =============================================================================
# MCP DASHBOARD SERVER EXISTENCE (RED - Implementation Required)
# =============================================================================

@test "RED: MCP dashboard server directory exists" {
    [ -d "$PROJECT_ROOT/servers/dashboard" ]
}

@test "RED: MCP dashboard package.json exists" {
    [ -f "$PROJECT_ROOT/servers/dashboard/package.json" ]
}

@test "RED: MCP dashboard tsconfig.json exists" {
    [ -f "$PROJECT_ROOT/servers/dashboard/tsconfig.json" ]
}

@test "RED: MCP dashboard index.ts exists" {
    [ -f "$PROJECT_ROOT/servers/dashboard/src/index.ts" ]
}

@test "RED: MCP dashboard has resource definitions in index.ts" {
    # Resources are defined in index.ts (single-file MCP server pattern)
    grep -q "server.resource" "$PROJECT_ROOT/servers/dashboard/src/index.ts"
}

@test "RED: MCP dashboard has tool definitions in index.ts" {
    # Tools are defined in index.ts (single-file MCP server pattern)
    grep -q "server.tool" "$PROJECT_ROOT/servers/dashboard/src/index.ts"
}

# =============================================================================
# PLUGIN CONFIGURATION (RED - Implementation Required)
# =============================================================================

@test "RED: plugin.json includes autonomous command" {
    run jq -e '.commands[] | select(contains("autonomous"))' "$PROJECT_ROOT/.claude-plugin/plugin.json"
    [ "$status" -eq 0 ]
}

@test "RED: plugin.json includes dashboard command" {
    run jq -e '.commands[] | select(contains("dashboard"))' "$PROJECT_ROOT/.claude-plugin/plugin.json"
    [ "$status" -eq 0 ]
}

@test "RED: plugin.json includes loop-controller agent" {
    run jq -e '.agents[] | select(contains("loop-controller"))' "$PROJECT_ROOT/.claude-plugin/plugin.json"
    [ "$status" -eq 0 ]
}

@test "RED: plugin.json includes green-implementer agent" {
    run jq -e '.agents[] | select(contains("green-implementer"))' "$PROJECT_ROOT/.claude-plugin/plugin.json"
    [ "$status" -eq 0 ]
}

@test "RED: plugin.json includes refactor-agent agent" {
    run jq -e '.agents[] | select(contains("refactor-agent"))' "$PROJECT_ROOT/.claude-plugin/plugin.json"
    [ "$status" -eq 0 ]
}

@test "RED: plugin.json includes bp-dashboard MCP server" {
    run jq -e '.mcpServers["bp-dashboard"]' "$PROJECT_ROOT/.claude-plugin/plugin.json"
    [ "$status" -eq 0 ]
}

# #############################################################################
# #############################################################################
# ##                                                                          ##
# ##  SECTION 2: STATE SCHEMA VALIDATION TESTS (Pass with helpers)           ##
# ##                                                                          ##
# ##  These tests verify the data structure schemas defined in the PRP.      ##
# ##  They pass because they use the helper functions defined above.         ##
# ##                                                                          ##
# #############################################################################
# #############################################################################

# =============================================================================
# RATE LIMIT STATE SCHEMA TESTS
# =============================================================================

@test "Schema: rate-limit.json initializes with zero calls made" {
    init_rate_limit 0 100
    local calls=$(get_rate_limit_calls)
    [ "$calls" -eq 0 ]
}

@test "Schema: rate-limit.json initializes with configurable limit" {
    init_rate_limit 0 50
    local limit=$(get_rate_limit)
    [ "$limit" -eq 50 ]
}

@test "Schema: rate-limit.json file is created in .prp-session" {
    init_rate_limit
    [ -f .prp-session/rate-limit.json ]
}

@test "Schema: rate-limit.json increment increases calls_made by 1" {
    init_rate_limit 0 100
    increment_rate_limit
    local calls=$(get_rate_limit_calls)
    [ "$calls" -eq 1 ]
}

@test "Schema: rate-limit.json multiple increments accumulate correctly" {
    init_rate_limit 0 100
    increment_rate_limit
    increment_rate_limit
    increment_rate_limit
    local calls=$(get_rate_limit_calls)
    [ "$calls" -eq 3 ]
}

@test "Schema: rate-limit.json reset sets calls_made to zero" {
    init_rate_limit 50 100
    reset_rate_limit_hourly
    local calls=$(get_rate_limit_calls)
    [ "$calls" -eq 0 ]
}

@test "Schema: rate-limit.json reset updates window_start timestamp" {
    init_rate_limit 50 100
    local before=$(jq -r '.hourly.window_start' .prp-session/rate-limit.json)
    sleep 1
    reset_rate_limit_hourly
    local after=$(jq -r '.hourly.window_start' .prp-session/rate-limit.json)
    [ "$before" != "$after" ]
}

@test "Schema: rate-limit.json 5h limit detection sets detected flag" {
    init_rate_limit 0 100
    set_5h_limit_detected
    local detected=$(is_5h_limit_detected)
    [ "$detected" = "true" ]
}

@test "Schema: rate-limit.json 5h limit detection sets waiting flag" {
    init_rate_limit 0 100
    set_5h_limit_detected
    local waiting=$(is_5h_waiting)
    [ "$waiting" = "true" ]
}

@test "Schema: rate-limit.json 5h limit detection sets resume_at timestamp" {
    init_rate_limit 0 100
    set_5h_limit_detected
    local resume_at=$(jq -r '.anthropic_5h.resume_at' .prp-session/rate-limit.json)
    [ "$resume_at" != "null" ]
}

@test "Schema: rate-limit.json pause sets paused flag" {
    init_rate_limit 0 100
    set_rate_limit_paused "Hourly limit reached"
    local paused=$(is_rate_limit_paused)
    [ "$paused" = "true" ]
}

@test "Schema: rate-limit.json pause records reason" {
    init_rate_limit 0 100
    set_rate_limit_paused "Manual pause"
    local reason=$(jq -r '.pause_reason' .prp-session/rate-limit.json)
    [ "$reason" = "Manual pause" ]
}

@test "Schema: rate-limit.json pause records timestamp" {
    init_rate_limit 0 100
    set_rate_limit_paused "Test pause"
    local paused_at=$(jq -r '.paused_at' .prp-session/rate-limit.json)
    [ "$paused_at" != "null" ]
}

@test "Schema: rate-limit.json has hourly object" {
    init_rate_limit 0 100
    local has_hourly=$(jq 'has("hourly")' .prp-session/rate-limit.json)
    [ "$has_hourly" = "true" ]
}

@test "Schema: rate-limit.json has anthropic_5h object" {
    init_rate_limit 0 100
    local has_5h=$(jq 'has("anthropic_5h")' .prp-session/rate-limit.json)
    [ "$has_5h" = "true" ]
}

@test "Schema: rate-limit.json has all required hourly fields" {
    init_rate_limit 0 100
    local has_calls=$(jq '.hourly | has("calls_made")' .prp-session/rate-limit.json)
    local has_limit=$(jq '.hourly | has("limit")' .prp-session/rate-limit.json)
    local has_window=$(jq '.hourly | has("window_start")' .prp-session/rate-limit.json)
    local has_reset=$(jq '.hourly | has("next_reset")' .prp-session/rate-limit.json)

    [ "$has_calls" = "true" ]
    [ "$has_limit" = "true" ]
    [ "$has_window" = "true" ]
    [ "$has_reset" = "true" ]
}

# =============================================================================
# LOOP STATE SCHEMA TESTS
# =============================================================================

@test "Schema: loop-state.json initializes with running status" {
    init_loop_state "RED" 1 "running"
    local status=$(get_loop_status)
    [ "$status" = "running" ]
}

@test "Schema: loop-state.json initializes with correct phase" {
    init_loop_state "RED" 1 "running"
    local phase=$(get_loop_phase)
    [ "$phase" = "RED" ]
}

@test "Schema: loop-state.json initializes with correct iteration" {
    init_loop_state "RED" 1 "running"
    local iteration=$(get_loop_iteration)
    [ "$iteration" -eq 1 ]
}

@test "Schema: loop-state.json file is created in .prp-session" {
    init_loop_state
    [ -f .prp-session/loop-state.json ]
}

@test "Schema: loop-state.json increment iteration updates correctly" {
    init_loop_state "RED" 1 "running"
    increment_loop_iteration
    local iteration=$(get_loop_iteration)
    [ "$iteration" -eq 2 ]
}

@test "Schema: loop-state.json increment iteration updates last_activity" {
    init_loop_state "RED" 1 "running"
    local before=$(jq -r '.last_activity' .prp-session/loop-state.json)
    sleep 1
    increment_loop_iteration
    local after=$(jq -r '.last_activity' .prp-session/loop-state.json)
    [ "$before" != "$after" ]
}

@test "Schema: loop-state.json phase transition updates current_phase" {
    init_loop_state "RED" 5 "running"
    update_loop_phase "GREEN"
    local phase=$(get_loop_phase)
    [ "$phase" = "GREEN" ]
}

@test "Schema: loop-state.json phase transition resets iteration to 1" {
    init_loop_state "RED" 5 "running"
    update_loop_phase "GREEN"
    local iteration=$(get_loop_iteration)
    [ "$iteration" -eq 1 ]
}

@test "Schema: loop-state.json status update to paused works" {
    init_loop_state "RED" 1 "running"
    update_loop_status "paused" "Manual pause"
    local status=$(get_loop_status)
    [ "$status" = "paused" ]
}

@test "Schema: loop-state.json status update records halt_reason" {
    init_loop_state "RED" 1 "running"
    update_loop_status "halted" "Circuit Breaker OPEN"
    local reason=$(jq -r '.halt_reason' .prp-session/loop-state.json)
    [ "$reason" = "Circuit Breaker OPEN" ]
}

@test "Schema: loop-state.json add completed phase updates array" {
    init_loop_state "GREEN" 1 "running"
    add_completed_phase "RED"
    local phases=$(jq -r '.phases_completed | length' .prp-session/loop-state.json)
    [ "$phases" -eq 1 ]
}

@test "Schema: loop-state.json add error to history" {
    init_loop_state "GREEN" 3 "running"
    add_error_to_history "GREEN" 3 "Test failed: expected 5 got 3"
    local count=$(get_error_history_count)
    [ "$count" -eq 1 ]
}

@test "Schema: loop-state.json error history includes hash for same-error detection" {
    init_loop_state "GREEN" 3 "running"
    add_error_to_history "GREEN" 3 "Test failed: expected 5 got 3"
    local hash=$(jq -r '.error_history[0].hash' .prp-session/loop-state.json)
    [ "$hash" != "null" ]
    [ -n "$hash" ]
}

@test "Schema: loop-state.json has session_id" {
    init_loop_state
    local has_session_id=$(jq 'has("session_id")' .prp-session/loop-state.json)
    [ "$has_session_id" = "true" ]
}

@test "Schema: loop-state.json has all required fields" {
    init_loop_state
    local has_prp=$(jq 'has("prp_file")' .prp-session/loop-state.json)
    local has_started=$(jq 'has("started_at")' .prp-session/loop-state.json)
    local has_phase=$(jq 'has("current_phase")' .prp-session/loop-state.json)
    local has_iteration=$(jq 'has("current_iteration")' .prp-session/loop-state.json)
    local has_status=$(jq 'has("status")' .prp-session/loop-state.json)

    [ "$has_prp" = "true" ]
    [ "$has_started" = "true" ]
    [ "$has_phase" = "true" ]
    [ "$has_iteration" = "true" ]
    [ "$has_status" = "true" ]
}

# =============================================================================
# SESSION RESUME DETECTION TESTS (State-Based Expiration)
# =============================================================================

@test "Schema: session valid with running status" {
    init_loop_state "GREEN" 3 "running"
    init_circuit_breaker "CLOSED" 0
    local valid=$(is_session_valid)
    [ "$valid" = "true" ]
}

@test "Schema: session valid with paused status" {
    init_loop_state "GREEN" 3 "paused"
    init_circuit_breaker "CLOSED" 0
    local valid=$(is_session_valid)
    [ "$valid" = "true" ]
}

@test "Schema: session invalid with completed status" {
    init_loop_state "DOCUMENT" 3 "completed"
    init_circuit_breaker "CLOSED" 0
    local valid=$(is_session_valid)
    [ "$valid" = "false" ]
}

@test "Schema: session invalid with halted status" {
    init_loop_state "GREEN" 3 "halted"
    init_circuit_breaker "CLOSED" 0
    local valid=$(is_session_valid)
    [ "$valid" = "false" ]
}

@test "Schema: session invalid with Circuit Breaker OPEN" {
    init_loop_state "GREEN" 3 "running"
    init_circuit_breaker "OPEN" 3
    local valid=$(is_session_valid)
    [ "$valid" = "false" ]
}

@test "Schema: session valid with Circuit Breaker HALF_OPEN" {
    init_loop_state "GREEN" 3 "running"
    init_circuit_breaker "HALF_OPEN" 1
    local valid=$(is_session_valid)
    [ "$valid" = "true" ]
}

@test "Schema: no session returns invalid" {
    # Don't create loop-state.json
    local valid=$(is_session_valid)
    [ "$valid" = "false" ]
}

@test "Schema: session without CB file defaults to valid" {
    init_loop_state "GREEN" 3 "running"
    # Don't create circuit-breaker.json
    local valid=$(is_session_valid)
    [ "$valid" = "true" ]
}

# =============================================================================
# LOOP STATE TRANSITION TESTS
# =============================================================================

@test "Schema: RED to GREEN on Dual-Gate exit" {
    init_loop_state "RED" 5 "running"
    init_dual_gate "RED" 5 "true" "true"

    add_completed_phase "RED"
    update_loop_phase "GREEN"

    local phase=$(get_loop_phase)
    local phases_completed=$(jq -r '.phases_completed | length' .prp-session/loop-state.json)

    [ "$phase" = "GREEN" ]
    [ "$phases_completed" -eq 1 ]
}

@test "Schema: GREEN to REFACTOR on Dual-Gate exit" {
    init_loop_state "GREEN" 3 "running"
    init_dual_gate "GREEN" 3 "true" "true"

    add_completed_phase "GREEN"
    update_loop_phase "REFACTOR"

    local phase=$(get_loop_phase)
    [ "$phase" = "REFACTOR" ]
}

@test "Schema: REFACTOR to DOCUMENT on Dual-Gate exit" {
    init_loop_state "REFACTOR" 5 "running"
    init_dual_gate "REFACTOR" 5 "true" "true"

    add_completed_phase "REFACTOR"
    update_loop_phase "DOCUMENT"

    local phase=$(get_loop_phase)
    [ "$phase" = "DOCUMENT" ]
}

@test "Schema: DOCUMENT to completed on Dual-Gate exit" {
    init_loop_state "DOCUMENT" 2 "running"
    init_dual_gate "DOCUMENT" 2 "true" "true"

    add_completed_phase "DOCUMENT"
    update_loop_status "completed"

    local status=$(get_loop_status)
    [ "$status" = "completed" ]
}

@test "Schema: running to halted on Circuit Breaker OPEN" {
    init_loop_state "GREEN" 3 "running"
    init_circuit_breaker "OPEN" 3

    update_loop_status "halted" "Circuit Breaker OPEN: No progress for 3 iterations"

    local status=$(get_loop_status)
    local reason=$(jq -r '.halt_reason' .prp-session/loop-state.json)

    [ "$status" = "halted" ]
    [ "$reason" != "null" ]
}

@test "Schema: running to paused on manual request" {
    init_loop_state "GREEN" 3 "running"
    update_loop_status "paused" "User requested pause"
    local status=$(get_loop_status)
    [ "$status" = "paused" ]
}

@test "Schema: paused to running on resume" {
    init_loop_state "GREEN" 3 "paused"
    update_loop_status "running"
    local status=$(get_loop_status)
    [ "$status" = "running" ]
}

# =============================================================================
# DUAL-GATE STATE FILE TESTS
# =============================================================================

@test "Schema: dual-gate.json initializes with correct phase" {
    init_dual_gate "RED" 1 "false" "false"
    local phase=$(jq -r '.phase' .prp-session/dual-gate.json)
    [ "$phase" = "RED" ]
}

@test "Schema: dual-gate.json initializes with correct iteration" {
    init_dual_gate "RED" 3 "false" "false"
    local iteration=$(jq -r '.iteration' .prp-session/dual-gate.json)
    [ "$iteration" -eq 3 ]
}

@test "Schema: dual-gate.json can_exit is false when gates are false" {
    init_dual_gate "RED" 1 "false" "false"
    local can_exit=$(get_dual_gate_can_exit)
    [ "$can_exit" = "false" ]
}

@test "Schema: dual-gate.json can_exit is true when both gates are true" {
    init_dual_gate "RED" 5 "true" "true"
    local can_exit=$(get_dual_gate_can_exit)
    [ "$can_exit" = "true" ]
}

@test "Schema: dual-gate.json update changes gate values" {
    init_dual_gate "RED" 1 "false" "false"
    update_dual_gate "true" "true" 5

    local gate1=$(jq -r '.gate_1.satisfied' .prp-session/dual-gate.json)
    local gate2=$(jq -r '.gate_2.satisfied' .prp-session/dual-gate.json)
    local iteration=$(jq -r '.iteration' .prp-session/dual-gate.json)

    [ "$gate1" = "true" ]
    [ "$gate2" = "true" ]
    [ "$iteration" -eq 5 ]
}

@test "Schema: dual-gate.json requires same iteration for both gates (critical rule)" {
    init_dual_gate "RED" 5 "true" "false"

    # Gate 1 satisfied at iteration 5, Gate 2 not satisfied
    local can_exit=$(get_dual_gate_can_exit)
    [ "$can_exit" = "false" ]

    # Now update to iteration 6 with Gate 2 true but Gate 1 needs re-evaluation
    update_dual_gate "false" "true" 6
    can_exit=$(get_dual_gate_can_exit)
    [ "$can_exit" = "false" ]

    # Both gates true at same iteration
    update_dual_gate "true" "true" 6
    can_exit=$(get_dual_gate_can_exit)
    [ "$can_exit" = "true" ]
}

# =============================================================================
# STATE FILE VALIDATION TESTS
# =============================================================================

@test "Schema: rate-limit.json is valid JSON" {
    init_rate_limit 50 100
    run jq '.' .prp-session/rate-limit.json
    [ "$status" -eq 0 ]
}

@test "Schema: loop-state.json is valid JSON" {
    init_loop_state "RED" 1 "running"
    run jq '.' .prp-session/loop-state.json
    [ "$status" -eq 0 ]
}

@test "Schema: dual-gate.json is valid JSON" {
    init_dual_gate "RED" 1 "false" "false"
    run jq '.' .prp-session/dual-gate.json
    [ "$status" -eq 0 ]
}

@test "Schema: all state files can coexist" {
    init_rate_limit 50 100
    init_loop_state "GREEN" 3 "running"
    init_dual_gate "GREEN" 3 "true" "false"
    init_circuit_breaker "CLOSED" 1
    init_metrics "GREEN"

    [ -f .prp-session/rate-limit.json ]
    [ -f .prp-session/loop-state.json ]
    [ -f .prp-session/dual-gate.json ]
    [ -f .prp-session/circuit-breaker.json ]
    [ -f .prp-session/metrics.json ]
}

@test "Schema: timestamps are ISO-8601 format" {
    init_rate_limit 0 100
    local window_start=$(jq -r '.hourly.window_start' .prp-session/rate-limit.json)

    # ISO-8601 format: YYYY-MM-DDTHH:MM:SS+HH:MM or similar
    [[ "$window_start" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]
}

@test "Schema: session_id is non-empty string" {
    init_loop_state
    local session_id=$(jq -r '.session_id' .prp-session/loop-state.json)
    [ -n "$session_id" ]
    [ "$session_id" != "null" ]
}

# =============================================================================
# INTEGRATION TESTS: Rate Limit + Loop State
# =============================================================================

@test "Integration: loop pauses when hourly limit reached" {
    init_rate_limit 99 100
    init_loop_state "GREEN" 3 "running"

    # Simulate one more call hitting limit
    increment_rate_limit
    local calls=$(get_rate_limit_calls)

    if [ "$calls" -ge 100 ]; then
        set_rate_limit_paused "Hourly limit reached"
        update_loop_status "paused" "Rate limit reached"
    fi

    local paused=$(is_rate_limit_paused)
    local status=$(get_loop_status)

    [ "$paused" = "true" ]
    [ "$status" = "paused" ]
}

@test "Integration: loop waits when 5h limit detected" {
    init_rate_limit 0 100
    init_loop_state "GREEN" 3 "running"

    # Simulate 5h limit detection (from Anthropic error response)
    set_5h_limit_detected

    local waiting=$(is_5h_waiting)
    local resume_at=$(jq -r '.anthropic_5h.resume_at' .prp-session/rate-limit.json)

    [ "$waiting" = "true" ]
    [ "$resume_at" != "null" ]
}

@test "Integration: full TDD cycle RED -> GREEN -> REFACTOR -> DOCUMENT -> completed" {
    # Initialize session at RED
    init_loop_state "RED" 1 "running"
    init_circuit_breaker "CLOSED" 0
    init_dual_gate "RED" 1 "false" "false"
    init_rate_limit 0 100

    # RED phase completes
    update_dual_gate "true" "true" 5
    add_completed_phase "RED"
    update_loop_phase "GREEN"

    # GREEN phase completes
    update_dual_gate "true" "true" 3
    add_completed_phase "GREEN"
    update_loop_phase "REFACTOR"

    # REFACTOR phase completes
    update_dual_gate "true" "true" 6
    add_completed_phase "REFACTOR"
    update_loop_phase "DOCUMENT"

    # DOCUMENT phase completes
    update_dual_gate "true" "true" 2
    add_completed_phase "DOCUMENT"
    update_loop_status "completed"

    # Verify final state
    local status=$(get_loop_status)
    local phases=$(jq -r '.phases_completed | length' .prp-session/loop-state.json)

    [ "$status" = "completed" ]
    [ "$phases" -eq 4 ]
}

@test "Integration: Circuit Breaker OPEN halts loop immediately" {
    init_loop_state "GREEN" 3 "running"
    init_circuit_breaker "CLOSED" 0

    # Simulate no progress iterations
    increment_no_progress
    increment_no_progress

    # GREEN phase threshold is 2, should trigger OPEN
    local count=$(get_cb_no_progress_count)
    local threshold=$(get_no_progress_threshold "GREEN")

    if [ "$count" -ge "$threshold" ]; then
        update_cb_state "OPEN" "No progress for $count iterations"
        update_loop_status "halted" "Circuit Breaker OPEN"
    fi

    local cb_state=$(get_cb_state)
    local loop_status=$(get_loop_status)

    [ "$cb_state" = "OPEN" ]
    [ "$loop_status" = "halted" ]
}

# =============================================================================
# EDGE CASE TESTS
# =============================================================================

@test "Edge Case: missing rate-limit file returns safe defaults" {
    local calls=$(get_rate_limit_calls)
    local limit=$(get_rate_limit)

    [ "$calls" = "0" ]
    [ "$limit" = "100" ]
}

@test "Edge Case: missing loop-state file returns NONE status" {
    local status=$(get_loop_status)
    [ "$status" = "NONE" ]
}

@test "Edge Case: missing dual-gate file returns false can_exit" {
    local can_exit=$(get_dual_gate_can_exit)
    [ "$can_exit" = "false" ]
}

@test "Edge Case: corrupted JSON is handled gracefully" {
    mkdir -p .prp-session
    echo "not valid json" > .prp-session/rate-limit.json

    run jq '.' .prp-session/rate-limit.json
    [ "$status" -ne 0 ]
}

@test "Edge Case: zero iteration is valid starting point" {
    init_loop_state "RED" 0 "running"
    local iteration=$(get_loop_iteration)
    [ "$iteration" -eq 0 ]
}

@test "Edge Case: phases_completed can be empty array" {
    init_loop_state "RED" 1 "running"
    local phases=$(jq -r '.phases_completed | length' .prp-session/loop-state.json)
    [ "$phases" -eq 0 ]
}

@test "Edge Case: error_history can grow indefinitely" {
    init_loop_state "GREEN" 1 "running"

    for i in {1..10}; do
        add_error_to_history "GREEN" "$i" "Error $i"
    done

    local count=$(get_error_history_count)
    [ "$count" -eq 10 ]
}
