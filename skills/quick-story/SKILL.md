---
name: quick-story
description: Use to add one small story to an existing `tasks/` plan when a full `/ck-code:plan` cycle is overkill — e.g. a database tweak or one-off epic adjustment. Argument is an optional one-line brief; `--epic NN` selects the target epic.
argument-hint: "[brief] [--epic NN]"
disable-model-invocation: true
---

# Quick Story — Single-Story Scaffolder for Existing Plans

Scaffold one small story directly inside an existing `tasks/` plan, without running the full `/ck-code:plan` cycle. Writes the story file and keeps `STORIES_INDEX.md` and `EPIC.md` in sync, so every downstream skill (`build`, `track`, `to-issues`, `ship`, `fix`, `sync`) treats it like any other story.

## When to use vs. when not

| Use `quick-story` when… | Use a different skill when… |
|---|---|
| Adding one small adjustment to an existing epic (DB field, config flag, one helper) | Starting a brand-new project or feature → `/ck-code:plan` |
| The work fits in one or two sentences | The change spans multiple stories or new components → `/ck-code:plan` |
| The target epic already exists in `tasks/<slug>/epics/` | No `tasks/` plan exists yet → `/ck-code:plan` first |
| You want a TODO story ready for `/ck-code:build` | Reporting a bug → `/ck-code:fix` (it can create stub stories too) |

## PHASE 1 — Locate active plan & target epic

### 1.1 Discover the tasks plan

- Run `Glob "tasks/*/PROJECT_OVERVIEW.md"` and `Glob "tasks/*/FEATURE_OVERVIEW.md"`. Take the most recent.
- If none exists, abort with: *"No `tasks/` plan found. Run `/ck-code:plan <spec>` first to create one."*
- If multiple plans exist, list them and ask: *"Which plan? (1–N)"*. Wait for the user to pick.

### 1.2 Read or bootstrap the index

- Read `tasks/<slug>/STORIES_INDEX.md`.
- If the file is missing or does not contain `<!-- Schema: v1 -->`, run the **Bootstrap** procedure from `ck-code/references/stories-index.md` (glob every story, derive rows, write the index, tell the user how many stories were imported), then re-read.

### 1.3 Pick the target epic

- List epic folders: `tasks/<slug>/epics/NN_<slug>/EPIC.md`. Display as a numbered list with the highest existing `SS` per epic:

  ```
  Available epics:
  1. 01 · Foundation   (last story 01-04)
  2. 02 · Billing      (last story 02-03)
  3. 03 · Reporting    (no stories yet)
  ```

- If `--epic NN` was provided, validate that the folder exists. On mismatch, show the list and re-prompt.
- Else ask: *"Which epic should this story go into? (1–N)"*. Wait for the user to pick.

## PHASE 2 — Capture story intent

### 2.1 Brief

- If a non-flag positional argument was given, treat it as the brief seed (e.g. `/ck-code:quick-story "Add audit_log column to Order table"`).
- Else prompt: *"What should this story do? (one or two sentences)"*. Wait for input. Reject empty input.

### 2.2 Size

- Ask: *"Size? S / M / L / XL — default S"*. Treat empty input as **S**.
- If the user picks **L** or **XL**, suggest `/ck-code:plan` instead and confirm before continuing — quick stories are by definition small.

## PHASE 3 — Draft story

### 3.1 Compute identifiers

- Next story ID = `EE-SS` where `EE` is the epic number and `SS = max(existing-SS-in-epic) + 1`, zero-padded to two digits. Empty epic ⇒ `SS = 01`.
- Slug = kebab-case of the brief, ≤ 5 words, alphanumeric and dashes only.
  - `"Add audit_log column to Order table"` → `add-audit-log-column`.

### 3.2 Generate sections

Draft the story using the template in `references/templates.md`. Fill each section from the brief:

- **Title** — Title-case one-liner derived from the brief.
- **Description** — 1–2 sentences expanding the brief: what it implements and why.
- **Acceptance Criteria** — 1–3 concrete, testable bullets (`[ ]` checkboxes). Each bullet must be verifiable by a test or a manual check, not a goal like *"works correctly"*.
- **Technical Notes** — 1–3 implementation hints. Pull keywords from the brief — *database / migration / schema / API / endpoint / config / type* — and propose the matching pattern.
- **Files to Create/Modify** — best-guess `Action | File Path | Purpose` table. If unknown, leave a single `TBD` row so `/ck-code:build` Phase 3 can fill it in.
- **Dependencies** — `Blocked by: None`, `Blocks: None` by default.
- **Related** — Epic slug; spec ref optional.

### 3.3 Confirmation gate

Show the full draft to the user and ask:

