---
description: Implement features from PRP specifications with TDD E2E workflow, Circuit Breaker protection, and architecture documentation generation
argument-hint: [path/to/prp-file.md]
allowed-tools: TodoWrite, Read, Write, Edit, MultiEdit, Glob, Grep, Bash, NotebookEdit, Task
---

# Execute PRP with TDD E2E Workflow (Ralph-Enhanced v2)

Implement a feature using the PRP file following a pure TDD (Test-Driven Development) approach with E2E tests, **Circuit Breaker protection**, **Dual-Gate exit validation**, and comprehensive architecture documentation generation.

## PRP File: $ARGUMENTS

## Ralph Pattern Integration

This command implements production-grade reliability patterns from Ralph for Claude Code:

1. **Circuit Breaker** - Prevents infinite loops by halting after no-progress iterations
2. **Dual-Gate Exit** - Requires 2 conditions before declaring phase complete
3. **PRP_PHASE_STATUS** - Structured status blocks for observability
4. **Metrics Tracking** - Quantitative progress detection

## TDD E2E Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    EXECUTE-PRP v2 (Ralph-Enhanced)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  INITIALIZATION                                                             │
│  ├── Load PRP & extract acceptance criteria                                │
│  ├── Initialize Circuit Breaker (state: CLOSED)                            │
│  ├── Initialize Metrics Tracker                                            │
│  └── Check for existing session (resume if found)                          │
│                                                                             │
│  🔴 PHASE RED (Circuit Breaker Protected) ─────────────────────────────────│
│  │  LOOP until Dual-Gate exit:                                             │
│  │    1. Check Circuit Breaker state (HALT if OPEN)                       │
│  │    2. Generate E2E tests from acceptance criteria                       │
│  │    3. Run tests (verify all FAIL)                                       │
│  │    4. Update metrics (tests_generated, tests_failing)                   │
│  │    5. Update Circuit Breaker (progress = tests increased)               │
│  │    6. Emit PRP_PHASE_STATUS block                                       │
│  │    7. Check Dual-Gate: (all_tests_fail AND exit_signal)                │
│  │  CIRCUIT_OPEN: Pause, report, ask user                                  │
│  │                                                                          │
│  🟢 PHASE GREEN (Circuit Breaker Protected - STRICT) ──────────────────────│
│  │  LOOP until Dual-Gate exit:                                             │
│  │    1. Check Circuit Breaker state (HALT if OPEN)                       │
│  │    2. Implement code for next failing test                              │
│  │    3. Run tests                                                          │
│  │    4. Update metrics (tests_passing, files_created)                     │
│  │    5. Update Circuit Breaker (progress = tests_passing increased)       │
│  │    6. Emit PRP_PHASE_STATUS block                                       │
│  │    7. Check Dual-Gate: (all_tests_pass AND 2_consecutive_runs)          │
│  │  CIRCUIT_OPEN: Suggest alternative approach, ask user                   │
│  │  NOTE: GREEN has STRICTER thresholds (2 vs 3) - highest loop risk       │
│  │                                                                          │
│  🔵 PHASE REFACTOR (Monitored) ────────────────────────────────────────────│
│  │  1. Analyze code for improvements                                       │
│  │  2. Apply refactoring (run tests after each)                            │
│  │  3. Revert if tests break                                               │
│  │  4. Track patterns_applied, complexity_delta                            │
│  │  5. Emit PRP_PHASE_STATUS block                                         │
│  │                                                                          │
│  📚 PHASE DOCUMENT (Tracked) ──────────────────────────────────────────────│
│  │  1. Call architecture-docs-generator                                    │
│  │  2. Track docs_generated, diagrams_valid                                │
│  │  3. Emit PRP_PHASE_STATUS block                                         │
│  │                                                                          │
│  🔍 PHASE QA (Circuit Breaker Protected) ──────────────────────────────────│
│  │  LOOP until Dual-Gate exit OR human escalation:                        │
│  │    1. Check Circuit Breaker state (HALT if OPEN)                       │
│  │    2. Query memory (4 mandatory queries via claude-self-reflect)       │
│  │    3. Detect project stack (Node/Python/Go/Lua)                        │
│  │    4. Validate against objective checklist                              │
│  │    5. Generate QA report                                                │
│  │    6. Emit PRP_PHASE_STATUS with QA metrics                            │
│  │    7. Check verdict: APPROVE or REJECT                                  │
│  │  ON APPROVE: Proceed to SHIP                                            │
│  │  ON REJECT: Return to GREEN (max 3 per cycle)                          │
│  │  ON 3rd REJECT: Escalate to human                                       │
│  │  NOTE: QA uses DIFFERENT model than implementer (model diversity)       │
│  │                                                                          │
│  ✅ COMPLETION REPORT ─────────────────────────────────────────────────────│
│     ├── Phase summaries with metrics                                       │
│     ├── Circuit Breaker events (if any occurred)                           │
│     ├── Total iterations and time spent                                    │
│     └── Final PRP_PHASE_STATUS with EXIT_SIGNAL=true                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Execution Process

