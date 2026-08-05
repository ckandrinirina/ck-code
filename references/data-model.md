# Data Model — v6 (Shared Source of Truth)

The v6 layout has **one writable source of truth for story state: the story file's
YAML frontmatter.** Every index (`STORIES_INDEX.md`, `FEATURE_INDEX.md`) is a
**generated, read-only view** regenerated from frontmatter — never hand-edited,
never independently mutated. This is what removes drift: a view is a pure function
of the frontmatter, so it cannot disagree with it. There is no reconciler skill
because there is nothing to reconcile — you regenerate.

The layout constant is `v6` (see [`version-gate.md`](version-gate.md)). A pre-v6
project is blocked and routed to `/ck-code:migrate`.

## Epic and story numbers are globally unique

**An epic number is unique across every plan in the project, and therefore so is a
story `id`.** `EE-SS` names exactly one story anywhere in `tasks/`.

This is the whole of v6. Through v5, epic numbering restarted at `01` inside each new
plan folder, so two plans could both own epic `01` and story `01-01`. Everything that
consumes an ID — `build --epic NN`, `build EE-SS`, `blocked_by`, the `epic/<NN>-*`
branch glob ([`branch-topology.md`](branch-topology.md)), `ck-doctor`'s dependency
graph — then had no way to tell which plan was meant, and silently resolved to
whichever it reached first.

What the invariant buys, stated plainly:

- **An ID never needs a plan qualifier.** `--epic 07` and `07-02` resolve on their
  own — no feature gate, no "which plan?" prompt.
- **`blocked_by` may cross plans**, because a dependency on any story in the project
  is now expressible.
- **`epic/<NN>-*` matching more than one branch means a stale branch**, never two plans.

`plan` allocates each new epic from the project-wide maximum, derived from the folders
on every run and never stored:

```bash
find tasks -mindepth 3 -maxdepth 3 -type d -path 'tasks/*/epics/*' 2>/dev/null \
  | sed 's|.*/epics/||;s|_.*||' | sort -n | tail -1
```

Next epic is that + 1, zero-padded; `01` when it returns nothing. A stored counter
would be a second source of truth that can drift from the folders — the exact failure
class this data model exists to eliminate.

