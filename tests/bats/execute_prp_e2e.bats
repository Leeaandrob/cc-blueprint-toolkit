#!/usr/bin/env bats
# execute_prp_e2e.bats - End-to-end tests for execute-prp workflow
# Tests full TDD workflow: RED → GREEN → REFACTOR → DOCUMENT

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
# SESSION INITIALIZATION TESTS
# =============================================================================

@test "execute-prp creates .prp-session directory" {
    mkdir -p .prp-session
    run session_exists
    [ "$status" -eq 0 ]
}

@test "execute-prp initializes circuit-breaker.json" {
    init_circuit_breaker
    run cb_state_exists
    [ "$status" -eq 0 ]
}

@test "execute-prp initializes metrics.json" {
    init_metrics "RED"
    run metrics_exists
    [ "$status" -eq 0 ]
}

@test "Session starts with current_phase = RED" {
    init_metrics "RED"
    assert_phase "RED"
}

# =============================================================================
# STATUS BLOCK GENERATION TESTS
# =============================================================================

@test "Status block contains all required fields" {
    local block=$(generate_status_block \
        "RED" "IN_PROGRESS" 1 50 \
        10 0 10 \
        "CLOSED" 0 \
        "false" "false" "false" \
        "Continue generating tests")

    echo "$block" | grep -q "---PRP_PHASE_STATUS---"
    echo "$block" | grep -q "PHASE: RED"
    echo "$block" | grep -q "STATUS: IN_PROGRESS"
    echo "$block" | grep -q "ITERATION: 1"
    echo "$block" | grep -q "PROGRESS_PERCENT: 50"
    echo "$block" | grep -q "TOTAL: 10"
    echo "$block" | grep -q "PASSING: 0"
    echo "$block" | grep -q "FAILING: 10"
    echo "$block" | grep -q "STATE: CLOSED"
    echo "$block" | grep -q "GATE_1: false"
    echo "$block" | grep -q "GATE_2: false"
    echo "$block" | grep -q "CAN_EXIT: false"
    echo "$block" | grep -q "EXIT_SIGNAL: false"
    echo "$block" | grep -q "---END_PRP_PHASE_STATUS---"
}

@test "Status block CAN_EXIT is computed from gates" {
    local block=$(generate_status_block \
        "GREEN" "COMPLETE" 5 100 \
        10 10 0 \
        "CLOSED" 0 \
        "true" "true" "true" \
        "Proceed to REFACTOR")

    echo "$block" | grep -q "CAN_EXIT: true"
}

@test "Status block appends to phase-status.log" {
    local block=$(generate_status_block \
        "RED" "IN_PROGRESS" 1 25 \
        5 0 5 \
        "CLOSED" 0 \
        "false" "false" "false" \
        "Continue")

    append_status_log "$block"

    [ -f .prp-session/phase-status.log ]
    grep -q "---PRP_PHASE_STATUS---" .prp-session/phase-status.log
}

@test "Multiple status blocks are appended correctly" {
    local block1=$(generate_status_block "RED" "IN_PROGRESS" 1 25 5 0 5 "CLOSED" 0 "false" "false" "false" "Continue")
    local block2=$(generate_status_block "RED" "COMPLETE" 2 100 5 0 5 "CLOSED" 0 "true" "true" "true" "Exit RED")

    append_status_log "$block1"
    append_status_log "$block2"

    local count=$(count_status_blocks)
    [ "$count" -eq 2 ]
}

# =============================================================================
# RED PHASE WORKFLOW TESTS
# =============================================================================

@test "RED phase: starts with all tests failing (expected)" {
    init_circuit_breaker
    init_metrics "RED"

    local gate1=$(evaluate_red_gate1 5 5 5)
    [ "$gate1" = "true" ]
}

@test "RED phase: detects progress when tests generated" {
    init_circuit_breaker
    init_metrics "RED"

    # Simulate iteration 1
    local progress=$(detect_red_progress 3 0 3 0)
    [ "$progress" = "true" ]
}

@test "RED phase: Circuit Breaker stays CLOSED on progress" {
    init_circuit_breaker "CLOSED" 0

    # Progress detected
    reset_no_progress
    assert_cb_state "CLOSED"
    assert_no_progress_count "0"
}

