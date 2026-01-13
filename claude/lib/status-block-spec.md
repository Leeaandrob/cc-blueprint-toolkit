# PRP_PHASE_STATUS Block Specification

**Version:** 1.0.0
**Pattern Origin:** Ralph for Claude Code (RALPH_STATUS)
**Purpose:** Machine-parseable structured communication for progress tracking

---

## Overview

The PRP_PHASE_STATUS block provides structured, machine-parseable status information after each significant action in the execute-prp workflow. This enables real-time progress tracking, automated monitoring, and debugging.

## Block Format

### Exact Syntax

```
---PRP_PHASE_STATUS---
TIMESTAMP: [ISO-8601 timestamp]
PHASE: [RED|GREEN|REFACTOR|DOCUMENT]
STATUS: [IN_PROGRESS|BLOCKED|COMPLETE]
ITERATION: [integer]
PROGRESS_PERCENT: [0-100]

TESTS:
  TOTAL: [integer]
  PASSING: [integer]
  FAILING: [integer]
  SKIPPED: [integer]

FILES:
  CREATED: [integer]
  MODIFIED: [integer]
  DELETED: [integer]

CIRCUIT_BREAKER:
  STATE: [CLOSED|HALF_OPEN|OPEN]
  NO_PROGRESS_COUNT: [integer]

DUAL_GATE:
  GATE_1: [true|false]
  GATE_2: [true|false]
  CAN_EXIT: [true|false]

BLOCKERS:
  - [blocker description or "none"]

EXIT_SIGNAL: [true|false]
RECOMMENDATION: [single line action recommendation]
---END_PRP_PHASE_STATUS---
```

### Critical Format Rules

1. **Delimiters**: Must be exactly `---PRP_PHASE_STATUS---` and `---END_PRP_PHASE_STATUS---`
2. **No extra whitespace**: No leading/trailing spaces on delimiter lines
3. **YAML-like format**: Key: Value pairs with proper indentation
4. **Lists**: Use `- item` format for arrays
5. **Booleans**: Lowercase `true` or `false`
6. **Numbers**: No quotes around integers

## Field Definitions

### Header Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| TIMESTAMP | ISO-8601 | Yes | When this status was emitted |
| PHASE | Enum | Yes | Current TDD phase |
| STATUS | Enum | Yes | Phase execution status |
| ITERATION | Integer | Yes | Current iteration number (1-based) |
| PROGRESS_PERCENT | Integer | Yes | Estimated progress 0-100 |

### PHASE Values

| Value | Description |
|-------|-------------|
| RED | Generating E2E tests from acceptance criteria |
| GREEN | Implementing code to pass tests |
| REFACTOR | Improving code quality |
| DOCUMENT | Generating architecture documentation |

### STATUS Values

| Value | Description | Next Action |
|-------|-------------|-------------|
| IN_PROGRESS | Phase is actively executing | Continue iteration |
| BLOCKED | Execution halted (Circuit Breaker open or error) | User intervention required |
| COMPLETE | Phase successfully finished | Move to next phase |

### TESTS Section

| Field | Type | Description |
|-------|------|-------------|
| TOTAL | Integer | Total number of test cases |
| PASSING | Integer | Tests currently passing |
| FAILING | Integer | Tests currently failing |
| SKIPPED | Integer | Tests skipped or disabled |

**Invariant**: `PASSING + FAILING + SKIPPED == TOTAL`

### FILES Section

| Field | Type | Description |
|-------|------|-------------|
| CREATED | Integer | New files created this session |
| MODIFIED | Integer | Existing files modified this session |
| DELETED | Integer | Files deleted this session |

### CIRCUIT_BREAKER Section

| Field | Type | Description |
|-------|------|-------------|
| STATE | Enum | Current CB state (CLOSED/HALF_OPEN/OPEN) |
| NO_PROGRESS_COUNT | Integer | Consecutive iterations without progress |