The ID *format* is unchanged from v5; only its scope widened. Team-generated skills
still live in flat `.claude/skills/expert-*/` and `guide-*/` folders, never nested
under `experts/` or `guides/` (that was v5's change).

## Story file (the source of truth)

`tasks/<slug>/epics/NN_<epic-slug>/stories/SS_<story-slug>.md`

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
| `id` | `EE-SS` | epic + story number, zero-padded. The stable key — **globally unique across every plan**. |
| `title` | text | story title, no `Story EE-SS:` prefix |
| `epic` | `NN` | parent epic number (matches the folder) |
| `status` | `todo` \| `in-progress` \| `done` \| `skip` \| `bug` | the single status of record |
| `size` | `S` \| `M` | one-dispatch sizing; larger work is split at a seam (no `L`/`XL`) |
| `blocked_by` | `[id, ...]` or `[]` | story IDs that must be `done` first; may name a story in another plan |
| `files` | `[path, ...]` or `[]` | files the story creates/modifies — the conflict-detection and touched-files key |
| `issue` | number or empty | linked GitHub issue, written by `ship` (incl. `--to-issues`); empty until pushed |
| `prior_status` | status or empty | set to the pre-`bug` status when `status: bug`; restored on fix |

**Format contract (so the generator can read it without a YAML library):** one key
per line, `key: value`; list values are inline flow style `[a, b, c]` (or `[]`);
no block/multiline scalars in frontmatter. Body prose is free-form Markdown below
the closing `---`. `status` and `size` are lowercase/uppercase exactly as the enum.

## Epic file (`plan` output)

`tasks/<slug>/epics/NN_<epic-slug>/EPIC.md` carries frontmatter the generator reads:

| Key | Values | Meaning |
|---|---|---|
| `epic` | `NN` | epic number — the rollup key; **must match the folder prefix**, and **unique across every plan** |
| `slug` | text | routes the `FEATURE_INDEX` `Docs` cell to `docs/architecture/features/<slug>/index.md`; set it to the owning feature-doc dir name (defaults to the folder slug) |
| `title` | text | epic display title |
| `description` | text | one line — becomes the `FEATURE_INDEX` Description cell |
| `issue` | number or empty | linked GitHub issue, written by `ship --to-issues` |
| `integration` | `story` \| `epic` \| `feature` \| empty | where this epic's work is proposed for review; empty ≡ `story`. Branch names are **derived, never stored** — see [`branch-topology.md`](branch-topology.md) |

Same format contract as story frontmatter. `title` and `description` must not
contain `|` (they are emitted into markdown table cells).

## Feature doc (`design` output)

`docs/architecture/features/<slug>/index.md` carries frontmatter too:

```markdown
---
slug: auth
design: planned
---
```

- `slug` — the feature key; matches the epic slug and the `Docs` routing path.
- `design` — `pending` (design written, not yet planned) or `planned` (a `plan`
  run has turned it into epics/stories). This one flag **replaces `DESIGN_LEDGER.md`**:
  `design` sets `pending`, `plan` flips it to `planned`. No separate ledger file, no
  dated design-record journal — git is the design history.

Delta/journal docs are **not** written in v5. A change's history is its commits.
`index.md` always holds current truth.

## Generated views (read-only, never hand-edited)

Both are produced by `scripts/ck-index.sh` (ships with the plugin). Each carries a
`GENERATED — DO NOT EDIT` header. A skill that changes any story frontmatter
regenerates them in the same phase by running the script; it never edits a cell.

- **`tasks/<slug>/STORIES_INDEX.md`** — one row per story in that plan, from each
  story's frontmatter. The selection/dependency source for `build`,
  `track`, `fix`.
- **`tasks/FEATURE_INDEX.md`** — one row per epic across all plans, rolled up from
  story statuses. `build` reads it first to pick a feature.

Status rollup (computed, never stored): a feature is `DONE` when every non-`skip`
story is `done`; `IN PROGRESS` when any story is `in-progress`/`bug` or some-but-not-all
are `done`; `TODO` when none has started. A `bug` story counts as not-done.

## Regeneration contract

```bash
ck-index            # all plans + feature index
ck-index tasks/<slug>   # one plan + feature index
```

The script reads only frontmatter (not story bodies), so it is cheap and cannot be
wrong. Call it after any frontmatter mutation. Because the views are generated,
there is no per-worktree "defer the shared-index edit" hazard: a `build`
PARALLEL MODE worktree edits only its own story's frontmatter, and the orchestrator
regenerates the views once on the target branch after merges.

## VERSION stamp

`tasks/VERSION.md` records `layout: v6`. The version gate reads it for a one-line
fast path; `migrate` writes it as its final step.

## What v5 had that v6 removes

| v5 | v6 |
|---|---|
| epic numbering restarts at `01` in each new plan folder | every epic allocated from the project-wide maximum |
| `EE-SS` unique only within its plan | `EE-SS` names one story anywhere in `tasks/` |
| `--epic NN` / `EE-SS` need a plan to resolve against | they resolve on their own |
| `blocked_by` confined to its own plan | may name any story in the project |
| `epic/<NN>-*` matching twice = two plans, ask which | matching twice = a stale branch |

## What v3 had that v5 removed

| v3 | v5 |
|---|---|
| status cell-edited in story file + `STORIES_INDEX` + `FEATURE_INDEX` + `EPIC.md` | status in frontmatter only; views regenerated |
| `sync` skill to repair story↔index↔epic drift | deleted — views are generated, nothing drifts |
| `DESIGN_LEDGER.md` pending/planned rows | `design:` frontmatter flag on the feature doc |
| dated design-record + delta journal docs (write-only, never read) | none — git is history |
| `EPIC.md` `## Stories` table (a second story list) | dropped — `STORIES_INDEX` is the only story listing |
| byte-exact `old_string` cell replacement | run the generator |
| issue linkage by title-substring `contains("02-1")` | `issue:` number in frontmatter |
| `L`/`XL` sizes | `S`/`M` only (split larger work) |

## Rules

- **Never hand-edit a generated view** — regenerate from frontmatter with `ck-index`.
- **Never store status anywhere but story frontmatter** — every other status display is derived.
- **Never write a delta/journal doc** — commits are the history.
- **Always run `ck-index` in the same phase** you change any story's frontmatter.
- **Frontmatter stays generator-readable** — one `key: value` per line, inline `[...]` lists, no block scalars.
- **Never restart epic numbering in a new plan** — allocate from the project-wide maximum, or two plans collide and every ID consumer silently picks the wrong one.
- **Never store the next epic number** — derive it from the epic folders on every run.
- **Never qualify an ID with its plan** — `EE-SS` and `NN` are unique project-wide; a skill that asks which plan an ID belongs to is working around a collision that `/ck-code:migrate` should fix.
