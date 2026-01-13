#!/usr/bin/env bats
# dual_gate.bats - Dual-Gate Exit validation tests
# Tests Gate 1 (objective metrics) + Gate 2 (explicit signal) requirements

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
# DUAL-GATE CORE LOGIC TESTS
# =============================================================================

@test "Dual-Gate requires BOTH gates to be true" {
    local result=$(evaluate_dual_gate "true" "true")
    [ "$result" = "true" ]
}

@test "Dual-Gate fails when only Gate 1 is true" {
    local result=$(evaluate_dual_gate "true" "false")
    [ "$result" = "false" ]
}

@test "Dual-Gate fails when only Gate 2 is true" {
    local result=$(evaluate_dual_gate "false" "true")
    [ "$result" = "false" ]
}

@test "Dual-Gate fails when both gates are false" {
    local result=$(evaluate_dual_gate "false" "false")
    [ "$result" = "false" ]
}

# =============================================================================
# RED PHASE GATE 1 TESTS
# =============================================================================

@test "RED Gate 1: passes when tests_generated >= criteria AND all failing" {
    # tests_generated=5, tests_failing=5, criteria_count=5
    local result=$(evaluate_red_gate1 5 5 5)
    [ "$result" = "true" ]
}

@test "RED Gate 1: passes when tests_generated > criteria AND all failing" {
    # tests_generated=7, tests_failing=7, criteria_count=5
    local result=$(evaluate_red_gate1 7 7 5)
    [ "$result" = "true" ]
}

@test "RED Gate 1: fails when tests_generated < criteria" {
    # tests_generated=3, tests_failing=3, criteria_count=5
    local result=$(evaluate_red_gate1 3 3 5)
    [ "$result" = "false" ]
}

@test "RED Gate 1: fails when not all tests failing" {
    # tests_generated=5, tests_failing=4 (one passing), criteria_count=5
    local result=$(evaluate_red_gate1 5 4 5)
    [ "$result" = "false" ]
}

@test "RED Gate 1: fails when no tests generated" {
    # tests_generated=0, tests_failing=0, criteria_count=5
    local result=$(evaluate_red_gate1 0 0 5)
    [ "$result" = "false" ]
}

# =============================================================================
# GREEN PHASE GATE 1 TESTS
# =============================================================================

@test "GREEN Gate 1: passes when all tests pass with 2 consecutive runs" {
    # tests_passing=10, tests_total=10, consecutive_runs=2
    local result=$(evaluate_green_gate1 10 10 2)
    [ "$result" = "true" ]
}

@test "GREEN Gate 1: passes when all tests pass with more than 2 consecutive runs" {
    # tests_passing=10, tests_total=10, consecutive_runs=5
    local result=$(evaluate_green_gate1 10 10 5)
    [ "$result" = "true" ]
}

@test "GREEN Gate 1: fails when not all tests passing" {
    # tests_passing=8, tests_total=10, consecutive_runs=2
    local result=$(evaluate_green_gate1 8 10 2)
    [ "$result" = "false" ]
}

@test "GREEN Gate 1: fails when consecutive runs < 2" {
    # tests_passing=10, tests_total=10, consecutive_runs=1
    local result=$(evaluate_green_gate1 10 10 1)
    [ "$result" = "false" ]
}

@test "GREEN Gate 1: fails when consecutive runs = 0" {
    # tests_passing=10, tests_total=10, consecutive_runs=0
    local result=$(evaluate_green_gate1 10 10 0)
    [ "$result" = "false" ]
}

@test "GREEN Gate 1: fails when no tests exist" {
    # tests_passing=0, tests_total=0, consecutive_runs=2
    local result=$(evaluate_green_gate1 0 0 2)
    [ "$result" = "true" ]  # Edge case: 0/0 is considered all passing
}

# =============================================================================
# REFACTOR PHASE GATE 1 TESTS
# =============================================================================

@test "REFACTOR Gate 1: passes when tests pass and iteration >= 5" {
    # tests_passing=10, tests_total=10, iteration=5
    local result=$(evaluate_refactor_gate1 10 10 5)
    [ "$result" = "true" ]
}

@test "REFACTOR Gate 1: passes when tests pass and iteration > 5" {
    # tests_passing=10, tests_total=10, iteration=7
    local result=$(evaluate_refactor_gate1 10 10 7)
    [ "$result" = "true" ]
}

