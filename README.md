<a href="https://vibecodekit.dev">
<img src="./public/vibecodekit-banner.png" alt="PRO Version" width="100%">
</a>

<p align="center">
<strong>🏆 Need advanced features?</strong> Check out the PRO version with early access and lifetime license<br>
→ <a href="https://vibecodekit.dev">vibecodekit.dev</a><br>
<strong>💎 Use code <code>CCBLUEPRINT</code> for 10% OFF</strong>
</p>

# 🏗️ Blueprint-Driven Claude Code Autopilot
> **Claude Code Plugin for smart blueprint-driven development**
>
> AI analyzes patterns, creates solid implementation plans, delivers working code in 15 minutes

[![GitHub stars](https://img.shields.io/github/stars/croffasia/cc-blueprint-toolkit?style=social)](https://github.com/croffasia/cc-blueprint-toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blue)](https://claude.ai/code)
[![Threads / Open Source Alternatives](https://img.shields.io/badge/Threads-OpenSourceAlternatves-black)](https://www.threads.com/@opensourcealternatives)

Blueprint-driven development plugin: AI analyzes your codebase patterns, creates comprehensive implementation plans, then delivers production-ready code with tests. Smart preparation over endless iterations.

```bash
/bp:init
# → Automatically installs/updates templates in your project → docs/templates/*

/bp:brainstorm Add user authentication with OAuth2
# → Smart feature planning session → docs/brainstorming/2025-08-22-user-auth.md

/bp:generate-prp @docs/brainstorming/2025-08-22-user-auth.md
# OR directly: /prp:generate Add user authentication with OAuth2
# → Complete implementation blueprint → docs/prps/user-auth.md

/bp:execute-prp @docs/prps/user-auth.md
# → Working auth system (direct PRP execution for simple features)

/bp:execute-task @docs/tasks/user-auth.md
# → Execute all tasks from breakdown (for complex features)
```

**Before**: 2-4 hours of coding, debugging, and integration  
**After**: 15 minutes → Production-ready feature ✨

> ⭐ **Found this helpful? Star the repo and hit Watch** to get notified of new updates!

## ❤️ Why Developers Love It

- **10x Faster Development** - Feature idea to production in one session
- **Zero "Vibe Coding"** - AI follows your exact patterns and conventions
- **Smart Research** - Finds patterns in your codebase or searches dev resources for best practices when needed
- **Auto Task Breakdown** - Complex features automatically split into manageable step-by-step tasks
- **Any Tech Stack** - React, Python, Go, PHP - works everywhere

## 🚀 Quick Start

### Installation (3 simple steps)

**Step 1: Add Plugin from Marketplace**

In Claude Code console, run:
```bash
# Short format
/plugin marketplace add croffasia/cc-blueprint-toolkit

# Or full URL
/plugin marketplace add https://github.com/croffasia/cc-blueprint-toolkit.git
```

**Step 2: Install Plugin**

```bash
/plugin install bp
```

Then restart Claude Code to load the plugin.

**Step 3: Initialize Templates**

In your project directory, run once:
```bash
/bp:init
```

This will automatically install documentation templates to your project, enabling the full Blueprint workflow.

## 🎯 Commands

### 1. **Think Through Your Feature** (`/bp:brainstorm`)
- Smart AI Scrum Master guides you through structured planning
- Asks the right questions to uncover hidden requirements
- Creates comprehensive feature documentation → `docs/brainstorming/feature-session.md`
- Perfect for solo developers who need a thinking partner

### 2. **Create Perfect Plan** (`/bp:generate-prp`)
- Validates your request is complete (may ask clarifying questions)
- Studies your codebase patterns
- Researches external docs if needed
- Creates detailed implementation plan → `docs/prps/feature-name.md`
- Breaks down into technical tasks → `docs/tasks/feature-name.md`

### 3. **Execute the Plan** (`/bp:execute-prp`)
- **NEW: TDD E2E Workflow** - Tests first, then implementation
- Follows your patterns exactly
- Writes production-ready code
- Generates comprehensive architecture documentation
- Validates everything works

#### TDD E2E Workflow (State of the Art)
```
🔴 RED      → Generate failing E2E tests from acceptance criteria
🟢 GREEN   → Implement minimum code to pass tests
🔵 REFACTOR → Improve code quality while tests stay green
📚 DOCUMENT → Generate architecture docs (ADRs, C4, ERD, Sequence)
```

#### Ralph-Enhanced Reliability Patterns (v2)

The `execute-prp` command now includes production-grade reliability patterns inspired by [Ralph for Claude Code](https://github.com/anthropics/ralph-claude-code):

| Pattern | Purpose | Protection |
|---------|---------|------------|
| **Circuit Breaker** | Prevents infinite loops | 3-state machine (CLOSED → HALF_OPEN → OPEN) halts after no-progress iterations |
| **Dual-Gate Exit** | Requires 2 conditions before phase exit | Gate 1: Objective metrics + Gate 2: Explicit signal |
| **Metrics Tracking** | Quantitative progress detection | Phase-specific metrics (tests_passing, files_created, etc.) |
| **Session Persistence** | Resume capability | State saved in `.prp-session/` directory |

**Phase-Specific Thresholds:**

| Phase | No-Progress Threshold | Reason |
|-------|----------------------|--------|
| RED | 3 | Standard - test generation |
| GREEN | **2** | **Stricter** - highest loop risk |
| REFACTOR | 5 | Lenient - iterative by nature |
| DOCUMENT | 3 | Standard - doc generation |

**Status Block Output:**
Every significant action emits a structured `PRP_PHASE_STATUS` block for observability:
```
---PRP_PHASE_STATUS---
PHASE: GREEN
STATUS: IN_PROGRESS
ITERATION: 5
PROGRESS_PERCENT: 60
TESTS:
  PASSING: 6
  FAILING: 4
CIRCUIT_BREAKER:
  STATE: CLOSED
DUAL_GATE:
  CAN_EXIT: false
---END_PRP_PHASE_STATUS---
```

### 4. **Execute Tasks** (`/bp:execute-task`)
- Breaks down complex features into manageable tasks
- Executes task-by-task with validation
- Perfect for large implementations
- Systematic progress tracking

## 🎯 How It Works

### 🧠 Full Feature Development Flow
**brainstorm → generate prp → execute**

1. **Start with Ideas** - Use `/bp:brainstorm` when you need to explore and refine feature concepts
2. **Generate Implementation Plan** - Use `/bp:generate-prp` to create detailed technical specifications  
3. **Choose Your Execution Path**:
   - **Simple Features**: `/bp:execute-prp` - Direct implementation for straightforward tasks
   - **Complex Features**: `/bp:execute-task` - Step-by-step implementation with progress tracking

### 🚀 Quick Implementation Flow
**generate prp → execute**

Skip brainstorming when you have clear requirements:
1. **Generate Plan**: `/bp:generate-prp`
2. **Execute**: Choose `/bp:execute-prp` for simple features or `/bp:execute-task` for complex ones

> **Pro Tip**: Use `/bp:execute-task` for higher quality first-pass implementations on complex features

## 🧪 TDD E2E Testing Support

Automatic E2E test generation for multiple stacks:

| Stack | Test Framework | Template |
|-------|---------------|----------|
| **Backend Node** | Supertest + Jest | `node-supertest.template.md` |
| **Frontend Web** | Playwright | `playwright.template.md` |
| **Backend Python** | pytest + httpx | `python-pytest.template.md` |
| **Mobile React Native** | Detox + Jest | `detox.template.md` |
| **Golang** | go test | `golang.template.md` |
| **Full-Stack** | Playwright | `playwright.template.md` |

## 📐 Architecture Documentation

Auto-generated documentation during `execute-prp`:

| Document Type | Format | Description |
|--------------|--------|-------------|
| **ADRs** | Markdown | Architecture Decision Records (MADR format) |
| **C4 Context** | Mermaid | System context diagram |
| **C4 Container** | Mermaid | Container architecture |
| **C4 Component** | Mermaid | Component details |
| **Data Flow** | Mermaid | Data flow diagrams |
| **ERD** | Mermaid | Entity Relationship Diagrams |
| **Sequence** | Mermaid | Interaction sequences |
| **OpenAPI** | YAML | API specification (3.0.3) |

All diagrams use **Mermaid** format for native GitHub/GitLab rendering.

## 💎 What You Get

### ⚙️ Works With Everything
- **Frontend**: React, Vue, Angular, Svelte
- **Backend**: Node.js, Python, Go, PHP, Java
- **Mobile**: React Native, Flutter, Swift, Kotlin

## 📊 Real Results

- **Development Speed**: Dramatically faster feature delivery
- **Code Quality**: Higher (follows existing patterns)
- **Technical Debt**: Zero (uses established conventions)
- **Completeness**: AI asks clarifying questions to fill gaps
- **Validation**: Built-in linting and project checks

## 📁 What's Included

```
📦 cc-blueprint-toolkit/
├── claude/agents/                    # Smart research agents
│   ├── tdd-e2e-generator.md          # TDD E2E test generator
│   ├── architecture-docs-generator.md # Architecture docs generator
│   └── phase-monitor.md              # Ralph pattern monitoring agent
├── claude/lib/                       # Specification documents
│   ├── circuit-breaker-spec.md       # Circuit Breaker state machine
│   ├── dual-gate-spec.md             # Dual-Gate exit conditions
│   ├── status-block-spec.md          # PRP_PHASE_STATUS format
│   └── metrics-spec.md               # Progress metrics tracking
├── claude/commands/                  # Claude Code Commands
├── tests/bats/                       # BATS test suite
│   ├── test_helper.bash              # Test helper functions
│   ├── circuit_breaker.bats          # Circuit Breaker tests
│   ├── dual_gate.bats                # Dual-Gate tests
│   └── execute_prp_e2e.bats          # E2E workflow tests
├── docs/templates/                   # Templates
│   ├── e2e-tests/                    # E2E test templates (5 stacks)
│   │   ├── node-supertest.template.md
│   │   ├── playwright.template.md
│   │   ├── python-pytest.template.md
│   │   ├── detox.template.md
│   │   └── golang.template.md
│   └── architecture/                 # Architecture doc templates
│       ├── adr.template.md
│       ├── c4-context.template.md
│       ├── c4-container.template.md
│       ├── c4-component.template.md
│       ├── data-flow.template.md
│       ├── erd.template.md
│       ├── sequence.template.md
│       └── openapi.template.yaml
└── docs/                             # Documentation & guides
    └── vibe-coding-guide.md          # 10 essential tips for AI-powered development
```

## 🎯 Perfect For

- **Solo Developers** - Get team-level productivity + AI thinking partner for feature planning
- **Startups** - Ship features 10x faster with structured planning
- **Large Teams** - Maintain consistency across developers

## 📖 Learning Resources

- **[Vibe Coding Guide](docs/vibe-coding-guide.md)** - 10 essential tips for building projects with AI assistance

## 🏆 Upgrade to PRO

Want production-ready setup with zero configuration?

[![Watch Demo](./public/vibecodekit-banner-youtube.png)](https://www.youtube.com/watch?v=eBMNLzb_w4Q)

### **[Vibe Code Kit PRO](https://vibecodekit.dev)** - Early Access with Lifetime License

💎 **Use code `CCBLUEPRINT` for 10% OFF**

**What's included:**

- **Enhanced PRP Workflow** - Optimized blueprint generation with smarter context handling
- **Smart CLAUDE.md** - Pre-configured with lightweight workflow for routine tasks
- **Context-Aware AI Rules** - Automatically loads relevant rules based on your task
  - Working with styles? Style guidelines and CSS libraries rules auto-loaded
  - API development? Backend patterns and security rules activated
  - Smart context detection eliminates rule overload
  - Modular system lets you customize rules to fit your exact needs
- **Standards Compliance Agent** - Validates code quality and best practices after task completion
- **Professional Vue 3 Starter Kit** - Senior-grade template with Claude Code development rules
  - Pre-configured: ESLint, Prettier, Stylelint, TypeScript, Husky, Docker
  - Zero setup required - works from day one
  - Deploy anywhere instantly

**Perfect for teams and professionals who want enterprise-grade AI development tools without the setup hassle.**

## 🤝 Join the Community

- ⭐ **Star this repo** if it saves you hours
- 🍴 **Fork** to customize for your stack
- 💬 **Issues** for questions and feature requests
- 🔄 **PRs welcome** for new agents and improvements

## 📄 License

MIT License - Use freely in commercial projects

---

**Ready to stop wasting hours on features?** [Install now](#quick-start) and experience autonomous development! 🚀

[![GitHub stars](https://img.shields.io/github/stars/croffasia/cc-blueprint-toolkit?style=social)](https://github.com/croffasia/cc-blueprint-toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blue)](https://claude.ai/code)
[![Threads / Open Source Alternatives](https://img.shields.io/badge/Threads-OpenSourceAlternatves-black)](https://www.threads.com/@opensourcealternatives)