### 0. Initialization

1. **Read the PRP file** completely
2. **Extract acceptance criteria** from Success Criteria section
3. **Check for existing session**:
   ```bash
   # Determine session directory (central location for dashboard monitoring)
   # Default: ~/.bp-sessions/{basename of current directory}
   # Override: PRP_SESSION_DIR environment variable
   SESSION_DIR="${PRP_SESSION_DIR:-$HOME/.bp-sessions/$(basename $(pwd))}"

   # Check if resuming from previous session
   if [ -d "$SESSION_DIR" ] && [ -f "$SESSION_DIR/loop-state.json" ]; then
     echo "Previous session found at: $SESSION_DIR - resuming..."
     # Load circuit breaker state
     # Load metrics
   else
     mkdir -p "$SESSION_DIR"
     echo "New session created at: $SESSION_DIR"
     # Initialize new session
   fi
   ```

   **Note**: Central session directory enables `/bp:dashboard` to monitor all active sessions.
4. **Initialize Circuit Breaker** (state: CLOSED, no_progress_count: 0)
5. **Initialize Metrics Tracker** with phase-specific metrics
6. **Identify the project stack** (Node, Python, Go, Web, Mobile, Full-Stack)

### 1. PHASE RED: Generate E2E Tests

**Before each action, CHECK Circuit Breaker:**
```yaml
if circuit_breaker.state == "OPEN":
  HALT execution
  Report to user with options:
    - [R]eset and retry
    - [S]kip phase
    - [A]bort
    - [M]odify approach
```

**Call the TDD E2E Generator Agent:**

```
Use the Task tool with subagent_type: test-engineer
Provide: PRP file path and acceptance criteria
Follow patterns from: claude/agents/tdd-e2e-generator.md
```

The agent will:
- Detect project stack
- Select appropriate test framework
- Generate E2E test file based on acceptance criteria
- Place tests in `tests/e2e/` directory
- Run tests to verify RED state (all should fail)
- **Emit PRP_PHASE_STATUS block with metrics**

**Update Circuit Breaker after action:**
```yaml
progress = (tests_generated > last.tests_generated)
if progress:
  circuit_breaker.state = "CLOSED"
  circuit_breaker.no_progress_count = 0
else:
  circuit_breaker.no_progress_count += 1
  if no_progress_count >= 3:  # RED threshold
    circuit_breaker.state = "OPEN"
    HALT and report
```

**Check Dual-Gate Exit:**
```yaml
gate_1 = (tests_failing == tests_total AND tests_total >= criteria_count)
gate_2 = exit_signal == true
can_exit = gate_1 AND gate_2
```

**Verify RED state before proceeding!**

### 2. PHASE GREEN: Implement Code

**CRITICAL**: GREEN phase has STRICTER Circuit Breaker thresholds:
- NO_PROGRESS_THRESHOLD: 2 (vs 3 for other phases)
- SAME_ERROR_THRESHOLD: 3 (vs 5 for other phases)