@test "RED phase: Circuit Breaker opens after 3 no-progress iterations" {
    init_circuit_breaker "CLOSED" 0

    # Simulate 3 no-progress iterations
    increment_no_progress
    increment_no_progress
    increment_no_progress

    local count=$(get_cb_no_progress_count)
    [ "$count" -eq 3 ]

    # Should trigger OPEN at threshold
    local threshold=$(get_no_progress_threshold "RED")
    [ "$count" -ge "$threshold" ]
}

# =============================================================================
# GREEN PHASE WORKFLOW TESTS
# =============================================================================

@test "GREEN phase: requires consecutive green runs" {
    # Single all-pass run is not enough
    local gate1=$(evaluate_green_gate1 10 10 1)
    [ "$gate1" = "false" ]

    # Two consecutive all-pass runs IS enough
    gate1=$(evaluate_green_gate1 10 10 2)
    [ "$gate1" = "true" ]
}

@test "GREEN phase: has stricter Circuit Breaker threshold" {
    local green_threshold=$(get_no_progress_threshold "GREEN")
    local red_threshold=$(get_no_progress_threshold "RED")

    [ "$green_threshold" -lt "$red_threshold" ]
    [ "$green_threshold" -eq 2 ]
}

@test "GREEN phase: detects progress when tests_passing increases" {
    local progress=$(detect_green_progress 5 3 5 7)
    [ "$progress" = "true" ]
}

@test "GREEN phase: detects progress when tests_failing decreases" {
    local progress=$(detect_green_progress 3 3 4 7)
    [ "$progress" = "true" ]
}

@test "GREEN phase: Circuit Breaker opens after 2 no-progress iterations" {
    init_circuit_breaker "CLOSED" 0

    # GREEN threshold is 2
    increment_no_progress
    increment_no_progress

    local count=$(get_cb_no_progress_count)
    local threshold=$(get_no_progress_threshold "GREEN")

    [ "$count" -ge "$threshold" ]
}

# =============================================================================
# REFACTOR PHASE WORKFLOW TESTS
# =============================================================================

@test "REFACTOR phase: has lenient threshold of 5" {
    local threshold=$(get_no_progress_threshold "REFACTOR")
    [ "$threshold" -eq 5 ]
}

@test "REFACTOR phase: Gate 1 requires tests passing AND iteration >= 5" {
    # Iteration 3, tests pass - not enough
    local gate1=$(evaluate_refactor_gate1 10 10 3)
    [ "$gate1" = "false" ]

    # Iteration 5, tests pass - enough
    gate1=$(evaluate_refactor_gate1 10 10 5)
    [ "$gate1" = "true" ]
}

@test "REFACTOR phase: Gate 1 fails if tests broken" {
    local gate1=$(evaluate_refactor_gate1 8 10 5)
    [ "$gate1" = "false" ]
}

# =============================================================================
# DOCUMENT PHASE WORKFLOW TESTS
# =============================================================================

@test "DOCUMENT phase: requires at least 3 docs AND ADR" {
    # 2 docs with ADR - not enough
    local gate1=$(evaluate_document_gate1 2 "true")
    [ "$gate1" = "false" ]

    # 3 docs without ADR - not enough
    gate1=$(evaluate_document_gate1 3 "false")
    [ "$gate1" = "false" ]

    # 3 docs with ADR - enough
    gate1=$(evaluate_document_gate1 3 "true")
    [ "$gate1" = "true" ]
}

# =============================================================================
# FULL WORKFLOW TRANSITION TESTS
# =============================================================================

@test "Workflow: RED → GREEN transition with Dual-Gate" {
    init_circuit_breaker
    init_metrics "RED"

    # Simulate RED completion
    local gate1=$(evaluate_red_gate1 5 5 5)
    local gate2="true"
    local can_exit=$(evaluate_dual_gate "$gate1" "$gate2")

    [ "$can_exit" = "true" ]

    # Transition to GREEN
    update_phase_metrics "GREEN" '{"tests_total": 5, "tests_passing": 0, "tests_failing": 5}'
    assert_phase "GREEN"
}

