#!/usr/bin/env bats
# qa_agent.bats - QA Agent integration tests
# Tests the QA phase: memory queries, checklist validation, verdict logic, model diversity

load 'test_helper'

# =============================================================================
# SETUP AND TEARDOWN
# =============================================================================

setup() {
    setup_test_session
}

teardown() {
    teardown_test_session
}

# =============================================================================
# QA CHECKLIST TESTS
# =============================================================================

@test "QA checklist file exists and is valid YAML" {
    cd "$ORIGINAL_DIR"
    [ -f "claude/lib/qa-checklist.yml" ]
    # Check for valid YAML structure
    run grep "^qa_checklist:" claude/lib/qa-checklist.yml
    [ "$status" -eq 0 ]
}

@test "QA checklist has 3 categories" {
    cd "$ORIGINAL_DIR"
    run grep -c "funcionalidade:\|qualidade_codigo:\|documentacao:" claude/lib/qa-checklist.yml
    [ "$output" -eq 3 ]
}

@test "QA checklist has 7 blocking criteria" {
    cd "$ORIGINAL_DIR"
    # Use pattern that excludes comment lines
    run bash -c 'grep -E "^[[:space:]]+blocking:" claude/lib/qa-checklist.yml | grep -c "true"'
    [ "$output" -eq 7 ]
}

@test "QA checklist has 4 warning criteria" {
    cd "$ORIGINAL_DIR"
    # Use pattern that excludes comment lines
    run bash -c 'grep -E "^[[:space:]]+blocking:" claude/lib/qa-checklist.yml | grep -c "false"'
    [ "$output" -eq 4 ]
}

@test "QA checklist total has 11 criteria" {
    cd "$ORIGINAL_DIR"
    local total=$(grep -c "id: [FCDE][0-9]" claude/lib/qa-checklist.yml)
    [ "$total" -eq 11 ]
}

# =============================================================================
# QA TOOLS MAPPING TESTS
# =============================================================================

@test "QA tools mapping file exists and is valid YAML" {
    cd "$ORIGINAL_DIR"
    [ -f "claude/lib/qa-tools-mapping.yml" ]
    run grep "^qa_tools:" claude/lib/qa-tools-mapping.yml
    [ "$status" -eq 0 ]
}

@test "QA tools mapping has node_typescript stack" {
    cd "$ORIGINAL_DIR"
    run grep "node_typescript:" claude/lib/qa-tools-mapping.yml
    [ "$status" -eq 0 ]
}

@test "QA tools mapping has python stack" {
    cd "$ORIGINAL_DIR"
    run grep "python:" claude/lib/qa-tools-mapping.yml
    [ "$status" -eq 0 ]
}

@test "QA tools mapping has golang stack" {
    cd "$ORIGINAL_DIR"
    run grep "golang:" claude/lib/qa-tools-mapping.yml
    [ "$status" -eq 0 ]
}

@test "QA tools mapping has lua stack" {
    cd "$ORIGINAL_DIR"
    run grep "lua:" claude/lib/qa-tools-mapping.yml
    [ "$status" -eq 0 ]
}

@test "QA tools mapping has detection markers" {
    cd "$ORIGINAL_DIR"
    run grep "markers:" claude/lib/qa-tools-mapping.yml
    [ "$status" -eq 0 ]
}

# =============================================================================
# QA AGENT SPEC TESTS
# =============================================================================

@test "QA Agent spec file exists" {
    cd "$ORIGINAL_DIR"
    [ -f "claude/agents/qa-agent.md" ]
}

@test "QA Agent has required MCP tools" {
    cd "$ORIGINAL_DIR"
    run grep "mcp__claude-self-reflect__csr_reflect_on_past" claude/agents/qa-agent.md
    [ "$status" -eq 0 ]
    run grep "mcp__claude-self-reflect__csr_search_by_concept" claude/agents/qa-agent.md
    [ "$status" -eq 0 ]
    run grep "mcp__claude-self-reflect__csr_search_narratives" claude/agents/qa-agent.md
    [ "$status" -eq 0 ]
    run grep "mcp__claude-self-reflect__csr_search_by_file" claude/agents/qa-agent.md
    [ "$status" -eq 0 ]
}

@test "QA Agent has 4 memory queries section" {
    cd "$ORIGINAL_DIR"
    run grep -c "tool: mcp__claude-self-reflect" claude/agents/qa-agent.md
    [ "$output" -ge 4 ]
}

