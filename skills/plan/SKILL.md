---
name: plan
description: Use to break a project specification or feature description into epics, stories, and a roadmap under `tasks/`. Argument is the path to the spec file.
argument-hint: "<path-to-spec-file>"
effort: high
---

# Project Architect — Specification to Epic/Story Planner

Transform a project specification document into a fully structured implementation plan
with epics, stories, dependencies, and a recommended roadmap.

**Supports two modes:**

- **New Project Mode:** Generate a full project plan from a specification
- **Feature Mode:** Generate scoped epics/stories for a new feature, aware of existing architecture

**Hand-off rules:**

- Requires `/ck-code:design` to have run first (architecture docs in `docs/architecture/`).
- Hands off to `/ck-code:build` (or `/ck-code:to-issues` then `/ck-code:build`) once the plan is generated.

## EFFORT SCALING

Higher effort adds **depth per story** — never more epics or stories. Fewer,
larger stories is the goal at every level: each story is one downstream `build`
session, so fewer stories means fewer tool invocations and lower token cost.

Adapt to the current effort level (**${CLAUDE_EFFORT}**):

- **low** — One epic; a handful of large, vertically-complete stories; minimal acceptance criteria.
- **medium** (default) — A few epics; each story is a complete feature slice with clear acceptance criteria and dependencies.
- **high / xhigh / max** — Same lean epic/story count; add detailed acceptance criteria, edge cases, test notes, a finer-grained `## Implementation Tasks` breakdown per story, and an explicit dependency graph in the roadmap. Do **not** split stories finer to spend the effort — add task and criteria depth instead.

## INPUT

The user provides a path to a specification file or feature description via `$ARGUMENTS`.

**If `$ARGUMENTS` is empty or the file does not exist:**

- Ask the user: "Please provide the path to your project specification file (e.g., `docs/specifications.md`)."
- Validate the file exists using Read before proceeding.
- If the file is empty or trivially short (< 50 words), warn the user and ask if they want to continue.

---

## MODE DETECTION

**Goal:** Determine whether this is a new project or a feature addition.

### Detection Steps

1. Check if `docs/architecture/` exists with architecture docs
2. Check if `tasks/` directory exists with prior generated plans
3. Check the codebase for existing source files

### Decision Logic

```
IF docs/architecture/ exists OR tasks/ has prior plans:
  → FEATURE MODE (adding to an existing project)
ELSE:
  → NEW PROJECT MODE (planning from scratch)
```

### Feature Mode Activation

In Feature Mode, present three options to the user (A / B / C):

- **A) ADD FEATURE** — Plan epics/stories for a new feature; read existing architecture and prior plans as context.
- **B) FULL PROJECT PLAN** — Replan the entire project from scratch (new dated folder, existing plans untouched).
- **C) CONTINUE EXISTING PLAN** — Add more epics/stories to a prior plan (user picks which `tasks/` folder to extend).

**If A (ADD FEATURE):**

1. Read ALL `docs/architecture/*.md` files for architectural context.
2. Read `$ARGUMENTS` spec/feature file.
3. Scan existing `tasks/` folders to understand what's already planned (avoid duplicating stories).
4. Ask: "What new feature do you want to plan?" (if not clear from the file).
5. Proceed to Phase 1 with feature-scoped analysis.

**If B (FULL PROJECT PLAN):**

1. Proceed as New Project Mode (new dated folder, no conflict).

**If C (CONTINUE EXISTING PLAN):**

1. List existing `tasks/*/` folders, ask user to pick one.
2. Read that plan's existing epics and stories.
3. Ask: "What additional scope do you want to add?"
4. Generate new epics/stories that continue the numbering from the existing plan
   (e.g., if the last epic was 04, new ones start at 05).
5. Write new files into the SAME folder structure.
6. Update `ROADMAP.md` to include the new epics.

---

## PHASE 1: DEEP ANALYSIS

**Goal:** Build a comprehensive mental model of the project before generating any output.

### 1.1 Read the Specification

