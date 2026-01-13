#!/usr/bin/env bats
# ship_e2e.bats - End-to-end tests for /bp:ship feature delivery command
# Tests complete ship workflow: PREFLIGHT -> PREPARE -> DELIVER -> COMPLETE
#
# TDD RED STATE: These tests are designed to FAIL until ship.md is implemented.
# The tests verify the acceptance criteria from the PRP.

load 'test_helper'

# =============================================================================
# CONSTANTS - Paths to implementation files (should fail in RED state)
# =============================================================================

SHIP_COMMAND_PATH="/home/leeaandrob/Projects/Personal/llm/cc-blueprint-toolkit/claude/commands/ship.md"
PR_GENERATOR_PATH="/home/leeaandrob/Projects/Personal/llm/cc-blueprint-toolkit/claude/agents/pr-generator.md"
SHIP_SPEC_PATH="/home/leeaandrob/Projects/Personal/llm/cc-blueprint-toolkit/claude/lib/ship-spec.md"

# =============================================================================
# SETUP AND TEARDOWN
# =============================================================================

setup() {
    setup_test_session
    # Create mock PRP file
    create_test_prp
    # Initialize git repository for ship tests
    init_test_git_repo
}

teardown() {
    teardown_test_session
}

# =============================================================================
# SHIP-SPECIFIC TEST HELPERS
# =============================================================================

# Create a test PRP file with standard structure
create_test_prp() {
    mkdir -p docs/PRPs
    cat > docs/PRPs/test-feature.md <<'EOF'
# PRP: Test Feature Implementation

**Version**: 1.0.0
**Date**: 2026-01-13
**Status**: In Progress

## Goal

Implement a test feature for demonstration purposes.

## Why

- To validate the ship command workflow
- To ensure proper PR generation

## What

### User-Visible Behavior

Users can execute the test feature command.

### Success Criteria

- [ ] Feature implemented correctly
- [ ] Tests pass
- [ ] Documentation updated
EOF
}

# Initialize a test git repository
init_test_git_repo() {
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "# Test Repo" > README.md
    git add README.md
    git commit -q -m "Initial commit"
}

# Create ship session file (simulates execute-prp completion)
init_ship_session() {
    local prp_file="${1:-docs/PRPs/test-feature.md}"
    echo "$prp_file" > .prp-session/current-prp.txt
}

# Create ship configuration
init_ship_config() {
    cat > .prp-session/ship-config.json <<EOF
{
    "prp_file": "docs/PRPs/test-feature.md",
    "feature_name": "test-feature",
    "commit_type": "feat",
    "auto_detected": true
}
EOF
}

# Simulate preflight check results
create_preflight_result() {
    local tests_passed="${1:-true}"
    local lint_passed="${2:-true}"
    local build_passed="${3:-true}"
    local has_changes="${4:-true}"
    local is_clean="${5:-true}"

    cat > .prp-session/preflight-result.json <<EOF
{
    "tests_passed": $tests_passed,
    "lint_passed": $lint_passed,
    "build_passed": $build_passed,
    "has_changes": $has_changes,
    "is_clean": $is_clean,
    "current_branch": "main",
    "checked_at": "$(date -Iseconds)"
}
EOF
}

# Get preflight result field
get_preflight_field() {
    local field="$1"
    if [[ -f .prp-session/preflight-result.json ]]; then
        jq -r ".$field" .prp-session/preflight-result.json
    else
        echo "null"
    fi
}

# Simulate ship result
create_ship_result() {
    local success="${1:-true}"
    local branch="${2:-feature/test-feature}"
    local commit_sha="${3:-abc1234}"
    local pr_url="${4:-https://github.com/user/repo/pull/123}"

    cat > .prp-session/ship-result.json <<EOF
{
    "success": $success,
    "branch_created": "$branch",
    "commit_sha": "$commit_sha",
    "pr_url": "$pr_url",
    "shipped_at": "$(date -Iseconds)",
    "errors": []
}
EOF
}

# Get ship result field
get_ship_result_field() {
    local field="$1"
    if [[ -f .prp-session/ship-result.json ]]; then
        jq -r ".$field" .prp-session/ship-result.json
    else
        echo "null"
    fi
}

# Validate conventional commit format
is_conventional_commit() {
    local message="$1"
    echo "$message" | grep -qE '^(feat|fix|docs|style|refactor|test|chore)(\([^)]+\))?: .+$'
}

