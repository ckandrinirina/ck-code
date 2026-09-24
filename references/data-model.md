# Data Model — v7 (Shared Source of Truth)

The v7 layout has **one writable source of truth for story state: the story file's
YAML frontmatter.** What belongs to a whole plan lives in that plan's record,
`OVERVIEW.md`. Every index (`STORIES_INDEX.md`, `EPICS_INDEX.md`) is a **generated,
read-only view** of that frontmatter: never hand-edited, never committed, never
independently mutated. A view is disposable. When one is missing or older than the
frontmatter it was built from, it is regenerated on the next read, so a stale view is
never the thing a skill decides from. There is no *index* reconciler: regenerating is the
whole repair. `ck-project reconcile` (run by `/ck-code:doctor --fix`) reconciles a
separate axis instead: `delivery`, the GitHub Projects board, and Issues state against
what GitHub actually did ([`github-projects.md`](github-projects.md)).

The layout constant is `v7` (see [`version-gate.md`](version-gate.md)). An older project
is blocked and routed to `/ck-code:migrate`. What earlier layouts did differently is in
`CHANGELOG.md`, not here.

## Layout

```
tasks/
  VERSION.md            layout: v7 / requires: ck-code >= 7.0.0   (rewritten only by migrate or project creation)
  .gitignore            STORIES_INDEX.md, EPICS_INDEX.md           (written by ck-index when missing; committed)
  SETTINGS.md           optional project settings                  (committed)
  EPICS_INDEX.md        GENERATED, gitignored — one row per epic across all plans
  <date>_<slug>/        one plan
    OVERVIEW.md         plan record (frontmatter) + prose body (Vision, Architecture, …)
    ROADMAP.md
    STORIES_INDEX.md    GENERATED, gitignored — one row per story of this plan
    epics/NN_<slug>/EPIC.md
    epics/NN_<slug>/stories/SS_<slug>.md
docs/specs/<date>_<slug>/
  spec.md               stakeholder spec (`spec` output)
  .metadata.json        spec metadata (below)
  design-brief.md       only when a design-system brief was handed out
docs/architecture/features/<slug>/index.md    feature doc (`design` output)
docs/architecture/design-system/
  index.md              human-readable body only, no frontmatter
  manifest.json         the one home of the design-system metadata
```

## Epic and story numbers are globally unique