@test "QA Agent has model diversity section" {
    cd "$ORIGINAL_DIR"
    run grep "Model Diversity" claude/agents/qa-agent.md
    [ "$status" -eq 0 ]
}

@test "QA Agent has verdict logic section" {
    cd "$ORIGINAL_DIR"
    run grep "verdict_logic:" claude/agents/qa-agent.md
    [ "$status" -eq 0 ]
}

@test "QA Agent registered in plugin.json" {
    cd "$ORIGINAL_DIR"
    run grep "qa-agent.md" .claude-plugin/plugin.json
    [ "$status" -eq 0 ]
}

# =============================================================================
# QA REPORT TEMPLATE TESTS
# =============================================================================

@test "QA report template exists" {
    cd "$ORIGINAL_DIR"
    [ -f "docs/templates/qa-report-template.md" ]
}

@test "QA report template has verdict section" {
    cd "$ORIGINAL_DIR"
    run grep "## Verdict:" docs/templates/qa-report-template.md
    [ "$status" -eq 0 ]
}

@test "QA report template has memory context section" {
    cd "$ORIGINAL_DIR"
    run grep "## Memory Context" docs/templates/qa-report-template.md
    [ "$status" -eq 0 ]
}

@test "QA report template has checklist results section" {
    cd "$ORIGINAL_DIR"
    run grep "## Checklist Results" docs/templates/qa-report-template.md
    [ "$status" -eq 0 ]
}

@test "QA report template has all 3 categories" {
    cd "$ORIGINAL_DIR"
    run grep -c "### Funcionalidade\|### Qualidade\|### Documentacao" docs/templates/qa-report-template.md
    [ "$output" -eq 3 ]
}

# =============================================================================
# VERDICT LOGIC TESTS
# =============================================================================

@test "Verdict is REJECT when blocking_failed > 0" {
    local verdict=$(calculate_qa_verdict 1 2)
    [ "$verdict" = "REJECT" ]
}

@test "Verdict is APPROVE when blocking_failed = 0" {
    local verdict=$(calculate_qa_verdict 0 2)
    [ "$verdict" = "APPROVE" ]
}

@test "Verdict is APPROVE with warnings but no blocking issues" {
    local verdict=$(calculate_qa_verdict 0 5)
    [ "$verdict" = "APPROVE" ]
}

# =============================================================================
# DUAL-GATE EXIT TESTS FOR QA PHASE
# =============================================================================

@test "QA Gate 1 satisfied when blocking_issues = 0 and verdict = APPROVE" {
    local gate1=$(evaluate_qa_gate1 0 "APPROVE")
    [ "$gate1" = "true" ]
}

@test "QA Gate 1 not satisfied when blocking_issues > 0" {
    local gate1=$(evaluate_qa_gate1 1 "APPROVE")
    [ "$gate1" = "false" ]
}

@test "QA Gate 1 not satisfied when verdict = REJECT" {
    local gate1=$(evaluate_qa_gate1 0 "REJECT")
    [ "$gate1" = "false" ]
}

@test "QA can exit when both gates satisfied" {
    local gate1=$(evaluate_qa_gate1 0 "APPROVE")
    local gate2="true"  # exit_signal
    local can_exit=$(evaluate_dual_gate "$gate1" "$gate2")
    [ "$can_exit" = "true" ]
}

@test "QA cannot exit when Gate 1 not satisfied" {
    local gate1=$(evaluate_qa_gate1 2 "REJECT")
    local gate2="true"
    local can_exit=$(evaluate_dual_gate "$gate1" "$gate2")
    [ "$can_exit" = "false" ]
}

# =============================================================================
# CIRCUIT BREAKER INTEGRATION TESTS
# =============================================================================

@test "QA phase has Circuit Breaker threshold of 3" {
    local threshold=$(get_no_progress_threshold "QA")
    [ "$threshold" -eq 3 ]
}

@test "QA phase same error threshold is 3" {
    local threshold=$(get_same_error_threshold "QA")
    [ "$threshold" -eq 3 ]
}

# =============================================================================
# PROGRESS DETECTION TESTS FOR QA
# =============================================================================

@test "QA detects progress when checks_passing increases" {
    local progress=$(detect_qa_progress 5 3 3 4)
    [ "$progress" = "true" ]
}

@test "QA detects progress when blocking_issues decreases" {
    local progress=$(detect_qa_progress 3 3 2 4)
    [ "$progress" = "true" ]
}

