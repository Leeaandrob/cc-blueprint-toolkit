---
description: Start autonomous TDD E2E execution with loop engine, rate limiting, and Circuit Breaker protection
argument-hint: [path/to/prp-file.md]
allowed-tools: TodoWrite, Read, Write, Edit, Bash, Glob, Grep, Task
---

# Autonomous Execution Command

Start autonomous development execution for a PRP file. The loop engine continuously executes TDD phases (RED → GREEN → REFACTOR → DOCUMENT) without human intervention, protected by rate limiting and Circuit Breaker patterns.

## PRP File: $ARGUMENTS

## Features

- **Autonomous loop**: Continuous execution until completion or halt
- **Rate limiting**: Protects against API overuse (hourly + 5h limit)
- **Circuit Breaker**: Prevents infinite loops on no-progress
- **Session resume**: Continue after interruption
- **Real-time status**: PRP_PHASE_STATUS blocks for observability

## Execution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    /bp:autonomous FLOW                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. SESSION DETECTION                                           │
│     ├── Check for .prp-session/loop-state.json                 │
│     ├── Validate session (state-based expiration)               │
│     └── Offer resume if valid session exists                    │
│                                                                  │
│  2. INITIALIZATION                                               │
│     ├── Create/load session state                               │
│     ├── Initialize Circuit Breaker (CLOSED)                     │
│     ├── Initialize rate limit tracking                          │
│     └── Load PRP and extract acceptance criteria                │
│                                                                  │
│  3. SPAWN LOOP CONTROLLER                                        │
│     ├── Task(subagent_type: "bp:loop-controller")              │
│     ├── Pass: prp_file, session_id, resume_state               │
│     └── Monitor via TaskOutput                                  │
│                                                                  │
│  4. HANDLE INTERRUPTION                                          │
│     ├── Save session state on Ctrl+C                           │
│     ├── Preserve for resume                                     │
│     └── Graceful shutdown                                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Session Directory

Sessions are stored in a **central directory** for multi-terminal dashboard monitoring:

```yaml
session_directory:
  base: ~/.bp-sessions/
  project: {derived from current directory name or PRP file}
  full_path: ~/.bp-sessions/{project-name}/

  # Examples:
  # Working in ~/projects/my-app → ~/.bp-sessions/my-app/
  # Working in ~/work/api-service → ~/.bp-sessions/api-service/

  # Environment variable override:
  # export PRP_SESSION_DIR=~/.bp-sessions/custom-name
```

**Why central?** Enables the `/bp:dashboard` web UI to monitor all active sessions from any terminal.

## Session Detection

Before starting, check for existing sessions:

```yaml
detection:
  1. DETERMINE: session directory path
     - Use PRP_SESSION_DIR env var if set
     - Otherwise: ~/.bp-sessions/{basename of current directory}
  2. CHECK: {session_dir}/loop-state.json exists
  3. IF exists:
     - LOAD: session state
     - VALIDATE: state integrity
     - CHECK: expiration conditions
       - Circuit Breaker OPEN → expired
       - PRP complete → expired
       - State corrupted → expired
       - PRP mismatch → expired
     - IF valid:
         DISPLAY: session summary
         PROMPT: "[R]esume, [N]ew, [A]bort"
     - ELSE:
         OFFER: reset or abort
  4. IF not exists:
     - CREATE: new session in central directory
```

## Session Resume Prompt

When a valid previous session is found:

```
╔════════════════════════════════════════════════════════════╗
║               PREVIOUS SESSION DETECTED                     ║
╠════════════════════════════════════════════════════════════╣
║                                                             ║
║  Session ID:  a1b2c3d4-...                                 ║
║  PRP:         $ARGUMENTS                                   ║
║  Phase:       GREEN                                        ║
║  Iteration:   5                                            ║
║  Last Active: 32 minutes ago                               ║
║  Status:      PAUSED (User interrupt)                      ║
║                                                             ║
║  Progress:                                                  ║
║  ├── RED:      ✅ Complete (10 tests generated)            ║
║  └── GREEN:    ⏳ In progress (6/10 tests passing)         ║
║                                                             ║
╠════════════════════════════════════════════════════════════╣
║  [R]esume  - Continue from where you left off              ║
║  [N]ew     - Start fresh (discards progress)               ║
║  [A]bort   - Cancel execution                              ║
╚════════════════════════════════════════════════════════════╝
```

## New Session Initialization

```yaml
create_session:
  1. GENERATE: session_id (UUID v4)
  2. DETERMINE: session directory
     - Default: ~/.bp-sessions/{basename of cwd}/
     - Override: PRP_SESSION_DIR environment variable
  3. CREATE: {session_dir}/ directory (mkdir -p)
  4. INITIALIZE files:
     loop-state.json:
       session_id: {generated}
       prp_file: $ARGUMENTS
       started_at: {now}
       current_phase: "RED"
       current_iteration: 0
       status: "running"
       phases_completed: []
       error_history: []

     circuit-breaker.json:
       state: "CLOSED"
       no_progress_count: 0
       same_error_count: 0
       last_error_hash: null
       opened_at: null
       open_reason: null
       history: []

     rate-limit.json:
       hourly:
         calls_made: 0
         limit: 100
         window_start: {now}
         next_reset: {now + 60min}
       anthropic_5h:
         detected: false
         detected_at: null
         resume_at: null
         waiting: false
       paused: false
       pause_reason: null
       paused_at: null

     metrics.json:
       session_id: {generated}
       prp_file: $ARGUMENTS
       started_at: {now}
       current_phase: "RED"
       phases: {}
```

