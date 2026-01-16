# Session Manager Specification

**Version:** 1.0.0
**Pattern Origin:** Ralph for Claude Code
**Purpose:** Session lifecycle management with state-based expiration and resume capability

---

## Overview

The Session Manager handles:
1. **Session creation** - Initialize new autonomous execution sessions
2. **Session detection** - Find and validate existing sessions
3. **Session resume** - Continue interrupted executions
4. **Session expiration** - State-based validity rules

## Session Lifecycle

```
    ┌─────────────────┐
    │   NO SESSION    │
    │  (First Run)    │
    └────────┬────────┘
             │ /bp:autonomous
             ▼
    ┌─────────────────┐
    │    CREATED      │
    │(New session_id) │
    └────────┬────────┘
             │ loop starts
             ▼
    ┌─────────────────┐     interrupt    ┌─────────────────┐
    │    RUNNING      │─────────────────▶│    SUSPENDED    │
    │ (Active loop)   │                  │ (Resumable)     │
    └────────┬────────┘                  └────────┬────────┘
             │                                    │
             │ all phases complete                │ resume
             ▼                                    │
    ┌─────────────────┐                          │
    │   COMPLETED     │◀─────────────────────────┘
    │ (Success)       │
    └─────────────────┘

             │ OR
             ▼
    ┌─────────────────┐     ┌─────────────────┐
    │    HALTED       │     │    EXPIRED      │
    │ (CB OPEN)       │     │ (Invalid state) │
    └─────────────────┘     └─────────────────┘
```

## Session Detection

### Check for Existing Session

```yaml
detection_flow:
  1. check: .prp-session/loop-state.json exists
  2. if exists:
     - read: session state
     - validate: state integrity
     - check: expiration conditions
     - if valid:
         return: {found: true, session: state, action: "offer_resume"}
     - else:
         return: {found: true, session: state, action: "offer_reset", reason: validation_error}
  3. else:
     return: {found: false, action: "create_new"}
```

### Session Validation

```python
def validate_session(state: dict, prp_file: str) -> tuple[bool, str]:
    """
    Validate session state for resume capability.
    Returns: (is_valid, error_message)
    """

    # Required fields check
    required = ["session_id", "prp_file", "started_at", "current_phase", "status"]
    for field in required:
        if field not in state:
            return False, f"Missing required field: {field}"

    # PRP file must match
    if state["prp_file"] != prp_file:
        return False, f"PRP mismatch: session={state['prp_file']}, requested={prp_file}"

    # Phase must be valid
    valid_phases = ["RED", "GREEN", "REFACTOR", "DOCUMENT"]
    if state["current_phase"] not in valid_phases:
        return False, f"Invalid phase: {state['current_phase']}"

    # Status must allow resume
    resumable_statuses = ["running", "paused", "suspended"]
    if state["status"] not in resumable_statuses:
        if state["status"] == "completed":
            return False, "Session already completed"
        if state["status"] == "halted":
            return False, "Session halted by Circuit Breaker"
        return False, f"Invalid status: {state['status']}"

    return True, ""
```

## State-Based Expiration

Sessions do NOT expire based on time. They expire based on state conditions:

### Expiration Conditions

```yaml
condition_1_circuit_breaker_open:
  check: .prp-session/circuit-breaker.json
  if: state == "OPEN"
  result: EXPIRED
  reason: "Circuit Breaker halted execution"
  action: "Offer reset or abort"

condition_2_prp_complete:
  check: .prp-session/loop-state.json
  if: status == "completed"
  result: EXPIRED
  reason: "PRP execution already completed"
  action: "No resume needed"

condition_3_state_corrupted:
  check: validation_errors
  if: any validation fails
  result: EXPIRED
  reason: "Session state corrupted"
  action: "Offer reset with fresh state"

condition_4_prp_mismatch:
  check: state.prp_file vs requested prp_file
  if: mismatch
  result: EXPIRED
  reason: "Different PRP requested"
  action: "Start new session for new PRP"
```

### Expiration Check Flow

