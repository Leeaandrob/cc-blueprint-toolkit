# Metrics Tracking Specification

**Version:** 1.0.0
**Pattern Origin:** Ralph for Claude Code
**Purpose:** Quantitative progress tracking for Circuit Breaker and Dual-Gate evaluation

---

## Overview

The Metrics Tracking system collects quantitative data about phase execution to enable:
1. **Progress detection** for Circuit Breaker
2. **Exit condition evaluation** for Dual-Gate
3. **Observability** via PRP_PHASE_STATUS blocks
4. **Debugging** when issues arise

## Core Principle: Quantitative Progress

```
WRONG: "Made some changes" (qualitative)
RIGHT: "tests_passing: 5 → 7" (quantitative)

WRONG: "Working on implementation" (vague)
RIGHT: "files_created: 2, iteration: 5" (specific)
```

## Metrics by Phase

### RED Phase Metrics

```yaml
phase: RED
purpose: Track E2E test generation from acceptance criteria

metrics:
  tests_generated:
    type: integer
    description: Total test cases generated
    progress_indicator: true
    initial_value: 0

  tests_failing:
    type: integer
    description: Tests that fail (expected = all in RED)
    progress_indicator: false
    expected: equals tests_generated

  criteria_count:
    type: integer
    description: Number of acceptance criteria in PRP
    progress_indicator: false
    source: PRP file

  criteria_covered:
    type: integer
    description: Criteria with at least one test
    progress_indicator: true
    initial_value: 0

progress_detection:
  rule: |
    progress = (
      tests_generated > last.tests_generated
      OR criteria_covered > last.criteria_covered
    )

completion_condition:
  rule: |
    tests_generated >= criteria_count
    AND tests_failing == tests_generated
    AND criteria_covered == criteria_count
```

### GREEN Phase Metrics

```yaml
phase: GREEN
purpose: Track implementation progress toward passing tests

metrics:
  tests_total:
    type: integer
    description: Total number of tests
    progress_indicator: false
    source: test runner output

  tests_passing:
    type: integer
    description: Tests currently passing
    progress_indicator: true
    initial_value: 0

  tests_failing:
    type: integer
    description: Tests currently failing
    progress_indicator: false
    initial_value: tests_total

  consecutive_green_runs:
    type: integer
    description: Consecutive runs with all tests passing
    progress_indicator: false
    initial_value: 0
    reset_on: any test failure

  files_created:
    type: integer
    description: New files created
    progress_indicator: false
    cumulative: true

  files_modified:
    type: integer
    description: Existing files modified
    progress_indicator: false
    cumulative: true

  iteration:
    type: integer
    description: Current iteration number
    progress_indicator: false
    initial_value: 0

progress_detection:
  rule: |
    progress = (
      tests_passing > last.tests_passing
      OR (tests_failing < last.tests_failing AND tests_total unchanged)
    )

completion_condition:
  rule: |
    tests_passing == tests_total
    AND tests_failing == 0
    AND consecutive_green_runs >= 2
```

### REFACTOR Phase Metrics

```yaml
phase: REFACTOR
purpose: Track code quality improvements

metrics:
  tests_passing:
    type: integer
    description: Must remain equal to tests_total
    progress_indicator: false
    expected: equals tests_total

  patterns_applied:
    type: list[string]
    description: Design patterns applied during refactoring
    progress_indicator: true
    initial_value: []

  complexity_score:
    type: integer
    description: Code complexity metric (lower is better)
    progress_indicator: true
    optional: true

  duplication_count:
    type: integer
    description: Number of duplicated code blocks
    progress_indicator: true
    optional: true

  iteration:
    type: integer
    description: Refactoring iteration
    progress_indicator: false
    max_value: 5

progress_detection:
  rule: |
    progress = (
      len(patterns_applied) > len(last.patterns_applied)
      OR complexity_score < last.complexity_score
      OR duplication_count < last.duplication_count
    )

completion_condition:
  rule: |
    tests_passing == tests_total  # Tests still green
    AND (
      iteration >= 5  # Max iterations reached
      OR no_improvements_identified
      OR refactoring_complete == true
    )
```

### DOCUMENT Phase Metrics

```yaml
phase: DOCUMENT
purpose: Track architecture documentation generation

metrics:
  docs_generated:
    type: integer
    description: Number of documentation files created
    progress_indicator: true
    initial_value: 0

  diagrams_total:
    type: integer
    description: Total diagrams to generate
    progress_indicator: false
    expected: 6  # C4x3 + DataFlow + ERD + Sequence

  diagrams_valid:
    type: integer
    description: Diagrams that render correctly
    progress_indicator: true
    initial_value: 0

  has_adr:
    type: boolean
    description: ADR document created
    progress_indicator: true
    initial_value: false

  has_openapi:
    type: boolean
    description: OpenAPI spec created (if applicable)
    progress_indicator: true
    initial_value: false
    optional: true

progress_detection:
  rule: |
    progress = (
      docs_generated > last.docs_generated
      OR diagrams_valid > last.diagrams_valid
      OR (has_adr AND NOT last.has_adr)
    )

completion_condition:
  rule: |
    docs_generated >= 3
    AND diagrams_valid == diagrams_total
    AND has_adr == true
```