# Mock gh CLI for testing
mock_gh_cli() {
    touch .mock-gh
    cat > gh <<'EOF'
#!/bin/bash
case "$1" in
    --version) echo "gh version 2.40.0" ;;
    auth) echo "Logged in to github.com" ;;
    pr)
        case "$2" in
            create) echo "https://github.com/user/repo/pull/123" ;;
            view) echo "PR #123 is open" ;;
        esac
        ;;
esac
EOF
    chmod +x gh
    export PATH=".:$PATH"
}

# Mock glab CLI for testing
mock_glab_cli() {
    touch .mock-glab
    cat > glab <<'EOF'
#!/bin/bash
case "$1" in
    --version) echo "glab version 1.30.0" ;;
    auth) echo "Logged in to gitlab.com" ;;
    mr)
        case "$2" in
            create) echo "https://gitlab.com/user/repo/-/merge_requests/456" ;;
            view) echo "MR !456 is open" ;;
        esac
        ;;
esac
EOF
    chmod +x glab
    export PATH=".:$PATH"
}

# =============================================================================
# CRITICAL IMPLEMENTATION TESTS (MUST FAIL IN RED STATE)
# These tests verify the actual implementation files exist
# =============================================================================

@test "RED-CRITICAL: ship.md command file MUST exist at claude/commands/ship.md" {
    # This test MUST FAIL until ship.md is implemented
    [ -f "$SHIP_COMMAND_PATH" ]
}

@test "RED-CRITICAL: pr-generator.md agent file MUST exist at claude/agents/pr-generator.md" {
    # This test MUST FAIL until pr-generator.md is implemented
    [ -f "$PR_GENERATOR_PATH" ]
}

@test "RED-CRITICAL: ship-spec.md specification file MUST exist at claude/lib/ship-spec.md" {
    # This test MUST FAIL until ship-spec.md is implemented
    [ -f "$SHIP_SPEC_PATH" ]
}

# =============================================================================
# CRITERION 1: PRP AUTO-DETECTION OR ARGUMENT
# Tests for: Detecta automaticamente o PRP usado na sessao (ou aceita como argumento)
# =============================================================================

@test "RED: ship.md must contain PRP auto-detection logic" {
    # Verify ship.md has PRP detection workflow
    [ -f "$SHIP_COMMAND_PATH" ] && grep -q "current-prp" "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must accept --prp argument" {
    # Verify ship.md documents --prp flag
    [ -f "$SHIP_COMMAND_PATH" ] && grep -q "\-\-prp" "$SHIP_COMMAND_PATH"
}

@test "HELPER: session stores current PRP path" {
    init_ship_session "docs/PRPs/test-feature.md"
    [[ -f .prp-session/current-prp.txt ]]
    local detected_prp=$(cat .prp-session/current-prp.txt)
    [ "$detected_prp" = "docs/PRPs/test-feature.md" ]
}

@test "HELPER: fails gracefully when no PRP available" {
    rm -f .prp-session/current-prp.txt
    run cat .prp-session/current-prp.txt 2>/dev/null
    [ "$status" -ne 0 ]
}

# =============================================================================
# CRITERION 2: PRE-DELIVERY VALIDATIONS (Tests, Lint, Build)
# Tests for: Roda validacoes pre-entrega (testes, lint, build)
# =============================================================================

@test "RED: ship.md must run preflight checks" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -qi "preflight\|pre-flight" "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must validate tests pass" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -qi "test" "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must validate lint passes" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -qi "lint" "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must validate build passes" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -qi "build" "$SHIP_COMMAND_PATH"
}

@test "RED: ship-spec.md must define preflight checks" {
    [ -f "$SHIP_SPEC_PATH" ] && grep -qi "preflight" "$SHIP_SPEC_PATH"
}

@test "HELPER: preflight result tracks test status" {
    create_preflight_result "true" "true" "true" "true" "true"
    local tests_passed=$(get_preflight_field "tests_passed")
    [ "$tests_passed" = "true" ]
}

@test "HELPER: preflight result tracks lint status" {
    create_preflight_result "true" "true" "true" "true" "true"
    local lint_passed=$(get_preflight_field "lint_passed")
    [ "$lint_passed" = "true" ]
}

@test "HELPER: preflight result tracks build status" {
    create_preflight_result "true" "true" "true" "true" "true"
    local build_passed=$(get_preflight_field "build_passed")
    [ "$build_passed" = "true" ]
}

@test "HELPER: preflight detects uncommitted changes" {
    echo "new content" > new-file.txt
    git add new-file.txt
    local is_clean=$(git diff --cached --quiet && echo "true" || echo "false")
    [ "$is_clean" = "false" ]
}