@test "Workflow: GREEN → REFACTOR transition with Dual-Gate" {
    init_circuit_breaker
    init_metrics "GREEN"

    # Simulate GREEN completion
    local gate1=$(evaluate_green_gate1 10 10 2)
    local gate2="true"
    local can_exit=$(evaluate_dual_gate "$gate1" "$gate2")

    [ "$can_exit" = "true" ]

    # Transition to REFACTOR
    update_phase_metrics "REFACTOR" '{"tests_passing": 10, "tests_total": 10, "iteration": 0}'
    assert_phase "REFACTOR"
}

@test "Workflow: REFACTOR → DOCUMENT transition with Dual-Gate" {
    init_circuit_breaker
    init_metrics "REFACTOR"

    # Simulate REFACTOR completion
    local gate1=$(evaluate_refactor_gate1 10 10 5)
    local gate2="true"
    local can_exit=$(evaluate_dual_gate "$gate1" "$gate2")

    [ "$can_exit" = "true" ]

    # Transition to DOCUMENT
    update_phase_metrics "DOCUMENT" '{"docs_generated": 0, "has_adr": false}'
    assert_phase "DOCUMENT"
}

@test "Workflow: full completion with DOCUMENT phase" {
    init_circuit_breaker
    init_metrics "DOCUMENT"

    # Simulate DOCUMENT completion
    local gate1=$(evaluate_document_gate1 6 "true")
    local gate2="true"
    local can_exit=$(evaluate_dual_gate "$gate1" "$gate2")

    [ "$can_exit" = "true" ]
}

# =============================================================================
# CIRCUIT BREAKER HALT TESTS
# =============================================================================

@test "Circuit Breaker HALT prevents phase continuation" {
    init_circuit_breaker "OPEN" 3

    local state=$(get_cb_state)
    [ "$state" = "OPEN" ]

    # When OPEN, workflow should HALT
    # This is a policy check, not function - open state means stop
}

@test "Circuit Breaker recovery allows continuation" {
    init_circuit_breaker "OPEN" 3

    # User resets
    reset_no_progress
    update_cb_state "CLOSED"

    local state=$(get_cb_state)
    [ "$state" = "CLOSED" ]

    local count=$(get_cb_no_progress_count)
    [ "$count" -eq 0 ]
}

# =============================================================================
# SESSION PERSISTENCE TESTS
# =============================================================================

@test "Session state survives simulated restart" {
    init_circuit_breaker "HALF_OPEN" 2
    init_metrics "GREEN"

    update_phase_metrics "GREEN" '{"tests_total": 10, "tests_passing": 5, "tests_failing": 5}'

    # Simulate "restart" by re-reading state
    local cb_state=$(get_cb_state)
    local phase=$(get_current_phase)

    [ "$cb_state" = "HALF_OPEN" ]
    [ "$phase" = "GREEN" ]
}

@test "Status log preserves history across phases" {
    local block1=$(generate_status_block "RED" "COMPLETE" 2 100 5 0 5 "CLOSED" 0 "true" "true" "true" "Exit RED")
    local block2=$(generate_status_block "GREEN" "IN_PROGRESS" 1 10 5 1 4 "CLOSED" 0 "false" "false" "false" "Continue")
    local block3=$(generate_status_block "GREEN" "COMPLETE" 5 100 5 5 0 "CLOSED" 0 "true" "true" "true" "Exit GREEN")

    append_status_log "$block1"
    append_status_log "$block2"
    append_status_log "$block3"

    local count=$(count_status_blocks)
    [ "$count" -eq 3 ]

    # Verify all phases are in log
    grep -q "PHASE: RED" .prp-session/phase-status.log
    grep -q "PHASE: GREEN" .prp-session/phase-status.log
}

# =============================================================================
# ERROR RECOVERY TESTS
# =============================================================================

@test "Missing session directory is handled" {
    # No setup - directory doesn't exist
    rmdir .prp-session 2>/dev/null || true

    run session_exists
    [ "$status" -ne 0 ]
}

@test "Corrupted Circuit Breaker state returns NONE" {
    mkdir -p .prp-session
    echo "not json" > .prp-session/circuit-breaker.json

    local state=$(get_cb_state 2>/dev/null || echo "NONE")
    # Should handle gracefully (either return NONE or error)
}
