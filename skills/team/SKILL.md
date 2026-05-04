---
name: team
description: >
  Use after /ck-code:design to generate project-tailored expert skills (frontend,
  backend, QA, DevOps, analyst) and language/framework guides (Rust, TypeScript,
  React Native, etc.). Researches current best practices via context7 before
  generating, so guides reflect up-to-date recommendations. Auto-detects missing
  skills on subsequent runs — generates only what's needed. Use --check to audit
  without generating, --regenerate to refresh all. Auto-loaded by /ck-code:build
  and /ck-code:fix.
argument-hint: "[--check|--regenerate]"
disable-model-invocation: true
---

# Generate Experts — Project-Tailored Expert Skill Factory

Reads the project architecture documentation and generates a set of specialized
expert skills, each deeply aware of the project's tech stack, patterns, folder
structure, and conventions.

**What it produces:**
- `.claude/skills/experts/<role>/SKILL.md` — expert persona skills (invoked as `/expert-<role>`)
- `.claude/skills/guides/<tech>/SKILL.md` — language/framework guide skills (auto-loaded by Claude)

**Auto-loaded by:** `/ck-code:build` and `/ck-code:fix`. Re-run with
`--regenerate` after architecture or framework upgrades to refresh project
context and research.

## INPUT

`$ARGUMENTS` can include a path to the architecture docs folder (default:
`docs/architecture/`) and/or one of these flags:
- `--check` — audit which skills are missing/present, then stop (no generation)
- `--regenerate` — overwrite all previously generated skills with fresh versions

---

## PHASE 0: DETECT EXISTING STATE

**Runs first. Skip entirely if:** `--regenerate` is set OR no skills exist yet.

```
skills_exist = any .claude/skills/experts/*/SKILL.md
             OR any .claude/skills/guides/*/SKILL.md

IF NOT skills_exist OR --regenerate:
  → Proceed to Phase 1 normally (generation mode: ALL)

IF skills_exist AND NOT --regenerate:
  1. Quick-read docs/architecture/tech-stack.md
  2. Run Phase 2.3 auto-detection logic → build EXPECTED skills list
  3. Scan .claude/skills/experts/ and .claude/skills/guides/ → build EXISTING list
  4. Compute:
       MISSING = EXPECTED − EXISTING
       EXTRA   = EXISTING − EXPECTED  (tech no longer detected)
  5. Show the state table (see references/examples.md#phase-0-state-table)
  6. IF --check flag → STOP (report only, no generation)
  7. IF MISSING is empty → inform user, suggest --regenerate if refresh needed → STOP
  8. IF MISSING is not empty → ask:
       A) Generate missing only
       B) Regenerate all
       C) Abort
     On A → Proceed to Phase 1 in MISSING-ONLY mode (target = MISSING list)
     On B → Proceed to Phase 1 in ALL mode
     On C → STOP
```

**MISSING-ONLY mode** is an internal flag carried through Phases 1–3: Phase 1.6
researches only the technologies needed for missing skills; Phase 2.4 shows only
missing skills in its plan table; Phase 3/3b generates only the missing skills.

---

## PHASE 1: READ PROJECT CONTEXT

**Goal:** Build a complete understanding of the project to inject into each expert.

### 1.1 Validate Prerequisites

```
IF docs/architecture/ does NOT exist or is empty:
  → "No architecture docs found. Run /ck-code:design first to generate them."
  → STOP
```

### 1.2 Read All Architecture Docs

Read every file in `docs/architecture/`:
- `overview.md` — project vision, goals, users
- `folder-structure.md` — directory layout
- `tech-stack.md` — languages, frameworks, versions
- `components.md` — system components and interactions
- `data-flow.md` — data movement patterns
- `api-contracts.md` — API definitions
- `database-schema.md` — DB schema
- `configuration.md` — config and env vars
- `dev-guide.md` — build, run, test instructions

Also read if available:
- `docs/specifications.md` or similar spec files
- `docs/architecture/features/*.md` — feature-specific docs

### 1.3 Scan Existing Codebase

Use Glob and Grep to understand:
- What source files exist and their languages
- Test file locations and testing frameworks used
- CI/CD configuration files
- Package manager files (package.json, Cargo.toml, CMakeLists.txt, etc.)
- Linting/formatting config files

### 1.4 Read Existing Plans (if any)

Check `tasks/` for existing epics and stories to give experts context on
what's planned vs. what's built.

### 1.5 Build Project Context Block

