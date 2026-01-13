# Dual-Gate Exit Specification

**Version:** 1.0.0
**Pattern Origin:** Ralph for Claude Code
**Purpose:** Prevent false completion detection by requiring two independent confirmations

---

## Overview

The Dual-Gate Exit pattern prevents premature phase completion by requiring TWO independent conditions to be TRUE before a phase can exit. This eliminates false positives where a single condition might be temporarily satisfied.

## Core Principle

```
                    ┌─────────────────────────────────────┐
                    │         DUAL-GATE EXIT CHECK        │
                    ├─────────────────────────────────────┤
                    │                                     │
                    │   GATE 1 (Objective Metrics)        │
                    │   ┌─────────────────────────────┐   │
                    │   │ tests_passing == tests_total│   │
                    │   │ AND consecutive_runs >= 2   │   │
                    │   └─────────────────────────────┘   │
                    │              │                      │
                    │              ▼                      │
                    │        ┌──────────┐                 │
                    │        │   AND    │                 │
                    │        └──────────┘                 │
                    │              │                      │
                    │              ▼                      │
                    │   GATE 2 (Explicit Signal)          │
                    │   ┌─────────────────────────────┐   │
                    │   │   exit_signal == true       │   │
                    │   └─────────────────────────────┘   │
                    │                                     │
                    │              │                      │
                    │              ▼                      │
                    │   ┌─────────────────────────────┐   │
                    │   │ BOTH TRUE? → CAN EXIT       │   │
                    │   │ ANY FALSE? → CONTINUE       │   │
                    │   └─────────────────────────────┘   │
                    │                                     │
                    └─────────────────────────────────────┘
```

## Why Two Gates?

| Single Gate Problem | Dual-Gate Solution |
|--------------------|--------------------|
| Tests pass once by accident | Gate 1: Requires 2 consecutive passes |
| Agent declares done prematurely | Gate 2: Requires explicit confirmation |
| Flaky test passes temporarily | Gate 1: Consecutive runs filter flakiness |
| Partial completion declared | Both gates must align in SAME iteration |

## Gate Definitions by Phase

### RED Phase Gates

```yaml
phase: RED
purpose: Verify all E2E tests are generated and failing

gate_1:
  name: "Tests Generated and Failing"
  condition: |
    tests_total >= criteria_count
    AND tests_failing == tests_total
    AND tests_passing == 0
  rationale: "All tests must exist and fail (code doesn't exist yet)"

gate_2:
  name: "Explicit Exit Signal"
  condition: |
    exit_signal == true
  rationale: "Agent explicitly confirms RED state is achieved"

exit_allowed:
  when: gate_1 == true AND gate_2 == true
```

### GREEN Phase Gates

```yaml
phase: GREEN
purpose: Verify all tests pass with implementation

gate_1:
  name: "All Tests Passing (Stable)"
  condition: |
    tests_failing == 0
    AND tests_passing == tests_total
    AND consecutive_green_runs >= 2
  rationale: "Tests must pass twice to filter flakiness"

gate_2:
  name: "Explicit Exit Signal"
  condition: |
    exit_signal == true
  rationale: "Agent explicitly confirms GREEN state is achieved"

exit_allowed:
  when: gate_1 == true AND gate_2 == true
```

### REFACTOR Phase Gates

```yaml
phase: REFACTOR
purpose: Verify code quality improved without breaking tests

gate_1:
  name: "Tests Still Passing + Refactoring Done"
  condition: |
    tests_failing == 0
    AND (
      refactoring_complete == true
      OR iteration >= max_refactor_iterations
      OR no_more_improvements_identified
    )
  rationale: "Tests must stay green, refactoring has diminishing returns"

gate_2:
  name: "Explicit Exit Signal"
  condition: |
    exit_signal == true
  rationale: "Agent explicitly confirms refactoring is complete"

exit_allowed:
  when: gate_1 == true AND gate_2 == true
```

### DOCUMENT Phase Gates

```yaml
phase: DOCUMENT
purpose: Verify architecture documentation is generated

gate_1:
  name: "Required Documentation Generated"
  condition: |
    docs_generated >= required_docs_count
    AND all_diagrams_valid == true
    AND (
      has_adr == true
      AND has_c4_diagrams == true
    )
  rationale: "Core documentation must exist and be valid"

gate_2:
  name: "Explicit Exit Signal"
  condition: |
    exit_signal == true
  rationale: "Agent explicitly confirms documentation is complete"

exit_allowed:
  when: gate_1 == true AND gate_2 == true
```

## Evaluation Logic

### Per-Iteration Evaluation