### DUAL_GATE Section

| Field | Type | Description |
|-------|------|-------------|
| GATE_1 | Boolean | Objective metrics condition satisfied |
| GATE_2 | Boolean | Explicit exit signal received |
| CAN_EXIT | Boolean | Both gates satisfied (GATE_1 AND GATE_2) |

### BLOCKERS Section

List of current blockers. Use `- none` if no blockers.

```yaml
# No blockers
BLOCKERS:
  - none

# With blockers
BLOCKERS:
  - Test 'should_validate_email' cannot pass - missing email validation library
  - Database connection timeout in test environment
```

### EXIT_SIGNAL

| Value | Meaning |
|-------|---------|
| false | Phase should continue |
| true | Agent confirms phase is complete |

### RECOMMENDATION

Single line describing the recommended next action.

Examples:
- `Continue implementing code for failing test: should_validate_email`
- `Run tests again to verify GREEN state stability`
- `Circuit breaker open - review implementation approach`
- `Phase complete - proceed to REFACTOR`

## Example Status Blocks

### RED Phase - In Progress

```
---PRP_PHASE_STATUS---
TIMESTAMP: 2026-01-13T10:15:00Z
PHASE: RED
STATUS: IN_PROGRESS
ITERATION: 1
PROGRESS_PERCENT: 50

TESTS:
  TOTAL: 5
  PASSING: 0
  FAILING: 5
  SKIPPED: 0

FILES:
  CREATED: 1
  MODIFIED: 0
  DELETED: 0

CIRCUIT_BREAKER:
  STATE: CLOSED
  NO_PROGRESS_COUNT: 0

DUAL_GATE:
  GATE_1: true
  GATE_2: false
  CAN_EXIT: false

BLOCKERS:
  - none

EXIT_SIGNAL: false
RECOMMENDATION: Verify all acceptance criteria have corresponding tests
---END_PRP_PHASE_STATUS---
```

### GREEN Phase - Progress Made

```
---PRP_PHASE_STATUS---
TIMESTAMP: 2026-01-13T10:30:00Z
PHASE: GREEN
STATUS: IN_PROGRESS
ITERATION: 5
PROGRESS_PERCENT: 60

TESTS:
  TOTAL: 10
  PASSING: 6
  FAILING: 4
  SKIPPED: 0

FILES:
  CREATED: 3
  MODIFIED: 2
  DELETED: 0

CIRCUIT_BREAKER:
  STATE: CLOSED
  NO_PROGRESS_COUNT: 0

DUAL_GATE:
  GATE_1: false
  GATE_2: false
  CAN_EXIT: false

BLOCKERS:
  - none

EXIT_SIGNAL: false
RECOMMENDATION: Continue implementing code for failing test: should_validate_email_format
---END_PRP_PHASE_STATUS---
```

### GREEN Phase - Circuit Breaker Open

```
---PRP_PHASE_STATUS---
TIMESTAMP: 2026-01-13T11:00:00Z
PHASE: GREEN
STATUS: BLOCKED
ITERATION: 8
PROGRESS_PERCENT: 60

TESTS:
  TOTAL: 10
  PASSING: 6
  FAILING: 4
  SKIPPED: 0

FILES:
  CREATED: 3
  MODIFIED: 5
  DELETED: 0

CIRCUIT_BREAKER:
  STATE: OPEN
  NO_PROGRESS_COUNT: 3

DUAL_GATE:
  GATE_1: false
  GATE_2: false
  CAN_EXIT: false

BLOCKERS:
  - No progress for 3 iterations on test: should_handle_edge_case
  - Possible design issue with current approach

EXIT_SIGNAL: false
RECOMMENDATION: Circuit breaker open - consider alternative implementation approach or split feature
---END_PRP_PHASE_STATUS---
```

### GREEN Phase - Complete