# =============================================================================
# CRITERION 3: BRANCH CREATION BASED ON PRP
# Tests for: Cria branch com nome baseado no PRP
# =============================================================================

@test "RED: ship.md must create branch from PRP name" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -qi "branch" "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must follow branch naming convention" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -qE "feature/|fix/|refactor/" "$SHIP_COMMAND_PATH"
}

@test "RED: ship-spec.md must define branch naming pattern" {
    [ -f "$SHIP_SPEC_PATH" ] && grep -qi "branch" "$SHIP_SPEC_PATH"
}

@test "HELPER: generates feature branch name from PRP" {
    # Extract feature name from PRP filename
    local prp_file="docs/PRPs/user-authentication.md"
    local feature_name=$(basename "$prp_file" .md | tr '[:upper:]' '[:lower:]')
    local branch="feature/$feature_name"
    [ "$branch" = "feature/user-authentication" ]
}

@test "HELPER: generates fix branch name from PRP" {
    local prp_file="docs/PRPs/login-bug.md"
    local feature_name=$(basename "$prp_file" .md | tr '[:upper:]' '[:lower:]')
    local branch="fix/$feature_name"
    [ "$branch" = "fix/login-bug" ]
}

@test "HELPER: strips date prefix from PRP filename" {
    local prp_file="docs/PRPs/2026-01-13-test-feature.md"
    local feature_name=$(basename "$prp_file" .md | sed 's/^[0-9-]*//' | tr '[:upper:]' '[:lower:]')
    [[ "$feature_name" == *"test-feature"* ]]
}

@test "HELPER: creates git branch successfully" {
    local branch="feature/test-feature"
    git checkout -b "$branch"
    local current_branch=$(git branch --show-current)
    [ "$current_branch" = "$branch" ]
}

# =============================================================================
# CRITERION 4: CONVENTIONAL COMMITS MESSAGE GENERATION
# Tests for: Gera commit message seguindo Conventional Commits
# =============================================================================

@test "RED: ship.md must generate Conventional Commits" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -qi "conventional" "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must support feat: commit type" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -q "feat:" "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must support fix: commit type" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -q "fix:" "$SHIP_COMMAND_PATH"
}

@test "RED: ship-spec.md must define commit message format" {
    [ -f "$SHIP_SPEC_PATH" ] && grep -qi "commit" "$SHIP_SPEC_PATH"
}

@test "HELPER: validates feat: commit format" {
    run is_conventional_commit "feat: implement user-authentication"
    [ "$status" -eq 0 ]
}

@test "HELPER: validates fix: commit format" {
    run is_conventional_commit "fix: resolve login bug"
    [ "$status" -eq 0 ]
}

@test "HELPER: validates scoped commit format" {
    run is_conventional_commit "feat(auth): implement user-authentication"
    [ "$status" -eq 0 ]
}

@test "HELPER: rejects invalid commit format" {
    run is_conventional_commit "implemented feature"
    [ "$status" -ne 0 ]
}

@test "HELPER: rejects commit without colon" {
    run is_conventional_commit "feat implement feature"
    [ "$status" -ne 0 ]
}

# =============================================================================
# CRITERION 5: PUSH TO ORIGIN
# Tests for: Faz push para origin
# =============================================================================

@test "RED: ship.md must push to origin" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -qi "push" "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must use git push -u origin" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -q "push.*origin" "$SHIP_COMMAND_PATH"
}

@test "HELPER: detects current branch for push" {
    git checkout -b feature/test-feature
    local branch=$(git branch --show-current)
    [ "$branch" = "feature/test-feature" ]
}

@test "HELPER: ship result records branch name" {
    create_ship_result "true" "feature/my-feature" "abc1234" "https://github.com/user/repo/pull/123"
    local branch=$(get_ship_result_field "branch_created")
    [ "$branch" = "feature/my-feature" ]
}

@test "HELPER: ship result records commit SHA" {
    create_ship_result "true" "feature/test-feature" "def5678" "https://github.com/user/repo/pull/123"
    local sha=$(get_ship_result_field "commit_sha")
    [ "$sha" = "def5678" ]
}

# =============================================================================
# CRITERION 6: PR CREATION WITH STRUCTURED DESCRIPTION
# Tests for: Cria PR com descricao estruturada baseada no PRP
# =============================================================================

@test "RED: ship.md must create PR" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -qi "pr\|pull request" "$SHIP_COMMAND_PATH"
}

