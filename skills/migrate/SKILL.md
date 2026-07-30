---
name: migrate
description: Use when a change-producing skill's version gate has blocked a pre-v5 ck-code project, when the user asks to upgrade a project to v5, when team-generated skills sit in nested .claude/skills/experts/ or guides/ folders, or when a ck-code-lite project (tasks/PLAN.md) should move to the full ck-code workflow. Converts v3 or older stories, epics and architecture docs — or a lite flat plan — to v5, flattens the team skill folders, regenerates the indexes, and stamps tasks/VERSION.md.
argument-hint: "[--dry-run]"
effort: medium
allowed-tools: Bash(ck-index*) Bash(git status*) Bash(git mv*) Bash(ls*) Bash(mkdir*) Bash(mv*)
---

# Migrate — Upgrade a Project to the v5 Layout

Converts a pre-v5 ck-code project **or a ck-code-lite project** to the **v5 layout**
(story-frontmatter source of truth + generated indexes — see
[`data-model.md`](../../references/data-model.md) — plus **flat** team-skill folders) and
stamps `tasks/VERSION.md` as its final step. This is the **only** v5 migrator; the
[version gate](../../references/version-gate.md) in every change-producing skill routes
pre-v5, nested and lite projects here. This skill itself never gates.

**v4 → v5 is a one-phase job.** A project already on v4 needs only Phase S (flatten the
skill folders); its stories, epics and architecture docs are already correct and Phases
2–4 must not touch them.

One-shot, idempotent, safe: an already-v5 project is a no-op that just (re)stamps. All
originals are converted in place behind a **single pre-migration commit** so the whole
conversion is one revertable step. The field-by-field mapping and the pre-v3
doc-layout conversion live in [references/migration-map.md](references/migration-map.md);
the lite conversion in [references/lite-migration.md](references/lite-migration.md).

## PROGRESS TRACKING

Open a `TodoWrite` list as the **first action of Phase 0** — one todo per phase this run will
actually execute — then flip each to `in_progress` when it starts and `completed` when its
gate passes. Drop a phase that mode routing skips; never leave it pending. A long run's only
view into where it is comes from this list, so update it as you go and never batch the
updates to the end.

## PHASE 0: SAFETY GATE (hard)

1. **Clean tree required.** Run `git status --porcelain`. If it is non-empty, STOP and
   tell the user to commit or stash first — migration rewrites many files and must be a
   clean, revertable step. Do not proceed on a dirty tree.
2. **Snapshot commit.** With a clean tree, note the current SHA (`git rev-parse HEAD`)
   and report it — this is the one-command rollback point (`git reset --hard <sha>`).
3. Confirm with the user: `AskUserQuestion` — "Migrate this project to the ck-code v5
   layout? All conversions land in one commit; rollback is `git reset --hard <sha>`."
   Options: `Migrate` / `Cancel`. On Cancel, stop.

## PHASE 1: DETECT SOURCE LAYOUT (read-only)

Determine how old the project is — it decides which conversion steps run:

1. **v4 already?** Read `tasks/VERSION.md`. `layout: v4` AND every
   `tasks/*/epics/*/stories/*.md` starts with `---` → the story layer is current. Skip
   Phases 2–4 entirely, run **Phase S**, then Phase 5. Report "v4 → v5 (skill folders
   only)". `layout: v5` and no nested skill folders → already v5; Phase 5 alone
   (re-stamp + regenerate), report "already v5".
2. **lite?** `tasks/PLAN.md` exists and no `tasks/*/epics/` directory does → a
   **ck-code-lite** project. Go to **PHASE L**; Phases 2–4 do not apply (there are no v3
   story files, epics, or layer docs to convert). If **both** are present the project is
   half-migrated: stop and report it, never merge a lite plan into an existing v4 plan.
3. **Pre-v3 doc layout?** Any of `docs/architecture/features/*.md` (flat feature docs),
   `docs/architecture/{components,api-contracts,database-schema,data-flow}.md` (layer
   docs) → the architecture docs also need conversion (Phase 3b).
4. **v3?** Story files without frontmatter, `Schema: v1/v2` indexes, or
   `docs/architecture/DESIGN_LEDGER.md` present → the common case (Phases 2–4).

Report the detected source layout before converting.

## PHASE 2: CONVERT STORIES

For every `tasks/*/epics/NN_<slug>/stories/*.md`, prepend v5 frontmatter derived from
the v3 prose, then leave the body intact.

**Dispatch decision first.** Count the story files and announce the branch **before
converting any of them**: at **≥3 epics' worth of stories**, fan out per the
[subagent-fanout contract](../../references/subagent-fanout.md) — one investigation agent
per epic (`model: haiku`) returns each story's extracted frontmatter as structured data,
and the **orchestrator** writes every file. Any story an agent cannot parse comes back in
an `unparsed` list and is handled inline. Below that, convert inline and say so.

