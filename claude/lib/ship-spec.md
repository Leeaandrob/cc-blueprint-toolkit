# Ship Workflow Specification

**Version:** 1.0.0
**Pattern Origin:** CC Blueprint Toolkit
**Purpose:** Define the automated feature delivery workflow from implementation to PR

---

## Overview

The Ship Workflow automates the final steps of feature delivery after successful implementation via `/bp:execute-prp`. It handles:

1. **Pre-flight Validation** - Ensure code is ready to ship
2. **Branch Creation** - Create feature/fix branch from PRP name
3. **Commit Generation** - Create Conventional Commits message
4. **Push to Remote** - Push branch to origin
5. **PR Creation** - Create Pull Request with structured description

## Ship Workflow Phases

```
┌─────────────────────────────────────────────────────────────────┐
│                    SHIP WORKFLOW                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PREFLIGHT ─────────────────────────────────────────────────────│
│  │  Check required conditions:                                 │
│  │  ├── Git status clean (no uncommitted changes)             │
│  │  ├── Tests pass                                             │
│  │  ├── Lint passes                                            │
│  │  └── Build passes (optional)                                │
│  │  FAIL: Report errors, halt workflow                         │
│  │                                                              │
│  PREPARE ──────────────────────────────────────────────────────│
│  │  Generate delivery artifacts:                               │
│  │  ├── Branch name from PRP feature name                     │
│  │  ├── Commit message (Conventional Commits)                 │
│  │  ├── PR title and body (from PRP sections)                 │
│  │  Create branch and commit:                                  │
│  │  ├── git checkout -b {branch}                               │
│  │  ├── git add .                                              │
│  │  └── git commit -m "{message}"                             │
│  │                                                              │
│  DELIVER ──────────────────────────────────────────────────────│
│  │  Push and create PR:                                        │
│  │  ├── git push -u origin {branch}                            │
│  │  └── gh pr create / glab mr create                          │
│  │                                                              │
│  COMPLETE ─────────────────────────────────────────────────────│
│     Generate report with:                                      │
│     ├── Branch name and commit SHA                             │
│     ├── PR/MR URL                                              │
│     └── All validation results                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Preflight Checks

### Required Checks

```yaml
preflight:
  required:
    - name: git_status_clean
      description: "No uncommitted changes in working directory"
      command: "git status --porcelain"
      pass_condition: "Output is empty OR only contains new files"
      fail_message: "Uncommitted changes detected. Please commit or stash changes first."

    - name: tests_pass
      description: "All tests must pass"
      commands:
        - "npm test"           # Node.js
        - "pytest"             # Python
        - "go test ./..."      # Go
        - "bats tests/bats/"   # BATS
      pass_condition: "Exit code is 0"
      fail_message: "Tests failed. Fix failing tests before shipping."

    - name: lint_pass
      description: "No linting errors"
      commands:
        - "npm run lint"       # Node.js
        - "ruff check ."       # Python
        - "golangci-lint run"  # Go
        - "shellcheck scripts/" # Shell
      pass_condition: "Exit code is 0"
      fail_message: "Lint errors detected. Fix linting issues before shipping."

  optional:
    - name: build_pass
      description: "Build succeeds (if applicable)"
      commands:
        - "npm run build"      # Node.js
        - "python -m build"    # Python
        - "go build ./..."     # Go
      pass_condition: "Exit code is 0"
      skip_if: "No build script found"

    - name: type_check
      description: "No type errors (if applicable)"
      commands:
        - "npm run type-check" # TypeScript
        - "mypy ."             # Python
      pass_condition: "Exit code is 0"
      skip_if: "No type checking configured"