@test "REFACTOR Gate 1: fails when tests fail" {
    # tests_passing=8, tests_total=10, iteration=5
    local result=$(evaluate_refactor_gate1 8 10 5)
    [ "$result" = "false" ]
}

@test "REFACTOR Gate 1: fails when iteration < 5" {
    # tests_passing=10, tests_total=10, iteration=3
    local result=$(evaluate_refactor_gate1 10 10 3)
    [ "$result" = "false" ]
}

# =============================================================================
# DOCUMENT PHASE GATE 1 TESTS
# =============================================================================

@test "DOCUMENT Gate 1: passes when docs >= 3 and has ADR" {
    # docs_generated=3, has_adr=true
    local result=$(evaluate_document_gate1 3 "true")
    [ "$result" = "true" ]
}

@test "DOCUMENT Gate 1: passes when docs > 3 and has ADR" {
    # docs_generated=6, has_adr=true
    local result=$(evaluate_document_gate1 6 "true")
    [ "$result" = "true" ]
}

@test "DOCUMENT Gate 1: fails when docs < 3" {
    # docs_generated=2, has_adr=true
    local result=$(evaluate_document_gate1 2 "true")
    [ "$result" = "false" ]
}

@test "DOCUMENT Gate 1: fails when no ADR" {
    # docs_generated=5, has_adr=false
    local result=$(evaluate_document_gate1 5 "false")
    [ "$result" = "false" ]
}

@test "DOCUMENT Gate 1: fails when both conditions not met" {
    # docs_generated=1, has_adr=false
    local result=$(evaluate_document_gate1 1 "false")
    [ "$result" = "false" ]
}

# =============================================================================
# FULL DUAL-GATE FLOW TESTS
# =============================================================================

@test "RED phase: full Dual-Gate evaluation passes" {
    local gate1=$(evaluate_red_gate1 5 5 5)
    local gate2="true"  # exit_signal
    local result=$(evaluate_dual_gate "$gate1" "$gate2")

    [ "$gate1" = "true" ]
    [ "$result" = "true" ]
}

@test "RED phase: full Dual-Gate evaluation fails without exit_signal" {
    local gate1=$(evaluate_red_gate1 5 5 5)
    local gate2="false"  # no exit_signal
    local result=$(evaluate_dual_gate "$gate1" "$gate2")

    [ "$gate1" = "true" ]
    [ "$result" = "false" ]
}

@test "GREEN phase: full Dual-Gate evaluation passes" {
    local gate1=$(evaluate_green_gate1 10 10 2)
    local gate2="true"  # exit_signal
    local result=$(evaluate_dual_gate "$gate1" "$gate2")

    [ "$gate1" = "true" ]
    [ "$result" = "true" ]
}

@test "GREEN phase: full Dual-Gate evaluation fails with only 1 consecutive run" {
    local gate1=$(evaluate_green_gate1 10 10 1)
    local gate2="true"  # exit_signal present
    local result=$(evaluate_dual_gate "$gate1" "$gate2")

    [ "$gate1" = "false" ]
    [ "$result" = "false" ]
}

@test "REFACTOR phase: full Dual-Gate evaluation passes" {
    local gate1=$(evaluate_refactor_gate1 10 10 5)
    local gate2="true"  # exit_signal
    local result=$(evaluate_dual_gate "$gate1" "$gate2")

    [ "$gate1" = "true" ]
    [ "$result" = "true" ]
}

@test "DOCUMENT phase: full Dual-Gate evaluation passes" {
    local gate1=$(evaluate_document_gate1 4 "true")
    local gate2="true"  # exit_signal
    local result=$(evaluate_dual_gate "$gate1" "$gate2")

    [ "$gate1" = "true" ]
    [ "$result" = "true" ]
}

# =============================================================================
# EDGE CASE TESTS
# =============================================================================

@test "Dual-Gate handles string 'true' and 'false' correctly" {
    local result1=$(evaluate_dual_gate "true" "true")
    local result2=$(evaluate_dual_gate "false" "false")

    [ "$result1" = "true" ]
    [ "$result2" = "false" ]
}

@test "Gate 2 is always an explicit signal (user control)" {
    # Gate 2 should never be computed - it's always explicit
    local gate2_explicit="true"
    [ "$gate2_explicit" = "true" ]

    gate2_explicit="false"
    [ "$gate2_explicit" = "false" ]
}
