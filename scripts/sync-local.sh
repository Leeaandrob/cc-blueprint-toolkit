#!/usr/bin/env bash
# sync-local.sh - Sync local development to Claude Code installation
#
# Usage:
#   ./scripts/sync-local.sh          # Sync files
#   ./scripts/sync-local.sh --link   # Use symlinks (dev mode)
#   ./scripts/sync-local.sh --watch  # Watch for changes and auto-sync
#
# Version: 1.0.0

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PLUGIN_NAME="bp"
MARKETPLACE_NAME="cc-blueprint-toolkit"

# Claude Code paths
CLAUDE_DIR="${HOME}/.claude"
MARKETPLACE_DIR="${CLAUDE_DIR}/plugins/marketplaces/${MARKETPLACE_NAME}"
CACHE_DIR="${CLAUDE_DIR}/plugins/cache/${MARKETPLACE_NAME}/${PLUGIN_NAME}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    # Check if Claude directory exists
    if [[ ! -d "$CLAUDE_DIR" ]]; then
        log_error "Claude Code directory not found: $CLAUDE_DIR"
        log_info "Make sure Claude Code is installed"
        exit 1
    fi

    # Check if marketplace directory exists
    if [[ ! -d "$MARKETPLACE_DIR" ]]; then
        log_error "Plugin not installed from marketplace"
        log_info "Run: /plugin marketplace add croffasia/cc-blueprint-toolkit"
        log_info "Then: /plugin install bp"
        exit 1
    fi
}

get_installed_version() {
    if [[ -d "$CACHE_DIR" ]]; then
        ls -1 "$CACHE_DIR" | head -1
    else
        echo "none"
    fi
}

# =============================================================================
# SYNC FUNCTIONS
# =============================================================================

sync_files() {
    log_info "Syncing files from local development to Claude installation..."

    local target="$1"

    # Directories to sync
    local dirs=(
        "claude/agents"
        "claude/commands"
        "claude/lib"
        "docs/templates"
    )

    # Files to sync
    local files=(
        "README.md"
        ".mcp.json"
        ".gitignore"
        "LICENSE"
    )

    # Sync directories
    for dir in "${dirs[@]}"; do
        if [[ -d "${PROJECT_ROOT}/${dir}" ]]; then
            mkdir -p "${target}/${dir}"
            rsync -av --delete "${PROJECT_ROOT}/${dir}/" "${target}/${dir}/"
            log_success "Synced ${dir}/"
        fi
    done

    # Sync individual files
    for file in "${files[@]}"; do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            cp "${PROJECT_ROOT}/${file}" "${target}/${file}"
            log_success "Synced ${file}"
        fi
    done

    # Sync .claude-plugin directory if exists
    if [[ -d "${PROJECT_ROOT}/.claude-plugin" ]]; then
        rsync -av "${PROJECT_ROOT}/.claude-plugin/" "${target}/.claude-plugin/"
        log_success "Synced .claude-plugin/"
    fi
}

create_symlinks() {
    log_info "Creating symlinks for development mode..."

    local target="$1"

    # Remove existing target and create symlink
    if [[ -d "$target" && ! -L "$target" ]]; then
        log_warning "Backing up existing installation to ${target}.bak"
        mv "$target" "${target}.bak"
    elif [[ -L "$target" ]]; then
        rm "$target"
    fi

    ln -sf "$PROJECT_ROOT" "$target"
    log_success "Created symlink: $target -> $PROJECT_ROOT"
}

update_cache() {
    local version
    version=$(get_installed_version)

    if [[ "$version" != "none" ]]; then
        log_info "Updating cache for version: $version"
        sync_files "${CACHE_DIR}/${version}"
        log_success "Cache updated!"
    else
        log_warning "No installed version found in cache"
    fi
}

# =============================================================================
# WATCH MODE
# =============================================================================

watch_mode() {
    log_info "Starting watch mode..."
    log_info "Watching for changes in: $PROJECT_ROOT"
    log_info "Press Ctrl+C to stop"

    # Check if inotifywait is available
    if ! command -v inotifywait &> /dev/null; then
        log_error "inotifywait not found. Install with: sudo apt install inotify-tools"
        exit 1
    fi

    # Initial sync
    sync_files "$MARKETPLACE_DIR"
    update_cache

    # Watch for changes
    while true; do
        inotifywait -r -e modify,create,delete,move \
            --exclude '(\.git|node_modules|__pycache__|\.prp-session)' \
            "$PROJECT_ROOT/claude" \
            "$PROJECT_ROOT/docs/templates" \
            "$PROJECT_ROOT/README.md" \
            2>/dev/null

        log_info "Changes detected, syncing..."
        sync_files "$MARKETPLACE_DIR"
        update_cache
        log_success "Sync complete! $(date '+%H:%M:%S')"
    done
}

# =============================================================================
# MAIN
# =============================================================================

show_status() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CC-BLUEPRINT-TOOLKIT LOCAL SYNC"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Project Root:     $PROJECT_ROOT"
    echo "  Marketplace Dir:  $MARKETPLACE_DIR"
    echo "  Cache Dir:        $CACHE_DIR"
    echo "  Installed Version: $(get_installed_version)"
    echo ""
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Sync local cc-blueprint-toolkit development to Claude Code installation.

Options:
  --sync      Sync files (default action)
  --link      Create symlinks for live development
  --watch     Watch for changes and auto-sync
  --status    Show current installation status
  --help      Show this help message

Examples:
  $(basename "$0")              # One-time sync
  $(basename "$0") --watch      # Auto-sync on file changes
  $(basename "$0") --link       # Symlink for live changes

EOF
}

main() {
    local mode="sync"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --sync)
                mode="sync"
                shift
                ;;
            --link)
                mode="link"
                shift
                ;;
            --watch)
                mode="watch"
                shift
                ;;
            --status)
                mode="status"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    show_status
    check_prerequisites

    case "$mode" in
        sync)
            log_info "Mode: One-time sync"
            sync_files "$MARKETPLACE_DIR"
            update_cache
            echo ""
            log_success "Sync complete!"
            log_info "Restart Claude Code to load changes"
            ;;
        link)
            log_info "Mode: Symlink (development)"
            create_symlinks "$MARKETPLACE_DIR"
            echo ""
            log_success "Symlinks created!"
            log_warning "Changes will be live - be careful in production!"
            ;;
        watch)
            log_info "Mode: Watch (auto-sync)"
            watch_mode
            ;;
        status)
            log_info "Status check complete"
            ;;
    esac
}

main "$@"
