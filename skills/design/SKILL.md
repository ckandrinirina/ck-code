---
name: design
description: >
  Use when you have a project specification file and need to generate architecture
  documentation (folder structure, components, APIs, database schema, tech stack).
  Fills specification gaps through targeted questions. Works for new projects and
  for adding new features to existing projects. Never modifies the original spec.
  First step in the ck-code workflow — runs before /ck-code:plan.
argument-hint: "[path-to-spec-file]"
---

# Spec Designer — Specification Refiner & Architecture Documenter

Read a project specification, identify gaps through conversational questioning,
and generate a complete set of split architecture documentation ready for development.

**Supports two modes:**
- **New Project Mode:** Generate full architecture docs from a project spec
- **Feature Mode:** Extend existing architecture docs with new feature documentation

This skill never modifies the original specification file. It reads it as the source
of truth and produces refined documentation in `docs/architecture/`.

---

## INPUT

Spec file path comes from `$ARGUMENTS`.

**If empty:** look for `docs/specifications.md`, `docs/spec.md`, `SPEC.md`, `docs/requirements.md`. If found, confirm with user. If not, ask whether to (A) provide a path or (B) start from scratch and be guided through creation.

**If the file does not exist:** tell the user and ask for the correct path.

---

## MODE DETECTION

**Goal:** Determine whether this is a new project or a feature addition.

### Detection Steps

1. Check if `docs/architecture/` already exists (Glob)
2. Check if `tasks/` directory exists with prior epics
3. Check the codebase for existing source files beyond just docs

### Decision Logic

```
IF docs/architecture/ exists AND has files:
  → FEATURE MODE (extending an existing project)
ELSE:
  → NEW PROJECT MODE (generating from scratch)
```

### Feature Mode Activation

When in Feature Mode, present the user with the existing-project prompt (A/B/C
options) and follow its branching logic. For the exact wording, options, and
branch handling see [references/qna-examples.md](references/qna-examples.md).

Branch summary:
- **A (ADD FEATURE):** read all existing `docs/architecture/*.md`, read spec,
  ask "What new feature or capability do you want to add?", proceed to Phase 1
  with feature-scoped analysis.
- **B (FULL REFRESH):** back up existing docs to
  `docs/architecture/backup_YYYY-MM-DD/`, proceed as New Project Mode.
- **C:** proceed as New Project Mode.

---

## PHASE 1: READ & ASSESS THE SPECIFICATION

**Goal:** Understand what the spec covers and identify what's missing or vague.

### 1.1 Read the Specification

Read the entire file using the Read tool. If the spec is in a non-English language,
process it in its original language but produce all output in English.

### 1.1b (Feature Mode) Read Existing Architecture Context

If in Feature Mode, BEFORE assessing coverage:
1. Read ALL files in `docs/architecture/` to understand the current state
2. Read existing source code structure using Glob
3. Build a mental model of: what exists, what the new feature needs to integrate with

This context is critical — new feature docs must be consistent with existing architecture.

### 1.2 Assess Coverage

Score each of these 12 dimensions as CLEAR / PARTIAL / MISSING:

Project vision & goals · Target users · System architecture · Folder structure · Tech stack & versions · Component breakdown · Data flow · API contracts · Database schema · Configuration · Build & run instructions · Non-functional requirements

### 1.3 Present Assessment

Show the user the coverage table and ask whether to start Q&A or SKIP. For the
exact presentation block, see [references/qna-examples.md](references/qna-examples.md).

If the user says SKIP, jump directly to Phase 3 and generate docs using only what's
available, marking gaps with `[TO BE DEFINED]`.

---

## PHASE 2: CONVERSATIONAL REFINEMENT

**Goal:** Fill gaps and clarify ambiguities through adaptive questioning.

### Questioning Strategy

- Ask **2-3 questions per round** maximum
- Start with the highest-impact MISSING dimensions first
- For PARTIAL dimensions, ask targeted questions about the vague parts
- Adapt follow-up questions based on previous answers
- For CLEAR dimensions, do not re-ask — briefly confirm and reuse

### Question Sets

- **Feature Mode:** use the feature-scoped question set (Scope & Integration,
  Architecture, Boundaries). After answers, map impact to docs (new endpoints →
  api-contracts.md, new tables → database-schema.md, etc.).
- **New Project Mode:** use the priority-ordered question bank covering
  Architecture & Components → Tech Stack → Data Flow & APIs → Database & State →
  Configuration → Build & Run → Non-Functional Requirements.

For the full wording of every question and the confirmation phrasing for CLEAR
and PARTIAL dimensions, see [references/qna-examples.md](references/qna-examples.md).