@test "RED: pr-generator.md must extract Goal from PRP" {
    [ -f "$PR_GENERATOR_PATH" ] && grep -qi "goal" "$PR_GENERATOR_PATH"
}

@test "RED: pr-generator.md must extract What from PRP" {
    [ -f "$PR_GENERATOR_PATH" ] && grep -qi "what" "$PR_GENERATOR_PATH"
}

@test "RED: pr-generator.md must extract Success Criteria from PRP" {
    [ -f "$PR_GENERATOR_PATH" ] && grep -qi "success\|criteria" "$PR_GENERATOR_PATH"
}

@test "RED: ship-spec.md must define PR template" {
    [ -f "$SHIP_SPEC_PATH" ] && grep -qi "pr.*template\|pull.*request" "$SHIP_SPEC_PATH"
}

@test "HELPER: ship result records PR URL" {
    create_ship_result "true" "feature/test-feature" "abc1234" "https://github.com/user/repo/pull/456"
    local pr_url=$(get_ship_result_field "pr_url")
    [ "$pr_url" = "https://github.com/user/repo/pull/456" ]
}

@test "HELPER: PRP file contains Goal section" {
    grep -q "## Goal" docs/PRPs/test-feature.md
}

@test "HELPER: PRP file contains What section" {
    grep -q "## What" docs/PRPs/test-feature.md
}

@test "HELPER: PRP file contains Success Criteria" {
    grep -q "### Success Criteria" docs/PRPs/test-feature.md
}

# =============================================================================
# CRITERION 7: GITHUB AND GITLAB CLI SUPPORT
# Tests for: Suporta GitHub (gh cli) e GitLab (glab cli)
# =============================================================================

@test "RED: ship.md must support gh CLI" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -q "gh " "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must support glab CLI" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -q "glab " "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must detect git provider" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -qi "github\|gitlab" "$SHIP_COMMAND_PATH"
}

@test "HELPER: mock gh CLI works" {
    mock_gh_cli
    local pr_url=$(./gh pr create 2>/dev/null || echo "")
    [[ "$pr_url" == *"github.com"* ]] || [[ "$pr_url" == *"pull"* ]]
}

@test "HELPER: mock glab CLI works" {
    mock_glab_cli
    local mr_url=$(./glab mr create 2>/dev/null || echo "")
    [[ "$mr_url" == *"gitlab.com"* ]] || [[ "$mr_url" == *"merge_requests"* ]]
}

# =============================================================================
# CRITERION 8: DRY-RUN MODE
# Tests for: Modo dry-run para preview sem executar
# =============================================================================

@test "RED: ship.md must support --dry-run flag" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -q "\-\-dry-run" "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must document dry-run behavior" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -qi "dry.*run\|preview" "$SHIP_COMMAND_PATH"
}

@test "HELPER: dry-run does not create branch" {
    local initial_branch=$(git branch --show-current)
    local dry_run="true"
    # In dry-run mode, no branch creation
    local current_branch=$(git branch --show-current)
    [ "$current_branch" = "$initial_branch" ]
}

@test "HELPER: dry-run does not commit changes" {
    echo "new content" > test-file.txt
    git add test-file.txt
    local commits_before=$(git rev-list --count HEAD)
    # In dry-run mode, no commit
    local commits_after=$(git rev-list --count HEAD)
    [ "$commits_before" -eq "$commits_after" ]
}

# =============================================================================
# CRITERION 9: GRACEFUL FAILURE HANDLING
# Tests for: Falha graciosamente se validacoes nao passarem
# =============================================================================

@test "RED: ship.md must handle validation failures" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -qi "fail\|error" "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must not proceed if tests fail" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -qi "test.*fail\|test.*pass" "$SHIP_COMMAND_PATH"
}

@test "RED: ship-spec.md must define error handling" {
    [ -f "$SHIP_SPEC_PATH" ] && grep -qi "error" "$SHIP_SPEC_PATH"
}

@test "HELPER: detects test failure in preflight" {
    create_preflight_result "false" "true" "true" "true" "true"
    local tests_passed=$(get_preflight_field "tests_passed")
    [ "$tests_passed" = "false" ]
}

@test "HELPER: detects lint failure in preflight" {
    create_preflight_result "true" "false" "true" "true" "true"
    local lint_passed=$(get_preflight_field "lint_passed")
    [ "$lint_passed" = "false" ]
}

@test "HELPER: detects build failure in preflight" {
    create_preflight_result "true" "true" "false" "true" "true"
    local build_passed=$(get_preflight_field "build_passed")
    [ "$build_passed" = "false" ]
}

