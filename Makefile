# Makefile - cc-blueprint-toolkit development commands
#
# Usage:
#   make sync       - Sync to Claude Code (one-time)
#   make watch      - Watch and auto-sync on changes
#   make link       - Create symlinks for live dev
#   make install    - Full install (sync + hooks)
#   make test       - Run BATS tests
#   make status     - Show installation status

.PHONY: sync watch link dev install test status hooks clean help

# Default target
.DEFAULT_GOAL := help

# =============================================================================
# MAIN COMMANDS
# =============================================================================

sync: ## Sync files to Claude Code installation
	@./scripts/sync-local.sh --sync

watch: ## Watch for changes and auto-sync
	@./scripts/sync-local.sh --watch

link: ## Create symlinks for live development
	@./scripts/sync-local.sh --link

dev: ## Setup local .claude symlinks for development in this project
	@mkdir -p .claude
	@ln -sf ../claude/commands .claude/commands 2>/dev/null || true
	@ln -sf ../claude/agents .claude/agents 2>/dev/null || true
	@echo "✅ Local symlinks created:"
	@echo "   .claude/commands -> claude/commands"
	@echo "   .claude/agents -> claude/agents"
	@echo ""
	@echo "⚠️  Restart Claude Code to load commands"

status: ## Show current installation status
	@./scripts/sync-local.sh --status

# =============================================================================
# INSTALLATION
# =============================================================================

install: sync hooks ## Full install: sync files + git hooks
	@echo ""
	@echo "✅ Installation complete!"
	@echo "   - Files synced to Claude Code"
	@echo "   - Git hooks installed for auto-sync"
	@echo ""
	@echo "⚠️  Restart Claude Code to load changes"

hooks: ## Install git hooks for auto-sync on commit
	@chmod +x ./scripts/install-hooks.sh
	@./scripts/install-hooks.sh

# =============================================================================
# TESTING
# =============================================================================

test: ## Run BATS tests
	@if command -v bats &> /dev/null; then \
		bats tests/bats/*.bats; \
	else \
		echo "BATS not installed. Install with:"; \
		echo "  sudo apt install bats"; \
		echo "  # or"; \
		echo "  brew install bats-core"; \
	fi

test-cb: ## Run Circuit Breaker tests only
	@bats tests/bats/circuit_breaker.bats

test-dg: ## Run Dual-Gate tests only
	@bats tests/bats/dual_gate.bats

test-e2e: ## Run E2E workflow tests only
	@bats tests/bats/execute_prp_e2e.bats

# =============================================================================
# CLEANUP
# =============================================================================

clean: ## Remove generated files
	@rm -rf .prp-session/
	@echo "Cleaned .prp-session/"

clean-all: clean ## Remove all generated and cache files
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "Cleaned all cache files"

# =============================================================================
# HELP
# =============================================================================

help: ## Show this help message
	@echo ""
	@echo "CC-BLUEPRINT-TOOLKIT Development Commands"
	@echo "=========================================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Quick Start:"
	@echo "  make install    # First time setup"
	@echo "  make watch      # Development mode"
	@echo ""
