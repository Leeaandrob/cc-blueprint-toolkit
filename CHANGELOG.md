# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.0] - 2026-01-16

### Added - TDD E2E Workflow (Major Feature)
- **TDD E2E Generator Agent** - Generates failing E2E tests from PRP acceptance criteria
- **Architecture Docs Generator Agent** - Creates comprehensive documentation post-implementation
- **Phase Monitor Agent** - Implements Ralph patterns for workflow reliability
- **6 E2E Test Templates** - Support for Node.js, Python, Golang, Playwright, Detox, Full-Stack
- **8 Architecture Templates** - ADR, C4 (Context/Container/Component), Data Flow, ERD, Sequence, OpenAPI

### Added - Ralph-Enhanced Reliability Patterns
- **Circuit Breaker** - Prevents infinite loops with 3-state machine (CLOSED → HALF_OPEN → OPEN)
- **Dual-Gate Exit** - Requires 2 conditions before phase completion
- **PRP_PHASE_STATUS Blocks** - Structured observability for workflow phases
- **Metrics Tracking** - Quantitative progress detection per phase

### Added - Ship Command
- `/bp:ship` - Automated branch creation, commit, push, and PR generation
- Supports both GitHub (`gh`) and GitLab (`glab`) CLIs
- Pre-flight validation (tests, lint, build)
- Conventional Commits format

### Added - Developer Experience
- `Makefile` with common development commands
- Improved `sync-local.sh` - Now syncs to ALL cache versions
- Git hooks for auto-sync on commit

### Changed
- **execute-prp** now follows TDD methodology: RED → GREEN → REFACTOR → DOCUMENT
- Plugin version system now properly syncs between `plugin.json` and `marketplace.json`
- Repository ownership transferred to active maintainer (Leeaandrob)

### Fixed
- Version mismatch between plugin.json and marketplace.json
- Missing agent registration (phase-monitor.md)
- Symlink issues in development mode
- Cache sync only updating first version instead of all versions

## [1.5.0] - 2026-01-09

### Added
- Initial TDD E2E workflow implementation
- Ralph patterns integration
- Basic architecture documentation generation

### Fixed
- Windows installation fails due to invalid filename character
- Synchronized git and plugin versions

## [1.4.1] - Previous Release (croffasia)

### Original Features
- Blueprint-driven development workflow
- PRP (Product Requirements & Plans) generation
- Brainstorming sessions with AI Scrum Master
- Task breakdown and execution
- Multi-stack support

---

## Credits

This project is a fork of [cc-blueprint-toolkit](https://github.com/croffasia/cc-blueprint-toolkit)
originally created by [Croffasia](https://github.com/croffasia).

**Original Author:** Croffasia (MIT License)
**Active Maintainer:** [Leeaandrob](https://github.com/Leeaandrob)

The original project provided an excellent foundation for blueprint-driven development.
This fork adds significant enhancements including TDD E2E workflows, Ralph reliability patterns,
and comprehensive architecture documentation generation.
