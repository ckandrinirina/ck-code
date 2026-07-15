---
name: migrate
description: Use when a project is on a pre-v4 ck-code layout and a change-producing skill's version gate has blocked it, or when the user asks to upgrade a ck-code project to v4. Converts v3 (or older) story files, epics, and architecture docs to the v4 frontmatter-based layout, regenerates the indexes, and stamps tasks/VERSION.md. One-shot, idempotent, safe.
disable-model-invocation: false
effort: medium
---

# Migrate — Upgrade a Project to the v4 Layout

Converts a pre-v4 ck-code project to the **v4 layout** (story-frontmatter source of
truth + generated indexes — see [`data-model.md`](../../references/data-model.md)) and
stamps `tasks/VERSION.md` as its final step. This is the **only** v4 migrator; the
[version gate](../../references/version-gate.md) in every change-producing skill routes
pre-v4 projects here. This skill itself never gates.

One-shot, idempotent, safe: an already-v4 project is a no-op that just (re)stamps. All
originals are converted in place behind a **single pre-migration commit** so the whole
conversion is one revertable step. The field-by-field mapping and the pre-v3
doc-layout conversion live in [references/migration-map.md](references/migration-map.md).

## PHASE 0: SAFETY GATE (hard)

1. **Clean tree required.** Run `git status --porcelain`. If it is non-empty, STOP and
   tell the user to commit or stash first — migration rewrites many files and must be a
   clean, revertable step. Do not proceed on a dirty tree.
2. **Snapshot commit.** With a clean tree, note the current SHA (`git rev-parse HEAD`)
   and report it — this is the one-command rollback point (`git reset --hard <sha>`).
3. Confirm with the user: `AskUserQuestion` — "Migrate this project to the ck-code v4
   layout? All conversions land in one commit; rollback is `git reset --hard <sha>`."
   Options: `Migrate` / `Cancel`. On Cancel, stop.

## PHASE 1: DETECT SOURCE LAYOUT (read-only)

Determine how old the project is — it decides which conversion steps run:

1. **v4 already?** Read `tasks/VERSION.md`. `layout: v4` AND every
   `tasks/*/epics/*/stories/*.md` starts with `---` → already v4. Skip to Phase 5
   (re-stamp + regenerate) and report "already v4".
2. **Pre-v3 doc layout?** Any of `docs/architecture/features/*.md` (flat feature docs),
   `docs/architecture/{components,api-contracts,database-schema,data-flow}.md` (layer
   docs) → the architecture docs also need conversion (Phase 3b).
3. **v3?** Story files without frontmatter, `Schema: v1/v2` indexes, or
   `docs/architecture/DESIGN_LEDGER.md` present → the common case (Phases 2–4).

Report the detected source layout before converting.

## PHASE 2: CONVERT STORIES

For every `tasks/*/epics/NN_<slug>/stories/*.md`, prepend v4 frontmatter derived from
the v3 prose, then leave the body intact. Use the mapping in
[references/migration-map.md](references/migration-map.md#story-fields). Key rules:

- `status`: `TODO`→`todo`, `IN PROGRESS`→`in-progress`, `DONE`→`done`, `SKIP`→`skip`,
  `BUG`→`bug` (carry the recorded `Prior status` into `prior_status`).
- `size`: `S`/`M` kept; **`L`/`XL`→`M`** and flag the story in the report as
  "was L/XL — consider splitting" (v4 sizes are S/M only).
- `blocked_by`: the story IDs from the `## Dependencies` section as `[id, ...]` (or `[]`).
- `files`: the paths from the `## Files to Create/Modify` table as `[path, ...]` (or `[]`).
- `issue`: a `#NNN` reference found in the story, else empty. When `gh` is available and
  the story has no `#NNN`, best-effort match a GitHub issue by the `[EE-SS]` title tag
  and record its number (this replaces v3's title-substring rediscovery permanently).

**Large projects (≥8 stories):** fan out per the
[subagent-fanout contract](../../references/subagent-fanout.md) — one investigation
agent per epic returns each story's extracted frontmatter as structured data; the
orchestrator writes the files. Any story the agent cannot parse is returned in an
`unparsed` list and handled inline.

Prepend the frontmatter block; never rewrite the body prose (acceptance criteria,
notes, implementation summaries stay as-is).

## PHASE 3: CONVERT EPICS + ARCHITECTURE

**3a — EPIC.md.** For each `epics/NN_<slug>/EPIC.md`, add frontmatter
(`epic`, `slug`, `title`, `description` from the Goal/first description line) and
**remove the `## Stories` table** — the story list is now generated into
`STORIES_INDEX.md`. Keep all other authored prose. See
[migration-map.md](references/migration-map.md#epic-fields).

**3b — architecture docs (only if Phase 1 found a pre-v3 doc layout).** Convert flat
`features/<slug>.md` → `features/<slug>/index.md` and split legacy layer docs into
per-feature docs, following
[migration-map.md](references/migration-map.md#pre-v3-architecture-docs). Then add
`slug` + `design` frontmatter to each `features/<slug>/index.md`.

**3c — design flag + ledger retirement.** Add `design:` frontmatter to every feature
doc (`planned` if the feature has any epic/story, else `pending`), folding in the state
from `DESIGN_LEDGER.md` if present, then **delete `DESIGN_LEDGER.md`** — the `design:`
flag replaces it.

## PHASE 4: RETIRE v3 ARTIFACTS

- The old hand-maintained `STORIES_INDEX.md` / `FEATURE_INDEX.md` are overwritten by the
  generator in Phase 5 — no action needed beyond that.
- Dated journal/delta docs (`features/<slug>/YYYY-MM-DD_*.md`, design records) are
  **left in place** as historical files (never deleted — they may hold notes a user
  values); v4 simply stops writing new ones. Note in the report that they are now inert.

## PHASE 5: REGENERATE + STAMP

1. **Regenerate indexes** from the new frontmatter:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh"
   ```
   This writes every `tasks/<slug>/STORIES_INDEX.md` and `tasks/FEATURE_INDEX.md` from
   the source of truth. Never hand-write these.
2. **Stamp** `tasks/VERSION.md` with `layout: v4` per the
   [version gate](../../references/version-gate.md) (`mkdir -p tasks` first if needed).
   This is the **final** step — only after conversion succeeded.
3. **Commit** all conversions in one commit:
   `git add -A && git commit -m "chore: migrate ck-code project to v4 layout"`.

## PHASE 6: VERIFY + REPORT

Report a verification table so the user can trust the conversion:

- Stories: N found → N converted; list every story whose status changed vocabulary and
  every `L`/`XL` re-sized to `M`.
- Any story file that could **not** be parsed — list it explicitly for manual review;
  never silently skip.
- Epics converted, `DESIGN_LEDGER.md` retired, journal docs left inert.
- Confirm `tasks/VERSION.md` now reads `layout: v4` and the indexes regenerated.
- Rollback reminder: `git reset --hard <pre-migration-sha>`.

## RULES

- **Never run on a dirty tree** — Phase 0 refuses; migration must be one revertable commit.
- **Never delete a story body, journal doc, or design record** — convert in place; only `DESIGN_LEDGER.md` is removed (its state moves to the `design:` flag).
- **Never hand-write an index** — always regenerate with `ck-index.sh` (Phase 5).
- **Never stamp `layout: v4` before conversion succeeds** — the stamp is the final step.
- **Always list unparseable files** in the report — a skipped file must be visible, never silent.
- **Idempotent** — an already-v4 project re-stamps and regenerates with no other change.
