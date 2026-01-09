---
description: Initialize CC Blueprint Toolkit - copy documentation templates, E2E test templates, and architecture templates to your project
allowed-tools: Bash, Read, Write
---

# Initialize Blueprint Toolkit

Copy PRP templates, E2E test templates, and architecture documentation templates from the Blueprint Toolkit to your current project.

## Installation Steps

Execute the following steps to set up the toolkit in your project:

### 1. Clone the toolkit repository

```bash
git clone https://github.com/croffasia/cc-blueprint-toolkit.git /tmp/cc-blueprint-toolkit-temp
```

### 2. Create documentation directories

```bash
mkdir -p docs/templates docs/templates/e2e-tests docs/templates/architecture docs/prps docs/tasks docs/brainstorming docs/architecture/decisions docs/architecture/diagrams docs/architecture/api
```

### 3. Copy all templates to project

```bash
# Copy PRP and brainstorming templates
cp -r /tmp/cc-blueprint-toolkit-temp/docs/templates/prp_document_template.md docs/templates/
cp -r /tmp/cc-blueprint-toolkit-temp/docs/templates/technical-task-template.md docs/templates/
cp -r /tmp/cc-blueprint-toolkit-temp/docs/templates/brainstorming_session_template.md docs/templates/

# Copy E2E test templates
cp -r /tmp/cc-blueprint-toolkit-temp/docs/templates/e2e-tests/* docs/templates/e2e-tests/

# Copy architecture documentation templates
cp -r /tmp/cc-blueprint-toolkit-temp/docs/templates/architecture/* docs/templates/architecture/

# Cleanup
rm -rf /tmp/cc-blueprint-toolkit-temp
```

## Verification

After installation, verify the following files exist:

### Core Templates
- `docs/templates/prp_document_template.md`
- `docs/templates/technical-task-template.md`
- `docs/templates/brainstorming_session_template.md`

### E2E Test Templates
- `docs/templates/e2e-tests/node-supertest.template.md`
- `docs/templates/e2e-tests/playwright.template.md`
- `docs/templates/e2e-tests/python-pytest.template.md`
- `docs/templates/e2e-tests/detox.template.md`
- `docs/templates/e2e-tests/golang.template.md`

### Architecture Documentation Templates
- `docs/templates/architecture/adr.template.md`
- `docs/templates/architecture/c4-context.template.md`
- `docs/templates/architecture/c4-container.template.md`
- `docs/templates/architecture/c4-component.template.md`
- `docs/templates/architecture/data-flow.template.md`
- `docs/templates/architecture/erd.template.md`
- `docs/templates/architecture/sequence.template.md`
- `docs/templates/architecture/openapi.template.yaml`

## Success Message

Display to user:

```
✅ Blueprint Toolkit initialized successfully!

📁 Core Templates installed:
   → docs/templates/prp_document_template.md
   → docs/templates/technical-task-template.md
   → docs/templates/brainstorming_session_template.md

🧪 E2E Test Templates installed:
   → docs/templates/e2e-tests/node-supertest.template.md
   → docs/templates/e2e-tests/playwright.template.md
   → docs/templates/e2e-tests/python-pytest.template.md
   → docs/templates/e2e-tests/detox.template.md
   → docs/templates/e2e-tests/golang.template.md

📐 Architecture Templates installed:
   → docs/templates/architecture/adr.template.md
   → docs/templates/architecture/c4-context.template.md
   → docs/templates/architecture/c4-container.template.md
   → docs/templates/architecture/c4-component.template.md
   → docs/templates/architecture/data-flow.template.md
   → docs/templates/architecture/erd.template.md
   → docs/templates/architecture/sequence.template.md
   → docs/templates/architecture/openapi.template.yaml

📂 Directories created:
   → docs/prps/           (for generated PRPs)
   → docs/tasks/          (for task breakdowns)
   → docs/brainstorming/  (for brainstorming sessions)
   → docs/architecture/   (for generated architecture docs)
     ├── decisions/       (ADRs)
     ├── diagrams/        (Mermaid diagrams)
     └── api/             (OpenAPI specs)

🚀 Ready to use:
   /bp:brainstorm        - Start feature planning session
   /bp:generate-prp      - Create implementation blueprint
   /bp:execute-prp       - Execute PRP with TDD E2E workflow
   /bp:execute-task      - Execute task breakdown

🧪 TDD E2E Workflow (NEW!):
   execute-prp now follows TDD methodology:
   1. 🔴 RED    - Generate failing E2E tests
   2. 🟢 GREEN  - Implement code to pass tests
   3. 🔵 REFACTOR - Improve code quality
   4. 📚 DOCUMENT - Generate architecture docs

📐 Supported Stacks:
   • Backend Node (Supertest + Jest)
   • Frontend Web (Playwright)
   • Backend Python (pytest + httpx)
   • Mobile React Native (Detox)
   • Golang (go test)
   • Full-Stack (Playwright)

📚 Architecture Docs Generated:
   • ADRs (Architecture Decision Records)
   • C4 Diagrams (Context, Container, Component)
   • Data Flow Diagrams (Mermaid)
   • ERD (Entity Relationship Diagrams)
   • Sequence Diagrams
   • OpenAPI Specifications

💡 Tip: Start with /bp:brainstorm to explore your feature ideas,
   then use /bp:generate-prp to create a detailed implementation plan.
   The execute-prp command will now generate tests FIRST (TDD style)!
```
