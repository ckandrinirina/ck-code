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

## ROUTING CHECK (do first)

This skill breaks a spec into a **full epic/story plan**.
If the request is actually something else, STOP and recommend the better skill:

- One small addition to an existing plan → `/ck-code:quick-story`
- No architecture docs yet → `/ck-code:design` (first)
- A stakeholder-facing spec, not a task breakdown → `/ck-code:pre-spec`

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:to-issues` *(optional)* or `/ck-code:track next`.

**Reuse-first:** plan from the design docs and existing `tasks/` — reuse settled architecture
instead of re-deriving it, and pick the simplest viable epic/story structure. See
[`reuse-first.md`](../../references/reuse-first.md).

## EFFORT SCALING

**Effort** controls **depth per story** — how much detail each story carries. It
never changes how many stories exist and it never changes story **size**: every
story is always sized to a single agent dispatch (Phase 2.2). Higher effort adds
depth per story, not larger or fewer stories. Adapt to the current effort level
(**${CLAUDE_EFFORT}**):

- **low** — Minimal acceptance criteria; terse technical notes.
- **medium** (default) — Each story is a complete feature slice with clear acceptance criteria and dependencies.
- **high / xhigh / max** — Add detailed acceptance criteria, edge cases, test notes, a finer-grained `## Implementation Tasks` breakdown per story, and an explicit dependency graph in the roadmap. Do **not** make stories larger to spend the effort — add task and criteria depth instead.

## INPUT

The user provides a path to a specification file or feature description via `$ARGUMENTS`.

**If `$ARGUMENTS` is empty or the file does not exist:**

- Ask the user: "Please provide the path to your project specification file (e.g., `docs/specifications.md`)."
- Validate the file exists using Read before proceeding.
- If the file is empty or trivially short (< 50 words), warn the user and ask if they want to continue.

---

## PHASE 0: VERSION GATE (hard gate)

Before reading/writing any `docs/architecture/` doc or `tasks/FEATURE_INDEX.md`, run the shared [version gate](../../references/version-gate.md); on BLOCK (pre-v3), offer `/ck-code:doc-optimizer upgrade` and stop until it PASSes (or the user declines). Fast path: `tasks/VERSION.md` = `layout: v3`.

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

1. Read the **global** architecture docs (`overview.md`, `tech-stack.md`,
   `folder-structure.md`, `_shared.md`) + the `README.md` index for architectural
   context. Do NOT read every feature doc — the README index lists each feature with a
   one-line summary; open a full `features/<slug>/index.md` only for a feature the new
   work directly integrates with.
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

1. **Read the global architecture docs + feature index** — `overview.md`, `tech-stack.md`, `folder-structure.md`, `_shared.md`, and the `README.md` index (which lists every feature with a one-line summary). Open a full `features/<slug>/index.md` only for a feature the new work directly integrates with — not the whole set.
2. **Scan existing plans** in `tasks/` — read `ROADMAP.md` and `EPIC.md` files to understand what's already planned and what numbering to continue from.
3. **Scan the actual codebase** — use Glob to check which planned components already exist as source files. This tells you what's built vs. what's only planned.

This context prevents: duplicating existing stories, planning already-implemented work, creating epics that conflict with the existing architecture, or proposing folder structures that contradict what's already in place.

### 1.1c Read the Design Ledger (both modes)