## Spawn Loop Controller

```yaml
spawn_controller:
  tool: Task
  parameters:
    subagent_type: "bp:loop-controller"
    prompt: |
      Execute autonomous TDD E2E workflow for PRP at: $ARGUMENTS

      Session ID: {session_id}
      Resume: {is_resume}
      Starting Phase: {current_phase}
      Starting Iteration: {current_iteration}

      Follow the loop-controller agent instructions to:
      1. Check rate limits before each iteration
      2. Check Circuit Breaker state
      3. Spawn appropriate phase agent
      4. Monitor progress via TaskOutput
      5. Update metrics and Circuit Breaker
      6. Evaluate Dual-Gate exit conditions
      7. Transition phases when conditions met
      8. Emit PRP_PHASE_STATUS after each iteration

      Continue until all phases complete or halt condition.
```

## Progress Display

During execution, show real-time status:

```
╔══════════════════════════════════════════════════════════════╗
║               AUTONOMOUS EXECUTION IN PROGRESS                ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  PRP:         autonomous-loop-engine-dashboard.md            ║
║  Phase:       GREEN 🟢                                       ║
║  Iteration:   5                                              ║
║  Status:      Running                                        ║
║                                                               ║
║  Tests:       6/10 passing                                   ║
║  Progress:    ████████████░░░░░░░░ 60%                       ║
║                                                               ║
║  Rate Limit:  45/100 calls this hour                         ║
║  CB State:    CLOSED ✓                                       ║
║                                                               ║
║  Press Ctrl+C to pause (session will be saved)               ║
╚══════════════════════════════════════════════════════════════╝
```

## Interruption Handling

When user presses Ctrl+C or terminal closes:

```yaml
graceful_shutdown:
  1. CATCH: interrupt signal
  2. UPDATE: loop-state.json
     - status: "paused"
     - pause_reason: "User interrupt"
     - paused_at: {now}
  3. SAVE: all state files
  4. DISPLAY:
     "Session saved. Resume with: /bp:autonomous $ARGUMENTS"
  5. EXIT: cleanly
```

## Completion Report

When all phases complete successfully:

```
╔══════════════════════════════════════════════════════════════╗
║                  AUTONOMOUS EXECUTION COMPLETE                ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  🎉 SUCCESS - All TDD phases completed!                      ║
║                                                               ║
║  PRP:         autonomous-loop-engine-dashboard.md            ║
║  Duration:    2h 15m                                         ║
║  Total Iterations: 23                                        ║
║                                                               ║
║  Phase Summary:                                               ║
║  ├── RED:      ✅ 2 iterations, 10 tests generated          ║
║  ├── GREEN:    ✅ 15 iterations, all tests passing          ║
║  ├── REFACTOR: ✅ 4 iterations, 6 patterns applied          ║
║  └── DOCUMENT: ✅ 2 iterations, 5 docs generated            ║
║                                                               ║
║  Circuit Breaker: No incidents                               ║
║  Rate Limit: 87 total API calls                              ║
║                                                               ║
║  Files Generated:                                            ║
║  ├── tests/e2e/feature.spec.ts                              ║
║  ├── src/services/*.ts                                       ║
║  └── docs/architecture/*.md                                  ║
║                                                               ║
╚══════════════════════════════════════════════════════════════╝
```

## Error Handling

### Circuit Breaker Open

```yaml
when: Circuit Breaker opens
display:
  "⚠️ CIRCUIT BREAKER OPEN

  Phase: GREEN
  Reason: No progress for 2 iterations
  Tests passing: 6/10 (unchanged)

  Options:
  [R]eset and retry current approach
  [S]kip phase (mark complete with warnings)
  [A]bort execution
  [M]odify approach (provide new guidance)"

action: Wait for user selection, handle accordingly
```

### Rate Limit Reached

```yaml
when: Hourly limit reached
display:
  "⏸️ RATE LIMIT REACHED

  Calls this hour: 100/100
  Reset in: 23m 45s

  Options:
  [W]ait for reset (recommended)
  [C]ontinue anyway (may cause errors)
  [A]bort execution"

action: Wait for user selection
```

### 5h Limit Detected

```yaml
when: Anthropic 5h limit detected
display:
  "🚫 ANTHROPIC 5H LIMIT DETECTED

  Auto-waiting until: 11:30 AM (45m remaining)
  Session will resume automatically.

  (No action required)"

action: Auto-wait, then continue
```

## Usage Examples

### Start New Execution

```
/bp:autonomous docs/PRPs/2026-01-16-feature.md
```

### Resume Previous Session

```
/bp:autonomous docs/PRPs/2026-01-16-feature.md
# Detects previous session, offers resume
```

### Check Status During Execution

```
/bp:dashboard
# Shows current loop state, metrics, rate limits
```

## Related Commands

- `/bp:dashboard` - View current execution status
- `/bp:execute-prp` - Manual (non-autonomous) PRP execution
- `/bp:generate-prp` - Create a new PRP document

## Specifications Reference

- `claude/lib/rate-limit-spec.md` - Rate limiting behavior
- `claude/lib/session-manager-spec.md` - Session lifecycle
- `claude/lib/loop-state-spec.md` - Loop state schema
- `claude/lib/circuit-breaker-spec.md` - CB state machine
- `claude/lib/dual-gate-spec.md` - Exit conditions
- `claude/agents/loop-controller.md` - Loop orchestrator

---

*Autonomous Execution Command v1.0.0*
*Ralph-powered continuous development without intervention*