```python
def check_session_expiration(state: dict, prp_file: str) -> dict:
    """
    Check all expiration conditions.
    Returns: {expired: bool, reason: str, action: str}
    """

    # Check Circuit Breaker
    cb_path = ".prp-session/circuit-breaker.json"
    if os.path.exists(cb_path):
        cb_state = json.load(open(cb_path))
        if cb_state.get("state") == "OPEN":
            return {
                "expired": True,
                "reason": f"Circuit Breaker OPEN: {cb_state.get('open_reason')}",
                "action": "reset_or_abort"
            }

    # Check completion
    if state.get("status") == "completed":
        return {
            "expired": True,
            "reason": "Session completed successfully",
            "action": "no_resume"
        }

    # Check PRP match
    if state.get("prp_file") != prp_file:
        return {
            "expired": True,
            "reason": f"PRP mismatch",
            "action": "create_new"
        }

    # Run validation
    is_valid, error = validate_session(state, prp_file)
    if not is_valid:
        return {
            "expired": True,
            "reason": f"State corrupted: {error}",
            "action": "reset"
        }

    return {"expired": False}
```

## Session State Schema

```json
{
  "session_id": "uuid-v4",
  "prp_file": "path/to/prp.md",
  "started_at": "2026-01-16T10:00:00-03:00",
  "current_phase": "GREEN",
  "current_iteration": 5,
  "last_activity": "2026-01-16T10:45:00-03:00",
  "status": "running",
  "halt_reason": null,
  "phases_completed": ["RED"],
  "error_history": [
    {
      "timestamp": "2026-01-16T10:30:00-03:00",
      "phase": "GREEN",
      "iteration": 3,
      "error": "TypeError: Cannot read property 'x' of undefined",
      "hash": "sha256-hash"
    }
  ]
}
```

## Resume Prompt

When a valid resumable session is found:

```
╔════════════════════════════════════════════════════════════╗
║               PREVIOUS SESSION DETECTED                     ║
╠════════════════════════════════════════════════════════════╣
║                                                             ║
║  Session ID:  a1b2c3d4-...                                 ║
║  PRP:         autonomous-loop-engine-dashboard.md          ║
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

## Session Operations

### Create New Session

```yaml
create_session:
  inputs:
    prp_file: path to PRP document

  steps:
    1. generate: session_id = uuid.v4()
    2. create: .prp-session/ directory
    3. initialize:
       loop-state.json:
         session_id: generated
         prp_file: input
         started_at: now()
         current_phase: "RED"
         current_iteration: 0
         status: "running"
         phases_completed: []
         error_history: []

       circuit-breaker.json:
         state: "CLOSED"
         no_progress_count: 0
         ...

       metrics.json:
         session_id: generated
         current_phase: "RED"
         phases: {}

       rate-limit.json:
         hourly: {calls_made: 0, ...}
         ...

    4. return: session_id
```

### Resume Session

```yaml
resume_session:
  inputs:
    session_id: from detected state

  steps:
    1. load: all state files
    2. validate: state integrity
    3. update: loop-state.json
       - status: "running"
       - last_activity: now()
    4. return: {
         phase: current_phase,
         iteration: current_iteration,
         metrics: loaded metrics
       }
```

### Update Session

```yaml
update_session:
  triggers:
    - phase transition
    - iteration complete
    - status change
    - error recorded

  steps:
    1. update: appropriate fields
    2. set: last_activity = now()
    3. persist: to .prp-session/loop-state.json
```

### End Session

```yaml
end_session:
  types:
    completed:
      - set: status = "completed"
      - set: completed_at = now()
      - preserve: all state files for audit

    halted:
      - set: status = "halted"
      - set: halt_reason = reason
      - preserve: all state files

    aborted:
      - set: status = "aborted"
      - optionally: remove .prp-session/
```

## Session Files Reference

```
.prp-session/
├── loop-state.json       # Main session state
├── circuit-breaker.json  # CB state for Ralph patterns
├── metrics.json          # Progress metrics history
├── rate-limit.json       # API rate limit tracking
├── dual-gate.json        # Exit condition state
└── phase-status.log      # Append-only status blocks
```

## Concurrency Protection

```yaml
file_locking:
  strategy: "last-write-wins"
  rationale: |
    Single agent execution model means no concurrent writes.
    If corruption detected, reset session.

corruption_detection:
  - JSON parse errors
  - Missing required fields
  - Invalid enum values
  - Future timestamps
```

## Best Practices

1. **Always validate before resume**: Check all expiration conditions
2. **Update last_activity**: Helps identify stale sessions
3. **Preserve error history**: Valuable for debugging
4. **State-based expiration**: Don't use time-based timeouts
5. **Clear user prompts**: Make resume/reset options obvious
6. **Atomic writes**: Use temp file + rename for safety

---

*Session Manager Specification v1.0.0*
*Inspired by Ralph for Claude Code session handling*
