---
description: Ship implemented feature - create branch, commit, push, and PR with automated preflight validation
argument-hint: [--prp path/to/prp.md] [--dry-run] [--no-pr] [--type feat|fix|refactor]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, TodoWrite
---

# /bp:ship - Feature Delivery Command

Ship an implemented feature by automating the entire delivery workflow: pre-flight validation, branch creation, commit generation, push to origin, and PR creation with structured description.

## Arguments

```yaml
arguments:
  --prp:
    description: "Path to PRP file (auto-detected from session if not provided)"
    required: false
    example: "--prp docs/PRPs/2026-01-13-my-feature.md"

  --dry-run:
    description: "Preview what would happen without executing any commands"
    required: false
    example: "--dry-run"

  --no-pr:
    description: "Skip PR creation (only commit and push)"
    required: false
    example: "--no-pr"

  --type:
    description: "Override commit type (auto-detected from PRP if not provided)"
    required: false
    values: ["feat", "fix", "refactor", "docs", "test", "chore"]
    example: "--type fix"
```

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    /bp:ship WORKFLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. DETECT CONTEXT                                              │
│     ├── Find PRP file (argument or .prp-session/current-prp)   │
│     ├── Detect git provider (GitHub or GitLab)                 │
│     └── Check CLI availability (gh or glab)                     │
│                                                                 │
│  2. PRE-FLIGHT VALIDATION                                       │
│     ├── ✅ Tests pass                                           │
│     ├── ✅ Lint passes                                          │
│     ├── ✅ Build passes (optional)                              │
│     └── ✅ Git status clean                                     │
│                                                                 │
│  3. PREPARE DELIVERY                                            │
│     ├── Generate branch name (feature/feature-name)            │
│     ├── Generate commit message (Conventional Commits)          │
│     └── Generate PR description (from PRP)                      │
│                                                                 │
│  4. EXECUTE DELIVERY                                            │
│     ├── git checkout -b {branch}                                │
│     ├── git add .                                               │
│     ├── git commit -m "{message}"                              │
│     ├── git push -u origin {branch}                             │
│     └── gh pr create / glab mr create                           │
│                                                                 │
│  5. REPORT RESULTS                                              │
│     ├── Branch created                                          │
│     ├── Commit SHA                                              │
│     └── PR URL                                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Execution Steps

### Step 1: Detect Context

**Find PRP File:**

```bash
# Check argument first
if [ -n "$ARGUMENTS" ] && echo "$ARGUMENTS" | grep -q "\-\-prp"; then
  PRP_FILE=$(echo "$ARGUMENTS" | grep -oP '(?<=--prp\s)[^\s]+')
# Check session file
elif [ -f ".prp-session/current-prp.txt" ]; then
  PRP_FILE=$(cat .prp-session/current-prp.txt)
else
  echo "ERROR: No PRP file found. Provide --prp argument or run /bp:execute-prp first."
  exit 1
fi
```

**Detect Git Provider:**

```bash
# Check for GitHub CLI
if command -v gh &> /dev/null && gh auth status &> /dev/null; then
  GIT_PROVIDER="github"
  CLI_COMMAND="gh"
# Check for GitLab CLI
elif command -v glab &> /dev/null && glab auth status &> /dev/null; then
  GIT_PROVIDER="gitlab"
  CLI_COMMAND="glab"
else
  echo "WARNING: No git provider CLI found. PR creation will be skipped."
  GIT_PROVIDER="none"
fi
```

### Step 2: Pre-Flight Validation

**Required Checks:**