@test "QA detects no progress when nothing changes" {
    local progress=$(detect_qa_progress 3 3 4 4)
    [ "$progress" = "false" ]
}

# =============================================================================
# RETRY LOGIC TESTS
# =============================================================================

@test "QA retry returns to GREEN when attempt < 3" {
    local action=$(get_qa_retry_action 1 "REJECT")
    [ "$action" = "GREEN" ]
}

@test "QA retry returns to GREEN when attempt = 2" {
    local action=$(get_qa_retry_action 2 "REJECT")
    [ "$action" = "GREEN" ]
}

@test "QA escalates to human when attempt = 3 and REJECT" {
    local action=$(get_qa_retry_action 3 "REJECT")
    [ "$action" = "ESCALATE" ]
}

@test "QA proceeds to SHIP on APPROVE" {
    local action=$(get_qa_retry_action 1 "APPROVE")
    [ "$action" = "SHIP" ]
}

# =============================================================================
# MODEL DIVERSITY TESTS
# =============================================================================

@test "QA model is sonnet when implementer used opus" {
    local qa_model=$(get_qa_model "opus")
    [ "$qa_model" = "sonnet" ]
}

@test "QA model is opus when implementer used sonnet" {
    local qa_model=$(get_qa_model "sonnet")
    [ "$qa_model" = "opus" ]
}

@test "QA model defaults to sonnet for unknown implementer" {
    local qa_model=$(get_qa_model "unknown")
    [ "$qa_model" = "sonnet" ]
}

# =============================================================================
# STATUS BLOCK TESTS
# =============================================================================

@test "QA status block has QA_METRICS section" {
    local status_block=$(generate_qa_status_block \
        "IN_PROGRESS" 1 50 \
        11 8 3 2 1 \
        4 3 2 1 \
        "CLOSED" 0 \
        "false" "false" \
        "false" "Continue validation")

    echo "$status_block" | grep -q "QA_METRICS:"
    [ $? -eq 0 ]
}

@test "QA status block has MEMORY_CONTEXT section" {
    local status_block=$(generate_qa_status_block \
        "IN_PROGRESS" 1 50 \
        11 8 3 2 1 \
        4 3 2 1 \
        "CLOSED" 0 \
        "false" "false" \
        "false" "Continue validation")

    echo "$status_block" | grep -q "MEMORY_CONTEXT:"
    [ $? -eq 0 ]
}

@test "QA status block has VERDICT field" {
    local status_block=$(generate_qa_status_block \
        "COMPLETE" 1 100 \
        11 11 0 0 2 \
        4 3 2 1 \
        "CLOSED" 0 \
        "true" "true" \
        "true" "Ready for SHIP" \
        "APPROVE")

    echo "$status_block" | grep -q "VERDICT: APPROVE"
    [ $? -eq 0 ]
}

@test "QA status block has ATTEMPT field" {
    local status_block=$(generate_qa_status_block \
        "IN_PROGRESS" 2 60 \
        11 9 2 1 1 \
        4 3 2 1 \
        "CLOSED" 0 \
        "false" "false" \
        "false" "Fix blocking issues")

    echo "$status_block" | grep -q "ATTEMPT: 2"
    [ $? -eq 0 ]
}

# =============================================================================
# WORKFLOW INTEGRATION TESTS
# =============================================================================

@test "execute-prp.md has QA phase" {
    cd "$ORIGINAL_DIR"
    run grep "PHASE QA" claude/commands/execute-prp.md
    [ "$status" -eq 0 ]
}

@test "execute-prp.md has QA Circuit Breaker threshold" {
    cd "$ORIGINAL_DIR"
    # Check QA phase has threshold of 3 in the thresholds table
    run grep "| QA | 3" claude/commands/execute-prp.md
    [ "$status" -eq 0 ]
}

@test "loop-controller.md has QA in phase sequence" {
    cd "$ORIGINAL_DIR"
    run grep "QA" claude/agents/loop-controller.md
    [ "$status" -eq 0 ]
}

@test "loop-controller.md has QA agent reference" {
    cd "$ORIGINAL_DIR"
    run grep "bp:qa-agent" claude/agents/loop-controller.md
    [ "$status" -eq 0 ]
}

@test "loop-controller.md has model diversity for QA" {
    cd "$ORIGINAL_DIR"
    run grep "model_param" claude/agents/loop-controller.md
    [ "$status" -eq 0 ]
}
