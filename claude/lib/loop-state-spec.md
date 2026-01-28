# Loop State Specification

**Version:** 1.0.0
**Pattern Origin:** Ralph for Claude Code
**Purpose:** Define loop iteration tracking, phase transitions, and state persistence

---

## Overview

The Loop State tracks the autonomous execution loop's progress through TDD phases:
1. **Iteration tracking** - Current position within each phase
2. **Phase transitions** - Moving from RED → GREEN → REFACTOR → DOCUMENT → QA
3. **Status management** - Running, paused, completed, halted states
4. **Error history** - Track errors for same-error detection

## Phase Flow

```
    ┌──────────────────────────────────────────────────────────────────┐
    │                     AUTONOMOUS LOOP FLOW                          │
    ├──────────────────────────────────────────────────────────────────┤
    │                                                                   │
    │    START                                                         │
    │      │                                                           │
    │      ▼                                                           │
    │  ┌───────┐                                                       │
    │  │  RED  │ ──▶ Generate E2E tests from PRP                      │
    │  │  🔴   │     Exit: all tests fail + exit_signal               │
    │  └───┬───┘                                                       │
    │      │ Dual-Gate satisfied                                       │
    │      ▼                                                           │
    │  ┌───────┐                                                       │
    │  │ GREEN │ ──▶ Implement code to pass tests                     │
    │  │  🟢   │     Exit: all tests pass + 2 consecutive runs        │
    │  └───┬───┘                                                       │
    │      │ Dual-Gate satisfied                                       │
    │      ▼                                                           │
    │  ┌───────────┐                                                   │
    │  │ REFACTOR  │ ──▶ Improve code quality                         │
    │  │    🔵     │     Exit: tests pass + iteration >= 5            │
    │  └─────┬─────┘                                                   │
    │        │ Dual-Gate satisfied                                     │
    │        ▼                                                         │
    │  ┌──────────┐                                                    │
    │  │ DOCUMENT │ ──▶ Generate architecture docs                    │
    │  │    📚    │     Exit: docs >= 3 + has_adr                     │
    │  └────┬─────┘                                                    │
    │       │ Dual-Gate satisfied                                      │
    │       ▼                                                          │
    │  ┌──────────┐                                                    │
    │  │    QA    │ ──▶ AI reviewing AI with memory                   │
    │  │    🔍    │     Exit: APPROVE verdict + exit_signal           │
    │  └────┬─────┘     On REJECT: return to GREEN (max 3)            │
    │       │ Dual-Gate satisfied                                      │
    │       ▼                                                          │
    │   COMPLETED ✅                                                   │
    │                                                                   │
    └──────────────────────────────────────────────────────────────────┘
```

## Loop State Schema

```json
{
  "session_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "prp_file": "docs/PRPs/2026-01-16-feature-name.md",
  "started_at": "2026-01-16T10:00:00-03:00",
  "current_phase": "GREEN",
  "current_iteration": 5,
  "last_activity": "2026-01-16T10:45:00-03:00",
  "status": "running",
  "halt_reason": null,
  "phases_completed": ["RED"],
  "phase_history": {
    "RED": {
      "started_at": "2026-01-16T10:00:00-03:00",
      "completed_at": "2026-01-16T10:15:00-03:00",
      "iterations": 2,
      "exit_reason": "Dual-Gate satisfied"
    },
    "GREEN": {
      "started_at": "2026-01-16T10:15:00-03:00",
      "completed_at": null,
      "iterations": 5
    }
  },
  "error_history": [
    {
      "timestamp": "2026-01-16T10:30:00-03:00",
      "phase": "GREEN",
      "iteration": 3,
      "error": "TypeError: Cannot read property 'x' of undefined",
      "hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    }
  ],
  "total_agent_calls": 12
}
```

## Field Definitions

### Core Fields

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | UUID | Unique session identifier |
| `prp_file` | string | Path to the PRP being executed |
| `started_at` | ISO-8601 | Session start timestamp |
| `current_phase` | enum | RED, GREEN, REFACTOR, DOCUMENT, QA |
| `current_iteration` | integer | Iteration within current phase (0-based) |
| `green_model` | string | Model used in GREEN phase (for QA diversity) |
| `last_activity` | ISO-8601 | Last update timestamp |
| `status` | enum | running, paused, completed, halted |
| `halt_reason` | string | null | Reason if status is halted |