This is because GREEN has the highest risk of infinite loops.

**Execution Loop:**

1. **Check Circuit Breaker** before each implementation attempt
2. **Create implementation plan** using TodoWrite
3. **Study reference files** specified in PRP
4. **Implement minimum code** to pass tests:
   - Follow existing codebase patterns
   - Run tests after each significant change
   - Fix failing tests one at a time
5. **Update metrics** after each test run:
   ```yaml
   metrics:
     tests_passing: [current count]
     tests_failing: [current count]
     consecutive_green_runs: [reset on any failure]
     files_created: [cumulative]
     files_modified: [cumulative]
   ```
6. **Update Circuit Breaker**:
   ```yaml
   progress = (tests_passing > last.tests_passing)
   # Apply stricter GREEN thresholds
   ```
7. **Emit PRP_PHASE_STATUS block**
8. **Check Dual-Gate Exit:**
   ```yaml
   gate_1 = (tests_failing == 0 AND consecutive_green_runs >= 2)
   gate_2 = exit_signal == true
   can_exit = gate_1 AND gate_2
   ```

**Do NOT proceed until all tests are GREEN with 2 consecutive passes!**

### 3. PHASE REFACTOR: Improve Code Quality

1. **Review implemented code** for quality issues
2. **Apply improvements** while keeping tests green:
   - Remove code duplication
   - Improve naming and structure
   - Apply appropriate design patterns
   - Optimize performance if needed
3. **Run tests after each refactoring** to ensure they still pass
4. **Track refactoring metrics:**
   ```yaml
   metrics:
     patterns_applied: [list]
     complexity_delta: [before - after]
     tests_still_passing: [boolean]
   ```
5. **Emit PRP_PHASE_STATUS block**

### 4. PHASE DOCUMENT: Generate Architecture Docs

**Call the Architecture Docs Generator Agent:**

```
Use the Task tool with subagent_type: docs-writer
Provide: PRP file path and implemented code context
Follow patterns from: claude/agents/architecture-docs-generator.md
```

The agent will generate:
- **ADRs** - Document key decisions made during implementation
- **C4 Context Diagram** - System context (Mermaid)
- **C4 Container Diagram** - Container architecture (Mermaid)
- **C4 Component Diagram** - Component details (Mermaid)
- **Data Flow Diagram** - How data flows through the system (Mermaid)
- **ERD** - Entity relationships if database involved (Mermaid)
- **Sequence Diagrams** - Key interaction sequences (Mermaid)
- **OpenAPI Spec** - API documentation if API endpoints exist
- **Emit PRP_PHASE_STATUS block with metrics**

Documentation will be placed in `docs/architecture/` directory.

### 5. PHASE QA: Validate Implementation

**CRITICAL**: QA uses DIFFERENT model than implementer to avoid echo chamber.

**Call the QA Agent:**

```
Use the Task tool with subagent_type: bp:qa-agent
Provide: PRP file path, modified files list, implementer model used
Follow patterns from: claude/agents/qa-agent.md
```

**QA Execution Flow:**

1. **Query Memory (MANDATORY)**
   - Historical bugs (csr_reflect_on_past)
   - Stack patterns (csr_search_by_concept)
   - Architecture decisions (csr_search_narratives)
   - File history (csr_search_by_file)

2. **Detect Project Stack**
   - Read marker files (package.json, pyproject.toml, go.mod)
   - Load stack-specific commands from qa-tools-mapping.yml

3. **Validate Checklist**
   - Load qa-checklist.yml
   - Execute validation for each criterion
   - Track blocking vs warning issues

4. **Generate Report**
   - Follow qa-report-template.md format
   - Include memory context summary
   - List all issues with fix suggestions

5. **Emit Verdict**
   - APPROVE: All blocking criteria pass → Proceed to SHIP
   - REJECT: Blocking issues exist → Return to GREEN