```
---PRP_PHASE_STATUS---
TIMESTAMP: 2026-01-13T11:30:00Z
PHASE: GREEN
STATUS: COMPLETE
ITERATION: 12
PROGRESS_PERCENT: 100

TESTS:
  TOTAL: 10
  PASSING: 10
  FAILING: 0
  SKIPPED: 0

FILES:
  CREATED: 4
  MODIFIED: 3
  DELETED: 0

CIRCUIT_BREAKER:
  STATE: CLOSED
  NO_PROGRESS_COUNT: 0

DUAL_GATE:
  GATE_1: true
  GATE_2: true
  CAN_EXIT: true

BLOCKERS:
  - none

EXIT_SIGNAL: true
RECOMMENDATION: All tests passing - proceed to REFACTOR phase
---END_PRP_PHASE_STATUS---
```

## Parsing Rules

### Regex Patterns

```python
# Block extraction
BLOCK_PATTERN = r'---PRP_PHASE_STATUS---\n(.*?)\n---END_PRP_PHASE_STATUS---'

# Field extraction
FIELD_PATTERN = r'^(\w+):\s*(.+)$'

# Nested field extraction (TESTS, FILES, etc.)
NESTED_PATTERN = r'^  (\w+):\s*(.+)$'
```

### Parser Implementation

```python
def parse_status_block(content: str) -> dict:
    """Parse PRP_PHASE_STATUS block into structured dict."""

    # Extract block content
    match = re.search(BLOCK_PATTERN, content, re.DOTALL)
    if not match:
        return None

    block_content = match.group(1)
    result = {}
    current_section = None

    for line in block_content.split('\n'):
        line = line.rstrip()

        # Skip empty lines
        if not line:
            continue

        # Check for list item
        if line.startswith('  - '):
            if current_section and current_section in result:
                if not isinstance(result[current_section], list):
                    result[current_section] = []
                result[current_section].append(line[4:])
            continue

        # Check for nested field
        if line.startswith('  '):
            nested_match = re.match(NESTED_PATTERN, line)
            if nested_match and current_section:
                key, value = nested_match.groups()
                if current_section not in result:
                    result[current_section] = {}
                result[current_section][key] = parse_value(value)
            continue

        # Check for top-level field
        field_match = re.match(FIELD_PATTERN, line)
        if field_match:
            key, value = field_match.groups()
            if value.strip() == '':
                # Section header (TESTS:, FILES:, etc.)
                current_section = key
                result[key] = {}
            else:
                result[key] = parse_value(value)
                current_section = key

    return result

def parse_value(value: str):
    """Parse string value to appropriate type."""
    value = value.strip()

    if value.lower() == 'true':
        return True
    if value.lower() == 'false':
        return False
    if value.isdigit():
        return int(value)

    return value
```

## Emission Requirements

### When to Emit

| Event | Emit Status Block? |
|-------|-------------------|
| Phase start | Yes |
| After each test run | Yes |
| After file creation/modification | Yes |
| On Circuit Breaker state change | Yes |
| On Dual-Gate evaluation | Yes |
| On phase completion | Yes |
| On error/blocker | Yes |

### Emission Frequency

- **Minimum**: Once per iteration
- **Maximum**: Once per significant action (test run, file write)
- **Always**: On any state change (CB, DG, STATUS)

## Persistence

Status blocks MUST be persisted for audit trail:

```yaml
persistence:
  file: .prp-session/phase-status.log
  format: append-only
  separator: "\n\n"  # Double newline between blocks
```

## Best Practices

1. **Emit immediately**: Don't batch status blocks
2. **Include all fields**: Never omit required fields
3. **Accurate timestamps**: Use actual time, not cached
4. **Honest progress**: Don't inflate PROGRESS_PERCENT
5. **Specific recommendations**: Actionable single-line guidance
6. **List all blockers**: Don't hide problems

---

*PRP_PHASE_STATUS Block Specification v1.0.0*
*Adapted from Ralph for Claude Code RALPH_STATUS*