### Tracking Fields

| Field | Type | Description |
|-------|------|-------------|
| `phases_completed` | string[] | Phases that passed Dual-Gate |
| `phase_history` | object | Detailed per-phase metrics |
| `error_history` | array | Errors for same-error detection |
| `total_agent_calls` | integer | API usage counter |

## Status Transitions

```yaml
running:
  description: Active execution in progress
  transitions:
    - to: paused
      trigger: user_interrupt OR rate_limit_reached
    - to: completed
      trigger: all_phases_done
    - to: halted
      trigger: circuit_breaker_open

paused:
  description: Temporarily stopped, resumable
  transitions:
    - to: running
      trigger: user_resume OR rate_limit_reset
    - to: halted
      trigger: user_abort

completed:
  description: All phases finished successfully
  transitions: []  # Terminal state

halted:
  description: Stopped due to Circuit Breaker or error
  transitions:
    - to: running
      trigger: manual_reset
```

## Phase Transitions

### Transition Triggers

```yaml
RED_to_GREEN:
  gate_1: |
    tests_generated >= criteria_count
    AND tests_failing == tests_generated
  gate_2: exit_signal == true
  action:
    - phases_completed.append("RED")
    - current_phase = "GREEN"
    - current_iteration = 0
    - record phase_history.RED.completed_at

GREEN_to_REFACTOR:
  gate_1: |
    tests_failing == 0
    AND tests_passing == tests_total
    AND consecutive_green_runs >= 2
  gate_2: exit_signal == true
  action:
    - phases_completed.append("GREEN")
    - current_phase = "REFACTOR"
    - current_iteration = 0
    - record phase_history.GREEN.completed_at

REFACTOR_to_DOCUMENT:
  gate_1: |
    tests_passing == tests_total
    AND (iteration >= 5 OR refactoring_complete)
  gate_2: exit_signal == true
  action:
    - phases_completed.append("REFACTOR")
    - current_phase = "DOCUMENT"
    - current_iteration = 0
    - record phase_history.REFACTOR.completed_at

DOCUMENT_to_QA:
  gate_1: |
    docs_generated >= 3
    AND has_adr == true
  gate_2: exit_signal == true
  action:
    - phases_completed.append("DOCUMENT")
    - current_phase = "QA"
    - current_iteration = 0
    - record phase_history.DOCUMENT.completed_at

QA_to_COMPLETE:
  gate_1: |
    blocking_issues == 0
    AND verdict == "APPROVE"
  gate_2: exit_signal == true
  action:
    - phases_completed.append("QA")
    - status = "completed"
    - record phase_history.QA.completed_at

QA_REJECT_to_GREEN:
  trigger: verdict == "REJECT" AND qa_attempts < 3
  action:
    - current_phase = "GREEN"
    - current_iteration = 0
    - qa_attempts += 1
    - record rejection reason
  note: Per-cycle retry, resets on GREEN success
```

## Iteration Management

### Iteration Increment

```yaml
increment_iteration:
  trigger: after each agent spawn completes
  action:
    - current_iteration += 1
    - last_activity = now()
    - total_agent_calls += 1
    - persist to loop-state.json
```

### Iteration Reset

```yaml
reset_iteration:
  trigger: phase transition
  action:
    - current_iteration = 0
    - record: previous phase iterations in phase_history
```

## Error History Management

### Recording Errors

```python
def record_error(state: dict, error: str, phase: str, iteration: int):
    """Record error for same-error detection."""

    # Calculate error hash
    error_hash = hashlib.sha256(error.encode()).hexdigest()

    # Add to history
    state["error_history"].append({
        "timestamp": datetime.now().isoformat(),
        "phase": phase,
        "iteration": iteration,
        "error": error[:500],  # Truncate long errors
        "hash": error_hash
    })

    # Keep only last 50 errors
    if len(state["error_history"]) > 50:
        state["error_history"] = state["error_history"][-50:]

    return error_hash
```

### Same Error Detection