**QA Retry Logic:**
```yaml
if verdict == "REJECT":
  qa_attempt += 1
  if qa_attempt < 3:
    return_to: GREEN  # Fix issues
  else:
    escalate_to: human
    provide: full QA report
    await: human decision

if verdict == "APPROVE":
  proceed_to: SHIP
  reset: qa_attempt = 0
```

**Check Dual-Gate Exit:**
```yaml
gate_1 = (blocking_issues == 0 AND verdict == "APPROVE")
gate_2 = exit_signal == true
can_exit = gate_1 AND gate_2
```

### 6. Final Validation

1. **Run complete test suite** one final time
2. **Verify all documentation** was generated correctly
3. **Check Mermaid diagrams** render properly
4. **Review against PRP checklist**
5. **Clean up session files** (optional):
   ```bash
   # Keep .prp-session for audit trail or remove
   # rm -rf .prp-session  # Optional cleanup
   ```

### 6. Completion Report

Provide a summary showing:

```
TDD E2E WORKFLOW - COMPLETION REPORT (Ralph-Enhanced)
=====================================================

📋 PRP: [PRP file name]
📅 Date: [Current date]
⏱️ Total Duration: [time from start to end]

🔴 PHASE RED (Tests Generated)
   ├── Stack detected: [Node/Python/Go/Web/Mobile/Full-Stack]
   ├── Framework used: [Test framework]
   ├── Test file: [Path to test file]
   ├── Test cases: [Number of tests]
   ├── Iterations: [count]
   └── Circuit Breaker events: [none or list]

🟢 PHASE GREEN (Implementation)
   ├── Files created: [Number]
   ├── Files modified: [Number]
   ├── Iterations: [count]
   ├── Consecutive green runs: [count]
   ├── Circuit Breaker events: [none or list]
   └── All tests passing: ✅

🔵 PHASE REFACTOR (Code Quality)
   ├── Patterns applied: [List]
   ├── Complexity delta: [before → after]
   └── Optimizations: [List]

📚 PHASE DOCUMENT (Architecture Docs)
   ├── ADRs: [Number created]
   ├── C4 Diagrams: [List]
   ├── Data Flow: [Created/Skipped]
   ├── ERD: [Created/Skipped]
   ├── Sequence Diagrams: [Number]
   └── OpenAPI: [Created/Skipped]

🔍 PHASE QA (Quality Validation)
   ├── QA Model: [Model used - different from implementer]
   ├── Memory Queries: 4 executed
   │   ├── Historical Bugs: [count found]
   │   ├── Stack Patterns: [count found]
   │   ├── Architecture Decisions: [count found]
   │   └── File History: [count reviewed]
   ├── Checklist Results:
   │   ├── Funcionalidade: [passed/total]
   │   ├── Qualidade de Codigo: [passed/total] ([warnings] warnings)
   │   └── Documentacao: [passed/total] ([warnings] warnings)
   ├── Blocking Issues: [count]
   ├── Warnings: [count]
   ├── Verdict: [APPROVE/REJECT]
   ├── Attempts: [1-3]
   └── QA Report: [path to report]

🔒 CIRCUIT BREAKER SUMMARY
   ├── Total state transitions: [count]
   ├── Times opened: [count]
   └── User interventions: [count]

✅ SUCCESS CRITERIA
   [List each criterion with ✅ or ❌]

📁 FILES GENERATED
   ├── tests/e2e/[feature].spec.ts
   ├── docs/architecture/decisions/ADR-XXX.md
   ├── docs/architecture/diagrams/c4-context.md
   ├── docs/architecture/diagrams/c4-container.md
   ├── docs/architecture/diagrams/c4-component.md
   ├── docs/architecture/diagrams/data-flow.md
   ├── docs/architecture/diagrams/erd.md
   ├── docs/architecture/diagrams/sequence-XXX.md
   └── docs/architecture/api/openapi.yaml

🎯 IMPLEMENTATION COMPLETE
```

**Final PRP_PHASE_STATUS Block:**

