---
name: doc-optimizer
description: Use when architecture docs under docs/architecture/ are bloated or slow to read for implementation, when a project is on a pre-v3 doc layout (the version gate sends it here), when a project still uses the legacy layer docs (components.md, api-contracts.md, database-schema.md, data-flow.md), or when features in FEATURE_INDEX lack a per-feature doc. Argument is `upgrade`, `migrate`, `sync`, or `optimize` (default).
argument-hint: "[upgrade|migrate|sync|optimize]"
disable-model-invocation: true
effort: medium
---

# Doc Optimizer — Feature-Scoped Architecture Docs

Keep `docs/architecture/` cheap to read during `build`/`fix`: one self-contained
doc per feature plus a single `_shared.md` for cross-cutting infra, routed by the
`Docs` column of `tasks/FEATURE_INDEX.md`. This skill migrates legacy layer docs into
that layout, scaffolds missing feature docs, and prunes duplication.

This is also the **v3 migrator**: the [version gate](../../references/version-gate.md)
in every change-producing skill sends pre-v3 projects here via `upgrade`. This skill
itself never gates — it is the fix.

The feature-doc and `_shared.md` templates are owned by `design` —
[../design/references/architecture-templates.md](../design/references/architecture-templates.md).
Use those verbatim; do not redefine them here. Migration heuristics, the dedup rules,
and the report format live in
[references/optimizer-playbook.md](references/optimizer-playbook.md).

---

## INPUT

Mode comes from `$ARGUMENTS`: `upgrade`, `migrate`, `sync`, or `optimize`. **Default
`optimize`** when empty. A mode is a hard scope — never run a mode the user did not ask
for. `upgrade` is the one-shot pre-v3 → v3 converter the version gate invokes; it chains
`migrate` + `sync` + the index rewrite + the ledger scaffold + the version stamp.

---

## PHASE 0: DETECT STATE

Run once, regardless of mode, to ground the run (read-only):

1. `Glob "docs/architecture/*.md"` and `Glob "docs/architecture/features/*.md"`.
2. Note which **legacy layer docs** exist: `components.md`, `api-contracts.md`,
   `database-schema.md`, `data-flow.md`.
3. Read `tasks/FEATURE_INDEX.md` if present — the feature list and `Docs` column are
   the routing authority. Note its schema (`v1` = no `Docs` column yet).
4. If `docs/architecture/` does not exist, tell the user to run `/ck-code:design` first
   and stop — there is nothing to optimize.

Then branch to the requested mode. If `migrate` is requested but no legacy layer docs
exist, say so and suggest `sync` instead.

---

## PHASE U: UPGRADE (`upgrade`) — one-shot pre-v3 → v3

The converter the [version gate](../../references/version-gate.md) calls. Idempotent and
safe (originals archived, never deleted). Run the existing phases in order, then stamp:

1. **Migrate layer docs** — if any retired layer doc (`components.md`, `api-contracts.md`,
   `database-schema.md`, `data-flow.md`) exists outside `archive/`, run **PHASE 1: MIGRATE**.
   Skip if none exist.
2. **Migrate flat → subfolder** — run **PHASE 2: SYNC** to move any flat
   `features/<slug>.md` to `features/<slug>/index.md`, sweep loose dated deltas, scaffold
   missing docs, and rewrite the `FEATURE_INDEX` header `v1 → v2` with the `Docs` column.