```
CONFIRM       — write all three files and finish
EDIT <field>  — re-draft a single section (title, description, criteria, notes, files, size)
ABORT         — cancel without writing anything
```

Loop on `EDIT` until the user types `CONFIRM` or `ABORT`. Never write any file before `CONFIRM`.

## PHASE 4 — Persist

All three writes happen in one logical step. If any one fails, stop the remaining writes and tell the user which artifacts are out of sync.

### 4.1 Write the story file

- Path: `tasks/<slug>/epics/NN_<epic-slug>/stories/SS_<story-slug>.md`.
- Body: the story template from `references/templates.md` with the Phase 3 fields substituted.
- Status: `TODO`.

### 4.2 Insert the index row

- Build the row: `| EE · Epic Display | EE-SS | <Title> | TODO | <Size> | - | epics/NN_<epic-slug>/stories/SS_<story-slug>.md |`.
- Use the cell-only Edit pattern from `ck-code/references/stories-index.md` to insert the row in `ID` order. Never re-write the table from scratch.

### 4.3 Append to EPIC.md story table

- Open `tasks/<slug>/epics/NN_<epic-slug>/EPIC.md`.
- Locate the `## Stories` table and append: `| SS | <Title> | <Size> | TODO |` at the end.

### 4.4 Print results

```
Created:        tasks/<slug>/epics/NN_<epic-slug>/stories/SS_<story-slug>.md
Index updated:  tasks/<slug>/STORIES_INDEX.md  (row EE-SS)
Epic updated:   tasks/<slug>/epics/NN_<epic-slug>/EPIC.md
```

## PHASE 5 — Hand-off

Print three suggestions; never auto-launch:

```
Next steps (pick one):
  /ck-code:build      <story-path>   # implement now (TDD + QA)
  /ck-code:to-issues  <story-path>   # publish as a GitHub Issue
  /ck-code:track      next           # see updated dashboard
```

The skill exits here. The user runs the next command explicitly.

## Worked example

```
$ /ck-code:quick-story "Add audit_log column to Order table" --epic 02

PHASE 1 — Locate active plan
  Found: tasks/2026-04-29_billing-feature/
  Index: STORIES_INDEX.md (Schema v1, 7 stories)
  --epic 02 → 02 · Billing (last story 02-03)

PHASE 2 — Capture intent
  Brief: Add audit_log column to Order table
  Size:  [empty] → S

PHASE 3 — Draft
  ID:    02-04
  Slug:  add-audit-log-column

  # Story 02-04: Add Audit Log Column To Order Table
  > Epic: Billing   Size: S   Status: TODO

  ## Description
  Add an `audit_log` JSONB column to the `orders` table so checkout flow
  events can be appended without a separate audit table.

  ## Acceptance Criteria
  - [ ] `audit_log` column exists on `orders` (JSONB, nullable, default `[]`)
  - [ ] Existing rows backfilled to `[]` in the same migration
  - [ ] ORM model exposes `auditLog: AuditEvent[]`

  ## Technical Notes
  - New migration in `migrations/` (sequential numbering).
  - Update `src/models/order.ts` ORM mapping.

  ## Files to Create/Modify
  | Action | File Path                            | Purpose                  |
  |--------|--------------------------------------|--------------------------|
  | CREATE | migrations/008_orders_audit_log.sql  | add column + backfill    |
  | MODIFY | src/models/order.ts                  | expose auditLog field    |

  ## Dependencies
  - Blocked by: None
  - Blocks: None

  ## Related
  - Epic: billing

  > CONFIRM

PHASE 4 — Persist
  Created:       tasks/2026-04-29_billing-feature/epics/02_billing/stories/04_add-audit-log-column.md
  Index updated: STORIES_INDEX.md (row 02-04)
  Epic updated:  epics/02_billing/EPIC.md

PHASE 5 — Hand-off
  Next: /ck-code:build tasks/.../stories/04_add-audit-log-column.md
```

## Rules

- **Never** create a new epic. If no epic fits, the user must run `/ck-code:plan` instead — tell them so and abort.
- **Never** write any file before the user types `CONFIRM` in Phase 3.
- **Never** auto-launch `/ck-code:build` or `/ck-code:to-issues`. Phase 5 is suggestion-only.
- **Never** rewrite `STORIES_INDEX.md` from scratch — use cell-only edits per `ck-code/references/stories-index.md` Mutation Protocol.
- **Always** keep the story file, index row, and EPIC.md row in sync within the same Phase 4 step. If one write fails, surface which file is out of sync.
- **Always** redirect bug reports to `/ck-code:fix` — it already auto-matches scope and can create stub stories.
- **Always** redirect L/XL stories to `/ck-code:plan` after a confirmation prompt — quick stories are small by definition.