Read the entire specification file provided in `$ARGUMENTS` using the Read tool.

### 1.1b (Feature/Continue Mode) Read Existing Context

Before extracting dimensions:

1. **Read all architecture docs** in `docs/architecture/` — current system architecture, components, tech stack, APIs, folder structure.
2. **Scan existing plans** in `tasks/` — read `ROADMAP.md` and `EPIC.md` files to understand what's already planned and what numbering to continue from.
3. **Scan the actual codebase** — use Glob to check which planned components already exist as source files. This tells you what's built vs. what's only planned.

This context prevents: duplicating existing stories, planning already-implemented work, creating epics that conflict with the existing architecture, or proposing folder structures that contradict what's already in place.

### 1.2 Extract Core Dimensions

Use extended thinking (ultrathink) to reason through ambiguities. Extract:

- **PROJECT IDENTITY** — name (slug: lowercase, hyphens, no spaces), one-line description, problem solved, target users.
- **ARCHITECTURE** — system architecture (monolith, microservices, client-server, etc.), major components/sub-systems, data flow, external integrations.
- **TECH STACK** — languages/frameworks/runtimes per component, build tools, package managers, databases, message queues, protocols, deployment targets.
- **FEATURES & REQUIREMENTS** — functional (explicit and implied), non-functional (performance, security, latency), user-facing vs. infrastructure, API surface (REST, WebSocket, gRPC, etc.).
- **PHASES / ROADMAP** (if specified) — phased rollout, MVP vs. future scope, priority indicators.

### 1.3 Research Tech Stack (when beneficial)

If the spec references frameworks/libraries/protocols that would benefit from current documentation lookup, use context7 (MCP tools if available, else the `ctx7` CLI via `npx -y @upstash/context7`) or WebSearch to confirm current best practices, identify version-specific considerations, and understand standard project structures. Only do this for unfamiliar or rapidly-evolving technologies.

### 1.4 Identify Dependencies & Complexity

Map out:

- Which components depend on which (build order)
- Shared artifacts (proto files, shared types, config schemas)
- Integration points requiring multiple components working together
- High-risk / high-complexity areas

---

## PHASE 2: EPIC & STORY STRUCTURING

**Goal:** Organize the analysis into a clean epic/story hierarchy.

### 2.1 Define Epics

**Minimize epics.** Create the fewest epics that still separate genuinely
distinct deliverables. Group related functionality under one epic instead of
spawning many small ones. Only open a new epic when the work ships as a separate
milestone or has a hard dependency boundary; aim for 1–4 epics on a typical plan.

Each epic should:

- Represent a coherent, deliverable chunk of work
- Be numbered sequentially (`01`, `02`, `03`, ...)
- Have a short, descriptive slug (e.g., `foundation-server`, `midi-arranger`, `mobile-ui`)
- Map roughly to a milestone or phase

**(Feature Mode) Numbering:**

- **Continue Mode:** continue numbering from the last epic in the existing plan (e.g., last was 04 → new ones start at 05).
- **Add Feature Mode:** start at `01` within the new dated folder. Prefix the folder slug with `feature-` (e.g., `tasks/YYYY-MM-DD_feature-<feature-name>/`).

**(Feature Mode) Cross-references:**

- When stories depend on components from the existing plan or codebase, reference them explicitly — e.g., `Depends on: existing server/src/ws/handlers.rs (already implemented)` or `Depends on: Epic 02 Story 03 from tasks/2026-04-01_project-name/`.

**Epic ordering principles:**

- Infrastructure and foundation epics come first
- Epics with no dependencies on other epics come before those that depend on them
- If the spec defines phases, respect that ordering
- Within a phase: shared/core code first, then feature code, then integration

### 2.2 Define Stories Within Each Epic

**Favor fewer, larger stories.** A story should deliver a complete, coherent
slice of functionality — a full feature or component, not a single file edit.
One story = one downstream `build` session, so combining related work into one
story directly cuts tool calls and token cost. Size up and combine by default.

Each story must still:

