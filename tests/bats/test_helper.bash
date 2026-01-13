#!/usr/bin/env bash
# test_helper.bash - BATS test helper functions for Ralph patterns testing
# Version: 1.0.0

# =============================================================================
# SETUP AND TEARDOWN
# =============================================================================

# Test session directory (unique per test run)
export TEST_SESSION_DIR=""
export ORIGINAL_DIR=""

setup_test_session() {
    ORIGINAL_DIR="$(pwd)"
    TEST_SESSION_DIR="$(mktemp -d)"
    cd "$TEST_SESSION_DIR" || exit 1
    mkdir -p .prp-session
}

teardown_test_session() {
    cd "$ORIGINAL_DIR" || exit 1
    if [[ -n "$TEST_SESSION_DIR" && -d "$TEST_SESSION_DIR" ]]; then
        rm -rf "$TEST_SESSION_DIR"
    fi
}

# =============================================================================
# CIRCUIT BREAKER STATE MANAGEMENT
# =============================================================================

# Initialize Circuit Breaker state file
init_circuit_breaker() {
    local state="${1:-CLOSED}"
    local no_progress_count="${2:-0}"
    local same_error_count="${3:-0}"

    cat > .prp-session/circuit-breaker.json <<EOF
{
    "state": "$state",
    "no_progress_count": $no_progress_count,
    "same_error_count": $same_error_count,
    "last_progress_metric": {},
    "last_error_hash": null,
    "opened_at": null,
    "open_reason": null,
    "history": []
}
EOF
}

# Get Circuit Breaker state
get_cb_state() {
    if [[ -f .prp-session/circuit-breaker.json ]]; then
        jq -r '.state' .prp-session/circuit-breaker.json
    else
        echo "NONE"
    fi
}

# Get no progress count
get_cb_no_progress_count() {
    if [[ -f .prp-session/circuit-breaker.json ]]; then
        jq -r '.no_progress_count' .prp-session/circuit-breaker.json
    else
        echo "0"
    fi
}

# Update Circuit Breaker state
update_cb_state() {
    local new_state="$1"
    local reason="${2:-}"

    local temp_file=$(mktemp)

    if [[ -n "$reason" ]]; then
        jq --arg state "$new_state" \
           --arg reason "$reason" \
           --arg timestamp "$(date -Iseconds)" \
           '.state = $state | .open_reason = $reason | .opened_at = $timestamp' \
           .prp-session/circuit-breaker.json > "$temp_file"
    else
        jq --arg state "$new_state" \
           '.state = $state' \
           .prp-session/circuit-breaker.json > "$temp_file"
    fi

    mv "$temp_file" .prp-session/circuit-breaker.json
}

# Increment no progress count
increment_no_progress() {
    local temp_file=$(mktemp)
    jq '.no_progress_count += 1' .prp-session/circuit-breaker.json > "$temp_file"
    mv "$temp_file" .prp-session/circuit-breaker.json
}

# Reset no progress count
reset_no_progress() {
    local temp_file=$(mktemp)
    jq '.no_progress_count = 0' .prp-session/circuit-breaker.json > "$temp_file"
    mv "$temp_file" .prp-session/circuit-breaker.json
}

# =============================================================================
# METRICS STATE MANAGEMENT
# =============================================================================

# Initialize metrics state file
init_metrics() {
    local phase="${1:-RED}"

    cat > .prp-session/metrics.json <<EOF
{
    "session_id": "$(uuidgen 2>/dev/null || echo "test-$(date +%s)")",
    "prp_file": "test-prp.md",
    "started_at": "$(date -Iseconds)",
    "current_phase": "$phase",
    "phases": {
        "RED": null,
        "GREEN": null,
        "REFACTOR": null,
        "DOCUMENT": null
    }
}
EOF
}

# Update phase metrics
update_phase_metrics() {
    local phase="$1"
    shift
    local metrics_json="$1"

    local temp_file=$(mktemp)
    jq --arg phase "$phase" \
       --argjson metrics "$metrics_json" \
       '.phases[$phase] = $metrics | .current_phase = $phase' \
       .prp-session/metrics.json > "$temp_file"
    mv "$temp_file" .prp-session/metrics.json
}

# Get current phase
get_current_phase() {
    if [[ -f .prp-session/metrics.json ]]; then
        jq -r '.current_phase' .prp-session/metrics.json
    else
        echo "NONE"
    fi
}

# =============================================================================
# DUAL-GATE EVALUATION
# =============================================================================