```

### Preflight Result Schema

```json
{
  "tests_passed": true,
  "lint_passed": true,
  "build_passed": true,
  "has_changes": true,
  "is_clean": true,
  "current_branch": "main",
  "checked_at": "2026-01-13T10:30:00Z"
}
```

## Branch Naming Convention

### Pattern Definition

```yaml
branch_naming:
  pattern: "{type}/{feature-slug}"

  types:
    - feature   # New feature implementation
    - fix       # Bug fix
    - refactor  # Code refactoring
    - docs      # Documentation changes
    - test      # Adding tests
    - chore     # Maintenance tasks

  slug_generation:
    input: "PRP filename or feature name"
    transformations:
      - Remove date prefix (YYYY-MM-DD-)
      - Convert to lowercase
      - Replace spaces with hyphens
      - Remove special characters
      - Truncate to 50 chars

  examples:
    - input: "2026-01-13-user-authentication.md"
      output: "feature/user-authentication"

    - input: "2026-01-13-fix-login-bug.md"
      output: "fix/login-bug"

    - input: "bp-ship-delivery-command.md"
      output: "feature/bp-ship-delivery-command"
```

### Type Detection

```yaml
type_detection:
  from_prp:
    - pattern: "fix|bug|patch|hotfix"
      type: "fix"

    - pattern: "refactor|cleanup|improve"
      type: "refactor"

    - pattern: "doc|readme|guide"
      type: "docs"

    - pattern: "test|spec|e2e"
      type: "test"

    - default: "feature"
```

## Commit Message Format

### Conventional Commits Specification

```yaml
commit_format:
  structure: |
    {type}({scope}): {description}

    {body}

    PRP: {prp_file_path}

  types:
    - feat      # New feature (maps to: feature)
    - fix       # Bug fix (maps to: fix)
    - refactor  # Code refactoring (maps to: refactor)
    - docs      # Documentation (maps to: docs)
    - test      # Adding tests (maps to: test)
    - chore     # Maintenance (maps to: chore)

  scope:
    optional: true
    derived_from: "PRP feature area or module"

  description:
    max_length: 72
    format: "imperative mood, lowercase start"
    derived_from: "PRP Goal section summary"

  body:
    optional: true
    format: "Paragraph from PRP What section"
    max_length: 500

  footer:
    required: true
    format: "PRP: {relative_path_to_prp}"

examples:
  - type: feat
    message: |
      feat: implement ship delivery command

      Add /bp:ship command that automates feature delivery by creating
      branch, generating commit, pushing to origin, and creating PR with
      structured description based on PRP content.

      PRP: docs/PRPs/2026-01-13-bp-ship-delivery-command.md

  - type: fix
    message: |
      fix: resolve login validation bug

      PRP: docs/PRPs/2026-01-13-fix-login-validation.md
