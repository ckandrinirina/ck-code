# Data Model — v4 (Shared Source of Truth)

The v4 layout has **one writable source of truth for story state: the story file's
YAML frontmatter.** Every index (`STORIES_INDEX.md`, `FEATURE_INDEX.md`) is a
**generated, read-only view** regenerated from frontmatter — never hand-edited,
never independently mutated. This is what removes drift: a view is a pure function
of the frontmatter, so it cannot disagree with it. There is no reconciler skill in
v4 because there is nothing to reconcile — you regenerate.

The layout constant is `v4` (see [`version-gate.md`](version-gate.md)). A pre-v4
project is blocked and routed to `/ck-code:migrate`.

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
| `id` | `EE-SS` | epic + story number, zero-padded. The stable key. |
| `title` | text | story title, no `Story EE-SS:` prefix |
| `epic` | `NN` | parent epic number (matches the folder) |
| `status` | `todo` \| `in-progress` \| `done` \| `skip` \| `bug` | the single status of record |
| `size` | `S` \| `M` | one-dispatch sizing; larger work is split at a seam (no `L`/`XL`) |
| `blocked_by` | `[id, ...]` or `[]` | story IDs that must be `done` first |
| `files` | `[path, ...]` or `[]` | files the story creates/modifies — the conflict-detection and touched-files key |
| `issue` | number or empty | linked GitHub issue, written by `to-issues`/`ship`; empty until pushed |
| `prior_status` | status or empty | set to the pre-`bug` status when `status: bug`; restored on fix |

**Format contract (so the generator can read it without a YAML library):** one key
per line, `key: value`; list values are inline flow style `[a, b, c]` (or `[]`);
no block/multiline scalars in frontmatter. Body prose is free-form Markdown below
the closing `---`. `status` and `size` are lowercase/uppercase exactly as the enum.

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

Delta/journal docs are **not** written in v4. A change's history is its commits.
`index.md` always holds current truth.

## Generated views (read-only, never hand-edited)

Both are produced by `scripts/ck-index.sh` (ships with the plugin). Each carries a
`GENERATED — DO NOT EDIT` header. A skill that changes any story frontmatter
regenerates them in the same phase by running the script; it never edits a cell.

- **`tasks/<slug>/STORIES_INDEX.md`** — one row per story in that plan, from each
  story's frontmatter. The selection/dependency source for `build`, `parallel-build`,
  `track`, `fix`.
- **`tasks/FEATURE_INDEX.md`** — one row per epic across all plans, rolled up from
  story statuses. `build`/`parallel-build` read it first to pick a feature.

Status rollup (computed, never stored): a feature is `DONE` when every non-`skip`
story is `done`; `IN PROGRESS` when any story is `in-progress`/`bug` or some-but-not-all
are `done`; `TODO` when none has started. A `bug` story counts as not-done.

## Regeneration contract

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh"            # all plans + feature index
"${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh" tasks/<slug>   # one plan + feature index
```

The script reads only frontmatter (not story bodies), so it is cheap and cannot be
wrong. Call it after any frontmatter mutation. Because the views are generated,
there is no per-worktree "defer the shared-index edit" hazard: a `parallel-build`
worktree edits only its own story's frontmatter, and the orchestrator regenerates
the views once on the target branch after merges.

## VERSION stamp

`tasks/VERSION.md` records `layout: v4`. The version gate reads it for a one-line
fast path; `migrate` writes it as its final step.

## What v3 had that v4 removes

| v3 | v4 |
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

- **Never hand-edit a generated view** — regenerate from frontmatter with `ck-index.sh`.
- **Never store status anywhere but story frontmatter** — every other status display is derived.
- **Never write a delta/journal doc** — commits are the history.
- **Always run `ck-index.sh` in the same phase** you change any story's frontmatter.
- **Frontmatter stays generator-readable** — one `key: value` per line, inline `[...]` lists, no block scalars.