Compile everything into a structured context block injected into each
generated skill: project name, description, architecture type, components,
tech stack, key patterns, condensed folder tree, paths to architecture docs /
spec / task plans. For the exact shape, see
[references/examples.md#project-context-block-built-in-phase-15](references/examples.md#project-context-block-built-in-phase-15).

### 1.6 Research Current Best Practices (MANDATORY)

This step is **NOT optional**. Before generating ANY skill, research current
best practices for every detected technology. Full procedure lives in
[references/context7-research.md](references/context7-research.md).

Required steps:
1. Identify every language, framework, library, and tool from `tech-stack.md`
   and the codebase scan.
2. For each, resolve the library ID via context7 and fetch current docs
   (conventions, project structure, patterns, anti-patterns, performance,
   error handling, testing, version notes).
3. If context7 lacks coverage, supplement with WebSearch.
4. Compile results into a "Best Practices Knowledge" block — feeds both
   expert skills (for current advice) and guide skills (as their content).

---

## PHASE 2: DETERMINE WHICH SKILLS TO GENERATE

**Goal:** Create only the skills relevant to this project's tech stack.
Two categories of skills are generated: **Expert Roles** and **Language/Framework Guides**.

### 2.1 Expert Role Definitions

| Role | Slug | Generated When |
|------|------|----------------|
| Frontend Developer | `expert-frontend` | Project has a frontend component (React, Vue, mobile app, etc.) |
| Backend Developer | `expert-backend` | Project has a backend/server component |
| QA Tester | `expert-qa` | Always (every project needs testing) |
| Code Analyst | `expert-analyst` | Always (every project benefits from code analysis) |
| DevOps / Infrastructure | `expert-devops` | Project has deployment, CI/CD, Docker, cloud infra |
| Project Q&A | `expert-qa-project` | Always (answers questions about the project) |

One-line role focus (full templates live in `references/expert-templates.md`):
- `expert-frontend` — implements UI components, state management, client-side
  communication, and accessibility for the project's frontend stack.
- `expert-backend` — implements server logic, APIs, database operations, and
  inter-service communication for the project's backend stack.
- `expert-qa` — designs test strategies, writes automated tests, and validates
  acceptance criteria across components.
- `expert-analyst` — performs deep code review, architecture compliance checks,
  complexity and security analysis.
- `expert-devops` — owns build systems, CI/CD, containers, environment setup,
  and dev-experience tooling.
- `expert-qa-project` — answers any project question by reading code, docs,
  task plans, and git history.

### 2.2 Language/Framework Guide Definitions

One guide skill is generated per major language or framework detected. These
are reference skills containing current best practices, conventions, patterns,
and anti-patterns — sourced from the Phase 1.6 research.

| Guide | Slug | Generated When |
|-------|------|----------------|
| C++ Guide | `guide-cpp` | Project uses C++ |
| Rust Guide | `guide-rust` | Project uses Rust |
| TypeScript Guide | `guide-typescript` | Project uses TypeScript |
| React Native Guide | `guide-react-native` | Project uses React Native |
| Python Guide | `guide-python` | Project uses Python |
| Go Guide | `guide-go` | Project uses Go |
| Java/Kotlin Guide | `guide-java` | Project uses Java/Kotlin |
| Swift Guide | `guide-swift` | Project uses Swift/SwiftUI |
| [Framework] Guide | `guide-[framework]` | Per major framework (Axum, Next.js, Django, JUCE, etc.) |

**What counts as a "major" technology deserving its own guide:**
- CREATE guide for: languages (C++, Rust, TS, Python, Go), major frameworks
  (Axum, React Native, Next.js, Django, JUCE, Express), major protocols (gRPC, GraphQL).
- DO NOT create guide for: small utility libraries (uuid, lodash), build tools
  (CMake, Cargo), serialization formats (JSON, Protobuf), databases (SQLite) —
  these are covered within relevant expert skills and language guides.

### 2.3 Auto-Detection Logic

```
Frontend expert IF:
  - tech-stack.md mentions React, Vue, Angular, Svelte, React Native, Expo,
    Flutter, SwiftUI, or any frontend framework
  - components.md has a frontend/mobile/UI component
  - Folder structure has a frontend/, mobile/, web/, app/, or ui/ directory

Backend expert IF:
  - tech-stack.md mentions server-side tech (Rust, Go, Node.js, Python, Java, etc.)
  - components.md has a server/API/engine component
  - Folder structure has a server/, api/, backend/, or engine/ directory

DevOps expert IF:
  - Project has Dockerfile, docker-compose, CI config (.github/workflows, .gitlab-ci),
    Terraform, Kubernetes configs, or cloud deployment docs
  - dev-guide.md mentions deployment steps
  - If NONE of the above exist, still generate but mark as "lightweight"
    (focused on local dev setup, build scripts, and future CI planning)

Language/Framework guide IF:
  - Technology appears in tech-stack.md as a primary language or major framework
  - Technology has source files in the codebase OR is planned per architecture docs
```

### 2.4 Present Plan

Show the user a plan listing every skill to be generated (in MISSING-ONLY mode:
only the missing skills), the trigger reason for each, and the output paths, then
ask **Proceed? YES / NO / ADJUST**. If ADJUST, let the user add/remove or
customize. For the exact layout, see
[references/examples.md#plan-presentation-phase-24](references/examples.md#plan-presentation-phase-24).

---

## PHASE 3: GENERATE ALL SKILLS

**Goal:** Create each expert skill AND language/framework guide with
project-specific context, role-specific instructions, and researched best
practices.

### Check for Existing Skills

Phase 0 handles the full detection and user prompt. By the time Phase 3 runs,
the generation mode is already set:
- **ALL mode** (no existing skills, or user chose "Regenerate all"): generate every planned skill, overwriting any that exist.
- **MISSING-ONLY mode** (user chose "Generate missing only"): skip any skill whose output file already exists.
- **REGENERATE mode** (`--regenerate` flag): overwrite all existing skills unconditionally.

### 3.1 Generate: expert-frontend

For the frontend-expert template, see
[references/expert-templates.md#frontend-expert](references/expert-templates.md#frontend-expert).

### 3.2 Generate: expert-backend

For the backend-expert template, see
[references/expert-templates.md#backend-expert](references/expert-templates.md#backend-expert).

### 3.3 Generate: expert-qa

For the qa-expert template, see
[references/expert-templates.md#qa-expert](references/expert-templates.md#qa-expert).

### 3.4 Generate: expert-analyst

For the analyst-expert template, see
[references/expert-templates.md#analyst-expert](references/expert-templates.md#analyst-expert).

### 3.5 Generate: expert-devops

For the devops-expert template, see
[references/expert-templates.md#devops-expert](references/expert-templates.md#devops-expert).

### 3.6 Generate: expert-qa-project

For the qa-project-expert template, see
[references/expert-templates.md#qa-project-expert](references/expert-templates.md#qa-project-expert).

When emitting any expert skill: resolve every `[bracketed placeholder]` from
real project data, replace `[PROJECT CONTEXT BLOCK — injected from Phase 1.5]`
with the actual block, and inject relevant slices of the Phase 1.6
best-practices knowledge so advice is current and version-correct.

---

## PHASE 3b: GENERATE LANGUAGE/FRAMEWORK GUIDE SKILLS

**Goal:** Create one guide skill per major technology, filled with current
best practices from the Phase 1.6 research.

For the guide skill template and the full guide-generation rules (research
first, code examples required, project-specific content, version-aware,
`user-invocable: false`, cross-reference experts), see
[references/guide-templates.md](references/guide-templates.md).

When emitting any guide skill: every section's content MUST come from Phase
1.6 research (context7 or WebSearch), not generic knowledge — if a section
has no research data, run WebSearch to fill it before writing the file.
Resolve every `[bracketed placeholder]`, replace the project context block
with the real one, and set `user-invocable: false` in the frontmatter.

---

## PHASE 4: POST-GENERATION

### 4.1 Verify All Files

After generating, verify each skill file was created:

```bash
ls -la .claude/skills/experts/*/SKILL.md .claude/skills/guides/*/SKILL.md
```

### 4.2 Present Summary

Show a summary of every generated expert and guide (tech focus / version,
research source, sample invocation prompts), note that guides auto-load while
experts are invoked directly, and close with regeneration guidance: re-run
`/ck-code:team --regenerate` after architecture changes, framework upgrades,
or new tech additions. For the exact layout, see
[references/examples.md#post-generation-summary-phase-42](references/examples.md#post-generation-summary-phase-42).

---

## IMPORTANT GUIDELINES

- **Research is MANDATORY.** Phase 1.6 (context7/WebSearch research) MUST run
  before any skill generation. Never generate skills from stale or generic
  knowledge.
- **Project-specific content:** Each skill MUST contain real project details
  (tech stack, file paths, patterns), NOT generic placeholders. The
  `[PROJECT CONTEXT BLOCK]` must be fully resolved with actual project data.
- **No hardcoding in this skill:** This generator skill itself is
  project-agnostic. It reads the project context dynamically and injects it
  into the generated skills.
- **Tech stack adaptation:** Only generate skills relevant to the project. A
  pure backend CLI tool doesn't need a frontend expert or React guide.
- **Consistency:** All generated experts reference the same architecture docs
  and follow the same format for easy maintenance.
- **Updatable:** When `--regenerate` is used, completely replace the expert
  skill files with fresh versions. Don't try to merge — full replacement is
  safer.
- **Language:** All output in English.