```
---PRP_PHASE_STATUS---
TIMESTAMP: [completion timestamp]
PHASE: DOCUMENT
STATUS: COMPLETE
ITERATION: [final iteration]
PROGRESS_PERCENT: 100

TESTS:
  TOTAL: [final count]
  PASSING: [all]
  FAILING: 0
  SKIPPED: 0

FILES:
  CREATED: [total]
  MODIFIED: [total]
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
RECOMMENDATION: TDD E2E workflow complete - all phases successful
---END_PRP_PHASE_STATUS---
```

## Circuit Breaker Reference

| Phase | NO_PROGRESS_THRESHOLD | SAME_ERROR_THRESHOLD | Notes |
|-------|----------------------|---------------------|-------|
| RED | 3 | 5 | Standard |
| GREEN | 2 | 3 | **Stricter** - highest loop risk |
| REFACTOR | 5 | 5 | Lenient - iterative by nature |
| DOCUMENT | 3 | 5 | Standard |
| QA | 3 | 3 | Memory-assisted validation |

## Dual-Gate Exit Conditions

| Phase | Gate 1 (Objective) | Gate 2 (Signal) |
|-------|-------------------|-----------------|
| RED | tests_failing == tests_total | exit_signal |
| GREEN | tests_failing == 0 AND consecutive_runs >= 2 | exit_signal |
| REFACTOR | tests_passing AND (iteration >= 5 OR done) | exit_signal |
| DOCUMENT | docs_generated >= 3 AND has_adr | exit_signal |
| QA | blocking_issues == 0 AND verdict == APPROVE | exit_signal |

## Stack Detection Reference

| Indicator | Stack | Test Framework |
|-----------|-------|----------------|
| `package.json` with express/fastify/nest | Backend Node | Supertest + Jest |
| `package.json` with react/vue/angular | Frontend Web | Playwright |
| `package.json` with next/nuxt/sveltekit | Full-Stack | Playwright |
| `package.json` with react-native | Mobile | Detox + Jest |
| `requirements.txt` or `pyproject.toml` | Backend Python | pytest + httpx |
| `go.mod` | Golang | go test |

## Important Notes

- **TDD is mandatory** - Tests MUST be written before implementation
- **Tests must fail first** - Verify RED state before coding
- **Tests must pass** - Do not proceed to refactor until GREEN
- **Documentation reflects reality** - Docs are generated AFTER implementation
- **All diagrams use Mermaid** - For GitHub/GitLab compatibility
- **Circuit Breaker protects** - Halts after no-progress iterations
- **Dual-Gate validates** - Requires 2 conditions for phase exit
- **Status blocks enable observability** - Emit after every significant action

## Session Files

The workflow creates a session directory in the **central location** for state persistence:

```
~/.bp-sessions/{project-name}/
├── loop-state.json         # Session state and phase info
├── circuit-breaker.json    # CB state for resume capability
├── metrics.json            # Progress metrics history
├── dual-gate.json          # Exit condition tracking
├── rate-limit.json         # API rate limit state
└── phase-status.log        # All PRP_PHASE_STATUS blocks (append-only)
```

**Central location benefits:**
- `/bp:dashboard` can monitor all sessions from any terminal
- Sessions persist across terminal restarts
- Easy to manage multiple concurrent executions

**Override with environment variable:**
```bash
export PRP_SESSION_DIR=~/.bp-sessions/custom-project-name
```

## Legacy Mode

If TDD workflow is not applicable (e.g., documentation-only PRP), fall back to standard execution:

1. Read PRP and understand requirements
2. Plan implementation with TodoWrite
3. Execute following reference patterns
4. Validate with project commands
5. Complete checklist items

## Specifications Reference

For detailed specifications of Ralph patterns, see:

- `claude/lib/circuit-breaker-spec.md` - Circuit Breaker state machine
- `claude/lib/dual-gate-spec.md` - Dual-Gate exit conditions
- `claude/lib/status-block-spec.md` - PRP_PHASE_STATUS format
- `claude/lib/metrics-spec.md` - Progress detection rules
