# PRP: QA Agent & Memory Integration

**Version:** 1.0.0
**Created:** 2025-01-27
**Status:** ✅ Implemented
**Confidence Score:** 9/10

---

## Discovery Summary

### Initial Task Analysis

Implement a QA Agent as the 5th phase in the TDD E2E workflow (RED→GREEN→REFACTOR→DOCUMENT→**QA**→SHIP) with memory integration via claude-self-reflect MCP server. The QA Agent validates implementation quality using an objective checklist before auto-shipping.

### User Clarifications Received

- **Question**: When should QA validation occur?
- **Answer**: At the end of the complete cycle (after DOCUMENT phase)
- **Impact**: QA becomes Phase 5, positioned before SHIP

- **Question**: What should QA validate?
- **Answer**: Functionality (tests + criteria), Code Quality (lint, complexity, DRY, naming), Documentation (README, ADR, CHANGELOG)
- **Impact**: 3-pillar checklist with blocking vs. warning criteria

- **Question**: Should QA consult memory?
- **Answer**: Yes, active memory - always query before validation
- **Impact**: 4 MCP queries mandatory before checklist evaluation

- **Question**: What happens on APPROVE/REJECT?
- **Answer**: APPROVE → auto-SHIP, REJECT → back to GREEN (max 3x, then human)
- **Impact**: Per-cycle attempt counter, Circuit Breaker integration

### Research Phase Summary

- **Codebase patterns found**: Agent frontmatter format, PRP_PHASE_STATUS blocks, Dual-Gate exit conditions, Circuit Breaker thresholds
- **External research needed**: No - claude-self-reflect MCP already integrated in project
- **Knowledge gaps identified**: None - all patterns exist in codebase

---

## Goal

Implement a **QA Agent** that acts as an autonomous quality gate, validating all AI-generated code before shipping. The agent uses **memory integration** (claude-self-reflect MCP) to provide historical context and an **objective checklist** to ensure consistent quality standards across all features.

## Why

- **Quality Assurance**: AI-generated code needs AI review before shipping (AI reviewing AI with model diversity)
- **Regression Prevention**: Memory integration surfaces similar bugs and patterns from project history
- **Autonomous Pipeline**: Enables fully automated feature delivery (PRP → SHIP without human intervention)
- **Consistency**: Objective checklist ensures same standards apply to every feature
- **Confidence**: Developers trust autonomous output when quality gates exist

## What

### User-Visible Behavior

1. After DOCUMENT phase completes, QA Agent automatically runs
2. QA queries memory for historical context (bugs, patterns, ADRs, file history)
3. QA validates against objective checklist (Functionality, Code, Docs)
4. QA generates detailed report with APPROVE/REJECT verdict
5. On APPROVE: Automatic SHIP (branch, commit, PR)
6. On REJECT: Return to GREEN phase with feedback (max 3 attempts)
7. After 3 rejections: Escalate to human with full report

### Success Criteria

- [ ] QA Agent validates 100% of features before shipping
- [ ] Memory queries complete in <3s total
- [ ] Checklist covers: tests passing, lint clean, complexity <10, docs updated
- [ ] QA uses different model than implementer (Opus↔Sonnet)
- [ ] Auto-SHIP triggers on QA approval
- [ ] Human escalation after 3 QA rejections
- [ ] QA Report generated in markdown format

---

## All Needed Context

### Documentation & References

```yaml
# MUST READ - Include these in your context window
- file: claude/agents/green-implementer.md
  why: Agent structure pattern to follow, PRP_PHASE_STATUS emission format

- file: claude/agents/refactor-agent.md
  why: Validation loop pattern, test-first verification approach

- file: claude/lib/circuit-breaker-spec.md
  why: CB state machine, threshold definitions, progress detection rules

- file: claude/lib/dual-gate-spec.md
  why: Exit condition format, Gate 1 + Gate 2 requirements

- file: claude/lib/status-block-spec.md
  why: PRP_PHASE_STATUS block format specification

- file: claude/commands/execute-prp.md
  why: Phase integration, agent spawning pattern, workflow orchestration

- file: .claude-plugin/plugin.json
  why: How to register new agent and MCP server

- external: /home/leeaandrob/Projects/Personal/mcp-servers/claude-self-reflect
  why: MCP server integration, tool signatures (csr_reflect_on_past, etc.)
```

### Current Codebase Tree