```python
def is_same_error(state: dict, current_hash: str) -> bool:
    """Check if this error matches the last error."""
    if not state["error_history"]:
        return False

    last_error = state["error_history"][-1]
    return last_error["hash"] == current_hash
```

## Pause/Resume Operations

### Pause

```yaml
pause_loop:
  trigger:
    - user interrupt (Ctrl+C)
    - rate limit reached
    - manual pause command
  action:
    - status = "paused"
    - pause_reason = trigger_reason
    - paused_at = now()
    - persist state
```

### Resume

```yaml
resume_loop:
  trigger: user confirmation or rate limit reset
  action:
    - validate: session state
    - status = "running"
    - last_activity = now()
    - continue: from current_phase, current_iteration
```

## Progress Calculation

```python
def calculate_overall_progress(state: dict) -> int:
    """Calculate overall execution progress percentage."""

    phases = ["RED", "GREEN", "REFACTOR", "DOCUMENT", "QA"]
    phase_weights = {"RED": 10, "GREEN": 45, "REFACTOR": 15, "DOCUMENT": 15, "QA": 15}

    completed_progress = sum(
        phase_weights[p] for p in state["phases_completed"]
    )

    # Add partial progress for current phase
    current = state["current_phase"]
    if current not in state["phases_completed"]:
        # Estimate based on iteration (max 10 iterations assumed)
        phase_progress = min(state["current_iteration"] / 10, 1.0)
        completed_progress += phase_weights[current] * phase_progress

    return int(completed_progress)
```

## Persistence

```yaml
persistence:
  # Central directory for multi-terminal dashboard monitoring
  directory:
    base: ~/.bp-sessions/
    project: derived from current working directory name
    full_path: ~/.bp-sessions/{project-name}/
    override: PRP_SESSION_DIR environment variable

  file: {session_dir}/loop-state.json
  format: JSON (pretty-printed)

  # Examples:
  # Working in ~/projects/my-api → ~/.bp-sessions/my-api/loop-state.json
  # With override → $PRP_SESSION_DIR/loop-state.json

  write_triggers:
    - session created
    - iteration incremented
    - phase transitioned
    - status changed
    - error recorded

  atomic_write:
    method: write to temp file, then rename
    reason: prevent corruption on interrupt

  # Why central directory?
  # - /bp:dashboard can monitor all sessions from web UI
  # - Sessions persist across terminal restarts
  # - Easy to manage multiple concurrent executions
```

## Validation Rules

```yaml
validation:
  session_id:
    format: UUID v4
    required: true

  prp_file:
    format: valid file path
    required: true

  current_phase:
    enum: [RED, GREEN, REFACTOR, DOCUMENT, QA]
    required: true

  current_iteration:
    type: integer
    min: 0
    max: 100

  status:
    enum: [running, paused, completed, halted]
    required: true

  timestamps:
    format: ISO-8601
    timezone: required
```

## Display Formats

### Status Line

```
[GREEN] Iteration 5/10 | 6/10 tests passing | Status: running
```

### Detailed Display

```
╔══════════════════════════════════════════╗
║          LOOP STATE SUMMARY              ║
╠══════════════════════════════════════════╣
║ Session:    a1b2c3d4-...                 ║
║ PRP:        feature-name.md              ║
║ Phase:      GREEN (🟢)                   ║
║ Iteration:  5                            ║
║ Status:     running                      ║
║                                          ║
║ Progress:                                ║
║ ├── RED:      ✅ Complete (2 iters)     ║
║ ├── GREEN:    ⏳ 5/10 iters             ║
║ ├── REFACTOR: ⏳ Pending                ║
║ ├── DOCUMENT: ⏳ Pending                ║
║ └── QA:       ⏳ Pending                ║
║                                          ║
║ Overall:    ████████░░░░░░░░░░░░  40%   ║
╚══════════════════════════════════════════╝
```

## Best Practices

1. **Atomic updates**: Always use temp file + rename
2. **Validate on load**: Check all fields before using
3. **Track everything**: History enables debugging
4. **Reasonable limits**: Cap error history size
5. **Clear status**: Make state obvious to users
6. **Preserve on error**: Don't lose progress on failures

---

*Loop State Specification v1.0.0*
*Inspired by Ralph for Claude Code loop management*