**An epic number is unique across every plan in the project, and therefore so is a
story `id`.** `EE-SS` names exactly one story anywhere in `tasks/`. Everything that
consumes an ID (`build --epic NN`, `build EE-SS`, `blocked_by`, the `epic/<NN>-*` branch
glob in [`branch-topology.md`](branch-topology.md), `ck-doctor`'s dependency graph)
resolves it on its own, with no plan to disambiguate against.

`plan` allocates each new epic from the project-wide maximum, derived from the folders
on every run and never stored:

```bash
find tasks -mindepth 3 -maxdepth 3 -type d -path 'tasks/*/epics/*' 2>/dev/null \
  | sed 's|.*/epics/||;s|_.*||' | sort -n | tail -1
```

Next epic is that + 1, zero-padded; `01` when it returns nothing. A stored counter
would be a second source of truth that can drift from the folders.

Team-generated skills live in flat `.claude/skills/expert-*/` and `guide-*/` folders,
never nested under `experts/` or `guides/`.

## Plan record (`tasks/<plan>/OVERVIEW.md`)

Written by `plan` when it creates the plan. The frontmatter is the plan's record; the
body below it is prose (Vision, Architecture, …) that `ck-issues --mode plan` reads for
the plan issue.

```yaml
---
slug: billing
title: Billing
integration: story      # story | epic | plan
branch:                 # plan-level branch, empty unless integration: plan
issue:                  # plan issue from `plan --publish --mode plan`
pr:                     # plan-level PR (integration: plan)
delivery:               # empty | pr | merged | direct
---
```

| Key | Values | Meaning | Written by |
|---|---|---|---|
| `slug` | text | the plan slug (folder name without the date prefix) | `plan` |
| `title` | text | plan display title | `plan` |
| `integration` | `story` \| `epic` \| `plan` | where the plan's work is proposed for review ([`branch-topology.md`](branch-topology.md)). Empty ≡ `story` | `plan` at creation, `/ck-code:config integration`, build P3's switch to `epic`, all through `ck-plan set` |
| `branch` | branch name or empty | the plan-level branch at level `plan`. `ck-plan set … integration=plan` records `plan/<slug>` when it is empty; a migrated plan may carry `feat/<slug>`, and the field wins | `ck-plan set` |
| `issue` | number or empty | the plan issue | `ck-issues --mode plan` |
| `pr` | number or empty | the plan PR (plan branch → trunk) | `ship --promote` |
| `delivery` | empty \| `pr` \| `merged` \| `direct` | the plan PR's state | `ship --promote` (`pr`), reconciled by `ck-project` |

Keys appear in exactly this order. `ck-plan set tasks/<plan> key=value…` is the writer for
`integration`, `branch`, `pr` and `delivery` and validates each enum; `ck-issues` writes
`issue` when the plan is published (`--mode plan`). `ck-plan get tasks/<plan> [key…]` reads
it. A plan's
integration level is chosen **once**, when `plan` creates it; changing it later is an
explicit `/ck-code:config integration <tasks/plan> <level>`, never a side effect.

## Story file (the source of truth)

`tasks/<plan>/epics/NN_<epic-slug>/stories/SS_<story-slug>.md`

```markdown
---
id: 02-01
title: Login form
epic: 02
status: todo
size: S
blocked_by: [01-01]
files: [src/auth/login.tsx, src/auth/session.ts]
issue: 123
pr:
delivery:
prior_status:
---

# Story 02-01: Login form

## Description
...

## Acceptance Criteria
- [ ] ...

## Implementation Tasks
- [ ] ...

## Technical Notes
...
```

**Frontmatter fields (the authoritative record):**

| Key | Values | Meaning |
|---|---|---|
| `id` | `EE-SS` | epic + story number, zero-padded. The stable key, **globally unique across every plan**. |
| `title` | text | story title, no `Story EE-SS:` prefix |
| `epic` | `NN` | parent epic number (matches the folder) |
| `status` | `todo` \| `in-progress` \| `done` \| `skip` \| `bug` | the single status of record |
| `size` | `S` \| `M` | one-dispatch sizing; larger work is split at a seam (no `L`/`XL`) |
| `blocked_by` | `[id, ...]` or `[]` | story IDs that must be `done` or `skip` first; may name a story in another plan |
| `files` | `[path, ...]` or `[]` | files the story creates/modifies: the conflict-detection and touched-files key. `ck-story files` merges the paths a build actually touched |
| `issue` | number or empty | linked GitHub issue, written by `plan --publish` or `ship`; empty until published |
| `pr` | number or empty | the **latest** PR carrying this story's work, written by `ship`; empty until a PR exists |
| `delivery` | empty \| `pr` \| `merged` \| `direct` | how far that work has travelled toward the trunk branch: the second axis, below |
| `prior_status` | status or empty | set to the pre-`bug` status when `status: bug`; restored on fix |

**Format contract (so the generator can read it without a YAML library):** one key
per line, `key: value`; list values are inline flow style `[a, b, c]` (or `[]`);
no block/multiline scalars in frontmatter. Body prose is free-form Markdown below
the closing `---`. `status` and `size` are lowercase/uppercase exactly as the enum.

State fields (`status`, `prior_status`, `delivery`, `pr`, `issue`, `size`) are written
with `ck-story set`; structural fields (`id`, `epic`, `title`, `blocked_by`) belong to
`plan` and `migrate`.

## The Ready rule

A story is **ready** when `status: todo` and every `blocked_by` story is `done` or
`skip`, or when `status: bug`. A skipped blocker releases its dependants: it is work the
plan decided not to do, and a dependant waiting on it would wait forever. An
`in-progress` story is not ready; `build` may resume it when it is named explicitly.

Every script reads this one rule from `scripts/lib/ck-common.sh` (`ck_blocker_met`); every
skill states it in these words.

## Two axes: `status` is work, `delivery` is integration

`status` answers *is the work finished?* (acceptance criteria met, QA green). `delivery`
answers *how far has it travelled toward the trunk branch?* They are **orthogonal**: a
story is `done` the moment `build` finishes it, whether it sits committed on a local
branch, in an open PR, or on `main`.

| `delivery` | Means | Written by |
|---|---|---|
| *(empty)* | nothing open for review, committed locally at most | `plan` scaffolds it empty |
| `pr` | PR `pr:` is open | `ship`, when it creates or updates the PR |
| `merged` | PR `pr:` merged into the trunk branch | `ck-project sync` reconciliation |
| `direct` | on the trunk branch, no PR ever opened | `ck-project landed`, from git |

**`status: done` means work-complete and nothing else.** `blocked_by` resolves against
`status` alone (the Ready rule above), never against `delivery`: at level `epic` a story
merges into its epic branch and never touches the trunk
([`branch-topology.md`](branch-topology.md)), so gating dependencies on `merged` would
deadlock every epic-level plan.

**Inheritance: story → epic → plan.** At level `epic` or `plan` a story never gets its
own PR, so `EPIC.md` and `OVERVIEW.md` carry the same `pr`/`delivery` pair and resolution
walks up: the story's own `pr:`, else its epic's `pr:`, else its plan's `pr:`, else
empty. A merged epic PR delivers every story of that epic; a merged plan PR delivers
every story of the plan.

The walk-up happens in `ck-project sync` and **nowhere else**: it writes both the
resolved `delivery:` *and* the `pr:` it resolved through onto the story, so every other
consumer reads one field on one file. Consequently `delivery: pr|merged` and `pr:` are
either both set or both empty; a `pr`/`merged` with no `pr:` is a defect `ck-doctor`
reports, not a valid state.

**`direct` is the one value that means "no PR".** Merge a story branch into the trunk
yourself and push, and there is no PR number to record. `direct` says the work arrived
without review, and it goes straight to Done: `ready_to_ship` and `in_review` are states
a PR passes through, and there was no PR. `ck-doctor` therefore exempts `direct` from the
anchor rule and reports the reverse (a `direct` **with** a `pr:`), because a story with a
PR is `pr` or `merged`, and only `ck-project sync` decides which.

It is derived from git, never authored: `ck-project landed` (and every `sync`, which runs
its provable tier) asks whether the trunk's own copy of the story file already reads
`status: done`, having arrived with code rather than in a bookkeeping commit. Work with no
such proof is reported as a candidate and written only on confirmation, because "the
files exist on `main`" is also true of files a later story created.

**`pr:` is the *latest* PR, not a permanent one.** A defect found in merged code keeps
`delivery: merged` while `status: bug`; the fix PR overwrites `pr:` and resets
`delivery: pr`. A PR closed **without** merging resets `delivery` to empty and warns.

## Epic file (`plan` output)

`tasks/<plan>/epics/NN_<epic-slug>/EPIC.md` carries frontmatter the generator reads:

| Key | Values | Meaning |
|---|---|---|
| `epic` | `NN` | epic number, the rollup key; **must match the folder prefix**, and **unique across every plan** |
| `slug` | text | routes the `EPICS_INDEX` `Docs` cell to `docs/architecture/features/<slug>/index.md`; set it to the owning feature-doc dir name (defaults to the folder slug) |
| `title` | text | epic display title |
| `description` | text | one line, the `EPICS_INDEX` Description cell |
| `issue` | number or empty | linked GitHub issue, written by `plan --publish` |
| `pr` | number or empty | the epic's own PR (level `epic` only), written by `ship --promote`; the stories of this epic inherit it. At level `plan` an epic has no PR — it merges `--no-ff` into the plan branch and inherits the plan PR |
| `delivery` | empty \| `pr` \| `merged` \| `direct` | the epic PR's state, same enum and same writers as a story's |

There is **no `integration:` key** on an epic: the level is a plan property, stored once
in `OVERVIEW.md`. Branch names are derived from the epic number and the plan record
([`branch-topology.md`](branch-topology.md)).

The body keeps a `## Dependencies` prose section. It records *why* one epic waits on
another, which `blocked_by` cannot; it is not a copy of the story dependencies.

Same format contract as story frontmatter. The generator escapes a raw `|` in
`title`/`description` before emitting either into a markdown table cell, so it will
not break the table, but an escaped pipe still reads awkwardly in the rendered row, so
avoid it anyway.

## Feature doc (`design` output)

`docs/architecture/features/<slug>/index.md` carries frontmatter too:

```markdown
---
slug: auth
design: planned
---
```

- `slug`: the feature key; matches the epic `slug:` and the `Docs` routing path.
- `design`: `pending` (design written, not yet planned) or `planned` (a `plan` run has
  turned it into epics/stories). `design` sets `pending`, `plan` flips it to `planned`.
  No separate ledger file, no dated design-record journal: git is the design history.

Delta/journal docs are never written. A change's history is its commits. `index.md`
always holds current truth.

## Spec metadata (`spec` output)

`docs/specs/<date>_<slug>/spec.md` is the stakeholder spec. Beside it,
`.metadata.json` holds its machine state in a fixed key order: `slug`, `title`,
`language`, `audience`, `createdAt`, `updatedAt`, `status`, `tags`, `github`,
`linkedDesign`, `designSystem`. There is no `stage` key. `status` is one of `draft`,
`ready-for-design`, `design-in-progress`; `design` with no argument offers the newest
spec at `ready-for-design`. The full key contract, including the `designSystem` block,
is in [`templates.md`](../skills/spec/references/templates.md).

## Design-system metadata

`docs/architecture/design-system/manifest.json` is the **one** home of the design-system
metadata: `projectId`, `projectName`, `projectUpdatedAt`, `syncedAt`, `tokensPath`, and
the per-card `cards[]`. `index.md` beside it has no frontmatter; it is the human-readable
body (tokens, inventory, fidelity rules). See [`design-system.md`](design-system.md).

## Project settings (`tasks/SETTINGS.md`)

Optional, one per project, written by `/ck-code:config` (including `config board`) and by
`plan --publish` on first use. Flat frontmatter, same format contract as story files. It
holds *project* configuration, never story or plan state: nothing here is derived from,
or feeds back into, any frontmatter under `tasks/<plan>/`. Absent file ≡ every optional
integration off, which is why no skill may require it to exist.

| Key | Meaning |
|---|---|
| `github_issues` | `true` turns on GitHub issue tracking and the board; `false` or absent makes every board and issue call a no-op |
| `trunk_branch` | the branch a story must reach to count as delivered, and the base every PR targets ([`branch-topology.md`](branch-topology.md#resolution)). Absent, the repo default |
| `github_repo`, `github_project_owner`, `github_project_number`, `github_project_id` | the board's repository and Projects v2 identity, written by `/ck-code:config board` |
| `board_field`, `board_<role>`, `board_*_id`, `board_archive_skip` | the column mapping ([`github-projects.md`](github-projects.md#configuration--taskssettingsmd)) |
| `experts` | `none` means the project chose to run without team skills: the build/fix team gate never fires ([`skill-detection.md`](skill-detection.md)). Written by the gate's "Never ask in this project" answer |

## Generated views (read-only, never committed)

Both are produced by `scripts/ck-index.sh` and carry a `GENERATED by ck-code … DO NOT
EDIT` header. `tasks/.gitignore` excludes them (ck-index writes that file when it is
missing), so a clone, a checkout or a pull can leave one missing or behind the
frontmatter. That is harmless: every reader regenerates first.

- **`tasks/<plan>/STORIES_INDEX.md`**: one row per story in that plan, from each
  story's frontmatter. The selection/dependency source for `build`, `track`, `fix`
  ([`stories-index.md`](stories-index.md)).
- **`tasks/EPICS_INDEX.md`**: one row per epic across all plans, rolled up from
  story statuses. `build` reads it first to pick an epic ([`epics-index.md`](epics-index.md)).

**Who regenerates them:**

| Trigger | When |
|---|---|
| `session-start.sh` | at every session start, when a view is missing or stale |
| `ck-view` (`track`, dashboards) | before rendering, when a view is missing or stale |
| `ck-story set` | after every state write |
| `ck-project sync` / `reconcile` | after any `delivery` change |
| `ck-index [tasks/<plan>]` | on demand |

Status rollup (computed, never stored): an epic is `MERGED` when every non-`skip` story
is `done` **and** `delivery: merged` **or** `direct`; `DONE` when every non-`skip` story
is `done` but at least one has not reached the trunk; `IN PROGRESS` when any story is
`in-progress`/`bug` or some-but-not-all are `done`; `TODO` when none has started. A `bug`
story counts as not-done. `MERGED` and `DONE` are both **finished** states: every
consumer that computes an "unfinished set" excludes both ([`epics-index.md`](epics-index.md)).

**A skill never stages or commits a view.** A skill that flips story frontmatter commits
the story files, which are real state; the views follow on the next read. `ck-doctor`
reports a committed view as an ERROR (a v6 leftover, fixed by `/ck-code:migrate`).

## Regeneration contract

```bash
ck-index                 # every plan + the epic index
ck-index tasks/<plan>    # one plan + the epic index
```

The script reads only frontmatter (not story bodies), so it is cheap and deterministic.
Because the views are generated and local, there is no per-worktree "defer the shared-index
edit" hazard: a `build` PARALLEL MODE worktree edits only its own story's frontmatter, and
the orchestrator runs `ck-index` once on the target branch after merges.

## VERSION stamp

`tasks/VERSION.md` records `layout: v7` and `requires: ck-code >= 7.0.0`. The version
gate reads it for a one-line fast path. Nothing rewrites it except a migration or the
creation of a new project ([`version-gate.md`](version-gate.md)).

## Rules

- **Never hand-edit a generated view**: regenerate from frontmatter with `ck-index`.
- **Never stage or commit a generated view**: commit the story, epic or plan files that changed; the views regenerate on the next read.
- **Never store status anywhere but story frontmatter**: every other status display is derived.
- **Never redefine `status: done` as "merged"**: `done` is work-complete; delivery lives in `delivery`. `blocked_by` resolves against `done` or `skip`, never against `delivery`.
- **Never resolve `delivery` by hand**: `ship` writes `pr`/`delivery: pr`; only `ck-project sync` promotes it to `merged`, from GitHub's answer, and only it materializes an inherited epic or plan `pr:` onto a story.
- **Never open a PR for a `delivery:`/`pr:` change alone**: both are derived from a PR number the plan already holds, so they are committed on the current branch with no review.
- **Never write the plan record by hand**: `ck-plan set` is its one writer and validates every enum.
- **Never put `integration:` on an epic**: the level is a plan property, stored once in `OVERVIEW.md`.
- **Never write a delta/journal doc**: commits are the history.
- **Always change story state with `ck-story set`**, which writes the field, regenerates the views and syncs the board in one call. After a structural edit by hand, run `ck-index tasks/<plan>`.
- **Frontmatter stays generator-readable**: one `key: value` per line, inline `[...]` lists, no block scalars.
- **Never restart epic numbering in a new plan**: allocate from the project-wide maximum, or two plans collide and every ID consumer silently picks the wrong one.
- **Never store the next epic number**: derive it from the epic folders on every run.
- **Never qualify an ID with its plan**: `EE-SS` and `NN` are unique project-wide; a skill that asks which plan an ID belongs to is working around a collision that `/ck-code:migrate` should fix.