Read `docs/architecture/DESIGN_LEDGER.md` (format: [`architecture-templates.md`](../design/references/architecture-templates.md#design_ledgermd-design--plan-bridge)).
Its **`pending` rows are the design additions that have been designed but not yet planned** —
the authoritative work-to-plan list, so you don't diff feature docs to find what's new.
Each `pending` row's `Slug` points to the feature doc to plan from. Plan those features in
this run; in Phase 4.5c you will flip their rows to `planned`. If the ledger is missing
(older v3 project, or design hasn't run), fall back to the feature index / spec as before.

### 1.2 Extract Core Dimensions

Use extended thinking (ultrathink) to reason through **genuine** ambiguities only — where the
spec or `docs/architecture/` already answers something, reuse that answer rather than
re-deriving it. Extract:

- **PROJECT IDENTITY** — name (slug: lowercase, hyphens, no spaces), one-line description, problem solved, target users.
- **ARCHITECTURE** — system architecture (monolith, microservices, client-server, etc.), major components/sub-systems, data flow, external integrations.
- **TECH STACK** — languages/frameworks/runtimes per component, build tools, package managers, databases, message queues, protocols, deployment targets.
- **FEATURES & REQUIREMENTS** — functional (explicit and implied), non-functional (performance, security, latency), user-facing vs. infrastructure, API surface (REST, WebSocket, gRPC, etc.).
- **PHASES / ROADMAP** (if specified) — phased rollout, MVP vs. future scope, priority indicators.

### 1.2b (Optional) Parallel domain analysis (fan-out — large multi-component specs)

If 1.2 surfaced **≥4 genuinely independent components** and the spec is large, dispatch one
**read-only** `general-purpose` Agent per component following the investigation variant in
[../../references/subagent-fanout.md](../../references/subagent-fanout.md). Each returns an
analysis brief (its features, requirements, tech stack, intra-domain deps) — no writes to
`tasks/`. Fix PROJECT IDENTITY (1.2) before dispatch so slugs stay consistent, then merge the
briefs here and do **all** cross-domain dependency mapping yourself in 1.4 (subagents see only
their slice and would miss integration points). Skip when components are few, tightly coupled, or
the spec is small — Phase 2 structuring and Phase 4 writes always stay sequential.

### 1.3 Research Tech Stack (when beneficial)

If the spec references frameworks/libraries/protocols that would benefit from current documentation lookup, use context7 (MCP, else `npx -y @upstash/context7` CLI) or WebSearch to confirm current best practices, identify version-specific considerations, and understand standard project structures. Only do this for unfamiliar or rapidly-evolving technologies.

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

Open a new epic only for a **distinct milestone or a hard dependency boundary** —
aim for the fewest epics that cleanly separate deliverables. Group cohesive work
that shares a milestone under one epic. Never create an epic that marks neither a
distinct milestone nor a dependency boundary — fold such work into an existing epic.

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
- The plan's **last** epic is always the mandatory Integration & E2E epic (Phase 2.4)

### 2.2 Define Stories Within Each Epic

**One story = one agent dispatch.** Every story must be small enough that a single
`build` session — or one `parallel-build` sub-agent — can implement it end-to-end
(red → green → refactor → QA → commit) without exhausting its tool-call/token
budget. A dispatched agent **cannot be resumed**, so an oversized story stalls
mid-build (the `◐ incomplete` outcome in `parallel-build`) and forces a costly
continue-in-place recovery pass. Sizing every story to one dispatch is what keeps
the plan buildable solo and in parallel.

Each story must:

- Cover exactly one cohesive concern (a feature, a component, a vertical slice) — never mix unrelated concerns into one story.
- Be sized **S or M only** — a self-contained concern a single dispatch finishes comfortably. Never plan an **L** or **XL** story.
- Be numbered sequentially within its epic (`01`, `02`, ...) with a short descriptive slug.
- Carry clear, testable acceptance criteria and an explicit files-to-touch list so `build` can execute it in one focused session.

**Story sizing rubric** (target: every story S or M, single-dispatch):

- **M:** A self-contained concern — one feature, one component, or one vertical slice with real logic. The default target.
- **S:** A small, focused change. Fold a trivial S (a lone config or type file) into the M story that consumes it rather than leaving it standalone.
- **L / XL:** Never plan one — they overflow a single dispatch. Split the work at a natural seam (interface vs. implementation, per-endpoint, per-component) **even when the parts are coupled**, and order the pieces with `Blocked by` dependencies. The split pieces stay coherent through their shared epic and dependency graph, and `## Implementation Tasks` (Phase 2.2c) carries the precision a single larger story would have held.

**Always split a story** when it would exceed one dispatch, **or** when one of these holds:

- The pieces are independent and can be built in parallel by different agents/people, or
- There is a hard dependency boundary (one part must merge and stabilize before the next can start), or
- The concerns are genuinely unrelated.

### 2.2b Consolidation Pass

Before presenting the plan, review the draft story list and merge only genuine
redundancy — **never merge to the point a story would exceed one dispatch** (Phase 2.2):

- Standalone **S** stories → fold into the related story that consumes them.
- Two stories that are truly the same concern on the same files → merge **only if the result still fits one dispatch**; otherwise keep them split.
- An epic left with a single story → fold the story upward and drop the epic, unless that epic marks a distinct milestone or dependency boundary.

Never combine stories just to reduce the count: a smaller plan that yields an
oversized, unbuildable story is worse than more single-dispatch stories.

### 2.2c Break Each Story into Tasks

A story stays precise only when it carries an explicit, ordered task list. For
every story, decompose the work into concrete
step-by-step **implementation tasks** — each task is one verifiable action that
moves the story toward its acceptance criteria (e.g. "define the `X` interface",
"implement `Y` against it", "wire `Y` into the handler"). These tasks populate
the story file's `## Implementation Tasks` section.

Rules:

- Tasks are **story-specific**, not generic TDD phases — never write "write tests / implement / refactor / QA" as the task list; that is build's runtime concern.
- Order tasks so each one builds on the previous; the final task completes the last acceptance criterion.
- Keep tasks at the right altitude: a handful of meaningful steps, not one line per file edit. **If a story needs more than ~8 tasks, it is too big for one dispatch — split it** (Phase 2.2). The task count is the practical size guardrail.
- Every acceptance criterion must be reachable by following the task list end to end.

### 2.3 Map Story Dependencies

For each story, identify:

- Which other stories must be completed first (blockers)
- Which stories can run in parallel
- Cross-epic dependencies

### 2.4 Mandatory Final Integration & E2E Epic

**Every plan run ends with a dedicated final epic that validates the whole feature (or
project) end-to-end** — no plan is complete without it. Individual feature stories prove
their own slice; this epic proves the slices work together through real entry points.

Add it as the **last** epic (highest number), regardless of mode:

- **New Project Mode:** the final epic covers the whole project end-to-end.
- **Feature / Add Feature Mode:** the final epic covers the whole feature end-to-end,
  including its integration points with the existing system (from `FEATURE_OVERVIEW.md`).
- **Continue Mode:** add a new final Integration & E2E epic for the appended scope only;
  do not touch the prior plan's existing epics.

Rules for this epic:

- Title/slug it `integration-e2e` (e.g. `NN_integration-e2e`); Goal states what end-to-end
  behavior it proves.
- **`Blocked by` every prior epic** in this plan — it runs only after the pieces exist, so
  it is always last in the roadmap and never a `parallel-build` candidate alongside the work
  it verifies.
- Its stories **exercise real user journeys / flows through actual entry points** (API,
  CLI, UI, message bus — whatever the spec defines), asserting cross-component behavior and
  the integration seams identified in Phase 1.4. Not more unit tests.
- **Each E2E story is still S or M, one dispatch** (Phase 2.2). When full coverage exceeds
  one dispatch, split by user-journey / flow (happy-path, error/edge, each major
  integration point) into multiple stories under this epic — never one oversized E2E story.
- Give each story an ordered `## Implementation Tasks` list like any other (Phase 2.2c):
  set up fixtures/environment → drive the flow → assert observable outcomes.

Do not fold this coverage into a feature epic and do not skip it because "the stories
already have tests" — those are per-slice; this epic is the whole-feature guarantee.

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

After all story files are written, generate `tasks/<slug>/STORIES_INDEX.md` from the in-memory list of stories you just authored. Format and mutation protocol: see [`ck-code/references/stories-index.md`](../../references/stories-index.md). Template: [references/templates.md#stories-index-template](references/templates.md#stories-index-template).

This index is the single source of truth that downstream skills (`build`, `parallel-build`, `track`) read to find ready stories — they will NOT scan individual story files for status. Every row must be present and correctly populated here.

**Continue Mode:** read the existing `STORIES_INDEX.md`, insert new rows for the appended stories in `ID` order, then write the merged file. Do not regenerate from scratch — preserve any current `Status` values for unchanged rows.

### 4.5b FEATURE_INDEX.md Content (top-level, one row per epic)

After the story index is written, update the project-wide `tasks/FEATURE_INDEX.md` — the top-level rollup that `build`/`parallel-build` read FIRST to pick a feature before opening any story index. Format and mutation protocol: see [`ck-code/references/feature-index.md`](../../references/feature-index.md).

Add one row per NEW epic from this plan: `Feature` = `NN · Display Name`, `Plan` = this plan's `tasks/<slug>` folder name, `Status` = `TODO`, `Stories` = `0/<story count>`, `Docs` = `docs/architecture/features/<slug>/index.md` if that feature doc exists (it usually does when `design` ran first, matching the epic slug) else `—`, `Description` = the epic's one-line Goal from its `EPIC.md`. If `tasks/FEATURE_INDEX.md` does not exist yet, create it first (schema-v2 header with the `Docs` column). The index is always schema v2 here — the version gate (Phase 0) guarantees it. Continue/Add-Feature mode: insert the new epic rows and leave all existing rows untouched. Any feature left `—` should be scaffolded with `/ck-code:doc-optimizer sync`.

### 4.5c DESIGN_LEDGER.md Update (flip pending → planned)

For each feature this plan now covers, update its row in `docs/architecture/DESIGN_LEDGER.md`
(format: [`architecture-templates.md`](../design/references/architecture-templates.md#design_ledgermd-design--plan-bridge)):
set `Planned?` from `pending` to `planned` and fill `Plan ref` with this plan's
`tasks/<slug>` folder (or the specific `NN_slug` epic). Match rows by `Slug`. Leave rows
for features not planned in this run untouched. Skip silently if the ledger does not exist.
This is what makes "what still needs planning?" a cheap ledger lookup for the next run.

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

Because every story is sized to a single dispatch, an epic with independent stories is a natural fit for `/ck-code:parallel-build` — it builds them concurrently across agents, each finishing its story in one pass.

---

## IMPORTANT GUIDELINES

- **Language:** All output must be in English, regardless of the specification language.
- **No hardcoding:** Never reference specific project names, technologies, or paths in the skill logic. Derive everything from the spec.
- **Thoroughness:** Every functional requirement in the spec must be covered by at least one story; related requirements may share a single story. If a requirement is vague, cover it with a note about needed clarification.
- **Mandatory final Integration & E2E epic:** every plan run ends with a dedicated final epic (Phase 2.4) that proves the whole feature/project works end-to-end through real entry points, `Blocked by` all prior epics. Never skip it and never fold it into a feature epic — its stories stay sized to one dispatch, split by user-journey when needed.
- **Scanning readability:** Use tables, bullet points, and headers. Avoid walls of text.
- **One story = one agent dispatch:** every story is sized **S or M** so a single `build`/`parallel-build` dispatch finishes it end-to-end. Never plan an L/XL story — split larger work at a natural seam (even when coupled) and connect the pieces with `Blocked by`. A dispatched agent cannot be resumed, so an oversized story stalls mid-build and breaks parallel runs.
- **Precision via tasks and seams, not oversized stories:** give each story an ordered `## Implementation Tasks` list (Phase 2.2c) for precision, and split at natural seams when work exceeds one dispatch — never grow a story past one dispatch to keep the count low.
- **Preserve spec language:** When the spec uses specific technical terms, preserve them in story titles and descriptions.
- **Date format:** Always use ISO 8601 (`YYYY-MM-DD`) for the folder name.
- **Reusability:** This skill must work with any project specification, not just the current project.
- **Design ledger drives planning:** the `pending` rows of `DESIGN_LEDGER.md` are the work-to-plan list (Phase 1.1c); flip each planned feature's row to `planned` with its `Plan ref` in Phase 4.5c. Never leave a planned feature `pending`.