```bash
claude/
├── agents/
│   ├── tdd-e2e-generator.md      # RED phase
│   ├── green-implementer.md       # GREEN phase
│   ├── refactor-agent.md          # REFACTOR phase
│   ├── architecture-docs-generator.md  # DOCUMENT phase
│   ├── phase-monitor.md           # CB/Dual-Gate evaluator
│   ├── loop-controller.md         # Orchestrator (needs QA integration)
│   └── ...
├── commands/
│   └── execute-prp.md             # Main workflow (needs QA phase)
└── lib/
    ├── circuit-breaker-spec.md
    ├── dual-gate-spec.md
    ├── status-block-spec.md
    └── metrics-spec.md
```

### Desired Codebase Tree

```bash
claude/
├── agents/
│   ├── ...existing agents
│   └── qa-agent.md                # NEW: QA validation agent
├── commands/
│   └── execute-prp.md             # MODIFY: Add QA phase
└── lib/
    ├── ...existing specs
    ├── qa-checklist.yml           # NEW: Objective checklist config
    └── qa-tools-mapping.yml       # NEW: Stack-specific tools

docs/
└── templates/
    └── qa-report-template.md      # NEW: Report format

.claude-plugin/
└── plugin.json                    # MODIFY: Add agent, MCP server ref
```

### Known Gotchas

```yaml
# CRITICAL: QA must use DIFFERENT model than implementer
# This prevents "echo chamber" validation (AI agreeing with itself)
# Enforcement: Check parent agent model, use opposite
# Example: If GREEN used opus → QA uses sonnet (or vice-versa)

# CRITICAL: Memory queries are MANDATORY, not optional
# QA must complete all 4 queries before checklist validation
# Fallback: If MCP unavailable, emit WARNING but continue validation

# CRITICAL: Per-cycle attempt counter, not global
# Counter resets when GREEN phase succeeds
# Only counts rejections within same GREEN→QA cycle

# GOTCHA: Lint/test commands vary by stack
# Must auto-detect stack from package.json, pyproject.toml, go.mod, etc.
# Fallback to manual stack declaration in PRP if auto-detect fails
```

---

## Implementation Blueprint

### Data Models and Structure

```yaml
# qa-checklist.yml schema
qa_checklist:
  version: "1.0.0"

  funcionalidade:
    - id: F1
      criterio: "100% testes E2E passando"
      validacao: "test_runner exit_code == 0"
      comando: "{detected_test_command}"
      blocking: true
    - id: F2
      criterio: "Todos acceptance criteria do PRP cobertos"
      validacao: "criteria_coverage == 100%"
      metodo: "parse_prp_and_verify"
      blocking: true

  qualidade_codigo:
    - id: C1
      criterio: "Lint passa sem erros"
      validacao: "linter exit_code == 0"
      comando: "{detected_lint_command}"
      blocking: true
    - id: C2
      criterio: "Complexidade ciclomática <10"
      validacao: "max_complexity < 10"
      comando: "{detected_complexity_command}"
      blocking: true
    - id: C3
      criterio: "Sem código duplicado (>5%)"
      validacao: "duplication_percentage < 5"
      comando: "jscpd --threshold 5"
      blocking: false  # WARNING only
    - id: C4
      criterio: "Naming conventions seguidas"
      validacao: "naming_violations == 0"
      comando: "{detected_lint_command} --rule naming"
      blocking: false  # WARNING only

  documentacao:
    - id: D1
      criterio: "README atualizado com feature"
      validacao: "readme_contains_feature"
      metodo: "grep_readme"
      blocking: true
    - id: D2
      criterio: "ADR existe para decisões"
      validacao: "adr_file_exists"
      metodo: "check_docs_adr"
      blocking: true
    - id: D3
      criterio: "API docs gerados (se aplicável)"
      validacao: "openapi_valid OR not_applicable"
      metodo: "validate_openapi"
      blocking: false
    - id: D4
      criterio: "Comentários em funções complexas"
      validacao: "complex_funcs_documented"
      metodo: "check_complexity_comments"
      blocking: false
    - id: D5
      criterio: "CHANGELOG atualizado"
      validacao: "changelog_has_entry"
      metodo: "grep_changelog"
      blocking: true
```

```yaml
# qa-tools-mapping.yml schema
qa_tools:
  detection:
    node_typescript:
      markers: ["package.json", "tsconfig.json"]

    python:
      markers: ["pyproject.toml", "setup.py", "requirements.txt"]

    golang:
      markers: ["go.mod", "go.sum"]

    lua:
      markers: ["*.rockspec", "lua/"]

  stacks:
    node_typescript:
      test: "npm test"
      lint: "npx eslint . --ext .ts,.tsx,.js,.jsx"
      complexity: "npx eslint . --rule 'complexity: [error, 10]'"
      duplication: "npx jscpd --threshold 5"

    python:
      test: "pytest tests/ -v"
      lint: "ruff check ."
      complexity: "radon cc . -a -nc"
      duplication: "jscpd --threshold 5"

    golang:
      test: "go test ./..."
      lint: "golangci-lint run"
      complexity: "gocyclo -over 10 ."
      duplication: "dupl -threshold 50 ."

    lua:
      test: "busted spec/"
      lint: "luacheck ."
      complexity: "luacheck . --config .luacheckrc"
      duplication: "jscpd --threshold 5"
```

