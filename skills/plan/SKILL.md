---
name: plan
description: Use when breaking a project spec or feature description into epics, stories, and a roadmap under `tasks/`. With `--quick [brief] [--epic NN]`, adds one small story to an existing epic instead of running a full planning cycle; redirects to full planning when no epic exists. Argument is the spec-file path, or the `--quick` flags.
argument-hint: "<path-to-spec> | --quick [brief] [--epic NN]"
effort: high
allowed-tools: Bash(ck-index*) Bash(git status*) Bash(git branch*) Bash(mkdir*)
---

# Project Architect — Spec to Epics/Stories (+ Quick Single-Story)

Transform a specification into a structured implementation plan — epics, stories,
dependencies, roadmap — under `tasks/`, or add one small story to an existing epic.

**Two operating modes:**

- **Full plan** (default) — a spec/feature becomes epics, stories, and a roadmap.
  Sub-modes: New Project, Add Feature, Continue Existing Plan.
- **Quick** (`--quick`) — one small story dropped into an existing epic, no full cycle.

Story state lives in **story-file frontmatter**; `STORIES_INDEX.md` and
`FEATURE_INDEX.md` are **generated** by `scripts/ck-index.sh` — never hand-written
(see [`data-model.md`](../../references/data-model.md)).

**Hand-off:** requires `/ck-code:design` (architecture docs in `docs/architecture/`),
then `/ck-code:team` (expert + guide skills). If no `.claude/skills/expert-*/` exists,
say so and recommend `/ck-code:team` before continuing — `build` relies on it. Hands
off to `/ck-code:build` (one story, several, or a whole epic) — or `/ck-code:ship` to
publish issues first.

## HARD GATES

- [Version gate](../../references/version-gate.md) — inlined in Phase 0. BLOCK halts the skill.
- **Fan-out decision announced before producing units** (2.5, 5.4) — count, compare to the
  threshold of 3, print the branch taken. Deciding after the units exist is a gate failure.

## ROUTING CHECK (do first)

This skill builds a **full epic/story plan** (or, with `--quick`, adds one story to an
existing epic). If the request is something else, STOP and recommend the better skill:

- No architecture docs yet → `/ck-code:design` (first)
- A stakeholder-facing spec, not a task breakdown → `/ck-code:spec`
- A bug in already-implemented code → `/ck-code:fix`
- `--quick` but no `tasks/` plan or target epic exists → fall through to full plan (Phase 1.2)

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:build`.

**Reuse-first:** plan from the design docs and existing `tasks/` — reuse settled
architecture instead of re-deriving it, and pick the simplest viable epic/story
structure. See [`reuse-first.md`](../../references/reuse-first.md).

## EFFORT

This skill pins `effort: high`: every story gets edge cases, test notes, a finer
`## Implementation Tasks` breakdown, and the roadmap gets an explicit dependency graph.
Effort controls **depth per story**, never story count or size — do **not** make stories
larger to spend effort; add task and criteria depth instead.

---

## PROGRESS TRACKING

Open a `TodoWrite` list as the **first action of Phase 0** — one todo per phase this run will
actually execute — then flip each to `in_progress` when it starts and `completed` when its
gate passes. Drop a phase that mode routing skips; never leave it pending. A long run's only
view into where it is comes from this list, so update it as you go and never batch the
updates to the end.

## PHASE 0: VERSION GATE (hard gate)

The stamp is injected at skill-load time — **do not spend a `Read` on it**:

Layout stamp: !`cat "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tasks/VERSION.md" 2>/dev/null || echo "ABSENT — no tasks/VERSION.md"`

Reads `layout: v6` → **PASS**, proceed. Anything else (including `ABSENT`) → run the
shared [version gate](../../references/version-gate.md) (HARD GATE) — it detects a pre-v6
layout, offers `/ck-code:migrate`, and stamps. Never read or write project state before
this PASSes.

---

## PHASE 1: INPUT & MODE

### 1.1 Route quick vs full