- Cover one cohesive concern (a feature, a component, a vertical slice) — never mix unrelated concerns into one story.
- Be numbered sequentially within its epic (`01`, `02`, ...) with a short descriptive slug.
- Carry clear, testable acceptance criteria and an explicit files-to-touch list so `build` can execute it in one focused session.

**Story sizing rubric:**

- **L (default target):** A full feature or component — multiple files, real logic or integration. Aim for this size.
- **XL:** A large but tightly-coupled deliverable (e.g., a complete subsystem). Keep it as one story when splitting would gain nothing.
- **M:** Only when a piece of work is genuinely small, self-contained, and cannot be folded into a related L story.
- **S:** Avoid as a standalone story. Fold small changes (a config file, a type definition) into the story that consumes them.

**Split a story ONLY when** one of these holds — otherwise keep it as a single story:

- The pieces are independent and can be implemented in parallel by different agents/people, or
- There is a hard dependency boundary (one part must merge and stabilize before the next can start), or
- The concerns are genuinely unrelated.

### 2.2b Consolidation Pass

Before presenting the plan, review the draft story list and merge wherever the split is not justified by the rule above:

- Stories that touch the same files or the same component/layer → merge into one.
- A chain of stories that can only run sequentially with no parallelization or dependency-boundary benefit → merge into one.
- Standalone S stories → fold into the related story that consumes them.
- An epic left with a single story → fold the story upward and drop the epic, unless that epic marks a distinct milestone.

Target the smallest epic/story count that still yields clear, independently-verifiable deliverables.

### 2.2c Break Each Story into Tasks

Fewer, larger stories stay precise only when each one carries an explicit,
ordered task list. For every story, decompose the work into concrete
step-by-step **implementation tasks** — each task is one verifiable action that
moves the story toward its acceptance criteria (e.g. "define the `X` interface",
"implement `Y` against it", "wire `Y` into the handler"). These tasks populate
the story file's `## Implementation Tasks` section.

Rules:

- Tasks are **story-specific**, not generic TDD phases — never write "write tests / implement / refactor / QA" as the task list; that is build's runtime concern.
- Order tasks so each one builds on the previous; the final task completes the last acceptance criterion.
- Keep tasks at the right altitude: a handful of meaningful steps, not one line per file edit. If a story needs more than ~8 tasks, it is probably two stories.
- Every acceptance criterion must be reachable by following the task list end to end.

### 2.3 Map Story Dependencies

For each story, identify:

- Which other stories must be completed first (blockers)
- Which stories can run in parallel
- Cross-epic dependencies

---

## PHASE 3: PRESENT PLAN FOR CONFIRMATION

**Goal:** Show the user the planned structure before writing any files.

