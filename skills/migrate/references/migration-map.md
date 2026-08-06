# Migration Map — v3 (and older) → v6 Field Conversion

Exact source→target mappings for `/ck-code:migrate`. The v6 target layout is defined in
[`data-model.md`](../../../references/data-model.md).

## Story fields

v3 story files carry no frontmatter; state lives in prose. v5 prepends a frontmatter
block and keeps the body untouched.

| v5 frontmatter key | v3 source | Conversion |
|---|---|---|
| `id` | `# Story EE-SS: …` heading, or the `EE-SS` filename/index | keep `EE-SS` |
| `title` | text after `# Story EE-SS:` | strip the `Story EE-SS:` prefix |
| `epic` | parent folder `epics/NN_<slug>/` | `NN` |
| `status` | `> **Status:** X` line | `TODO`→`todo`, `IN PROGRESS`→`in-progress`, `DONE`→`done`, `SKIP`→`skip`, `BUG`→`bug` |
| `size` | the epic's `## Stories` table row, or a `Size:` line | `S`/`M` kept; `L`/`XL`→`M` (flag in report) |
| `blocked_by` | `## Dependencies` section (story IDs) | `[id, ...]`; none → `[]` |
| `files` | `## Files to Create/Modify` table (backtick-wrapped paths) | `[path, ...]`; none → `[]` |
| `issue` | a `#NNN` in the story body; else `gh issue list` match on the `[EE-SS]` title tag | the number, or empty |
| `pr` | — | empty. The pointer is unknowable from the old layout; `ck-project backfill` recovers it from the linked issue after the migration |
| `delivery` | — | empty ≡ pre-6.4 behaviour, so a migrated project keeps working untouched |
| `prior_status` | the Bug Report's `Prior status:` (only when `status: bug`) | the recorded status, else empty |

Result prepended above the existing `# Story …` heading:

```markdown
---
id: 02-01
title: Login form
epic: 02
status: in-progress
size: M
blocked_by: [01-01]
files: [src/auth/login.tsx, src/auth/session.ts]
issue: 123
pr:
delivery:
prior_status:
---

# Story 02-01: Login form
...unchanged body...
```

The v3 in-body `> **Status:** …` line becomes redundant. Leave it if removing it risks
disturbing prose; the frontmatter `status` is authoritative regardless. Prefer removing
it when it sits cleanly on its own line, to avoid a stale second copy.

## Epic fields

`EPIC.md` gains frontmatter and loses its `## Stories` table (now generated).

| v5 frontmatter key | v3 source |
|---|---|
| `epic` | parent folder `NN` |
| `slug` | parent folder slug (`NN_<slug>` → `<slug>`) |
| `title` | the epic title heading |
| `description` | the `Goal:` line or first description sentence |

Remove the entire `## Stories` table section. Keep Goal, scope, and any other authored
prose. The generated `STORIES_INDEX.md` is now the only story listing.

## Feature-doc fields

Each `docs/architecture/features/<slug>/index.md` gains:

```markdown
---
slug: <slug>
design: planned
---
```

- `slug` — the feature key (folder name).
- `design` — `planned` if the feature has any epic/story in `tasks/`, else `pending`.
  Fold in `DESIGN_LEDGER.md` state if present: a `planned` ledger row → `planned`, a
  `pending` row → `pending`. Then delete `DESIGN_LEDGER.md`.

## Pre-v3 architecture docs

Only when Phase 1 detects a pre-v3 doc layout. Mechanical, link-preserving moves:

1. **Flat feature doc → subfolder.** `docs/architecture/features/<slug>.md` →
   `docs/architecture/features/<slug>/index.md` (`mkdir -p` the folder, `git mv` the
   file). Rewrite its relative links one hop deeper: `../_shared.md` → `../../_shared.md`,
   `../folder-structure.md` → `../../folder-structure.md`.
2. **Legacy layer docs → per-feature.** Split `components.md` / `api-contracts.md` /
   `database-schema.md` / `data-flow.md` by feature: a component/endpoint/table/flow goes
   to the feature that owns it; anything ≥2 features share goes to `_shared.md`. Write
   each feature's slices into its `features/<slug>/index.md`. Move the originals to
   `docs/architecture/archive/` — never delete.
3. Add the `slug` + `design` frontmatter (above) to each resulting `index.md`.

If a feature's owner is ambiguous when splitting a layer doc, list the ambiguous pieces
and ask before assigning — never guess silently.

## Vocabulary changes to surface in the report

- Every status re-spelled (`IN PROGRESS` → `in-progress`, etc.) — mechanical, list the count.
- Every `L`/`XL` story re-sized to `M` — list each by ID so the user can split it later.
- `DESIGN_LEDGER.md` retired — state moved to `design:` flags.
- Journal/delta/design-record docs left inert (not deleted, no longer written).
- Any story file that could not be parsed into frontmatter — list explicitly.