### Research During Refinement

When the user mentions specific technologies, use context7 (MCP tools if
available, else the `ctx7` CLI via `npx -y @upstash/context7`) or WebSearch to:
- Look up current best practices for project structure
- Verify standard folder conventions for the frameworks mentioned
- Check for recommended configuration patterns

### Refinement Loop

After each round of questions:
1. Summarize what was learned
2. Check if remaining gaps exist
3. If yes, ask the next round
4. If all dimensions are CLEAR or user says "enough", move to Phase 3

Maximum **5 rounds**. If gaps remain after 5 rounds, proceed to generation and
mark remaining gaps with `[TO BE DEFINED]`.

---

## PHASE 3: GENERATE ARCHITECTURE DOCUMENTATION

**Goal:** Create or update the split documentation files in `docs/architecture/`.

### 3.1 Confirm Before Writing

Present a pre-generation confirmation block (different content for New Project
Mode vs. Feature Mode) and wait for YES / NO / ADJUST. For the exact blocks see
[references/qna-examples.md](references/qna-examples.md).

### 3.2 Create Directory

```bash
mkdir -p docs/architecture
```

### (Feature Mode) Update Strategy

When updating existing architecture docs:

1. **Never delete or overwrite existing content.** Only add or extend.
2. **Files needing new sections** (e.g., new component in components.md): Read
   the existing file, append the new section at the appropriate location, use
   the Edit tool (not Write) to insert content.
3. **Files needing extended sections** (e.g., new endpoint in api-contracts.md):
   Read the file, find the relevant section, add new content under the existing
   structure.
4. **README.md index:** if new files were created, add them to the index table
   and append a `## Changelog` entry. For the changelog format see
   [references/qna-examples.md](references/qna-examples.md).
5. **Feature-specific file** when the feature is large enough:
   `docs/architecture/features/YYYY-MM-DD_<feature-slug>.md`. Cross-reference
   it from the updated main docs.

### 3.3 – 3.12 Generate Each Architecture Document

Generate the following files in `docs/architecture/`. The exact template for
each file (markdown structure, tables, sections, placeholders) lives in
[references/architecture-templates.md](references/architecture-templates.md).
Use those templates verbatim, filling placeholders with project-specific
content derived from the spec and user answers.

| Step | File | Template section |
|------|------|------------------|
| 3.3 | `README.md` (index) | README.md (Index) |
| 3.4 | `overview.md` | overview.md |
| 3.5 | `folder-structure.md` | folder-structure.md |
| 3.6 | `tech-stack.md` | tech-stack.md |
| 3.7 | `components.md` | components.md |
| 3.8 | `data-flow.md` | data-flow.md |
| 3.9 | `api-contracts.md` | api-contracts.md |
| 3.10 | `database-schema.md` | database-schema.md |
| 3.11 | `configuration.md` | configuration.md |
| 3.12 | `dev-guide.md` | dev-guide.md |

**folder-structure.md note:** if the original spec already defines a folder
structure, use it as the base and refine/expand. Otherwise, propose one based
on the tech stack and best practices (research via context7/WebSearch if needed).

---

## PHASE 4: SUMMARY

After all files are written (or updated), present a final summary block. The
content differs between New Project Mode (table of created files, gaps
remaining, next steps) and Feature Mode (table of UPDATED/CREATED/UNCHANGED
files, impact summary, next steps).

For the exact summary blocks, see
[references/qna-examples.md](references/qna-examples.md).

In both modes, the final next step is: run `/ck-code:plan` to generate epics
and stories.

---

## CONDITIONAL FILE GENERATION

Not all files are relevant to every project. Skip files that don't apply:

- **database-schema.md** — Skip if the project has no database
- **api-contracts.md** — Skip if there are no APIs (e.g., a CLI tool)
- **configuration.md** — Skip if the project has no configuration files

When skipping a file, still list it in `README.md` with a note: "Not applicable for this project."

---

## IMPORTANT GUIDELINES

- **Never modify the original specification file.** It is read-only input.
- **Language:** All output in English, regardless of the spec's language.
- **No hardcoding:** Derive everything from the spec and user answers. This skill must work with any project.
- **Use context7/WebSearch** to research standard folder structures and best practices for the specific tech stack.
- **Be specific:** Every file should contain real, project-specific content derived from the spec and user answers — not generic prose.
- **Mark gaps:** Use `[TO BE DEFINED]` for anything that couldn't be determined. Never invent information.
- **Scanning readability:** Use tables, code blocks, ASCII diagrams, and bullet points. Avoid walls of text.
- **File independence:** Each file should be self-contained, with cross-references where relevant.