```bash
# Run tests
echo "Running tests..."
if ! make test 2>/dev/null || ! npm test 2>/dev/null || ! pytest 2>/dev/null; then
  echo "❌ Tests failed. Fix test failures before shipping."
  exit 1
fi
echo "✅ Tests passed"

# Run lint
echo "Running lint..."
if ! make lint 2>/dev/null || ! npm run lint 2>/dev/null; then
  echo "❌ Lint failed. Fix lint errors before shipping."
  exit 1
fi
echo "✅ Lint passed"

# Run build (optional)
echo "Running build..."
if make build 2>/dev/null || npm run build 2>/dev/null; then
  echo "✅ Build passed"
else
  echo "⚠️ Build skipped (not configured)"
fi

# Check git status
echo "Checking git status..."
if [ -n "$(git status --porcelain)" ]; then
  echo "📝 Changes detected - will be included in commit"
  HAS_CHANGES=true
else
  echo "❌ No changes to ship"
  exit 1
fi
```

**Store Pre-flight Results:**

```bash
mkdir -p .prp-session
cat > .prp-session/preflight-result.json <<EOF
{
  "tests_passed": true,
  "lint_passed": true,
  "build_passed": true,
  "has_changes": true,
  "is_clean": true,
  "current_branch": "$(git branch --show-current)",
  "checked_at": "$(date -Iseconds)"
}
EOF
```

### Step 3: Prepare Delivery

**Call PR Generator Agent:**

```
Use the Task tool with subagent_type: general-purpose
Provide:
  - PRP file path
  - Request to extract: branch name, commit message, PR title, PR body
  - Follow pr-generator.md agent patterns
```

The agent will generate:
- **Branch name**: `feature/{feature-slug}` or `fix/{feature-slug}`
- **Commit message**: Following Conventional Commits format
- **PR title**: `{type}: {short description}`
- **PR body**: With Summary, What Changed, Acceptance Criteria sections

**Example Generated Artifacts:**

```yaml
branch_name: "feature/bp-ship-delivery-command"
commit_type: "feat"
commit_message: |
  feat: implement ship delivery command

  Add /bp:ship command that automates feature delivery workflow
  including preflight validation, branch creation, and PR generation.

  PRP: docs/PRPs/2026-01-13-bp-ship-delivery-command.md
pr_title: "feat: implement ship delivery command"
```

### Step 4: Execute Delivery

**Check Dry-Run Mode:**

```bash
if echo "$ARGUMENTS" | grep -q "\-\-dry-run"; then
  DRY_RUN=true
  echo "[DRY-RUN] Would create branch: $BRANCH_NAME"
  echo "[DRY-RUN] Would commit: $COMMIT_MESSAGE"
  echo "[DRY-RUN] Would push to origin"
  echo "[DRY-RUN] Would create PR with title: $PR_TITLE"
  echo "[DRY-RUN] No changes made"
  exit 0
fi
```

**Create Branch:**

```bash
echo "Creating branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"
```

**Stage and Commit:**

```bash
echo "Staging changes..."
git add .

echo "Creating commit..."
git commit -m "$COMMIT_MESSAGE"
COMMIT_SHA=$(git rev-parse --short HEAD)
```

**Push to Origin:**

```bash
echo "Pushing to origin..."
git push -u origin "$BRANCH_NAME"
```

**Create PR (unless --no-pr):**

```bash
if ! echo "$ARGUMENTS" | grep -q "\-\-no-pr"; then
  if [ "$GIT_PROVIDER" = "github" ]; then
    echo "Creating GitHub PR..."
    PR_URL=$(gh pr create --title "$PR_TITLE" --body "$PR_BODY" --base main)
  elif [ "$GIT_PROVIDER" = "gitlab" ]; then
    echo "Creating GitLab MR..."
    PR_URL=$(glab mr create --title "$PR_TITLE" --description "$PR_BODY" --target-branch main)
  fi
fi
```

### Step 5: Report Results

**Store Ship Result:**

```bash
cat > .prp-session/ship-result.json <<EOF
{
  "success": true,
  "branch_created": "$BRANCH_NAME",
  "commit_sha": "$COMMIT_SHA",
  "pr_url": "$PR_URL",
  "shipped_at": "$(date -Iseconds)",
  "errors": []
}
EOF
```

