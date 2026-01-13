# Circuit Breaker Specification

**Version:** 1.0.0
**Pattern Origin:** Ralph for Claude Code (Michael Nygard's "Release It!")
**Purpose:** Prevent runaway execution and infinite loops in autonomous AI workflows

---

## Overview

The Circuit Breaker pattern prevents cascading failures and runaway token consumption by monitoring progress and halting execution when the system is stuck in a non-productive loop.

## State Machine

```
         ┌──────────────────────────────────────┐
         │                                      │
         ▼                                      │
    ┌─────────┐   2 iterations   ┌───────────┐ │
    │ CLOSED  │───no progress───▶│ HALF_OPEN │ │
    │(Normal) │                  │(Monitoring)│ │
    └─────────┘                  └───────────┘ │
         ▲                            │        │
         │    progress                │ threshold │
         │    detected                │ reached   │
         │                            ▼        │
         │                       ┌────────┐   │
         └───────────────────────│  OPEN  │───┘
              manual reset       │(Halted)│
              OR user action     └────────┘
```

## States

### CLOSED (Normal Operation)
- **Description**: Normal execution state, all actions proceed
- **Behavior**: Execute phase actions, monitor metrics, check for progress
- **Transitions**: → HALF_OPEN when `no_progress_count >= 2`

### HALF_OPEN (Monitoring)
- **Description**: Warning state, system detected potential stagnation
- **Behavior**: Continue execution but with heightened monitoring
- **Transitions**:
  - → CLOSED when progress is detected (reset counters)
  - → OPEN when `no_progress_count >= threshold` (phase-specific)

### OPEN (Halted)
- **Description**: Execution halted, requires intervention
- **Behavior**: Stop all phase actions, emit BLOCKED status, prompt user
- **Transitions**: → CLOSED only via manual reset or user intervention

## State Transitions

### Transition: CLOSED → HALF_OPEN

```yaml
trigger:
  condition: no_progress_count >= 2

action:
  - log: "WARNING: No progress detected for 2 iterations"
  - state: HALF_OPEN
  - continue_execution: true
```

### Transition: HALF_OPEN → OPEN

```yaml
trigger:
  condition: no_progress_count >= phase_threshold

action:
  - log: "CIRCUIT OPEN: Execution halted after {threshold} no-progress iterations"
  - state: OPEN
  - emit_status:
      status: BLOCKED
      exit_signal: false
      recommendation: "Circuit breaker opened. Review and provide guidance."
  - halt_execution: true
  - prompt_user: true
```

### Transition: HALF_OPEN → CLOSED

```yaml
trigger:
  condition: progress_detected == true

action:
  - log: "Progress detected, circuit closing"
  - state: CLOSED
  - reset: no_progress_count = 0
  - continue_execution: true
```

### Transition: OPEN → CLOSED

```yaml
trigger:
  condition: manual_reset OR user_intervention

action:
  - log: "Circuit reset by user"
  - state: CLOSED
  - reset:
      no_progress_count: 0
      same_error_count: 0
      open_reason: null
      opened_at: null
  - continue_execution: true
```

## Phase-Specific Thresholds

| Phase | NO_PROGRESS_THRESHOLD | SAME_ERROR_THRESHOLD | Rationale |
|-------|----------------------|---------------------|-----------|
| RED | 3 | 5 | Standard - test generation is usually straightforward |
| GREEN | 2 | 3 | **Stricter** - highest risk of infinite implementation loops |
| REFACTOR | 5 | 5 | Lenient - refactoring is iterative by nature |
| DOCUMENT | 3 | 5 | Standard - doc generation is usually straightforward |

### GREEN Phase Special Handling

The GREEN phase has the highest risk of infinite loops because:
1. Tests may be impossible to pass due to design issues
2. Implementation attempts may not make progress
3. The same error can repeat indefinitely

**GREEN Phase Circuit Breaker Behavior:**
- Opens after only 2 no-progress iterations (vs 3 for others)
- Opens after 3 same-error iterations (vs 5 for others)
- When opened, suggests: "Consider refactoring approach or splitting the feature"

## Progress Detection Rules

### RED Phase
```yaml
progress_detected: true
when:
  - tests_generated > last_tests_generated
  - OR criteria_covered > last_criteria_covered
```

### GREEN Phase
```yaml
progress_detected: true
when:
  - tests_passing > last_tests_passing
  - OR tests_failing < last_tests_failing (same total)
```

### REFACTOR Phase
```yaml
progress_detected: true
when:
  - pattern_applied == true
  - OR complexity_score < last_complexity_score
  - OR duplication_removed == true
```

### DOCUMENT Phase
```yaml
progress_detected: true
when:
  - docs_generated > last_docs_generated
  - OR diagrams_valid > last_diagrams_valid
```

## Same Error Detection

To prevent loops where the same error repeats:

```yaml
same_error_detection:
  method: hash comparison
  hash_function: SHA256(error_message + error_type)

  on_same_error:
    - increment: same_error_count
    - if same_error_count >= SAME_ERROR_THRESHOLD:
        trigger: OPEN
        reason: "Same error repeated {count} times"
```

## Circuit Breaker State Schema

```json
{
  "state": "CLOSED | HALF_OPEN | OPEN",
  "no_progress_count": 0,
  "same_error_count": 0,
  "last_progress_metric": {
    "RED": { "tests_generated": 0 },
    "GREEN": { "tests_passing": 0 },
    "REFACTOR": { "patterns_applied": 0 },
    "DOCUMENT": { "docs_generated": 0 }
  },
  "last_error_hash": null,
  "opened_at": null,
  "open_reason": null,
  "history": [
    {
      "timestamp": "ISO-8601",
      "event": "state_change | progress | error",
      "from_state": "CLOSED",
      "to_state": "HALF_OPEN",
      "reason": "No progress for 2 iterations"
    }
  ]
}
```

## Persistence

The Circuit Breaker state MUST be persisted to enable:
1. Resume capability after interruption
2. Cross-iteration state maintenance
3. Audit trail of events

**Persistence Location:** `.prp-session/circuit-breaker.json`

```yaml
persistence:
  read: at start of each phase action
  write: after each state change
  format: JSON
  location: .prp-session/circuit-breaker.json
```

## Integration with Execute-PRP

```markdown
## Before Each Phase Action

1. READ circuit breaker state from .prp-session/
2. CHECK state:
   - IF OPEN: HALT, report to user, do NOT proceed
   - IF HALF_OPEN: WARN, proceed with monitoring
   - IF CLOSED: proceed normally

## After Each Phase Action

1. CALCULATE progress based on phase-specific rules
2. UPDATE circuit breaker:
   - IF progress: reset no_progress_count, state → CLOSED
   - IF no progress: increment no_progress_count
   - IF same error: increment same_error_count
3. CHECK thresholds:
   - IF exceeded: transition state
4. WRITE state to .prp-session/
5. EMIT PRP_PHASE_STATUS with circuit breaker info
```

## User Intervention Options

When Circuit Breaker opens, user can:

1. **Reset and Continue**: Reset counters, continue execution
2. **Skip Phase**: Mark current phase as complete, move to next
3. **Abort**: Stop execution entirely
4. **Modify Approach**: Provide new guidance and reset

```markdown
---CIRCUIT_BREAKER_OPEN---
PHASE: GREEN
REASON: No progress for 2 iterations
ITERATIONS: 5
TESTS_PASSING: 3/10 (no change)
LAST_ERROR: TypeError: Cannot read property 'x' of undefined

OPTIONS:
1. [R]eset and retry with current approach
2. [S]kip GREEN phase (mark tests as known failures)
3. [A]bort execution
4. [M]odify approach (provide new guidance)

Enter choice:
---END_CIRCUIT_BREAKER_OPEN---
```

## Best Practices

1. **Check BEFORE action**: Always check circuit breaker state before executing any phase action
2. **Quantitative progress**: Progress must be measurable, not subjective
3. **Persist immediately**: Write state after every change
4. **Log transitions**: All state transitions should be logged with timestamps
5. **Phase-specific thresholds**: Don't use one-size-fits-all thresholds
6. **User visibility**: Always show circuit breaker state in status blocks

---

*Circuit Breaker Specification v1.0.0*
*Inspired by Ralph for Claude Code and Michael Nygard's "Release It!"*