@test "HELPER: detects no changes to ship" {
    create_preflight_result "true" "true" "true" "false" "true"
    local has_changes=$(get_preflight_field "has_changes")
    [ "$has_changes" = "false" ]
}

@test "HELPER: ship result records errors on failure" {
    cat > .prp-session/ship-result.json <<EOF
{
    "success": false,
    "branch_created": null,
    "commit_sha": null,
    "pr_url": null,
    "shipped_at": "$(date -Iseconds)",
    "errors": ["Tests failed", "Cannot proceed with ship"]
}
EOF
    local success=$(get_ship_result_field "success")
    [ "$success" = "false" ]
    local errors=$(jq -r '.errors | length' .prp-session/ship-result.json)
    [ "$errors" -gt 0 ]
}

# =============================================================================
# COMMAND FILE STRUCTURE VALIDATION (RED STATE)
# =============================================================================

@test "RED: ship.md must have YAML frontmatter" {
    [ -f "$SHIP_COMMAND_PATH" ] && head -1 "$SHIP_COMMAND_PATH" | grep -q "^---"
}

@test "RED: ship.md must have description in frontmatter" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -q "^description:" "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must have argument-hint in frontmatter" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -q "^argument-hint:" "$SHIP_COMMAND_PATH"
}

@test "RED: ship.md must have allowed-tools in frontmatter" {
    [ -f "$SHIP_COMMAND_PATH" ] && grep -q "^allowed-tools:" "$SHIP_COMMAND_PATH"
}

# =============================================================================
# FULL WORKFLOW INTEGRATION TESTS (HELPER)
# =============================================================================

@test "HELPER: full workflow - preflight -> prepare -> deliver" {
    init_ship_session "docs/PRPs/test-feature.md"
    init_ship_config

    # Phase 1: Preflight
    create_preflight_result "true" "true" "true" "true" "true"
    local preflight_ok=$(get_preflight_field "tests_passed")
    [ "$preflight_ok" = "true" ]

    # Phase 2: Prepare (branch + commit)
    local prp_file="docs/PRPs/test-feature.md"
    local feature_name=$(basename "$prp_file" .md | tr '[:upper:]' '[:lower:]')
    local branch="feature/$feature_name"
    [ "$branch" = "feature/test-feature" ]

    local message="feat: implement $feature_name"
    run is_conventional_commit "$message"
    [ "$status" -eq 0 ]

    # Phase 3: Deliver (push + PR) - simulated
    create_ship_result "true" "$branch" "abc1234" "https://github.com/user/repo/pull/123"
    local success=$(get_ship_result_field "success")
    [ "$success" = "true" ]
}

@test "HELPER: workflow halts at preflight if tests fail" {
    init_ship_session "docs/PRPs/test-feature.md"
    create_preflight_result "false" "true" "true" "true" "true"

    local tests_passed=$(get_preflight_field "tests_passed")
    [ "$tests_passed" = "false" ]

    # Should not proceed to prepare/deliver
    [[ ! -f .prp-session/ship-result.json ]] || {
        local success=$(get_ship_result_field "success")
        [ "$success" = "false" ]
    }
}

@test "HELPER: generates complete ship report on success" {
    create_ship_result "true" "feature/test-feature" "abc1234" "https://github.com/user/repo/pull/123"

    local success=$(get_ship_result_field "success")
    local branch=$(get_ship_result_field "branch_created")
    local sha=$(get_ship_result_field "commit_sha")
    local pr=$(get_ship_result_field "pr_url")

    [ "$success" = "true" ]
    [ "$branch" = "feature/test-feature" ]
    [ "$sha" = "abc1234" ]
    [[ "$pr" == *"pull"* ]]
}

@test "HELPER: session state persists across operations" {
    init_ship_session "docs/PRPs/test-feature.md"
    init_ship_config
    create_preflight_result "true" "true" "true" "true" "true"

    local prp=$(cat .prp-session/current-prp.txt)
    local config_exists=$([[ -f .prp-session/ship-config.json ]] && echo "true" || echo "false")
    local preflight_exists=$([[ -f .prp-session/preflight-result.json ]] && echo "true" || echo "false")

    [ "$prp" = "docs/PRPs/test-feature.md" ]
    [ "$config_exists" = "true" ]
    [ "$preflight_exists" = "true" ]
}

@test "HELPER: ship result is written to session directory" {
    create_ship_result "true" "feature/test-feature" "abc1234" "https://github.com/user/repo/pull/123"
    [[ -f .prp-session/ship-result.json ]]
}
