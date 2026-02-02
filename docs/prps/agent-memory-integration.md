# PRP: Agent Memory Integration with Claude Self-Reflect

> **Status**: Blocked (waiting for dependency)
> **Priority**: High
> **Estimated Effort**: Medium (2-3 days)
> **Confidence Score**: 9/10
> **Dependency**: claude-self-reflect Agent Memory Layer PRP must be completed first

## 1. Goal

Integrate claude-self-reflect's new Agent Memory tools into cc-blueprint-toolkit agents to enable:
- **GREEN phase**: Query patterns and error fixes before implementing
- **QA phase**: Store successful patterns after APPROVE verdict
- **Loop Controller**: Manage session context across agent spawns

**Business Impact**: Reduce GREEN phase iterations by 30-40% through intelligent memory retrieval.

## 2. Background & Problem Statement

### Current State
| Agent | Memory Integration | Tools Available |
|-------|-------------------|-----------------|
| **green-implementer** | None | Read, Write, Edit, Bash, Glob, Grep, TodoWrite |
| **loop-controller** | None | Read, Write, Bash, Glob, Task, TodoWrite |
| **qa-agent** | Partial (4 tools) | Existing `csr_reflect_on_past`, `csr_search_by_concept`, `csr_search_narratives`, `csr_search_by_file` |

### Pain Points
| Problem | Impact | Root Cause |
|---------|--------|------------|
| GREEN repeats resolved errors | +2-3 iterations | No `csr_get_error_fix` tool |
| Patterns rediscovered each spawn | Wasted tokens | No `csr_get_pattern` tool |
| Context lost between spawns | 20% token overhead | No session context tools |
| Learnings not persisted | Knowledge loss | No `csr_store_pattern` on APPROVE |

### Success Metrics
| Metric | Baseline | Target |
|--------|----------|--------|
| GREEN iterations per feature | 5-7 | 3-4 |
| Repeated errors per session | 30% | <5% |
| Context rebuild overhead | 20% tokens | <5% |
| Pattern reuse rate | 0% | >60% |

## 3. Architecture Decisions

### ADR-001: Memory Query Before Implementation
**Decision**: GREEN agent queries memory for patterns and error fixes BEFORE starting implementation.

**Rationale**:
- Early context prevents repeated mistakes
- Minimal overhead (2 MCP calls at start)
- Non-blocking if MCP unavailable

### ADR-002: Pattern Storage on QA APPROVE
**Decision**: QA agent stores successful patterns AFTER issuing APPROVE verdict.

**Rationale**:
- Only validated implementations become patterns
- Single point of extraction
- Clear success signal

### ADR-003: Session Context in Loop Controller
**Decision**: Loop-controller manages session context and passes it to spawned agents.

**Rationale**:
- Centralized context management
- Consistent context across all agents
- Enables session resume with full context

### ADR-004: Explicit Agent Type Parameter
**Decision**: All agents pass explicit `agent_type` parameter on every tool call.

**Rationale**:
- Clear audit trail
- Enables per-agent filtering
- No hidden state dependencies

## 4. Technical Specification

### 4.1 New Tools to Add (from claude-self-reflect)

```yaml
pattern_memory:
  - csr_get_pattern         # Query patterns by feature/stack
  - csr_store_pattern       # Store successful patterns

error_resolution:
  - csr_get_error_fix       # Query similar errors
  - csr_store_error_resolution  # Store error fixes

session_context:
  - csr_get_session_context    # Load session context
  - csr_update_session_context # Update session context
  - csr_flush_session          # Flush before termination
```

### 4.2 Agent Modifications

#### green-implementer.md

**Add to tools line:**
```yaml
tools: Read, Write, Edit, Bash, Glob, Grep, TodoWrite, mcp__claude-self-reflect__csr_get_pattern, mcp__claude-self-reflect__csr_get_error_fix, mcp__claude-self-reflect__csr_update_session_context
```

**Add to Step 1 (Load Context):**
```yaml
### Step 0: Query Memory (BEFORE implementation)

memory_queries:
  1_relevant_patterns:
    tool: mcp__claude-self-reflect__csr_get_pattern
    params:
      query: "{feature_description} implementation"
      feature_area: "{detected_feature_area}"
      stack: "{detected_stack}"
      agent_type: "green-implementer"
      limit: 3
      min_score: 0.7
    purpose: "Find similar implementations to follow"
    on_failure: "Continue without patterns (non-blocking)"

  2_similar_errors:
    tool: mcp__claude-self-reflect__csr_get_error_fix
    params:
      error_message: "{last_test_error if available}"
      agent_type: "green-implementer"
      limit: 3
      min_score: 0.85
    purpose: "Find fixes for similar errors"
    on_failure: "Continue without error context (non-blocking)"

  3_update_session:
    tool: mcp__claude-self-reflect__csr_update_session_context
    params:
      session_id: "{session_id}"
      agent_type: "green-implementer"
      task_description: "Implementing {feature_name}"
    purpose: "Track session progress"
```