### Tasks to Complete

```yaml
Task 1:
CREATE claude/agents/qa-agent.md:
  - MIRROR structure from: claude/agents/green-implementer.md
  - ADD sections:
    - Memory Integration (4 queries)
    - Stack Detection
    - Checklist Validation
    - Report Generation
    - Model Diversity Enforcement
  - EMIT PRP_PHASE_STATUS with QA-specific metrics

Task 2:
CREATE claude/lib/qa-checklist.yml:
  - DEFINE 3 categories: funcionalidade, qualidade_codigo, documentacao
  - MARK each criterion as blocking (true/false)
  - INCLUDE validation command or method for each

Task 3:
CREATE claude/lib/qa-tools-mapping.yml:
  - DEFINE detection markers per stack
  - MAP commands per stack: test, lint, complexity, duplication
  - SUPPORT 6 stacks: Node/TS, Python, Go, Lua, JS

Task 4:
CREATE docs/templates/qa-report-template.md:
  - STRUCTURE: Verdict, Memory Context, Checklist Results, Issues, Recommendations
  - INCLUDE tables for each checklist category
  - ADD Next Action section

Task 5:
MODIFY claude/commands/execute-prp.md:
  - ADD QA phase after DOCUMENT in phase_sequence
  - ADD bp:qa-agent to phase_agents mapping
  - ADD QA-specific Circuit Breaker threshold (3)
  - ADD retry logic: REJECT → GREEN (max 3x)
  - ADD human escalation after 3 rejections

Task 6:
MODIFY claude/agents/loop-controller.md:
  - ADD QA to phase list
  - ADD per-cycle attempt counter
  - ADD SHIP trigger on QA APPROVE
  - ADD human escalation flow

Task 7:
MODIFY .claude-plugin/plugin.json:
  - ADD qa-agent.md to agents array
  - ADD claude-self-reflect MCP server reference (optional external)

Task 8:
CREATE tests/bats/qa_agent.bats:
  - TEST checklist validation
  - TEST memory query integration
  - TEST reject/approve flow
  - TEST human escalation
```

### Per Task Pseudocode

```markdown
# Task 1: qa-agent.md structure

---
name: qa-agent
description: >
  QA validation agent with memory integration.
  Validates implementation against objective checklist.
  Uses different model than implementer for diversity.
  Emits PRP_PHASE_STATUS with QA metrics.
tools: Read, Grep, Glob, Bash, mcp__claude-self-reflect__*
model: "{opposite_of_implementer}"  # CRITICAL: Model diversity
---

# Purpose
- Query memory for historical context before validation
- Validate against objective checklist (Functionality, Code, Docs)
- Generate detailed QA report
- Emit APPROVE or REJECT verdict

## Memory Integration

BEFORE any validation, execute these 4 queries:

1. Historical Bugs:
   mcp__claude-self-reflect__csr_reflect_on_past(
     query="bugs errors issues {feature_name}",
     limit=5
   )

2. Stack Patterns:
   mcp__claude-self-reflect__csr_search_by_concept(
     concept="{detected_stack} patterns conventions",
     limit=5
   )

3. Architecture Decisions:
   mcp__claude-self-reflect__csr_search_narratives(
     query="architecture decision {feature_area}",
     limit=3
   )

4. File History:
   FOR each modified_file:
     mcp__claude-self-reflect__csr_search_by_file(
       file_path="{modified_file}",
       limit=3
     )

## Checklist Validation Flow

1. Detect stack (read package.json, pyproject.toml, go.mod)
2. Load qa-tools-mapping.yml for detected stack
3. Load qa-checklist.yml
4. FOR each category (funcionalidade, qualidade_codigo, documentacao):
   FOR each criterion:
     IF criterion.comando:
       result = Bash(criterion.comando)
     ELSE:
       result = execute_method(criterion.metodo)
     record_result(criterion.id, PASS/FAIL, details)
5. Calculate totals:
   blocking_passed, blocking_failed, warnings

## Verdict Logic

IF blocking_failed > 0:
  verdict = REJECT
  recommendation = "Fix {blocking_failed} blocking issues"
ELSE:
  verdict = APPROVE
  recommendation = "Ready for SHIP"

## Report Generation

Generate markdown report following qa-report-template.md:
- Verdict (APPROVE/REJECT)
- Memory Context (summary of 4 queries)
- Checklist Results (3 tables)
- Issues Found (if REJECT)
- Recommendations
- Next Action

## Exit Conditions (Dual-Gate)

Gate 1 (Objective): blocking_failed == 0
Gate 2 (Signal): exit_signal == true AND verdict == APPROVE

## PRP_PHASE_STATUS

---PRP_PHASE_STATUS---
TIMESTAMP: {ISO-8601}
PHASE: QA
STATUS: {IN_PROGRESS|COMPLETE}
ITERATION: {integer}
PROGRESS_PERCENT: {calculated}

QA_METRICS:
  CHECKS_TOTAL: {integer}
  CHECKS_PASSING: {integer}
  CHECKS_FAILING: {integer}
  BLOCKING_ISSUES: {integer}
  WARNING_ISSUES: {integer}

MEMORY_CONTEXT:
  QUERIES_EXECUTED: 4
  HISTORICAL_BUGS_FOUND: {integer}
  PATTERNS_IDENTIFIED: {integer}

VERDICT: {APPROVE|REJECT}
ATTEMPT: {1|2|3}

CIRCUIT_BREAKER:
  STATE: {CLOSED|HALF_OPEN|OPEN}
  NO_PROGRESS_COUNT: {integer}

DUAL_GATE:
  GATE_1: {true|false}  # blocking_failed == 0
  GATE_2: {true|false}  # exit_signal AND verdict == APPROVE
  CAN_EXIT: {true|false}

EXIT_SIGNAL: {true|false}
RECOMMENDATION: {single line}
---END_PRP_PHASE_STATUS---
```

