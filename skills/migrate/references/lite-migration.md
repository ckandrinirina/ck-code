# Lite → v6 Migration Map

Field-by-field conversion of a **ck-code-lite** project (`docs/ARCHITECTURE.md` +
`tasks/PLAN.md`) into the ck-code **v6 layout**. Read by `migrate` PHASE L only.

The two plugins are alternatives, not companions — this is the one-way upgrade path.
Nothing here converts v6 back to lite.

Source contracts (in the ck-code-lite plugin): `references/plan-format.md` and
`skills/start/references/architecture-template.md`.
Target contract: [`data-model.md`](../../../references/data-model.md).

Templates are **never redefined here** — story/epic/overview come from
[`plan/references/templates.md`](../../plan/references/templates.md), roadmap from
[`plan/references/roadmap-format.md`](../../plan/references/roadmap-format.md),
architecture docs from
[`design/references/architecture-templates.md`](../../design/references/architecture-templates.md).

## Detection (SKILL Phase 1)

```bash
ls tasks/PLAN.md 2>/dev/null | grep -q . && echo LITE
ls -d tasks/*/epics 2>/dev/null | grep -q . && echo HAS_EPICS
```

## Names

| Name | Derived from |
|---|---|
| project slug | `# PLAN — <name>` in `tasks/PLAN.md`, else `# ARCHITECTURE — <name>`, else the repo directory name. Kebab-cased. |
| plan folder | `tasks/$(date +%F)_<project-slug>/` — the same dated convention `plan` writes |
| epic slug | kebab-cased epic name from the grouping, ≤ 4 words |
| story slug | kebab-cased task title, ≤ 5 words |

## Epic grouping

A lite plan is flat; v6 requires epics. Infer them from task titles and their `files:`
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

| lite field | v6 frontmatter | Rule |
|---|---|---|
| `T-NN` | `id` | `EE-SS` from the grouping. Record every pair in the ID map — `blocked_by` and the report both need it. |
| Title | `title` | verbatim, no `Story EE-SS:` prefix |
| (grouping) | `epic` | `EE`, matches the folder |
| `todo` | `status` | `todo` |
| `doing` | `status` | `in-progress` |
| `done` | `status` | `done` |
| `blocked` | `status` | **`todo`** — v6 has no `blocked` status. Append a `## Technical Notes` line: `Was \`blocked\` in the lite plan — re-triage.` List every such story in the report. |
| `S` / `M` | `size` | unchanged — both vocabularies are S/M, so no re-sizing is ever needed |
| `needs: T-01, T-03` | `blocked_by` | translate through the ID map → `[01-01, 02-01]`. `—` → `[]` |
| `files: a.ts, b.ts` | `files` | `[a.ts, b.ts]`, `—` or absent → `[]` |
| — | `issue` | empty |
| — | `pr` | empty — `ck-project backfill` recovers it later from the linked issue |
| — | `delivery` | empty ≡ pre-6.4 behaviour |
| — | `prior_status` | empty |

Frontmatter stays generator-readable: one `key: value` per line, inline `[…]` lists,
no block scalars.

## Epic frontmatter

One `EPIC.md` per inferred epic, carrying the **same eight keys** a freshly planned epic
does — a lite-migrated epic must be indistinguishable from a planned one:

| lite source | v6 frontmatter | Rule |
|---|---|---|
| (grouping) | `epic` | `NN`, matches the folder |
| (grouping) | `slug` | the kebab-cased epic slug; the same slug names its feature-doc folder, so `FEATURE_INDEX.Docs` links |
| (grouping) | `title` | the epic name, title-cased |
| (grouping) | `description` | one line summarising that epic's stories — becomes the `FEATURE_INDEX` Description cell; no `\|` |
| — | `issue` | empty — lite publishes no issues |
| — | `pr` | empty |
| — | `delivery` | empty |
| — | `integration` | empty (≡ `story`, one PR per story) — the right default for a just-migrated project; `build` fills it on the epic's first story |

Emit all eight lines even though four are empty.

## Story body

Moved **verbatim** — checkbox state included, so completed work stays completed.

| lite section | v6 section |
|---|---|
| (task title) | `## Description` — the title as a sentence; add nothing the plan does not say |
| `### Acceptance` | `## Acceptance Criteria` |
| `### Tasks` | `## Implementation Tasks` |
| `### Notes` | `## Technical Notes` |

A lite task has no description prose beyond its title. Never invent one — a thin
`## Description` is correct; a fabricated one is a defect.

## Plan-folder files

| File | Content source |
|---|---|
| `PROJECT_OVERVIEW.md` | Project Overview Template in [`templates.md`](../../plan/references/templates.md); Vision from the `ARCHITECTURE.md` intro paragraph, Tech Stack from `## Stack`, Key Design Decisions from `## Decisions`. Anything lite does not record → `[TO BE DEFINED]`. |
| `ROADMAP.md` | ROADMAP.md Template in [`roadmap-format.md`](../../plan/references/roadmap-format.md); phases follow the epic order, dependencies from the translated `blocked_by`. |
| `epics/NN_<slug>/EPIC.md` | Epic Template in [`templates.md`](../../plan/references/templates.md), frontmatter per [§ Epic frontmatter](#epic-frontmatter) above. No `## Stories` table. |

## `docs/ARCHITECTURE.md` → `docs/architecture/`

Every target file comes from
[`architecture-templates.md`](../../design/references/architecture-templates.md).

| lite section | v6 destination |
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

One `docs/architecture/features/<epic-slug>/index.md` per epic, so
`FEATURE_INDEX.Docs` resolves.

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
   > **Superseded.** Migrated to the ck-code v6 layout on <date>.
   > The live plan is `tasks/<plan-folder>/` — see its `STORIES_INDEX.md`.
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
`"ck-code@ck-marketplace": true`, in the migration commit, and tell the user the change
takes effect after a session restart. On **Leave it**: change neither key yourself and say
so in the report. Never edit any other key in that file.

**`ck-bootstrap install` sets `"ck-code@ck-marketplace": true` regardless of this answer** —
it is the guard installer Phase 5 runs beside the stamp
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
- the plugin swap: the answer, **and the final value of both `enabledPlugins` keys** —
  `ck-code@ck-marketplace` is `true` either way because `ck-bootstrap install` sets it, so
  say plainly whether `ck-code-lite@ck-marketplace` is still `true` and how to turn it off
- lite artifacts renamed / bannered