Present a summary using the format in [references/roadmap-format.md#phase-3-plan-confirmation-format](references/roadmap-format.md#phase-3-plan-confirmation-format).

**Wait for explicit user confirmation before proceeding to Phase 4.**

If the user says ADJUST, ask what they want to change and loop back to Phase 2.

---

## PHASE 4: GENERATE OUTPUT FILES

**Goal:** Create the full folder structure with detailed content.

### 4.1 Create Directory Structure

Use today's date for `YYYY-MM-DD` (ISO 8601).

- **New Project Mode:** see [references/examples.md#new-project-mode--tasks-folder-layout](references/examples.md#new-project-mode--tasks-folder-layout).
- **Feature Mode — Add Feature:** see [references/examples.md#feature-mode--add-feature-folder-layout](references/examples.md#feature-mode--add-feature-folder-layout). `FEATURE_OVERVIEW.md` replaces `PROJECT_OVERVIEW.md` and includes feature description/motivation, affected existing components, new components introduced, and integration points with the existing system.
- **Feature Mode — Continue:** see [references/examples.md#feature-mode--continue-existing-plan-layout](references/examples.md#feature-mode--continue-existing-plan-layout).

### 4.2 PROJECT_OVERVIEW.md Content

For the project overview template (and the `FEATURE_OVERVIEW.md` variant for Add Feature mode), see [references/templates.md#project-overview-template](references/templates.md#project-overview-template).

### 4.3 EPIC.md Content (per epic)

For the epic template, see [references/templates.md#epic-template](references/templates.md#epic-template).

### 4.4 Story File Content (per story)

For the story file template, see [references/templates.md#story-template](references/templates.md#story-template).

### 4.5 STORIES_INDEX.md Content

After all story files are written, generate `tasks/<slug>/STORIES_INDEX.md` from the in-memory list of stories you just authored. Format and mutation protocol: see [`ck-code/references/stories-index.md`](../../../references/stories-index.md). Template: [references/templates.md#stories-index-template](references/templates.md#stories-index-template).

This index is the single source of truth that downstream skills (`build`, `parallel-build`, `track`) read to find ready stories — they will NOT scan individual story files for status. Every row must be present and correctly populated here.

**Continue Mode:** read the existing `STORIES_INDEX.md`, insert new rows for the appended stories in `ID` order, then write the merged file. Do not regenerate from scratch — preserve any current `Status` values for unchanged rows.

### 4.5b FEATURE_INDEX.md Content (top-level, one row per epic)

After the story index is written, update the project-wide `tasks/FEATURE_INDEX.md` — the top-level rollup that `build`/`parallel-build` read FIRST to pick a feature before opening any story index. Format and mutation protocol: see [`ck-code/references/feature-index.md`](../../../references/feature-index.md).

Add one row per NEW epic from this plan: `Feature` = `NN · Display Name`, `Plan` = this plan's `tasks/<slug>` folder name, `Status` = `TODO`, `Stories` = `0/<story count>`, `Description` = the epic's one-line Goal from its `EPIC.md`. If `tasks/FEATURE_INDEX.md` does not exist yet, create it first (schema-v1 header). Continue/Add-Feature mode: insert the new epic rows and leave all existing rows untouched.

### 4.6 ROADMAP.md Content

For the roadmap template, see [references/roadmap-format.md#roadmapmd-template](references/roadmap-format.md#roadmapmd-template).

---

## PHASE 5: SUMMARY

After all files are created, present a summary tailored to the mode. For each summary template:

- **New Project Mode:** see [references/roadmap-format.md#new-project-mode-summary](references/roadmap-format.md#new-project-mode-summary).
- **Feature Mode — Add Feature:** see [references/roadmap-format.md#feature-mode--add-feature-summary](references/roadmap-format.md#feature-mode--add-feature-summary).
- **Feature Mode — Continue Existing Plan:** see [references/roadmap-format.md#feature-mode--continue-existing-plan-summary](references/roadmap-format.md#feature-mode--continue-existing-plan-summary).

## NEXT

Run `/ck-code:to-issues` to push the epics and stories to GitHub Issues, **or** skip publishing and run `/ck-code:track next` to find the first story to implement.

---

## IMPORTANT GUIDELINES

- **Language:** All output must be in English, regardless of the specification language.
- **No hardcoding:** Never reference specific project names, technologies, or paths in the skill logic. Derive everything from the spec.
- **Thoroughness:** Every functional requirement in the spec must be covered by at least one story; related requirements may share a single story. If a requirement is vague, cover it with a note about needed clarification.
- **Scanning readability:** Use tables, bullet points, and headers. Avoid walls of text.
- **Consolidation-first sizing:** When in doubt, combine. Fewer, larger stories beat many small ones — each story is one `build` session, so fewer stories means fewer tool calls and lower token cost. Never split for the sake of granularity.
- **Precision via tasks, not splitting:** Recover the precision a large story might lose by giving it an ordered `## Implementation Tasks` list (Phase 2.2c) — never by breaking it into more, smaller stories.
- **Preserve spec language:** When the spec uses specific technical terms, preserve them in story titles and descriptions.
- **Date format:** Always use ISO 8601 (`YYYY-MM-DD`) for the folder name.
- **Reusability:** This skill must work with any project specification, not just the current project.