### Integration Points

```yaml
# Execute-PRP Integration
COMMAND:
  modify: claude/commands/execute-prp.md
  changes:
    - Add QA to phase_sequence after DOCUMENT
    - Add phase_agents.QA = "bp:qa-agent"
    - Add QA Circuit Breaker threshold = 3
    - Add retry logic for REJECT verdict

# Loop Controller Integration
AGENT:
  modify: claude/agents/loop-controller.md
  changes:
    - Add QA phase to workflow visualization
    - Implement per-cycle attempt counter
    - Add SHIP trigger on QA APPROVE
    - Add human escalation after 3 rejections

# Plugin Registration
CONFIG:
  modify: .claude-plugin/plugin.json
  changes:
    - Add "./claude/agents/qa-agent.md" to agents array
    - Optionally add claude-self-reflect to mcpServers (if bundled)

# Session State
STATE:
  extend: .prp-session/
  new_files:
    - qa-state.json: {attempt: integer, last_verdict: string, report_path: string}
```

---

## Validation Loop

### Level 1: Syntax & Style

```bash
# Validate YAML configurations
python -c "import yaml; yaml.safe_load(open('claude/lib/qa-checklist.yml'))"
python -c "import yaml; yaml.safe_load(open('claude/lib/qa-tools-mapping.yml'))"

# Validate markdown structure
# (Agent files should have valid YAML frontmatter)
grep -q "^---$" claude/agents/qa-agent.md && echo "Frontmatter OK"
```

### Level 2: Integration Tests

```bash
# Run BATS test suite
bats tests/bats/qa_agent.bats

# Expected: All tests pass
# - Checklist loads correctly
# - Stack detection works
# - Memory queries execute (mock)
# - Verdict logic correct
# - Report generated
```

---

## Final Validation Checklist

- [x] QA Agent spec created: `claude/agents/qa-agent.md`
- [x] Checklist config created: `claude/lib/qa-checklist.yml`
- [x] Tools mapping created: `claude/lib/qa-tools-mapping.yml`
- [x] Report template created: `docs/templates/qa-report-template.md`
- [x] Execute-PRP updated with QA phase
- [x] Loop Controller updated with QA integration
- [x] Plugin.json updated with new agent
- [x] BATS tests pass: `bats tests/bats/qa_agent.bats` (51/51 tests passing)
- [x] Memory queries work with claude-self-reflect MCP
- [x] Model diversity enforced (different from implementer)
- [x] APPROVE → SHIP flow works
- [x] REJECT → GREEN retry works (max 3x)
- [x] Human escalation works after 3 rejections

---

## Anti-Patterns to Avoid

