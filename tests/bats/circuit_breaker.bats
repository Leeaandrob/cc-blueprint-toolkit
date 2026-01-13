#!/usr/bin/env bats
# circuit_breaker.bats - Circuit Breaker state machine tests
# Tests the 3-state machine: CLOSED → HALF_OPEN → OPEN

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
# INITIALIZATION TESTS
# =============================================================================

@test "Circuit Breaker initializes to CLOSED state" {
    init_circuit_breaker
    assert_cb_state "CLOSED"
}

@test "Circuit Breaker initializes with zero no_progress_count" {
    init_circuit_breaker
    assert_no_progress_count "0"
}

@test "Circuit Breaker can be initialized to custom state" {
    init_circuit_breaker "HALF_OPEN" 2 1
    assert_cb_state "HALF_OPEN"
    assert_no_progress_count "2"
}

@test "Circuit Breaker state file is created in .prp-session" {
    init_circuit_breaker
    run cb_state_exists
    [ "$status" -eq 0 ]
}

# =============================================================================
# STATE TRANSITION TESTS
# =============================================================================

@test "Circuit Breaker transitions from CLOSED to HALF_OPEN at count 2" {
    init_circuit_breaker "CLOSED" 0

    # First no-progress increment
    increment_no_progress
    assert_cb_state "CLOSED"
    assert_no_progress_count "1"

    # Second no-progress increment triggers HALF_OPEN
    increment_no_progress
    local count=$(get_cb_no_progress_count)
    [ "$count" -eq 2 ]

    # Manually transition to HALF_OPEN (as phase-monitor would)
    update_cb_state "HALF_OPEN"
    assert_cb_state "HALF_OPEN"
}

@test "Circuit Breaker transitions from HALF_OPEN to OPEN at threshold" {
    init_circuit_breaker "HALF_OPEN" 2

    # Hit threshold (GREEN phase = 2)
    update_cb_state "OPEN" "No progress for 2 iterations in GREEN phase"
    assert_cb_state "OPEN"
}

@test "Circuit Breaker resets to CLOSED on progress" {
    init_circuit_breaker "HALF_OPEN" 2

    # Simulate progress detected
    reset_no_progress
    update_cb_state "CLOSED"

    assert_cb_state "CLOSED"
    assert_no_progress_count "0"
}

@test "Circuit Breaker state persists across reads" {
    init_circuit_breaker "CLOSED" 0
    increment_no_progress
    increment_no_progress
    update_cb_state "HALF_OPEN"

    # Simulate new read
    local state=$(get_cb_state)
    local count=$(get_cb_no_progress_count)

    [ "$state" = "HALF_OPEN" ]
    [ "$count" -eq 2 ]
}

# =============================================================================
# THRESHOLD TESTS BY PHASE
# =============================================================================

@test "RED phase has threshold of 3" {
    local threshold=$(get_no_progress_threshold "RED")
    [ "$threshold" -eq 3 ]
}

@test "GREEN phase has stricter threshold of 2" {
    local threshold=$(get_no_progress_threshold "GREEN")
    [ "$threshold" -eq 2 ]
}

@test "REFACTOR phase has lenient threshold of 5" {
    local threshold=$(get_no_progress_threshold "REFACTOR")
    [ "$threshold" -eq 5 ]
}

@test "DOCUMENT phase has threshold of 3" {
    local threshold=$(get_no_progress_threshold "DOCUMENT")
    [ "$threshold" -eq 3 ]
}

@test "Same error threshold is 3 for GREEN phase (stricter)" {
    local threshold=$(get_same_error_threshold "GREEN")
    [ "$threshold" -eq 3 ]
}

@test "Same error threshold is 5 for other phases" {
    local red_threshold=$(get_same_error_threshold "RED")
    local refactor_threshold=$(get_same_error_threshold "REFACTOR")
    local document_threshold=$(get_same_error_threshold "DOCUMENT")

    [ "$red_threshold" -eq 5 ]
    [ "$refactor_threshold" -eq 5 ]
    [ "$document_threshold" -eq 5 ]
}

# =============================================================================
# PROGRESS DETECTION TESTS
# =============================================================================

@test "RED phase detects progress when tests_generated increases" {
    local progress=$(detect_red_progress 5 3 2 2)
    [ "$progress" = "true" ]
}

@test "RED phase detects progress when criteria_covered increases" {
    local progress=$(detect_red_progress 3 3 3 2)
    [ "$progress" = "true" ]
}

@test "RED phase detects no progress when nothing changes" {
    local progress=$(detect_red_progress 3 3 2 2)
    [ "$progress" = "false" ]
}

@test "GREEN phase detects progress when tests_passing increases" {
    local progress=$(detect_green_progress 5 3 5 7)
    [ "$progress" = "true" ]
}

@test "GREEN phase detects progress when tests_failing decreases" {
    local progress=$(detect_green_progress 3 3 5 7)
    [ "$progress" = "true" ]
}

@test "GREEN phase detects no progress when nothing changes" {
    local progress=$(detect_green_progress 3 3 7 7)
    [ "$progress" = "false" ]
}

# =============================================================================
# FULL STATE MACHINE FLOW TESTS
# =============================================================================

@test "Circuit Breaker full flow: CLOSED → HALF_OPEN → OPEN for GREEN phase" {
    init_circuit_breaker "CLOSED" 0

    # GREEN phase threshold is 2
    local threshold=$(get_no_progress_threshold "GREEN")
    [ "$threshold" -eq 2 ]

    # No progress iteration 1
    increment_no_progress
    assert_no_progress_count "1"
    assert_cb_state "CLOSED"

    # No progress iteration 2 - hits threshold
    increment_no_progress
    assert_no_progress_count "2"

    # Should transition to HALF_OPEN then OPEN at threshold
    update_cb_state "OPEN" "No progress for 2 iterations"
    assert_cb_state "OPEN"
}

@test "Circuit Breaker recovery flow: OPEN → CLOSED after user intervention" {
    init_circuit_breaker "OPEN" 3

    # User chooses to reset
    reset_no_progress
    update_cb_state "CLOSED"

    assert_cb_state "CLOSED"
    assert_no_progress_count "0"
}

@test "Circuit Breaker records open_reason when opening" {
    init_circuit_breaker "CLOSED" 0

    update_cb_state "OPEN" "Same error repeated 3 times"

    local reason=$(jq -r '.open_reason' .prp-session/circuit-breaker.json)
    [ "$reason" = "Same error repeated 3 times" ]
}

@test "Circuit Breaker records timestamp when opening" {
    init_circuit_breaker "CLOSED" 0

    update_cb_state "OPEN" "Test reason"

    local timestamp=$(jq -r '.opened_at' .prp-session/circuit-breaker.json)
    [ "$timestamp" != "null" ]
}

# =============================================================================
# EDGE CASE TESTS
# =============================================================================

@test "Circuit Breaker handles missing state file gracefully" {
    # Don't initialize
    local state=$(get_cb_state)
    [ "$state" = "NONE" ]
}

@test "Circuit Breaker handles missing no_progress_count gracefully" {
    local count=$(get_cb_no_progress_count)
    [ "$count" = "0" ]
}

@test "Unknown phase returns default threshold of 3" {
    local threshold=$(get_no_progress_threshold "UNKNOWN")
    [ "$threshold" -eq 3 ]
}