## Metrics State Schema

```json
{
  "session_id": "uuid",
  "prp_file": "path/to/prp.md",
  "started_at": "ISO-8601",
  "current_phase": "GREEN",
  "phases": {
    "RED": {
      "started_at": "ISO-8601",
      "completed_at": "ISO-8601",
      "iterations": 2,
      "final_metrics": {
        "tests_generated": 10,
        "tests_failing": 10,
        "criteria_count": 9,
        "criteria_covered": 9
      }
    },
    "GREEN": {
      "started_at": "ISO-8601",
      "completed_at": null,
      "iterations": 5,
      "current_metrics": {
        "tests_total": 10,
        "tests_passing": 6,
        "tests_failing": 4,
        "consecutive_green_runs": 0,
        "files_created": 3,
        "files_modified": 2,
        "iteration": 5
      },
      "history": [
        {
          "iteration": 1,
          "timestamp": "ISO-8601",
          "tests_passing": 0,
          "tests_failing": 10
        },
        {
          "iteration": 2,
          "timestamp": "ISO-8601",
          "tests_passing": 2,
          "tests_failing": 8
        }
      ]
    },
    "REFACTOR": null,
    "DOCUMENT": null
  }
}
```

## Progress Detection Algorithm

```python
def detect_progress(phase: str, current: dict, last: dict) -> bool:
    """
    Detect if progress was made between iterations.
    Used by Circuit Breaker to determine if loop is productive.
    """

    if phase == "RED":
        return (
            current["tests_generated"] > last.get("tests_generated", 0)
            or current["criteria_covered"] > last.get("criteria_covered", 0)
        )

    elif phase == "GREEN":
        return (
            current["tests_passing"] > last.get("tests_passing", 0)
            or (
                current["tests_failing"] < last.get("tests_failing", float('inf'))
                and current["tests_total"] == last.get("tests_total", 0)
            )
        )

    elif phase == "REFACTOR":
        return (
            len(current.get("patterns_applied", [])) > len(last.get("patterns_applied", []))
            or current.get("complexity_score", float('inf')) < last.get("complexity_score", float('inf'))
            or current.get("duplication_count", float('inf')) < last.get("duplication_count", float('inf'))
        )

    elif phase == "DOCUMENT":
        return (
            current["docs_generated"] > last.get("docs_generated", 0)
            or current["diagrams_valid"] > last.get("diagrams_valid", 0)
            or (current.get("has_adr", False) and not last.get("has_adr", False))
        )

    return False
```

## Progress Percentage Calculation

```python
def calculate_progress_percent(phase: str, metrics: dict) -> int:
    """Calculate progress percentage for status block."""

    if phase == "RED":
        if metrics["criteria_count"] == 0:
            return 0
        return int((metrics["criteria_covered"] / metrics["criteria_count"]) * 100)

    elif phase == "GREEN":
        if metrics["tests_total"] == 0:
            return 0
        base_progress = (metrics["tests_passing"] / metrics["tests_total"]) * 90
        # Add 10% for consecutive runs stability
        stability_bonus = min(metrics["consecutive_green_runs"] * 5, 10)
        return int(base_progress + stability_bonus)

    elif phase == "REFACTOR":
        # Refactoring progress is iteration-based
        return min(metrics["iteration"] * 20, 100)

    elif phase == "DOCUMENT":
        required_docs = 6  # ADR + 5 diagram types
        return int((metrics["docs_generated"] / required_docs) * 100)

    return 0
```

## Metric Collection Points

### When to Collect

| Event | Metrics Updated |
|-------|-----------------|
| Test run completed | tests_passing, tests_failing, consecutive_green_runs |
| File created | files_created |
| File modified | files_modified |
| Pattern applied | patterns_applied |
| Document generated | docs_generated, diagrams_valid, has_adr |
| Phase iteration | iteration |

### How to Collect

```yaml
collection_methods:
  tests_passing:
    source: test runner output
    command: "npm test --json" or "pytest --json"
    parse: extract pass/fail counts

  files_created:
    source: git status or file system
    command: "git status --porcelain"
    parse: count new files (A prefix)

  files_modified:
    source: git status or file system
    command: "git status --porcelain"
    parse: count modified files (M prefix)

  complexity_score:
    source: complexity analyzer (optional)
    command: "npx eslint --format json" or "radon cc"
    parse: average complexity score

  diagrams_valid:
    source: Mermaid validation
    command: manual check or mermaid-cli
    parse: count valid diagrams
```

## Persistence

```yaml
persistence:
  location: .prp-session/metrics.json
  format: JSON
  operations:
    read: at start of each iteration
    write: after each metric update
    history: append to phase.history array
```

## Best Practices

1. **Quantitative always**: Every metric must be a number or boolean
2. **Collect immediately**: Update metrics right after the event
3. **Persist immediately**: Write to disk after every update
4. **Track history**: Keep per-iteration snapshots for debugging
5. **Use deltas**: Progress detection compares current vs last
6. **Phase isolation**: Each phase has its own metrics namespace

---

*Metrics Tracking Specification v1.0.0*
*Inspired by Ralph for Claude Code progress detection*
