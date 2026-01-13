#!/usr/bin/env bash
# install-hooks.sh - Install git hooks for auto-sync
#
# This installs a post-commit hook that automatically syncs
# changes to your local Claude Code installation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="${PROJECT_ROOT}/.git/hooks"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Installing git hooks...${NC}"

# Create post-commit hook
cat > "${HOOKS_DIR}/post-commit" << 'EOF'
#!/usr/bin/env bash
# Auto-sync to Claude Code after commit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

if [[ -x "${PROJECT_ROOT}/scripts/sync-local.sh" ]]; then
    echo ""
    echo "🔄 Auto-syncing to Claude Code..."
    "${PROJECT_ROOT}/scripts/sync-local.sh" --sync 2>/dev/null || true
fi
EOF

chmod +x "${HOOKS_DIR}/post-commit"

echo -e "${GREEN}✓ post-commit hook installed${NC}"
echo ""
echo "Now every commit will automatically sync to your Claude Code installation."
echo "To disable, remove: ${HOOKS_DIR}/post-commit"
