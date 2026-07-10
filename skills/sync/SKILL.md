---
name: sync
description: Use to reconcile `STORIES_INDEX.md`, `EPIC.md`, and story files when they drift out of sync — after a failed sync, manual edits, git merges, or to verify project state. Story files are the source of truth; index and epics are rewritten to match.
argument-hint: "[tasks/<slug> | --all]"
disable-model-invocation: true
effort: low
---

# Sync — Story Index, Epic & Story Reconciler

Detects and (after confirmation) repairs drift between `STORIES_INDEX.md`, each
`EPIC.md` story list, and the individual story files under
`tasks/<slug>/epics/*/stories/*.md`.

For diff and report templates, see [references/sync-report.md](references/sync-report.md).
For the index format and mutation contract, see [`../../references/stories-index.md`](../../references/stories-index.md).

## ROUTING CHECK (do first)

This skill **reconciles drift** between story files, index, and epics.
If the request is actually something else, STOP and recommend the better skill:

- Adding a new story → `/ck-code:quick-story`
- Just viewing progress → `/ck-code:track`

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).

## INPUT

`$ARGUMENTS` is either a `tasks/<slug>` path (sync that one plan), `--all` (sync every plan folder), or empty (interactive plan picker).

## PHASE 0: VERSION GATE (hard gate)

Read `tasks/VERSION.md`. If `layout: v3` → PASS, proceed. Otherwise run the shared [version gate](../../references/version-gate.md) (HARD GATE) — it detects, offers `/ck-code:doc-optimizer upgrade`, and stamps.

## PHASE 1: SELECT PLAN(S)

### 1.1 Resolve Argument

- Path provided → validate it exists, contains `PROJECT_OVERVIEW.md` or `FEATURE_OVERVIEW.md`, then sync that plan only.
- `--all` → Glob `tasks/*/PROJECT_OVERVIEW.md` and `tasks/*/FEATURE_OVERVIEW.md`; sync each in turn.
- Empty → list every plan folder with last-modified date, ask the user to pick one (or `ALL`).

### 1.2 Per-Plan Sync

For each selected plan, run Phases 2–5. Report per-plan results separately.

## PHASE 2: SCAN

### 2.1 Read the Story Files

Glob `tasks/<slug>/epics/*/stories/*.md`. For each story, extract:

- ID (from `# Story EE-SS:` header)
- Title
- Status (`TODO` / `IN PROGRESS` / `DONE` / `SKIP`)
- Size (`S` / `M` / `L` / `XL`)
- Blocked by (from `## Dependencies` section, or `-`)
- Parent epic display name (from parent folder name, `NN_slug` → `NN · Slug Title-Cased`)
- File path relative to `tasks/<slug>/`

### 2.2 Read the Index

Read `tasks/<slug>/STORIES_INDEX.md`. Parse the table into rows keyed by ID.

If the file is missing or the schema header is not `<!-- Schema: v1 -->`, fall through to **bootstrap** (write a fresh index from the scanned story files) — see the Bootstrap procedure in [`../../references/stories-index.md`](../../references/stories-index.md). Skip Phase 3 in that case and report `Bootstrapped index from N stories.`

### 2.3 Read Each EPIC.md Story List

For each `tasks/<slug>/epics/*/EPIC.md`, parse the story list (table or bullet list — preserve whichever format the file uses).

## PHASE 3: DIFF

Compute these diff sets:

| Set              | Definition                                                                              | Repair                                               |
| ---------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| **Index drift**  | Index row's `Status` / `Size` / `Blocked by` / `Title` differs from the story file      | Rewrite cell(s) in the index to match the story file |
| **Index orphan** | Story file exists with no matching index row                                            | Insert row into index in `ID` order                  |
| **Index stale**  | Index row exists with no matching story file                                            | Remove row from index                                |
| **Epic drift**   | Story listed in `EPIC.md` differs from the actual story file (title / status / missing) | Rewrite the entry                                    |
| **Epic orphan**  | Story file exists in epic folder but is not in `EPIC.md`'s list                         | Append entry in `SS` order                           |
| **Epic stale**   | `EPIC.md` lists a story that has no file                                                | Remove entry                                         |

The story file is the **source of truth** for content (status, size, dependencies). The index and EPIC lists are derived views — `sync` rewrites them to match the files, never the other way around.

## PHASE 4: PRESENT REPORT & CONFIRM

Show the diff using the report template in `references/sync-report.md`. Three possible outcomes:

- `IN SYNC` — no diffs found. Report and stop.
- `DRIFT FOUND` — present the per-row diff and the proposed writes; wait for `YES` / `ABORT` / `SELECT` (apply only specific repairs).
- `ERRORS` — malformed story files or unparseable EPIC entries: report each problem with the file path and stop without writing.

On `SELECT`, ask the user which diff items to apply (by row number); then proceed to Phase 5 with only that subset.

## PHASE 5: WRITE

For each approved repair:

1. **Index repairs** — apply cell-only Edits per [`../../references/stories-index.md`](../../references/stories-index.md) Mutation Protocol. Insert / remove rows as whole-line edits, preserving the table layout.
2. **EPIC.md repairs** — apply Edits to the story list section only; do not touch the rest of the epic body.

After each write, re-read the file and verify the change landed. If a write fails (missing `old_string` match, hook rejection, etc.), report the failure and continue with the remaining repairs — do not abort the batch.

## PHASE 6: REPORT

Print a final per-plan summary:

- Repairs applied: [count]
- Repairs skipped (user `SELECT`): [count]
- Repairs failed (write errors): [count]
- Files now in sync: [list]

If any repair failed, instruct the user to fix the file by hand and re-run `/ck-code:sync`.

## RULES

- **Story files are the source of truth** — `sync` never rewrites a story file based on the index. Edit the story file directly first, then re-run `sync`.
- **Always confirm before writing.** No diff is applied without explicit `YES` (or a `SELECT` subset).
- **Never edit the index header** — the `<!-- AUTO-GENERATED ... -->` and `<!-- Schema: v1 -->` lines are the contract.
- **Bootstrap is allowed only when the index is missing or schema-incompatible.** If the index exists with the right schema, treat orphans / stale rows as drift, not as a reason to regenerate.
- **Per-plan isolation.** When `--all` is used, a failure in one plan must not block syncing the others.
- **Read-only by default.** Phases 1–4 never write. Only Phase 5 mutates files, and only after explicit confirmation.
- **Language: English** for all output.

---

## NEXT

After `sync` reports `IN SYNC` (or applies repairs successfully), continue with whatever skill you were running:

- `/ck-code:fix` if the drift was caused by a failed stub-story sync.
- `/ck-code:track` to see the corrected dashboard.
- `/ck-code:build` to pick up the next ready story.