3. **Scaffold the design ledger** — if `docs/architecture/DESIGN_LEDGER.md` is missing,
   create it from the **DESIGN_LEDGER template** in
   [../design/references/architecture-templates.md](../design/references/architecture-templates.md),
   backfilling one `planned` row per feature that already has a built/`DONE` epic in
   `FEATURE_INDEX` (Date = today, Type = `new`, Plan ref = the epic's `Plan`). Leave an
   empty table (header only) when no features qualify. Never invent `pending` rows.
4. **Stamp the version** — write `tasks/VERSION.md` per the
   [version gate](../../references/version-gate.md) (`layout: v3`, `ck-code:` = the running
   plugin version). This is the **final** step — only after migration succeeded.
5. **Report** — features created/moved, archived files, index upgraded, ledger rows
   added, `VERSION.md` stamped, before/after token totals.

Already-v3 input is a no-op: phases 1–2 find nothing to move, the ledger may already
exist, and step 4 (re)writes the stamp. Report "already v3 — stamped clean".

---

## PHASE 1: MIGRATE (`migrate`)

Decompose legacy layer docs into the feature-scoped layout. Repeatable and safe —
originals are archived, never deleted.

1. Build the **feature list**: from `FEATURE_INDEX` if present, else from the headings
   in `components.md` / spec. Confirm the list with the user before slicing.
2. For each legacy layer doc, split its content by feature using the mapping rules in
   [references/optimizer-playbook.md](references/optimizer-playbook.md) — a component,
   endpoint, table, or flow goes to the feature that owns it; anything ≥2 features share
   goes to `_shared.md`.
3. For each feature, `mkdir -p docs/architecture/features/<slug>/` and Write
   `docs/architecture/features/<slug>/index.md` from the Feature Doc template, filling
   `## Components` / `## API` / `## Data` / `## Flows` with that feature's slices and
   linking shared pieces to `_shared.md` with `../../` relative paths (two hops up from
   `features/<slug>/`).
4. Write/extend `docs/architecture/_shared.md` with the cross-cutting content.
5. Move the originals to `docs/architecture/archive/` (`mkdir -p` first). Never delete.
6. Update the `README.md` index (Feature Documents table + changelog).
7. Run the **FEATURE_INDEX update** (below) to fill the `Docs` column and upgrade v1→v2.
8. Report: features created, `_shared.md` size, archived files, before/after token totals.

---

## PHASE 2: SYNC (`sync`)

Bring the doc set into lockstep with `FEATURE_INDEX` — the "as the project grows" pass.

1. Read `FEATURE_INDEX`. For each feature, check whether
   `docs/architecture/features/<slug>/index.md` exists (canonical), or a legacy flat
   `docs/architecture/features/<slug>.md` exists (pre-subfolder layout).
2. **Layout migration (legacy flat → subfolder)** → when a flat
   `features/<slug>.md` exists but `features/<slug>/index.md` does not: `mkdir -p
features/<slug>/`, move the file to `features/<slug>/index.md`, and rewrite its
   inbound/outbound relative links one hop deeper (`../_shared.md` → `../../_shared.md`,
   `../folder-structure.md` → `../../folder-structure.md`). Then sweep any **loose dated
   delta docs** sitting flat in `features/` (`features/YYYY-MM-DD_<...>.md`) into the
   parent feature folder they belong to — match by the feature each delta names; if the
   parent is ambiguous, list them and ask before moving. Never delete; only move.
3. **Missing** → `mkdir -p features/<slug>/` and scaffold
   `features/<slug>/index.md` from the Feature Doc template (header + section stubs +
   a `[TO BE DEFINED]` note), using the epic `Description` for the `## Summary`. Do not
   invent component/API/data detail — leave stubs for `design`/`build` to fill.
4. **Slug drift** → if a feature doc exists under a different slug than the epic
   (e.g. design used `roles`, plan's epic is `role-management`), rename the
   `features/<slug>/` folder to the epic slug and fix inbound links. Ask before renaming
   if ambiguous.
5. Run the **FEATURE_INDEX update** (below): set each `Docs` cell to the resolved
   `features/<slug>/index.md` path, `—` only when no doc could be created.
6. Update the `README.md` Feature Documents table.
7. Report: docs migrated (flat→subfolder), delta docs relocated, scaffolded, renamed,
   and any features left as `—`.

---

## PHASE 3: OPTIMIZE (`optimize`, default)

The token diet. Operates on the existing feature docs + `_shared.md` — never invents
content, only restructures and reports.

1. **Measure** — report a per-doc token estimate (see the report format in
   [references/optimizer-playbook.md](references/optimizer-playbook.md)) and a total.
   **Fan-out (≥8 feature docs):** dispatch one **read-only** `general-purpose` Agent per
   `features/<slug>/index.md` following the investigation variant in
   [../../references/subagent-fanout.md](../../references/subagent-fanout.md); each returns
   `{token estimate, candidate shared sections}` and writes nothing. Merge the reports here.
   Below ~8 docs, measure inline. All steps below (Dedup, Prune, Right-size, index/`_shared.md`
   writes) stay sequential in the orchestrator — subagents only measure and propose.
2. **Dedup** — find content that appears in 2+ feature docs (shared components, base
   tables, common middleware). Move one canonical copy to `_shared.md` and replace each
   occurrence with a link under `## Shared dependencies`.
3. **Prune** — flag sections that are empty, `[TO BE DEFINED]` stale, or duplicate the
   global docs; remove redundant prose, keep tables/lists. Confirm before deleting any
   non-empty content.
4. **Right-size** — if a single feature doc is oversized (covers what are really two
   features), propose a split and, on confirmation, create the second doc + a new
   `FEATURE_INDEX`/epic-slug note for the user to wire into `plan`.
5. Update `README.md` if files changed; run the **FEATURE_INDEX update** if any `Docs`
   path changed.
6. Report before/after token totals per doc and the total saved.

---

## FEATURE_INDEX UPDATE (shared sub-step)

Whenever a feature doc is created, relocated, or renamed, update
`tasks/FEATURE_INDEX.md` per [../../references/feature-index.md](../../references/feature-index.md):

- Set the feature's `Docs` cell to `docs/architecture/features/<slug>/index.md`.
- Upgrade a `v1` header to `v2` and add the `Docs` column (cell `—` for any feature
  with no doc).
- This is the only skill allowed to fill a `—` `Docs` cell from scratch.

---

## RULES

- **Never delete the original layer docs** — `migrate` moves them to
  `docs/architecture/archive/`, always.
- **Never invent technical content.** `sync` scaffolds stubs; `optimize` restructures
  and measures. Component/API/data detail is authored by `design`/`build`, not here.
- **Never duplicate the feature-doc or `_shared.md` template** — reference
  `design`'s `architecture-templates.md` as the single source.
- **Respect the requested mode** — run only `upgrade`, `migrate`, `sync`, or `optimize`
  as asked; default to `optimize` only when no argument is given.
- **`upgrade` stamps `tasks/VERSION.md` only as its final step** — never before the
  layout migration has succeeded; this is the one place the v3 stamp is written by a
  full migration. It is also the only place a `v1` `FEATURE_INDEX` header is rewritten.
- **Never invent `pending` ledger rows** — `upgrade` backfills only `planned` rows for
  already-built features; new design work is recorded by `design`, not here.
- **Never validate docs against source code** — drift auditing is out of scope; do not
  read the codebase to verify documented components exist.
- **Always update `FEATURE_INDEX.Docs` and the `README.md` index** in the same run that
  a feature doc is created, renamed, or moved — never leave routing stale.
- **Always confirm before destructive or structural changes** — deleting non-empty
  content, renaming on ambiguous slug drift, or splitting a feature doc.