**Add after error handling section:**
```yaml
### Error Resolution with Memory

when: test fails after implementation
action:
  1. QUERY: csr_get_error_fix with error message
  2. IF fix found with score > 0.85:
     - APPLY: suggested fix
     - LOG: "Applied fix from memory"
  3. ELSE:
     - ANALYZE: error independently
     - IMPLEMENT: fix
  4. RUN: test again
```

#### qa-agent.md

**Add to tools line:**
```yaml
tools: Read, Write, Grep, Glob, Bash, mcp__claude-self-reflect__csr_reflect_on_past, mcp__claude-self-reflect__csr_search_by_concept, mcp__claude-self-reflect__csr_search_narratives, mcp__claude-self-reflect__csr_search_by_file, mcp__claude-self-reflect__csr_store_pattern, mcp__claude-self-reflect__csr_store_error_resolution, mcp__claude-self-reflect__csr_flush_session
```

**Add Step 8 (after verdict calculation):**
```yaml
### Step 8: Store Learnings (on APPROVE only)

IF verdict == "APPROVE":

  8.1_store_patterns:
    FOR each significant_implementation in modified_files:
      tool: mcp__claude-self-reflect__csr_store_pattern
      params:
        content: "{implementation_description}"
        pattern_type: "implementation"
        feature_area: "{detected_feature_area}"
        stack: "{detected_stack}"
        code_snippets: ["{key_code_snippets}"]
        files_involved: ["{modified_files}"]
        trigger_context: "{from_prp_problem_statement}"
        success_criteria: "{from_prp_success_criteria}"
        agent_type: "qa-agent"
        session_id: "{session_id}"
      purpose: "Store successful pattern for future reuse"

  8.2_store_error_resolutions:
    FOR each error_resolved in session_errors:
      tool: mcp__claude-self-reflect__csr_store_error_resolution
      params:
        error_type: "{error.type}"
        error_message: "{error.message}"
        stack_trace: "{error.stack_trace}"
        resolution_steps: ["{how_it_was_fixed}"]
        files_modified: ["{files_that_fixed_it}"]
        agent_type: "qa-agent"
        session_id: "{session_id}"
        confidence: 1.0  # High confidence since QA approved
      purpose: "Store error fix for future reference"

  8.3_flush_session:
    tool: mcp__claude-self-reflect__csr_flush_session
    params:
      session_id: "{session_id}"
      agent_type: "qa-agent"
      status: "completed"
      final_summary: "{implementation_summary}"
    purpose: "Finalize session and extract learnings"
```

#### loop-controller.md

**Add to tools line:**
```yaml
tools: Read, Write, Bash, Glob, Task, TodoWrite, mcp__claude-self-reflect__csr_get_session_context, mcp__claude-self-reflect__csr_update_session_context
```

**Add to Step 2.3 (before spawning agent):**
```yaml
# 2.3a LOAD MEMORY CONTEXT (NEW)
memory_context = None
try:
  memory_context = CALL mcp__claude-self-reflect__csr_get_session_context(
    session_id: loop_state.session_id,
    agent_type: "loop-controller"
  )
except:
  LOG: "Memory context unavailable, continuing without"

# 2.3b UPDATE SESSION CONTEXT (NEW)
CALL mcp__claude-self-reflect__csr_update_session_context(
  session_id: loop_state.session_id,
  agent_type: "loop-controller",
  progress_summary: f"Starting {current_phase} iteration {loop_state.current_iteration}"
)
```

**Modify Agent Prompt Builder:**
```markdown
# Prompt for {phase} Phase Agent

## Context
- PRP File: {prp_file}
- Current Phase: {phase}
- Iteration: {iteration}
- Session ID: {session_id}

## Previous Metrics
{last_metrics as YAML}

## Memory Context (NEW)
{memory_context if available, else "No memory context available"}

## Instructions
Execute the {phase} phase for the PRP at {prp_file}.

**Memory Tools Available**: Use csr_get_pattern and csr_get_error_fix before implementing.

After completing your work, emit a PRP_PHASE_STATUS block.
```

### 4.3 Workflow Changes

#### Before (Current Flow)
```
GREEN spawn → Implement from scratch → Repeat errors → QA validates → Done
```

#### After (With Memory)
```
GREEN spawn → Query memory → Apply patterns → Avoid known errors → QA validates → Store patterns → Done
```

## 5. Implementation Plan

### Phase 1: Update Agent Tool Lists (1 hour)

1. Edit `claude/agents/green-implementer.md`:
   - Add 3 new MCP tools to tools line
   - Add Step 0 for memory queries
   - Add error resolution with memory section

2. Edit `claude/agents/qa-agent.md`:
   - Add 3 new MCP tools to tools line
   - Add Step 8 for storing learnings

