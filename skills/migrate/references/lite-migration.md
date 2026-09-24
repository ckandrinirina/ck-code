# Lite → v7 Migration Map

Field-by-field conversion of a **ck-code-lite** project (`docs/ARCHITECTURE.md` +
`tasks/PLAN.md`) into the ck-code **v7 layout**, directly. Read by `migrate` PHASE L only.

The two plugins are alternatives, not companions — this is the one-way upgrade path.
Nothing here converts v7 back to lite.

Source contracts (in the ck-code-lite plugin): `references/plan-format.md` and
`skills/start/references/architecture-template.md`.
Target contract: [`data-model.md`](../../../references/data-model.md).

Templates are **never redefined here**. Story, epic and overview come from
[`plan/references/templates.md`](../../plan/references/templates.md), roadmap from
[`plan/references/roadmap-format.md`](../../plan/references/roadmap-format.md),
architecture docs from
[`design/references/architecture-templates.md`](../../design/references/architecture-templates.md).

## Detection (SKILL Phase 1)

```bash
[ -f tasks/PLAN.md ] && echo LITE
find tasks -mindepth 2 -maxdepth 2 -name epics 2>/dev/null | grep -q . && echo HAS_EPICS
```

`LITE` with `HAS_EPICS` is a half-migrated project: `migrate` stops. `LITE` alone means
there is no other plan, so the new epics start at `01` and cannot collide with another
plan's numbers.

## Names

| Name | Derived from |
|---|---|
| project slug | `# PLAN — <name>` in `tasks/PLAN.md`, else `# ARCHITECTURE — <name>`, else the repo directory name. Kebab-cased. |
| plan folder | `tasks/$(date +%F)_<project-slug>/` — the same dated convention `plan` writes |
| epic slug | kebab-cased epic name from the grouping, ≤ 4 words |
| story slug | kebab-cased task title, ≤ 5 words |

## Epic grouping

A lite plan is flat; v7 requires epics. Infer them from task titles and their `files:`
paths (tasks touching the same directory usually belong together), then present the
proposal using the **Phase 4 Plan Confirmation Format** in
[`roadmap-format.md`](../../plan/references/roadmap-format.md), extended with a
`T-NN → EE-SS` column so the user sees every ID move before anything is written.

`AskUserQuestion` — "Group the lite tasks into these epics?"

| Option | Effect |
|---|---|
| **Accept** | write the proposed grouping |
| **Single epic** | one epic `01_<project-slug>`, stories in PLAN order — the zero-interpretation fallback |
| **Adjust** | ask what to change, re-present, ask again |

Epic numbers follow the proposed order (`01`, `02`, …); story numbers are sequential
within each epic, following PLAN order.

## Story frontmatter

One story file per `T-NN` at
`tasks/<plan-folder>/epics/NN_<epic-slug>/stories/SS_<story-slug>.md`.