If `$ARGUMENTS` contains `--quick` → **QUICK MODE**: go to [PHASE Q](#phase-q-quick-single-story-mode).
Otherwise continue with **FULL PLAN MODE** (Phases 2–6).

**Full-plan input:** `$ARGUMENTS` is a path to a spec/feature file.

- Empty or missing file → ask: "Please provide the path to your project specification
  file (e.g., `docs/specifications.md`)." Validate with Read before proceeding.
- File empty or < 50 words → warn and ask whether to continue.

### 1.2 Full-plan sub-mode

Detect existing context, then pick the sub-mode with `AskUserQuestion`:

```
IF docs/architecture/ exists OR tasks/ has prior plans → offer FEATURE-mode choice:
ELSE → NEW PROJECT MODE (plan from scratch, no prompt).
```

`AskUserQuestion` — "This project already has architecture/plans. How should I plan?"
Options:

- **Add Feature** — plan epics/stories for a new feature, reading existing architecture
  and prior plans as context. New dated folder `tasks/YYYY-MM-DD_feature-<slug>/`,
  epic numbering continues from the project-wide maximum (3.1);
  `FEATURE_OVERVIEW.md` instead of `PROJECT_OVERVIEW.md`.
- **Full Project Plan** — replan the whole project from scratch (new dated folder;
  existing plans untouched).
- **Continue Existing Plan** — append epics/stories to a prior plan. List `tasks/*/`
  folders, ask which to extend, continue epic numbering from the **project-wide** maximum
  (3.1) — which may live in a newer plan than the one being extended, so never read it
  off that folder's own last epic — write into the SAME folder, update `ROADMAP.md`.

---

## PHASE 2: DEEP ANALYSIS

**Goal:** a full mental model before generating any output.

### 2.1 Read the specification

Read the entire `$ARGUMENTS` file.

### 2.2 (Feature / Continue) read existing context

Groups 1–3 are independent — issue them as **one parallel tool-call message** (batched
Reads + Globs), never three sequential rounds:

1. **Global architecture + feature docs** — `overview.md`, `tech-stack.md`,
   `folder-structure.md`, `_shared.md`, and the feature index. Open a full
   `features/<slug>/index.md` only for a feature the new work directly integrates with.
2. **Existing plans** — read `ROADMAP.md` and `EPIC.md` files to learn what is planned
   and what numbering to continue from.
3. **The codebase** — Glob to see which planned components already exist as source, so
   you plan only what is not built.

This prevents duplicating stories, planning already-implemented work, or conflicting
with the existing architecture.

### 2.3 Find unplanned design work (replaces the design ledger)

Read the feature docs' frontmatter to find work that has been **designed but not yet
planned**: a `docs/architecture/features/<slug>/index.md` whose frontmatter carries
`design: pending`. Those are the authoritative features to plan in this run — each
`slug` points to the feature doc to plan from. In Phase 5.5 you flip them to
`design: planned`. If no feature docs exist (design has not run), fall back to the
spec / feature index.

```bash
grep -rl 'design: pending' docs/architecture/features/*/index.md 2>/dev/null
```

### 2.4 Extract core dimensions

Use extended thinking (ultrathink) for **genuine** ambiguities only — where the spec or
`docs/architecture/` already answers something, reuse that answer. Extract:

- **PROJECT IDENTITY** — name (slug: lowercase, hyphens), one-line description, problem, users.
- **ARCHITECTURE** — system shape, components/sub-systems, data flow, external integrations.
- **TECH STACK** — languages/frameworks per component, build tools, package managers, datastores, protocols, deploy targets.
- **FEATURES & REQUIREMENTS** — functional (explicit + implied), non-functional (perf, security, latency), API surface.
- **PHASES / ROADMAP** (if specified) — phased rollout, MVP vs. future scope, priorities.

### 2.5 Parallel domain analysis (fan-out decision — make it before analysing)

Count the genuinely independent components 2.4 surfaced, then announce the branch:

- **≥3 independent components** → fix PROJECT IDENTITY (2.4) first so slugs stay
  consistent, then dispatch one **read-only** `general-purpose` Agent per component
  following the investigation variant in
  [`subagent-fanout.md`](../../references/subagent-fanout.md) (`model: haiku`). Each
  returns an analysis brief (features, requirements, tech stack, intra-domain deps) and
  writes nothing to `tasks/`. Merge the briefs here.
- **<3, or components tightly coupled** → analyse inline; say so in one line.

Either way, **all** cross-domain dependency mapping stays yours in 2.7 — never a subagent's.

### 2.6 Research tech stack (when beneficial)

Only for unfamiliar or rapidly-evolving frameworks the spec references, use context7
(MCP, else `npx -y @upstash/context7` CLI) or WebSearch to confirm current best
practices, version considerations, and standard project structures.

### 2.7 Identify dependencies & complexity

Map: which components depend on which (build order); shared artifacts (proto files,
shared types, config schemas); integration points needing multiple components; and
high-risk / high-complexity areas.

---

## PHASE 3: EPIC & STORY STRUCTURING

### 3.1 Define epics

Open a new epic only for a **distinct milestone or a hard dependency boundary** — the
fewest epics that cleanly separate deliverables. Group cohesive work that shares a
milestone under one epic; never create an epic that marks neither a milestone nor a
boundary — fold it into an existing one.

Each epic: a coherent deliverable chunk, numbered sequentially, a short descriptive slug.
**Set the epic slug to match its feature-doc slug** so the generated `FEATURE_INDEX.md`
links its `Docs` cell.

**Epic numbers are unique across the whole project, never per-folder.** Allocate the first
new epic from the project-wide maximum — in **every** mode, including a brand-new plan
folder — then number consecutively from there:

```bash
find tasks -mindepth 3 -maxdepth 3 -type d -path 'tasks/*/epics/*' 2>/dev/null \
  | sed 's|.*/epics/||;s|_.*||' | sort -n | tail -1
```

First new epic = that + 1, zero-padded to two digits; `01` when the command prints
nothing. Run it **once**, at the start of 3.1. `find`, not a `tasks/*/…` glob — an
unmatched glob aborts the command under zsh and would silently return "no epics" on a
project that has some.

Never restart at `01` because the folder is new: two plans owning epic `01` make every
`EE-SS` ambiguous, and `build --epic NN`, `blocked_by` and the `epic/<NN>-*` branch glob
then resolve to whichever plan they reach first. See
[`data-model.md`](../../references/data-model.md#epic-and-story-numbers-are-globally-unique).

- **Cross-references:** when a story depends on existing plan/code, reference it
  explicitly (e.g. `blocked_by` an existing story ID, or a note citing the source file).
  A globally unique ID means `blocked_by` may name a story in **another plan** — use it
  when the dependency is real rather than duplicating the work.

**Ordering:** infrastructure/foundation first; no-dependency epics before dependents;
respect spec phases; within a phase — shared/core code, then feature code, then
integration. The plan's **last** epic is always the mandatory Integration & E2E epic (3.6).

### 3.2 Define stories

**One story = one agent dispatch.** A single `build` session — or one PARALLEL MODE
sub-agent — implements it end-to-end (red → green → refactor → QA → commit) within its
budget. An oversized story stalls mid-build and forces a costly recovery pass.

Each story: exactly one cohesive concern (a feature, component, or vertical slice);
sized **S or M only**; numbered sequentially within its epic (`01`, `02`, …) with a
short slug; clear testable acceptance criteria and a `files` list.

**Sizing rubric (S or M only, single-dispatch):**

- **M** — a self-contained concern (one feature, component, or vertical slice with real logic). The default.
- **S** — a small focused change. Fold a trivial S (a lone config or type file) into the M story that consumes it.
- **L / XL** — never plan one. Split at a natural seam (interface vs. implementation,
  per-endpoint, per-component) **even when the parts are coupled**, and order the pieces
  with `blocked_by`. `## Implementation Tasks` (3.4) carries the precision a bigger story
  would have held.

**Always split** when the work exceeds one dispatch, **or** the pieces are independent
and parallelizable, **or** there is a hard dependency boundary (one part must merge and
stabilize before the next), **or** the concerns are unrelated.

### 3.3 Consolidation pass

Before presenting, merge only genuine redundancy — **never merge past one dispatch** (3.2):

- Standalone **S** stories → fold into the story that consumes them.
- Two stories that are truly the same concern on the same files → merge **only if the
  result still fits one dispatch**; else keep them split.
- An epic left with a single story → fold it upward and drop the epic, unless it marks a
  distinct milestone or dependency boundary.

### 3.4 Break each story into tasks

Decompose every story into an ordered list of concrete **implementation tasks** — each
one verifiable action toward its acceptance criteria (e.g. "define the `X` interface",
"implement `Y` against it", "wire `Y` into the handler"). These populate the story's
`## Implementation Tasks` section.

- Tasks are **story-specific**, never generic TDD phases (not "write tests / implement / refactor / QA").
- Order so each builds on the previous; the final task completes the last acceptance criterion.
- Right altitude: a handful of meaningful steps. **> ~8 tasks means the story is too big — split it** (3.2).
- Every acceptance criterion must be reachable by following the task list end to end.

### 3.5 Map story dependencies

For each story, identify blockers (must-complete-first story IDs → `blocked_by`),
parallel-safe siblings, and cross-epic dependencies.

### 3.6 Mandatory final Integration & E2E epic

**Every plan run ends with a dedicated final epic that validates the whole feature (or
project) end-to-end** — no plan is complete without it. Add it as this run's **last**
epic, regardless of mode — which, since 3.1 allocates from the project-wide maximum, is
also the highest-numbered epic in the project:

- **New Project:** covers the whole project end-to-end.
- **Add Feature:** covers the whole feature end-to-end, including its integration points.
- **Continue:** a new final Integration & E2E epic for the appended scope only; do not
  touch the prior plan's epics.

Rules:

- Slug it `integration-e2e` (`NN_integration-e2e`); its Goal states the end-to-end behavior proved.
- `blocked_by` every prior epic's terminal stories — it runs only after the pieces exist,
  so it is last in the roadmap and never a parallel candidate alongside the work it verifies.
- Its stories **exercise real user journeys through actual entry points** (API, CLI, UI,
  message bus), asserting cross-component behavior and the seams from 2.7 — not more unit tests.
- **Each E2E story is still S or M, one dispatch** (3.2). When coverage exceeds one
  dispatch, split by journey (happy-path, error/edge, each integration point) — never one oversized E2E story.
- Give each an ordered `## Implementation Tasks` list: set up fixtures → drive the flow → assert observable outcomes.

Do not fold this into a feature epic, and do not skip it because "the stories already
have tests" — those are per-slice; this epic is the whole-feature guarantee.

---

## PHASE 4: CONFIRM

Present the planned structure (no files written yet) using
[roadmap-format.md#phase-4-plan-confirmation-format](references/roadmap-format.md#phase-4-plan-confirmation-format),
then gate with `AskUserQuestion` — "Proceed with generating this plan?" Options:
**Proceed** / **Adjust** / **Cancel**.

- **Adjust** → ask what to change, loop back to Phase 3.
- **Cancel** → stop, write nothing.
- **Proceed** → Phase 5.

---

## PHASE 5: GENERATE FILES

### 5.1 Directory structure

Use today's date for `YYYY-MM-DD` (ISO 8601). Layouts per mode:
[examples.md](references/examples.md) (New Project / Add Feature / Continue).

### 5.2 Overview

Write `PROJECT_OVERVIEW.md` (New/Full) or `FEATURE_OVERVIEW.md` (Add Feature) —
templates in [templates.md](references/templates.md#project-overview-template).

### 5.3 EPIC.md (per epic) — with frontmatter, no story table

Write `epics/NN_<slug>/EPIC.md` from
[templates.md#epic-template](references/templates.md#epic-template). It carries
frontmatter (`epic`, `slug`, `title`, `description`) — the generator reads `description`
for the `FEATURE_INDEX.md` cell — and has **no `## Stories` table**: the story list is
generated into `STORIES_INDEX.md`.

### 5.4 Story files (per story) — with frontmatter + Implementation Tasks

Each story file is one independent artifact, fully decided in Phase 3, so **count the
confirmed stories and pick the branch before writing the first one** — announce it in one
line (`Fan-out: 6 stories ≥ 3 → dispatching 6 agents.`):

- **≥3 stories** → dispatch one `general-purpose` Agent per story per the artifact variant
  in [`subagent-fanout.md`](../../references/subagent-fanout.md) (`model: sonnet`), all in
  a single message. Give each: its full Phase 3 breakdown (title, size, criteria, tasks,
  `blocked_by`, `files`), the template reference, and its exact output path; it writes
  exactly one `stories/SS_<slug>.md` and nothing else. On collection verify every story
  landed, rewriting any missing unit inline.
- **<3 stories** → write them inline.

The content is identical on both branches: `epics/NN_<slug>/stories/SS_<story-slug>.md`
from [templates.md#story-template](references/templates.md#story-template). Frontmatter is
the source of truth: `id`, `title`, `epic`, `status: todo`, `size` (`S`/`M`), `blocked_by`
(inline `[…]` or `[]`), `files` (inline `[…]` or `[]`), `issue:` empty, `prior_status:`
empty. Body keeps `## Description`, `## Acceptance Criteria`, `## Implementation Tasks`,
`## Technical Notes`.

The overview (5.2) and every `EPIC.md` (5.3) are orchestrator-owned and already written
before dispatch; 5.5–5.7 also stay with the orchestrator, after collection.

### 5.5 Flip design flag (pending → planned)

For each feature this plan now covers, set its feature-doc frontmatter from
`design: pending` to `design: planned` (Edit `docs/architecture/features/<slug>/index.md`).
Match by `slug`. Leave unplanned features untouched. Skip silently if no feature doc
exists. This is what makes "what still needs planning?" a cheap frontmatter lookup next run.

### 5.6 ROADMAP.md

Write from [roadmap-format.md#roadmapmd-template](references/roadmap-format.md#roadmapmd-template).
Continue mode: update the existing roadmap to include the new epics.

### 5.7 Regenerate the indexes (never hand-write)

After all story + epic files are written, regenerate `STORIES_INDEX.md` and
`FEATURE_INDEX.md` from frontmatter — never write or cell-edit them by hand:

```bash
ck-index
```

The script reads only frontmatter, so the views cannot disagree with the stories. It
picks up the new plan, the epic descriptions, and the `Docs` cells automatically.

---

## PHASE 6: SUMMARY

Present a mode-tailored summary from
[roadmap-format.md#phase-6-summary-formats](references/roadmap-format.md#phase-6-summary-formats)
(New Project / Add Feature / Continue).

---

## PHASE Q: QUICK SINGLE-STORY MODE

Adds one small story to an **existing epic**, no full cycle. (Phase 0 already gated.)

### Q.1 Locate plan & target epic

1. **`--epic NN` given** — resolve the plan **from the number**; it is unique
   project-wide, so exactly one folder can match and there is nothing to ask:

   ```bash
   find tasks -mindepth 3 -maxdepth 3 -type d -path 'tasks/*/epics/NN_*'
   ```

   No match → show every epic with its plan and re-prompt. More than one match → the
   project has colliding epic numbers; stop and say to run `/ck-code:migrate`.
2. **No `--epic`** — `Glob "tasks/*/PROJECT_OVERVIEW.md"` and
   `Glob "tasks/*/FEATURE_OVERVIEW.md"`; take the most recent. **No plan → redirect:**
   "No `tasks/` plan found. Run `/ck-code:plan <spec>` first." Stop. Multiple plans → ask
   which. Then list that plan's epic folders and ask which epic.
3. Record the target epic's highest existing `SS` (Q.3 numbers the new story from it).
   **No epic exists anywhere → redirect to full plan** — there is nothing to add to.

### Q.2 Capture intent

- **Brief** — a non-flag positional argument is the brief seed; else ask "What should
  this story do? (one or two sentences)". Reject empty.
- **Size** — S or M only. Default **S**. If the work is larger than M, stop and recommend
  `/ck-code:plan` — quick stories are by definition small.

### Q.3 Draft & confirm

Compute the ID: `EE-SS` where `EE` is the epic number and `SS = max(existing SS in epic) + 1`,
zero-padded; empty epic ⇒ `01`. Slug = kebab-case of the brief, ≤ 5 words.

Draft the full story from [templates.md#story-template](references/templates.md#story-template):
title (title-case one-liner), description (1–2 sentences), 1–3 concrete testable
acceptance criteria, an ordered `## Implementation Tasks` list, 1–3 technical notes, and
the `files` frontmatter (best guess; `[]` if unknown — `build` fills it). Show the draft,
then gate with `AskUserQuestion` — "Add this story?" Options: **Confirm** / **Edit** /
**Cancel**. Loop on **Edit** (ask which section) until Confirm or Cancel. Write nothing
before Confirm.

### Q.4 Write the story file

Path `tasks/<slug>/epics/NN_<epic-slug>/stories/SS_<story-slug>.md`, frontmatter
(`status: todo`, `size` S/M, `blocked_by` `[]` unless a dependency was named, `files`,
`issue:`/`prior_status:` empty) + body with `## Implementation Tasks`.

### Q.5 Regenerate the indexes

Never cell-edit an index and never touch `EPIC.md` — the story list is generated:

```bash
ck-index tasks/<slug>
```

Print the created path and confirm the index regenerated (row `EE-SS`).

### Q.6 Hand-off

Print suggestions; never auto-launch:

```
Next steps (pick one):
  /ck-code:build   <story-path>   # implement now (TDD + QA)
  /ck-code:ship    <story-path>   # publish as a GitHub Issue
  /ck-code:track   next           # see the updated dashboard
```

---

## NEXT

Run `/ck-code:ship` to publish the epics and stories to GitHub Issues, **or** skip
publishing and run `/ck-code:track next` to find the first story to implement. An epic of
independent stories is a natural fit for `/ck-code:build --epic NN`.

---

## RULES

- **Never restart epic numbering at `01` in a new plan folder** (3.1) — allocate from the project-wide maximum in every mode. Colliding epic numbers make every `EE-SS` ambiguous.
- **Never store the next epic number** — derive it from the epic folders each run (3.1).
- **Never ask which plan an `--epic NN` belongs to** (Q.1) — the number is unique project-wide; more than one match is a collision to migrate, not a question to ask.
- **Never plan an L/XL story** (3.2) — split at a natural seam and connect with `blocked_by`.
- **Never skip the final Integration & E2E epic** (3.6), and never fold it into a feature epic.
- **Never hand-write or cell-edit `STORIES_INDEX.md` / `FEATURE_INDEX.md`** — regenerate with `ck-index` (5.7, Q.5).
- **Always relay `ck-index: WARN` lines** printed by `ck-index` — a skipped story is invisible in every generated view while its file still exists ([stories-index.md](../../references/stories-index.md)).
- **Never write an `EPIC.md` `## Stories` table** — the story list is generated.
- **Never leave a planned feature `design: pending`** — flip it to `planned` (5.5).
- **Never create a new epic in `--quick` mode** — redirect to full plan when no epic exists.
- **Never write story files inline when ≥3 are confirmed** (5.4) — the dispatch decision happens before the first file, never after the last.
- **Never delegate shared writes to a subagent** (5.4) — overview, epics, indexes, roadmap are orchestrator-owned; subagents write only their own story file.
- **Never hardcode** project names, technologies, or paths — derive everything from the spec.
- **Always cover every functional requirement** with at least one story; flag vague ones for clarification.
- **Always keep frontmatter generator-readable** — one `key: value` per line, inline `[…]` lists, no block scalars.
- **Always use ISO 8601** (`YYYY-MM-DD`) for folder names, and output in English.