```python
def check_dual_gate(phase: str, metrics: dict) -> DualGateResult:
    """
    Evaluate dual-gate exit conditions.
    BOTH conditions must be TRUE in the SAME iteration.
    """

    # Get phase-specific gate conditions
    gate_config = GATE_CONFIGS[phase]

    # Evaluate Gate 1 (Objective Metrics)
    gate_1_result = evaluate_gate_1(gate_config.gate_1, metrics)

    # Evaluate Gate 2 (Explicit Signal)
    gate_2_result = metrics.get("exit_signal", False)

    # BOTH must be TRUE
    can_exit = gate_1_result and gate_2_result

    return DualGateResult(
        can_exit=can_exit,
        gate_1=gate_1_result,
        gate_2=gate_2_result,
        reason=get_reason(gate_1_result, gate_2_result)
    )
```

### Gate 1 Evaluation Functions

```python
def evaluate_gate_1_red(metrics: dict) -> bool:
    return (
        metrics["tests_total"] >= metrics["criteria_count"]
        and metrics["tests_failing"] == metrics["tests_total"]
        and metrics["tests_passing"] == 0
    )

def evaluate_gate_1_green(metrics: dict) -> bool:
    return (
        metrics["tests_failing"] == 0
        and metrics["tests_passing"] == metrics["tests_total"]
        and metrics["consecutive_green_runs"] >= 2
    )

def evaluate_gate_1_refactor(metrics: dict) -> bool:
    tests_ok = metrics["tests_failing"] == 0
    done = (
        metrics.get("refactoring_complete", False)
        or metrics["iteration"] >= 5
        or metrics.get("no_improvements_found", False)
    )
    return tests_ok and done

def evaluate_gate_1_document(metrics: dict) -> bool:
    return (
        metrics["docs_generated"] >= 3
        and metrics["diagrams_valid"] == metrics["diagrams_total"]
        and metrics.get("has_adr", False)
    )
```

## Critical Rules

### Rule 1: Same Iteration Requirement

```markdown
WRONG: Cache gate_1 from iteration N, check gate_2 in iteration N+1
RIGHT: Evaluate BOTH gates in iteration N, require BOTH true in N
```

### Rule 2: No Implicit Exit Signals

```markdown
WRONG: exit_signal = (gate_1 == true)  // Inferred from metrics
RIGHT: exit_signal set EXPLICITLY by agent after confirming completion
```

### Rule 3: Consecutive Runs for GREEN

```markdown
WRONG: Exit on first all-tests-pass run
RIGHT: Require 2+ consecutive runs with all tests passing
```

### Rule 4: Early Exit Prevention

```markdown
WRONG: Allow exit if "close enough" (9/10 tests pass)
RIGHT: 100% test pass rate required (10/10)
```

## Status Block Integration

The Dual-Gate status MUST be included in every PRP_PHASE_STATUS block:

```yaml
---PRP_PHASE_STATUS---
# ... other fields ...

DUAL_GATE:
  GATE_1: true | false
  GATE_1_DETAIL: "tests_passing: 10/10, consecutive_runs: 2"
  GATE_2: true | false
  CAN_EXIT: true | false

EXIT_SIGNAL: true | false
---END_PRP_PHASE_STATUS---
```

## Edge Cases

### Flaky Tests

```yaml
scenario: Test passes on run 1, fails on run 2
handling:
  - consecutive_green_runs resets to 0
  - gate_1 becomes false
  - exit not allowed
  - continue iteration
```

### Premature Exit Signal

```yaml
scenario: Agent sets exit_signal=true but tests still failing
handling:
  - gate_1 is false (tests failing)
  - gate_2 is true (exit_signal)
  - can_exit = false (both must be true)
  - log warning: "Exit signal set but Gate 1 not satisfied"
```

### Never-Satisfiable Gate 1

```yaml
scenario: Tests cannot pass due to fundamental issue
handling:
  - Circuit Breaker will eventually open
  - When CB opens, user can choose to skip phase
  - Skipping sets forced_exit=true, bypasses dual-gate
```

## Dual-Gate State Schema

```json
{
  "phase": "GREEN",
  "iteration": 5,
  "gate_1": {
    "satisfied": true,
    "condition": "tests_failing == 0 AND consecutive_green_runs >= 2",
    "values": {
      "tests_failing": 0,
      "tests_passing": 10,
      "tests_total": 10,
      "consecutive_green_runs": 2
    }
  },
  "gate_2": {
    "satisfied": true,
    "source": "explicit_signal"
  },
  "can_exit": true,
  "timestamp": "2026-01-13T10:30:00Z"
}
```

## Best Practices

1. **Evaluate together**: Always evaluate both gates in the same iteration
2. **No caching**: Don't remember gate results across iterations
3. **Explicit signals**: Gate 2 must be explicitly set, never inferred
4. **Log everything**: Log gate evaluation results for debugging
5. **Consecutive requirement**: GREEN phase must have 2+ consecutive passes
6. **100% requirement**: No partial success - all tests must pass

---

*Dual-Gate Exit Specification v1.0.0*
*Inspired by Ralph for Claude Code*