```

## Pull Request Template

### PR Body Structure

```yaml
pr_template:
  title: "{type}: {feature_name}"

  body: |
    ## Summary
    {Goal section from PRP}

    ## What Changed
    {What section from PRP}

    ## Acceptance Criteria
    {Success Criteria as markdown checklist}

    ## Testing
    - [ ] All tests pass
    - [ ] Manual testing completed
    - [ ] Edge cases verified

    ## Documentation
    - PRP: {link_to_prp_file}

    ---
    Generated with [CC Blueprint Toolkit](https://github.com/croffasia/cc-blueprint-toolkit)
```

### Section Extraction

```yaml
section_extraction:
  goal:
    source: "## Goal"
    end_marker: "## Why|## What|---"
    transformation: "Clean markdown, first paragraph"

  what:
    source: "## What"
    subsection: "### User-Visible Behavior"
    end_marker: "### Success|## All"
    transformation: "Clean markdown, preserve formatting"

  success_criteria:
    source: "### Success Criteria"
    end_marker: "---|## "
    transformation: "Convert [ ] to - [ ], preserve checklist"
```

## Git Provider Integration

### GitHub Integration

```yaml
github:
  detection:
    command: "gh --version"
    auth_check: "gh auth status"

  pr_create:
    command: |
      gh pr create \
        --title "{title}" \
        --body "{body}" \
        --base main

    options:
      - "--assignee @me"      # Auto-assign
      - "--label feature"     # Auto-label
      - "--draft"             # Create as draft
```

### GitLab Integration

```yaml
gitlab:
  detection:
    command: "glab --version"
    auth_check: "glab auth status"

  mr_create:
    command: |
      glab mr create \
        --title "{title}" \
        --description "{body}" \
        --target-branch main

    options:
      - "--assignee @me"           # Auto-assign
      - "--label feature"          # Auto-label
      - "--draft"                  # Create as draft
```

## Error Handling

### Error Categories

```yaml
error_handling:
  preflight_failures:
    - error: "tests_failed"
      action: "Halt workflow, show test output"
      recovery: "Fix tests and retry"

    - error: "lint_failed"
      action: "Halt workflow, show lint errors"
      recovery: "Fix lint issues and retry"

    - error: "uncommitted_changes"
      action: "Halt workflow, show status"
      recovery: "Commit or stash changes"

  git_errors:
    - error: "branch_exists"
      action: "Warn user"
      recovery: "Use existing branch or suggest different name"

    - error: "push_failed"
      action: "Show error, keep local changes"
      recovery: "Check permissions, fix remote issues"

    - error: "not_on_main"
      action: "Warn user"
      recovery: "Continue if user confirms"

  pr_errors:
    - error: "pr_exists"
      action: "Show existing PR URL"
      recovery: "Update existing PR or skip creation"

    - error: "auth_failed"
      action: "Show auth instructions"
      recovery: "Run gh auth login / glab auth login"

    - error: "cli_not_installed"
      action: "Show installation instructions"
      recovery: "Install gh/glab CLI and retry"
```

## Session Integration

### Session Files

```yaml
session_files:
  directory: ".prp-session/"

  read_from:
    - file: "current-prp.txt"
      purpose: "Path to current PRP (from execute-prp)"

    - file: "metrics.json"
      purpose: "Implementation metrics (from execute-prp)"

  write_to:
    - file: "ship-config.json"
      purpose: "Ship configuration and derived values"
      schema:
        prp_file: "string"
        feature_name: "string"
        branch_name: "string"
        commit_type: "string"
        auto_detected: "boolean"

    - file: "ship-result.json"
      purpose: "Ship operation results"
      schema:
        success: "boolean"
        branch_created: "string"
        commit_sha: "string"
        pr_url: "string"
        shipped_at: "timestamp"
        errors: "string[]"
```

## Dry-Run Mode

### Behavior

```yaml
dry_run:
  description: "Preview what would happen without executing"
  flag: "--dry-run"

  actions:
    - "Show detected PRP file"
    - "Show generated branch name"
    - "Show generated commit message"
    - "Show PR title and body preview"
    - "Show validation results"
    - "DO NOT create branch"
    - "DO NOT commit changes"
    - "DO NOT push to remote"
    - "DO NOT create PR"

  output_format: |
    [DRY-RUN] Pre-flight validation
    ├── Tests: {would pass/fail}
    ├── Lint: {would pass/fail}
    └── Build: {would pass/fail}

    [DRY-RUN] Would create branch: {branch_name}
    [DRY-RUN] Would commit with message:
    {commit_message_preview}

    [DRY-RUN] Would push to origin
    [DRY-RUN] Would create PR with title: {pr_title}

    [DRY-RUN] No changes made - rerun without --dry-run to execute
```

## Anti-Patterns

```yaml
anti_patterns:
  - pattern: "Create PR without running tests"
    why: "May ship broken code"
    instead: "Always run preflight checks"

  - pattern: "Force push to shared branches"
    why: "Destroys collaborator history"
    instead: "Never force push, resolve conflicts manually"

  - pattern: "Hardcode branch names"
    why: "Breaks automation, causes conflicts"
    instead: "Always derive from PRP filename"

  - pattern: "Skip preflight in dry-run"
    why: "Dry-run should show real validation state"
    instead: "Run preflight but don't fail on issues"

  - pattern: "Create empty commits"
    why: "Pollutes git history"
    instead: "Only commit if has_changes is true"

  - pattern: "Create duplicate PRs"
    why: "Confuses reviewers, wastes resources"
    instead: "Check for existing PR before creating"

  - pattern: "Leave uncommitted changes"
    why: "Breaks subsequent operations"
    instead: "Ensure clean state after ship"

  - pattern: "Ignore git errors"
    why: "May leave repo in bad state"
    instead: "Always report errors clearly"
```

---

*Ship Workflow Specification v1.0.0*
*Part of CC Blueprint Toolkit*
