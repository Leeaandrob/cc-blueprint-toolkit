---
description: Implement features from PRP specifications with TDD E2E workflow and architecture documentation generation
argument-hint: [path/to/prp-file.md]
allowed-tools: TodoWrite, Read, Write, Edit, MultiEdit, Glob, Grep, Bash, NotebookEdit, Task
---

# Execute PRP with TDD E2E Workflow

Implement a feature using the PRP file following a pure TDD (Test-Driven Development) approach with E2E tests and comprehensive architecture documentation generation.

## PRP File: $ARGUMENTS

## TDD E2E Workflow

This command follows the **state of the art** TDD workflow:

```
┌─────────────────────────────────────────────────────────────────┐
│                    TDD E2E WORKFLOW                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🔴 PHASE 1: RED                                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Generate E2E tests from PRP acceptance criteria        │   │
│  │  • Tests MUST fail (code doesn't exist yet)             │   │
│  │  • Tests define expected behavior                       │   │
│  │  • Run tests to confirm RED state                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           │                                     │
│                           ▼                                     │
│  🟢 PHASE 2: GREEN                                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Implement minimum code to pass tests                   │   │
│  │  • Follow codebase patterns                             │   │
│  │  • Run tests after each change                          │   │
│  │  • Stop when all tests pass                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           │                                     │
│                           ▼                                     │
│  🔵 PHASE 3: REFACTOR                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Improve code quality while keeping tests green         │   │
│  │  • Apply design patterns                                │   │
│  │  • Remove duplication                                   │   │
│  │  • Optimize performance                                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           │                                     │
│                           ▼                                     │
│  📚 PHASE 4: DOCUMENT                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Generate architectural documentation                   │   │
│  │  • ADRs (Architecture Decision Records)                 │   │
│  │  • C4 Diagrams (Context, Container, Component)          │   │
│  │  • API Documentation (OpenAPI)                          │   │
│  │  • Data Flow Diagrams                                   │   │
│  │  • ERD (Entity Relationship Diagrams)                   │   │
│  │  • Sequence Diagrams                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Execution Process

### 0. Load and Understand PRP

1. **Read the PRP file** completely
2. **Extract acceptance criteria** from Success Criteria section
3. **Understand the context** and requirements
4. **Identify the project stack** (Node, Python, Go, Web, Mobile, Full-Stack)

### 1. PHASE RED: Generate E2E Tests

**Call the TDD E2E Generator Agent:**

```
Use the Task tool with subagent_type: bp:tdd-e2e-generator
Provide: PRP file path and acceptance criteria
```

The agent will:
- Detect project stack (package.json, requirements.txt, go.mod, etc.)
- Select appropriate test framework:
  - **Backend Node**: Supertest + Jest
  - **Frontend Web**: Playwright
  - **Backend Python**: pytest + httpx
  - **Mobile React Native**: Detox + Jest
  - **Golang**: go test
  - **Full-Stack**: Playwright
- Generate E2E test file based on acceptance criteria
- Place tests in `tests/e2e/` directory
- Run tests to verify RED state (all should fail)

**Verify RED state before proceeding!**

### 2. PHASE GREEN: Implement Code

1. **Create implementation plan** using TodoWrite
2. **Study reference files** specified in PRP
3. **Implement minimum code** to pass tests:
   - Follow existing codebase patterns
   - Run tests after each significant change
   - Fix failing tests one at a time
4. **Continue until all tests pass**

**Do NOT proceed until all tests are GREEN!**

### 3. PHASE REFACTOR: Improve Code Quality

1. **Review implemented code** for quality issues
2. **Apply improvements** while keeping tests green:
   - Remove code duplication
   - Improve naming and structure
   - Apply appropriate design patterns
   - Optimize performance if needed
3. **Run tests after each refactoring** to ensure they still pass

### 4. PHASE DOCUMENT: Generate Architecture Docs

**Call the Architecture Docs Generator Agent:**

```
Use the Task tool with subagent_type: bp:architecture-docs-generator
Provide: PRP file path and implemented code context
```

The agent will generate:
- **ADRs** - Document key decisions made during implementation
- **C4 Context Diagram** - System context (Mermaid)
- **C4 Container Diagram** - Container architecture (Mermaid)
- **C4 Component Diagram** - Component details (Mermaid)
- **Data Flow Diagram** - How data flows through the system (Mermaid)
- **ERD** - Entity relationships if database involved (Mermaid)
- **Sequence Diagrams** - Key interaction sequences (Mermaid)
- **OpenAPI Spec** - API documentation if API endpoints exist

Documentation will be placed in `docs/architecture/` directory.

### 5. Final Validation

1. **Run complete test suite** one final time
2. **Verify all documentation** was generated correctly
3. **Check Mermaid diagrams** render properly
4. **Review against PRP checklist**

### 6. Completion Report

Provide a summary showing:

```
TDD E2E WORKFLOW - COMPLETION REPORT
====================================

📋 PRP: [PRP file name]
📅 Date: [Current date]

🔴 PHASE RED (Tests Generated)
   ├── Stack detected: [Node/Python/Go/Web/Mobile/Full-Stack]
   ├── Framework used: [Test framework]
   ├── Test file: [Path to test file]
   └── Test cases: [Number of tests]

🟢 PHASE GREEN (Implementation)
   ├── Files created: [Number]
   ├── Files modified: [Number]
   └── All tests passing: ✅

🔵 PHASE REFACTOR (Code Quality)
   ├── Patterns applied: [List]
   └── Optimizations: [List]

📚 PHASE DOCUMENT (Architecture Docs)
   ├── ADRs: [Number created]
   ├── C4 Diagrams: [List]
   ├── Data Flow: [Created/Skipped]
   ├── ERD: [Created/Skipped]
   ├── Sequence Diagrams: [Number]
   └── OpenAPI: [Created/Skipped]

✅ SUCCESS CRITERIA
   [List each criterion with ✅ or ❌]

📁 FILES GENERATED
   ├── tests/e2e/[feature].spec.ts
   ├── docs/architecture/decisions/ADR-XXX.md
   ├── docs/architecture/diagrams/c4-context.md
   ├── docs/architecture/diagrams/c4-container.md
   ├── docs/architecture/diagrams/c4-component.md
   ├── docs/architecture/diagrams/data-flow.md
   ├── docs/architecture/diagrams/erd.md
   ├── docs/architecture/diagrams/sequence-XXX.md
   └── docs/architecture/api/openapi.yaml

🎯 IMPLEMENTATION COMPLETE
```

## Stack Detection Reference

| Indicator | Stack | Test Framework |
|-----------|-------|----------------|
| `package.json` with express/fastify/nest | Backend Node | Supertest + Jest |
| `package.json` with react/vue/angular | Frontend Web | Playwright |
| `package.json` with next/nuxt/sveltekit | Full-Stack | Playwright |
| `package.json` with react-native | Mobile | Detox + Jest |
| `requirements.txt` or `pyproject.toml` | Backend Python | pytest + httpx |
| `go.mod` | Golang | go test |

## Important Notes

- **TDD is mandatory** - Tests MUST be written before implementation
- **Tests must fail first** - Verify RED state before coding
- **Tests must pass** - Do not proceed to refactor until GREEN
- **Documentation reflects reality** - Docs are generated AFTER implementation
- **All diagrams use Mermaid** - For GitHub/GitLab compatibility

## Legacy Mode

If TDD workflow is not applicable (e.g., documentation-only PRP), fall back to standard execution:

1. Read PRP and understand requirements
2. Plan implementation with TodoWrite
3. Execute following reference patterns
4. Validate with project commands
5. Complete checklist items