# Evaluate Gate 1 for RED phase
evaluate_red_gate1() {
    local tests_generated="$1"
    local tests_failing="$2"
    local criteria_count="$3"

    if [[ "$tests_generated" -ge "$criteria_count" && "$tests_failing" -eq "$tests_generated" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Evaluate Gate 1 for GREEN phase
evaluate_green_gate1() {
    local tests_passing="$1"
    local tests_total="$2"
    local consecutive_runs="$3"

    if [[ "$tests_passing" -eq "$tests_total" && "$consecutive_runs" -ge 2 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Evaluate Gate 1 for REFACTOR phase
evaluate_refactor_gate1() {
    local tests_passing="$1"
    local tests_total="$2"
    local iteration="$3"

    if [[ "$tests_passing" -eq "$tests_total" && "$iteration" -ge 5 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Evaluate Gate 1 for DOCUMENT phase
evaluate_document_gate1() {
    local docs_generated="$1"
    local has_adr="$2"

    if [[ "$docs_generated" -ge 3 && "$has_adr" == "true" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Evaluate Dual-Gate (both gates)
evaluate_dual_gate() {
    local gate1="$1"
    local gate2="$2"

    if [[ "$gate1" == "true" && "$gate2" == "true" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# =============================================================================
# PROGRESS DETECTION
# =============================================================================

# Detect progress for RED phase
detect_red_progress() {
    local current_tests="$1"
    local last_tests="$2"
    local current_criteria="$3"
    local last_criteria="$4"

    if [[ "$current_tests" -gt "$last_tests" || "$current_criteria" -gt "$last_criteria" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Detect progress for GREEN phase
detect_green_progress() {
    local current_passing="$1"
    local last_passing="$2"
    local current_failing="$3"
    local last_failing="$4"

    if [[ "$current_passing" -gt "$last_passing" ]] || \
       [[ "$current_failing" -lt "$last_failing" && "$current_failing" -ge 0 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# =============================================================================
# THRESHOLD MANAGEMENT
# =============================================================================

# Get no progress threshold for phase
get_no_progress_threshold() {
    local phase="$1"

    case "$phase" in
        RED)      echo "3" ;;
        GREEN)    echo "2" ;;  # Stricter
        REFACTOR) echo "5" ;;
        DOCUMENT) echo "3" ;;
        *)        echo "3" ;;
    esac
}

# Get same error threshold for phase
get_same_error_threshold() {
    local phase="$1"

    case "$phase" in
        RED)      echo "5" ;;
        GREEN)    echo "3" ;;  # Stricter
        REFACTOR) echo "5" ;;
        DOCUMENT) echo "5" ;;
        *)        echo "5" ;;
    esac
}

# =============================================================================
# STATUS BLOCK GENERATION
# =============================================================================

# Generate PRP_PHASE_STATUS block
generate_status_block() {
    local phase="$1"
    local status="$2"
    local iteration="$3"
    local progress_percent="$4"
    local tests_total="$5"
    local tests_passing="$6"
    local tests_failing="$7"
    local cb_state="$8"
    local cb_no_progress="$9"
    local gate1="${10}"
    local gate2="${11}"
    local exit_signal="${12}"
    local recommendation="${13}"

    local can_exit=$(evaluate_dual_gate "$gate1" "$gate2")

    cat <<EOF
---PRP_PHASE_STATUS---
TIMESTAMP: $(date -Iseconds)
PHASE: $phase
STATUS: $status
ITERATION: $iteration
PROGRESS_PERCENT: $progress_percent

TESTS:
  TOTAL: $tests_total
  PASSING: $tests_passing
  FAILING: $tests_failing
  SKIPPED: 0

FILES:
  CREATED: 0
  MODIFIED: 0
  DELETED: 0

CIRCUIT_BREAKER:
  STATE: $cb_state
  NO_PROGRESS_COUNT: $cb_no_progress

DUAL_GATE:
  GATE_1: $gate1
  GATE_2: $gate2
  CAN_EXIT: $can_exit

BLOCKERS:
  - none

EXIT_SIGNAL: $exit_signal
RECOMMENDATION: $recommendation
---END_PRP_PHASE_STATUS---
EOF
}

# Parse status block field
parse_status_field() {
    local status_block="$1"
    local field="$2"

    echo "$status_block" | grep "^${field}:" | head -1 | cut -d':' -f2- | xargs
}

# =============================================================================
# ASSERTIONS
# =============================================================================

# Assert Circuit Breaker state
assert_cb_state() {
    local expected="$1"
    local actual=$(get_cb_state)

    if [[ "$actual" != "$expected" ]]; then
        echo "Circuit Breaker state assertion failed: expected '$expected', got '$actual'" >&2
        return 1
    fi
    return 0
}

# Assert no progress count
assert_no_progress_count() {
    local expected="$1"
    local actual=$(get_cb_no_progress_count)

    if [[ "$actual" != "$expected" ]]; then
        echo "No progress count assertion failed: expected '$expected', got '$actual'" >&2
        return 1
    fi
    return 0
}

# Assert phase
assert_phase() {
    local expected="$1"
    local actual=$(get_current_phase)

    if [[ "$actual" != "$expected" ]]; then
        echo "Phase assertion failed: expected '$expected', got '$actual'" >&2
        return 1
    fi
    return 0
}

# =============================================================================
# FILE UTILITIES
# =============================================================================

# Check if session exists
session_exists() {
    [[ -d .prp-session ]]
}

# Check if Circuit Breaker state file exists
cb_state_exists() {
    [[ -f .prp-session/circuit-breaker.json ]]
}

# Check if metrics file exists
metrics_exists() {
    [[ -f .prp-session/metrics.json ]]
}

# Append to phase status log
append_status_log() {
    local status_block="$1"
    echo "$status_block" >> .prp-session/phase-status.log
    echo "" >> .prp-session/phase-status.log
}

# Count status blocks in log
count_status_blocks() {
    if [[ -f .prp-session/phase-status.log ]]; then
        grep -c "^---PRP_PHASE_STATUS---$" .prp-session/phase-status.log || echo "0"
    else
        echo "0"
    fi
}