Use the mapping in
[references/migration-map.md](references/migration-map.md#story-fields). Key rules:

- `status`: `TODO`→`todo`, `IN PROGRESS`→`in-progress`, `DONE`→`done`, `SKIP`→`skip`,
  `BUG`→`bug` (carry the recorded `Prior status` into `prior_status`).
- `size`: `S`/`M` kept; **`L`/`XL`→`M`** and flag the story in the report as
  "was L/XL — consider splitting" (v5 sizes are S/M only).
- `blocked_by`: the story IDs from the `## Dependencies` section as `[id, ...]` (or `[]`).
- `files`: the paths from the `## Files to Create/Modify` table as `[path, ...]` (or `[]`).
- `issue`: a `#NNN` reference found in the story, else empty. When `gh` is available and
  the story has no `#NNN`, best-effort match a GitHub issue by the `[EE-SS]` title tag
  and record its number (this replaces v3's title-substring rediscovery permanently).

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
  values); v5 simply stops writing new ones. Note in the report that they are now inert.

## PHASE S: FLATTEN THE TEAM SKILL FOLDERS (every path)

Runs on **every** migration path, including after Phase L. It is the whole of a v4 → v5
migration and a no-op when the project has no nested folders.

`/ck-code:team` used to write `.claude/skills/experts/<role>/SKILL.md` and
`.claude/skills/guides/<tech>/SKILL.md`. Claude Code discovers project skills at
`.claude/skills/<skill-name>/SKILL.md` and takes the command name from that directory,
so nothing under `experts/` or `guides/` was ever registered — no `/expert-<role>`
command existed and no guide auto-loaded. Only ck-code's own `Read`-by-path detection
saw them. v5 puts each skill in its own top-level folder, where the name is real.

**S1 — enumerate (read-only):**

```bash
ls -d .claude/skills/experts/*/ .claude/skills/guides/*/ 2>/dev/null
```

Empty → nothing to do; say so in the report and continue to Phase 5.

**S2 — collision check (hard).** For every `experts/<role>/` the target is
`.claude/skills/expert-<role>/`; for every `guides/<tech>/`, `.claude/skills/guide-<tech>/`
(so `guides/conventions/` → `guide-conventions/`). If any target already exists, the
project is half-migrated: **stop**, list every colliding pair, and never merge or
overwrite. The user resolves it, then re-runs.

**S3 — move.** One `git mv` per folder, preserving history and every sibling file in the
skill directory (`references/`, scripts, assets — the whole folder moves, not just
`SKILL.md`):

```bash
for d in .claude/skills/experts/*/; do git mv "$d" ".claude/skills/expert-$(basename "$d")"; done
for d in .claude/skills/guides/*/;  do git mv "$d" ".claude/skills/guide-$(basename "$d")";  done
rmdir .claude/skills/experts .claude/skills/guides 2>/dev/null
```

`rmdir` (never `rm -rf`) — it refuses if anything was left behind, which is the signal
that a file escaped the loop. If it refuses, list the remainder and stop.

**S4 — reconcile names and stale paths.** The generated frontmatter already carries
`name: expert-<slug>` / `name: guide-<slug>`, which now matches the directory. Verify,
and fix any file whose `name:` disagrees with its new folder — at project level the
**directory name** is the command, so a mismatch is invisible rather than an error:

```bash
grep -H '^name:' .claude/skills/expert-*/SKILL.md .claude/skills/guide-*/SKILL.md
grep -rln 'skills/experts/\|skills/guides/' .claude/skills/ CLAUDE.md docs/ 2>/dev/null
```

Rewrite any surviving `.claude/skills/experts/…` or `…/guides/…` path found by the second
grep to its flat form. Leave every other line of every skill body untouched — the
`ck-code:team GENERATED` marker included, so `--regenerate` still behaves.

## PHASE L: CONVERT A LITE PROJECT

Runs **instead of** Phases 2–4 when Phase 1 detected `lite`. Every mapping table,
template pointer, and banner text lives in
[references/lite-migration.md](references/lite-migration.md) — open it before L1.

**Always inline, never fan out.** A lite plan is small by contract (S/M tasks, one file),
so the `≥3 epics` dispatch rule in Phase 2 does not apply here.

### L1 — Read the source

Read `docs/ARCHITECTURE.md` whole (it is one screen by contract), then the plan's table:

```bash
grep -n '^| T-' tasks/PLAN.md
grep -n '^## T-' tasks/PLAN.md
```

Read each task section by offset. Resolve the project slug and the dated plan folder.

### L2 — Propose the grouping (hard gate)

Infer epics from task titles and `files:` paths, then present the proposal **with the
`T-NN → EE-SS` column** and gate on `AskUserQuestion` (Accept / Single epic / Adjust).
Write nothing before the answer. On Adjust, re-present and ask again.

### L3 — Write epics and stories

Create the plan folder, `PROJECT_OVERVIEW.md`, `ROADMAP.md`, one `EPIC.md` per epic, and
one story file per task. Frontmatter and body follow the mapping tables; `blocked` tasks
become `todo` and are recorded for the report. Bodies move verbatim — a ticked box stays
ticked.

### L4 — Write the architecture docs

Split `docs/ARCHITECTURE.md` into the global docs per the mapping, then write one
**stub** `features/<epic-slug>/index.md` per epic (`design: planned`, `## Summary` from
the epic description, everything else `[TO BE DEFINED]`). Never invent component, API,
data, or flow detail lite never recorded.

### L5 — Retire the lite artifacts and offer the swap

Rename `tasks/PLAN.md` → `tasks/PLAN.superseded.md` with its banner, banner
`docs/ARCHITECTURE.md`, then offer the `.claude/settings.json` plugin swap (one
`AskUserQuestion`, applied only on Swap).

Continue at Phase S (a no-op for lite — it has no team skills), then Phase 5, committing
with `chore: migrate ck-code-lite project to ck-code v5 layout`.

## PHASE 5: REGENERATE + STAMP

1. **Regenerate indexes** from the new frontmatter:
   ```bash
   ck-index
   ```
   This writes every `tasks/<slug>/STORIES_INDEX.md` and `tasks/FEATURE_INDEX.md` from
   the source of truth. Never hand-write these.
2. **Stamp** `tasks/VERSION.md` with `layout: v5` per the
   [version gate](../../references/version-gate.md) (`mkdir -p tasks` first if needed).
   This is the **final** step — only after conversion succeeded.
3. **Commit** all conversions in one commit:
   `git add -A && git commit -m "chore: migrate ck-code project to v5 layout"`.

## PHASE 6: VERIFY + REPORT

Report a verification table so the user can trust the conversion:

- Stories: N found → N converted; list every story whose status changed vocabulary and
  every `L`/`XL` re-sized to `M`.
- Any story file that could **not** be parsed — list it explicitly for manual review;
  never silently skip.
- Epics converted, `DESIGN_LEDGER.md` retired, journal docs left inert.
- **Skill folders flattened** (Phase S): one line per move, `experts/<role>` →
  `expert-<role>`, `guides/<tech>` → `guide-<tech>`, or "none — no nested folders". Add
  one line stating that these are now real Claude Code skills: `/expert-<role>` is
  invocable and the guides auto-load. Tell the user to restart Claude Code so the new
  top-level directories are picked up.
- Confirm `tasks/VERSION.md` now reads `layout: v5` and the indexes regenerated.
- Rollback reminder: `git reset --hard <pre-migration-sha>`.

After a **lite** migration, add the items listed under "Report additions" in
[references/lite-migration.md](references/lite-migration.md) — the ID map above all, since
every task ID in the project changed.

## RULES

- **Never run on a dirty tree** — Phase 0 refuses; migration must be one revertable commit.
- **Never delete a story body, journal doc, or design record** — convert in place; only `DESIGN_LEDGER.md` is removed (its state moves to the `design:` flag).
- **Always relay `ck-index: WARN` lines** printed by `ck-index` — a skipped story is invisible in every generated view while its file still exists ([stories-index.md](../../references/stories-index.md)).
- **Never hand-write an index** — always regenerate with `ck-index` (Phase 5).
- **Never stamp `layout: v5` before conversion succeeds** — the stamp is the final step.
- **Always list unparseable files** in the report — a skipped file must be visible, never silent.
- **Idempotent** — an already-v5 project re-stamps and regenerates with no other change.
- **Never run Phases 2–4 on a v4 project** — its stories, epics and docs are already correct; v4 → v5 is Phase S plus the stamp.
- **Always move skill folders with `git mv`, never copy-then-delete** — the whole folder moves, siblings included, and history survives.
- **Never overwrite an existing flat skill folder** — a collision is a half-migrated project; stop and report it (S2).
- **Never merge a lite plan into an existing v4 plan folder** — `tasks/PLAN.md` alongside `tasks/*/epics/` is a half-migrated project; stop and report it.
- **Never write epics or stories before the L2 grouping is confirmed** — the ID map changes every task ID, so the user sees it first.
- **Never invent architecture detail in a lite migration** — feature docs are stubs; `/ck-code:design` fills them.
- **Never leave `tasks/PLAN.md` live after a lite migration** — the rename is what stops a competing `/ck-code-lite:build` and clears the version-gate marker.
- **Never edit `.claude/settings.json` without the Swap confirmation**, and never touch a key other than the two `enabledPlugins` entries.