- ❌ Don't use same model for QA and implementer (echo chamber)
- ❌ Don't skip memory queries - they're mandatory
- ❌ Don't make all checklist items blocking - some are warnings
- ❌ Don't hardcode stack detection - use marker files
- ❌ Don't forget per-cycle attempt counter (not global)
- ❌ Don't auto-ship on first QA attempt if tests failing
- ❌ Don't ignore Circuit Breaker state in QA phase
- ❌ Don't generate report without memory context section

---

## Appendix A: QA Report Template

```markdown
# QA VALIDATION REPORT

**Feature:** {feature_name}
**PRP:** {prp_path}
**Timestamp:** {ISO-8601}
**Attempt:** {1|2|3} of 3

---

## Verdict: {✅ APPROVED | ❌ REJECTED}

---

## Memory Context (from claude-self-reflect)

| Query | Results | Key Findings |
|-------|---------|--------------|
| Historical Bugs | {count} found | {summary} |
| Stack Patterns | {count} found | {summary} |
| Architecture Decisions | {count} found | {summary} |
| File History | {count} files | {summary} |

---

## Checklist Results

### Funcionalidade

| ID | Check | Status | Details |
|----|-------|--------|---------|
| F1 | 100% E2E Tests Passing | {✅|❌} | {count} passing |
| F2 | Acceptance Criteria Covered | {✅|❌} | {coverage}% |

### Qualidade de Código

| ID | Check | Status | Details |
|----|-------|--------|---------|
| C1 | Lint Clean | {✅|❌} | {error_count} errors |
| C2 | Complexity <10 | {✅|❌} | Max: {max_complexity} |
| C3 | No Duplication | {✅|⚠️} | {percentage}% |
| C4 | Naming Conventions | {✅|⚠️} | {violations} violations |

### Documentação

| ID | Check | Status | Details |
|----|-------|--------|---------|
| D1 | README Updated | {✅|❌} | {details} |
| D2 | ADR Exists | {✅|❌} | {adr_path} |
| D3 | API Docs | {✅|⚠️|N/A} | {details} |
| D4 | Complex Funcs Documented | {✅|⚠️} | {count} functions |
| D5 | CHANGELOG Updated | {✅|❌} | {details} |

---

## Issues Found

### Blocking Issues ({count})

1. **[{ID}]** {description}
   - **File:** {file_path}
   - **Fix:** {suggestion}

### Warnings ({count})

1. **[{ID}]** {description}
   - **File:** {file_path}
   - **Note:** {suggestion}

---

## Recommendations

- {recommendation_1}
- {recommendation_2}
- Memory found similar bug in conv_{id} - verify fix addresses root cause

---

## Next Action

{IF APPROVED}
**✅ Ready for SHIP** - Proceeding to branch creation and PR.

{IF REJECTED}
**❌ Return to GREEN** - Fix {blocking_count} blocking issues.
Attempt {current}/3 - {remaining} attempts remaining before human escalation.
```

---

## Appendix B: Circuit Breaker Thresholds

| Phase | NO_PROGRESS_THRESHOLD | SAME_ERROR_THRESHOLD |
|-------|----------------------|---------------------|
| RED | 3 | 5 |
| GREEN | 2 | 3 |
| REFACTOR | 5 | 5 |
| DOCUMENT | 3 | 5 |
| **QA** | **3** | **3** |

**QA-specific progress detection:**
- Progress = checks_passing increased OR blocking_issues decreased
- No progress = same checks_passing AND same blocking_issues

---

## Task Breakdown Reference

See: [`docs/tasks/qa-agent-memory-integration.md`](../tasks/qa-agent-memory-integration.md)

### Task Summary

| Task ID | Task Name | Priority | Effort | Dependencies |
|---------|-----------|----------|--------|--------------|
| T-001 | Create QA Checklist Configuration | Critical | S | None |
| T-002 | Create QA Tools Mapping Configuration | Critical | S | None |
| T-003 | Create QA Agent Specification | Critical | M | T-001, T-002 |
| T-004 | Create QA Report Template | High | S | None |
| T-005 | Integrate QA Phase into execute-prp.md | Critical | M | T-003 |
| T-006 | Integrate QA Phase into loop-controller.md | Critical | M | T-003 |
| T-007 | Register QA Agent in plugin.json | High | XS | T-003 |
| T-008 | Create QA State Schema Extension | Medium | S | T-006 |
| T-009 | Create BATS Test Suite | High | M | T-001-T-003 |
| T-010 | Integration Testing and Final Validation | Critical | M | T-001-T-009 |

**Estimated Duration:** 4-6 development days
**Critical Path:** T-001 → T-003 → T-005/T-006 → T-009 → T-010

---

*PRP generated from brainstorming session 2025-01-27*
*CC-Blueprint-Toolkit v1.7.0 → v1.8.0*