3. Edit `claude/agents/loop-controller.md`:
   - Add 2 new MCP tools to tools line
   - Add memory context loading before spawn
   - Update agent prompt builder

### Phase 2: Update Workflow Documentation (1 hour)

1. Update `claude/lib/loop-state-spec.md`:
   - Add `memory_context` field to schema
   - Add `patterns_applied` tracking
   - Add `errors_resolved` tracking

2. Update workflow diagrams if any

### Phase 3: Testing (2-4 hours)

1. Test with sample PRP:
   - Verify GREEN queries memory
   - Verify QA stores patterns on APPROVE
   - Verify session context flows through

2. Test fallback behavior:
   - MCP unavailable → agents continue without memory
   - Low score results → agents ignore and proceed

## 6. Reference Files

### Files to Modify

| File | Changes |
|------|---------|
| `claude/agents/green-implementer.md` | Add 3 tools, Step 0, error resolution |
| `claude/agents/qa-agent.md` | Add 3 tools, Step 8 |
| `claude/agents/loop-controller.md` | Add 2 tools, memory context |
| `claude/lib/loop-state-spec.md` | Add memory fields to schema |

### Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| claude-self-reflect Agent Memory Layer | **BLOCKING** | Must be implemented first |
| claude-self-reflect MCP server running | Required | For tool calls to work |

## 7. Validation Gates

### Unit Tests
```bash
# Verify agent files are valid YAML frontmatter
grep -E "^tools:" claude/agents/*.md

# Verify MCP tools are correctly named
grep "mcp__claude-self-reflect__csr_" claude/agents/*.md
```

### Integration Tests
```bash
# Run sample PRP with memory integration
/bp:autonomous docs/prps/test-feature.md

# Verify memory queries in logs
grep "csr_get_pattern\|csr_get_error_fix" .prp-session/phase-status.log

# Verify patterns stored
grep "csr_store_pattern" .prp-session/phase-status.log
```

### Manual Validation
1. Run GREEN phase and verify memory query at start
2. Run QA phase with APPROVE and verify pattern storage
3. Resume session and verify context is loaded

## 8. Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| MCP server unavailable | Medium | Low | Non-blocking fallback, continue without memory |
| Slow memory queries | Low | Medium | Async queries, timeout at 5s |
| Wrong patterns applied | Medium | Low | Score threshold (0.7 for patterns, 0.85 for errors) |
| Storage failure | Low | Low | Log warning, don't block QA APPROVE |

## 9. Out of Scope

- Modifying the MCP tools themselves (handled by claude-self-reflect PRP)
- UI for pattern management
- Cross-project pattern sharing
- Memory decay configuration

## 10. Success Criteria

| Criterion | Measurement |
|-----------|-------------|
| GREEN queries memory before implementing | Log shows `csr_get_pattern` call in Step 0 |
| Errors are looked up | Log shows `csr_get_error_fix` call on test failure |
| Patterns stored on APPROVE | Log shows `csr_store_pattern` in QA Step 8 |
| Session context persists | Resume shows previous context loaded |
| Non-blocking on failure | Agents continue if MCP unavailable |

---

## Appendix A: Tool Call Examples

### GREEN Phase - Query Patterns
```python
# At start of GREEN phase
csr_get_pattern(
    query="FastAPI authentication endpoint",
    feature_area="authentication",
    stack="fastapi",
    agent_type="green-implementer",
    limit=3,
    min_score=0.7
)
```

### GREEN Phase - Query Error Fix
```python
# After test failure
csr_get_error_fix(
    error_message="TypeError: 'NoneType' object is not subscriptable",
    error_type="TypeError",
    agent_type="green-implementer",
    limit=3,
    min_score=0.85
)
```

### QA Phase - Store Pattern
```python
# After APPROVE verdict
csr_store_pattern(
    content="FastAPI endpoint with JWT authentication and Pydantic validation",
    pattern_type="implementation",
    feature_area="authentication",
    stack="fastapi",
    code_snippets=["@router.post('/login')\nasync def login(...)"],
    files_involved=["app/routers/auth.py", "app/models/user.py"],
    trigger_context="Need to implement secure login endpoint",
    success_criteria="Returns JWT token on valid credentials",
    agent_type="qa-agent",
    session_id="session-abc123"
)
```

### Loop Controller - Session Context
```python
# Before spawning GREEN agent
csr_get_session_context(
    session_id="session-abc123",
    agent_type="loop-controller"
)

# After spawning agent
csr_update_session_context(
    session_id="session-abc123",
    agent_type="loop-controller",
    progress_summary="Starting GREEN phase iteration 3",
    patterns_applied=["auth-pattern-001"],
    errors_encountered=["TypeError: NoneType..."]
)
```

---

**Dependency**: This PRP is **BLOCKED** until claude-self-reflect Agent Memory Layer PRP is completed.

**Task Breakdown Document**: [docs/tasks/agent-memory-integration.md](../tasks/agent-memory-integration.md)