Coverage check: the left column names every lite field, the middle column every v7
story key in [`data-model.md`](../../../references/data-model.md#story-file-the-source-of-truth).

| lite field | v7 frontmatter | Rule |
|---|---|---|
| `T-NN` | `id` | `EE-SS` from the grouping. Record every pair in the ID map — `blocked_by` and the report both need it. |
| Title | `title` | verbatim, no `Story EE-SS:` prefix |
| (grouping) | `epic` | `EE`, matches the folder |
| `todo` | `status` | `todo` |
| `doing` | `status` | `in-progress` |
| `done` | `status` | `done` |
| `blocked` | `status` | **`todo`**, since v7 has no `blocked` status. Append a `## Technical Notes` line: `Was \`blocked\` in the lite plan — re-triage.` List every such story in the report. |
| `S` / `M` | `size` | unchanged — both vocabularies are S/M, so no re-sizing is ever needed |
| `needs: T-01, T-03` | `blocked_by` | translate through the ID map → `[01-01, 02-01]`. `—` → `[]` |
| `files: a.ts, b.ts` | `files` | `[a.ts, b.ts]`, `—` or absent → `[]` |
| — | `issue` | empty |
| — | `pr` | empty; lite opened PRs without recording them |
| — | `delivery` | empty |
| — | `prior_status` | empty |

Frontmatter stays generator-readable: one `key: value` per line, inline `[…]` lists,
no block scalars.

## Epic frontmatter

One `EPIC.md` per inferred epic, carrying the **same seven keys** a freshly planned epic
does. A lite-migrated epic must be indistinguishable from a planned one:

| lite source | v7 frontmatter | Rule |
|---|---|---|
| (grouping) | `epic` | `NN`, matches the folder |
| (grouping) | `slug` | the kebab-cased epic slug; the same slug names its feature-doc folder, so the `EPICS_INDEX` Docs cell links |
| (grouping) | `title` | the epic name, title-cased |
| (grouping) | `description` | one line summarising that epic's stories, the `EPICS_INDEX` Description cell; no `\|` |
| — | `issue` | empty; lite publishes no issues |
| — | `pr` | empty |
| — | `delivery` | empty |

Emit all seven lines even though three are empty. Never write `integration:` on an epic:
the level lives in the plan record. Keep the template's `## Dependencies` section and fill
it from the translated `blocked_by` between epics (why one epic waits on another), or
`None` when no story crosses an epic boundary.

## Story body

Moved **verbatim** — checkbox state included, so completed work stays completed.

| lite section | v7 section |
|---|---|
| (task title) | `## Description` — the title as a sentence; add nothing the plan does not say |
| `### Acceptance` | `## Acceptance Criteria` |
| `### Tasks` | `## Implementation Tasks` |
| `### Notes` | `## Technical Notes` |

A lite task has no description prose beyond its title. Never invent one — a thin
`## Description` is correct; a fabricated one is a defect.

## Plan record (`OVERVIEW.md` frontmatter)

The plan's `OVERVIEW.md` opens with the record, in this exact key order. Coverage check:
the right column names every record key in
[`data-model.md`](../../../references/data-model.md#plan-record-tasksplanoverviewmd).

| lite source | v7 record key | Rule |
|---|---|---|
| project slug ([§ Names](#names)) | `slug` | the plan slug, the folder name without its date |
| `# PLAN — <name>`, else `# ARCHITECTURE — <name>` | `title` | the name; double-quote it when it contains `: ` |
| — (lite has no integration field) | `integration` | `story`: each story its own PR into the trunk, which is how lite shipped tasks. `/ck-code:config integration` changes it later |
| — | `branch` | empty; a `story` plan has no plan branch |
| — | `issue` | empty; lite publishes no issues |
| — | `pr` | empty |
| — | `delivery` | empty |

```markdown
---
slug: word-count
title: Word count CLI
integration: story
branch:
issue:
pr:
delivery:
---
```

## Plan-folder files

| File | Content source |
|---|---|
| `OVERVIEW.md` | the record above, then the overview template body in [`templates.md`](../../plan/references/templates.md): Vision from the `ARCHITECTURE.md` intro paragraph, Tech Stack from `## Stack`, Key Design Decisions from `## Decisions`. Anything lite does not record → `[TO BE DEFINED]`. |
| `ROADMAP.md` | ROADMAP.md Template in [`roadmap-format.md`](../../plan/references/roadmap-format.md); phases follow the epic order, dependencies from the translated `blocked_by`. |
| `epics/NN_<slug>/EPIC.md` | Epic Template in [`templates.md`](../../plan/references/templates.md), frontmatter per [§ Epic frontmatter](#epic-frontmatter) above. No `## Stories` table. |

## Views, stamp and guard

Written once L3 and L4 are done, in this order:

1. `tasks/.gitignore`, so the views never reach git:

   ```
   # Generated by ck-code. The views regenerate from story frontmatter; never commit them.
   STORIES_INDEX.md
   EPICS_INDEX.md
   ```

2. `ck-index` regenerates `tasks/<plan>/STORIES_INDEX.md` and `tasks/EPICS_INDEX.md`.
   They stay uncommitted; relay every `ck-index: WARN` line.
3. `tasks/VERSION.md`, per [`version-gate.md`](../../../references/version-gate.md#the-stamp-tasksversionmd):

   ```markdown
   <!-- AUTO-GENERATED by ck-code. DO NOT EDIT BY HAND. -->

   layout: v7
   requires: ck-code >= 7.0.0
   ```

4. The guard, per `migrate` Phase 4 (`ck-bootstrap install` when `check` finds it missing).

## `docs/ARCHITECTURE.md` → `docs/architecture/`

Every target file comes from
[`architecture-templates.md`](../../design/references/architecture-templates.md).

| lite section | v7 destination |
|---|---|
| intro paragraph | `overview.md` → `## Vision` |
| `## Stack` | `tech-stack.md` → `## Overview` table |
| `## Commands` | `dev-guide.md` → `## Setup` / `## Running` / `## Testing` |
| `## Folder structure` | `folder-structure.md` → `## Directory Tree` |
| `## Decisions` | `overview.md` → `## Key Design Decisions` |
| `## Conventions` | `_shared.md` → `## Conventions` |

Also written: `README.md` (index, listing the globals and every feature doc) and
`configuration.md` — the latter only when the repo actually has config files, else
listed in `README.md` as "Not applicable for this project."

Sections lite never records (Goals, Target Users, Scope, prerequisites versions) →
`[TO BE DEFINED]`.

## Feature docs

One `docs/architecture/features/<epic-slug>/index.md` per epic, so the `EPICS_INDEX`
Docs cell resolves.

```markdown
---
slug: <epic-slug>
design: planned
---
```

`design: planned` because the epic already has stories.

These are **stubs**: `## Summary` from the epic description, every other section
`[TO BE DEFINED]`. A lite `ARCHITECTURE.md` holds no component, API, data, or flow
detail, so there is nothing to convert — inventing it here would put unreviewed
architecture in front of a `build`. The report tells the user to run `/ck-code:design`
to fill them in.

## Retiring the lite artifacts

Content is kept; only the live plan is stood down.

1. `git mv tasks/PLAN.md tasks/PLAN.superseded.md`, then prepend:

   ```markdown
   > **Superseded.** Migrated to the ck-code v7 layout on <date>.
   > The live plan is `tasks/<plan-folder>/`; `/ck-code:track` shows its stories.
   > Kept for reference; nothing reads this file.
   ```

2. Prepend to `docs/ARCHITECTURE.md`:

   ```markdown
   > **Superseded** by `docs/architecture/` — see its `README.md`.
   ```

The rename is what stops a stray `/ck-code-lite:build` writing into a plan ck-code no
longer reads, and it clears the `tasks/PLAN.md` marker so the
[version gate](../../../references/version-gate.md) cannot re-fire.

## Plugin swap

Read `.claude/settings.json`. If `enabledPlugins` has
`"ck-code-lite@ck-marketplace": true`, ask once (`AskUserQuestion`, Swap / Leave it):

> ck-code and ck-code-lite are alternatives — leaving both enabled gives this project
> two competing `build` and `ship` skills. Swap them?

On **Swap**: set `"ck-code-lite@ck-marketplace": false` and
`"ck-code@ck-marketplace": true` in the migration commit, and tell the user the change
takes effect after a session restart. On **Leave it**: change neither key yourself and say
so in the report. Never edit any other key in that file.

**`ck-bootstrap install` sets `"ck-code@ck-marketplace": true` regardless of this answer.**
It is the guard installer `migrate` Phase 4 runs beside the stamp
([`version-gate.md`](../../../references/version-gate.md)), and it opts the project into the
plugin whose layout the stamp now claims. So **Leave it** does not mean "ck-code stays
disabled"; it means only that `ck-code-lite` is left enabled too, and the project ends the
migration with **both** plugins on. That is the competing-skills state the question warns
about, so the report names the final value of **both** keys rather than just the answer, and
repeats that `/plugin` can flip the lite key later.

## Report additions

On top of the standard `migrate` report:

- the full `T-NN → EE-SS` ID map
- every task that was `blocked` and is now `todo`
- feature-doc stubs written, with the `/ck-code:design` follow-up
- the plan record: `integration: story`, and `/ck-code:config integration` to change it
- the plugin swap: the answer, **and the final value of both `enabledPlugins` keys**.
  `ck-code@ck-marketplace` is `true` either way because `ck-bootstrap install` sets it, so
  say plainly whether `ck-code-lite@ck-marketplace` is still `true` and how to turn it off
- lite artifacts renamed / bannered