**Display Report:**

```
╔══════════════════════════════════════════════════════════════╗
║  SHIP COMPLETE                                                ║
╠══════════════════════════════════════════════════════════════╣
║  Branch:  feature/bp-ship-delivery-command                    ║
║  Commit:  abc1234                                             ║
║  PR:      https://github.com/user/repo/pull/123               ║
║                                                               ║
║  ✅ Tests passed                                              ║
║  ✅ Lint passed                                               ║
║  ✅ Build passed                                              ║
║  ✅ PR created                                                ║
╚══════════════════════════════════════════════════════════════╝
```

## Error Handling

### Pre-flight Failures

```yaml
test_failure:
  message: "❌ Tests failed. Fix failing tests before shipping."
  action: "Halt workflow, show test output"
  recovery: "Run tests locally, fix failures, retry"

lint_failure:
  message: "❌ Lint errors detected. Fix linting issues before shipping."
  action: "Halt workflow, show lint errors"
  recovery: "Run lint --fix if available, or fix manually"

no_changes:
  message: "❌ No changes to ship"
  action: "Halt workflow"
  recovery: "Make changes first or use --force if intentional"
```

### Git Errors

```yaml
branch_exists:
  message: "⚠️ Branch already exists: {branch_name}"
  action: "Warn user, offer options"
  options:
    - "Use existing branch"
    - "Generate different name"
    - "Delete and recreate"

push_failed:
  message: "❌ Push failed"
  action: "Show error, keep local changes"
  recovery: "Check permissions, network, retry"

not_on_expected_branch:
  message: "⚠️ Not on main/master branch"
  action: "Warn user"
  recovery: "Continue if user confirms"
```

### PR Errors

```yaml
pr_exists:
  message: "⚠️ PR already exists for this branch"
  action: "Show existing PR URL"
  recovery: "Update existing PR or skip creation"

auth_failed:
  message: "❌ GitHub/GitLab authentication failed"
  action: "Show auth instructions"
  recovery: "Run 'gh auth login' or 'glab auth login'"
```

## Integration with Execute-PRP

The ship command integrates seamlessly with the execute-prp workflow:

```
/bp:execute-prp docs/PRPs/my-feature.md
    ↓
Implementation complete, tests pass
    ↓
/bp:ship
    ↓
Feature delivered, PR created
```

The session state from execute-prp is used:
- `.prp-session/current-prp.txt` - Auto-detected PRP file
- `.prp-session/metrics.json` - Implementation metrics for PR context

## Specification Reference

For detailed workflow specifications, see:
- `claude/lib/ship-spec.md` - Complete ship workflow specification
- `claude/agents/pr-generator.md` - PR generation agent specification
- `claude/commands/execute-prp.md` - Execute PRP command (upstream workflow)
- `claude/commands/generate-prp.md` - Generate PRP command (creates PRP files)

## Examples

### Basic Usage

```bash
# After /bp:execute-prp completes:
/bp:ship

# Output:
# ✅ Pre-flight checks passed
# ✅ Branch created: feature/my-feature
# ✅ Changes committed: feat: implement my feature
# ✅ Pushed to origin
# ✅ PR created: https://github.com/user/repo/pull/123
```

### With Explicit PRP

```bash
/bp:ship --prp docs/PRPs/2026-01-13-user-auth.md
```

### Dry-Run Preview

```bash
/bp:ship --dry-run

# Output:
# [DRY-RUN] Would create branch: feature/user-auth
# [DRY-RUN] Would commit: feat: implement user authentication
# [DRY-RUN] Would push to origin
# [DRY-RUN] Would create PR with title: feat: implement user authentication
# [DRY-RUN] No changes made
```

### Without PR Creation

```bash
/bp:ship --no-pr

# Creates branch, commits, pushes, but skips PR creation
```

### Override Commit Type

```bash
/bp:ship --type fix

# Forces fix: instead of auto-detected feat:
```
