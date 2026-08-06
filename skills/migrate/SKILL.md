---
name: migrate
description: Use when a change-producing skill's version gate has blocked a pre-v6 ck-code project, when the user asks to upgrade a project to v6, when the same epic number is used by more than one plan folder, when team-generated skills sit in nested .claude/skills/experts/ or guides/ folders, or when a ck-code-lite project (tasks/PLAN.md) should move to the full ck-code workflow.
argument-hint: "[--dry-run]"
effort: medium
allowed-tools: Bash(ck-index*) Bash(git status*) Bash(git mv*) Bash(git branch*) Bash(git rev-parse*) Bash(gh pr list*) Bash(find*) Bash(grep*) Bash(ls*) Bash(mkdir*) Bash(mv*) Skill
---

# Migrate — Upgrade a Project to the v6 Layout

Converts a pre-v6 ck-code project **or a ck-code-lite project** to the **v6 layout**
(story-frontmatter source of truth + generated indexes + **globally unique epic
numbers** — see [`data-model.md`](../../references/data-model.md) — plus **flat**
team-skill folders) and stamps `tasks/VERSION.md` as its final step. This is the **only**
v6 migrator; the [version gate](../../references/version-gate.md) in every
change-producing skill routes pre-v6, colliding, nested and lite projects here. This skill
itself never gates.

**v5 → v6 is a one-phase job.** A project already on v5 needs only **Phase R** (renumber
colliding epics); its stories, epics, docs and skill folders are already correct and
Phases 2–4 and S must not touch them.

**v4 → v6 needs two phases.** A project already on v4 needs Phase S (flatten the skill
folders) and Phase R; its stories, epics and architecture docs are already correct and
Phases 2–4 must not touch them.

**Phase R runs on every path**, last before the stamp — a v3 conversion can surface
collisions too.

One-shot, idempotent, safe: an already-v6 project is a no-op that just (re)stamps. All
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
3. Confirm with the user: `AskUserQuestion` — "Migrate this project to the ck-code v6
   layout? All conversions land in one commit; rollback is `git reset --hard <sha>`."
   Options: `Migrate` / `Cancel`. On Cancel, stop.

## PHASE 1: DETECT SOURCE LAYOUT (read-only)

Determine how old the project is — it decides which conversion steps run:

1. **v5 already?** Read `tasks/VERSION.md`. `layout: v5` AND no nested skill folders →
   the stories, epics, docs and skill folders are all current. Skip Phases 2–4 and S
   entirely, run **Phase R**, then Phase 5. Report "v5 → v6 (epic renumbering)", or
   "v5 → v6 (re-stamp only)" when R finds no collision.
   `layout: v5` WITH nested `experts/`/`guides/` folders → the stamp overstates the
   layout; run **Phase S**, then **Phase R**, then Phase 5, exactly as for v4.
   `layout: v6` → already current; Phase R (a no-op check) plus Phase 5, report
   "already v6".
2. **v4 already?** `layout: v4` AND every `tasks/*/epics/*/stories/*.md` starts with
   `---` → the story layer is current. Skip Phases 2–4 entirely, run **Phase S**, then
   **Phase R**, then Phase 5. Report "v4 → v6 (skill folders + epic numbering)".
3. **lite?** `tasks/PLAN.md` exists and no `tasks/*/epics/` directory does → a
   **ck-code-lite** project. Go to **PHASE L**; Phases 2–4 do not apply (there are no v3
   story files, epics, or layer docs to convert). If **both** are present the project is
   half-migrated: stop and report it, never merge a lite plan into an existing v4 plan.
4. **Pre-v3 doc layout?** Any of `docs/architecture/features/*.md` (flat feature docs),
   `docs/architecture/{components,api-contracts,database-schema,data-flow}.md` (layer
   docs) → the architecture docs also need conversion (Phase 3b).
5. **v3?** Story files without frontmatter, `Schema: v1/v2` indexes, or
   `docs/architecture/DESIGN_LEDGER.md` present → the common case (Phases 2–4).

Report the detected source layout before converting.

## PHASE 2: CONVERT STORIES

For every `tasks/*/epics/NN_<slug>/stories/*.md`, prepend v6 frontmatter derived from
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
  "was L/XL — consider splitting" (v6 sizes are S/M only).
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

## PHASE S: FLATTEN THE TEAM SKILL FOLDERS

Runs on every migration path where nested folders can still exist — including after
Phase L — and is a no-op when there are none. Phase 1 step 1 skips it only for a
v5/v6 project already verified flat. It is the v4 → v5 step of the conversion
(Phase R carries it the rest of the way to v6).

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

Continue at Phase S (a no-op for lite — it has no team skills), then Phase R (a lite plan
becomes one plan folder, so it collides only if the project already held others), then
Phase 5, committing with `chore: migrate ck-code-lite project to ck-code v6 layout`.

## PHASE R: RENUMBER COLLIDING EPICS (every path)

Runs on **every** migration path, immediately before Phase 5, and is the whole of a
v5 → v6 migration. A no-op when no epic number is used by more than one plan.

v6 requires an epic number — and therefore a story `id` — to be unique across every plan
([`data-model.md`](../../references/data-model.md#epic-and-story-numbers-are-globally-unique)).
Through v5, numbering restarted at `01` in each new plan folder, so two plans could both
own epic `01` and story `01-01`, and every ID consumer silently resolved to whichever it
reached first.

**`--dry-run` stops after R2**: print the ID map, write nothing.

### R1 — Detect (read-only)

List plans the way `ck-index.sh` does — a directory under `tasks/` holding
`PROJECT_OVERVIEW.md` or `FEATURE_OVERVIEW.md` — **sorted by folder name**. Plan folders
are dated `YYYY-MM-DD_…`, so that sort is chronological.

```bash
find tasks -maxdepth 2 \( -name PROJECT_OVERVIEW.md -o -name FEATURE_OVERVIEW.md \) \
  | sed 's|/[^/]*$||' | sort
find tasks -mindepth 3 -maxdepth 3 -type d -path 'tasks/*/epics/*' | sort
```

`find`, never a `tasks/*/…` glob — an unmatched glob aborts the command under zsh and
would report "no epics" on a project that has some.

A plan with no `epics/` directory, or none holding numbered epic folders, is **skipped**:
it contributes no numbers and takes no offset.

**Divergence guard (hard).** A directory holding `epics/` but **no** overview file is
invisible to the plan list above while still contributing story IDs. Renumbering around
it would leave a fresh collision behind. If any exists, **stop** and list them — the user
adds the overview file or moves the folder, then re-runs.

If no number appears in more than one plan, Phase R is done: report "no renumbering
needed" and continue to Phase 5.

### R2 — Compute offsets

Walk the plans in sorted order, tracking `running_max` (starting at 0):

```
offset(plan) = max(0, running_max + 1 - min(epic numbers of plan))
new(NN)      = NN + offset
running_max  = max(running_max, largest new(NN) in this plan)
```

Why this shape:

- **The oldest plan never renumbers** (its offset is 0), so the original project plan's
  merged branches and published issues stay valid. Churn lands only on later plans.
- **A plan already above the running max is left alone** — the offset resolves to 0
  rather than shifting it needlessly.
- **Gaps are preserved, not densified.** A plan holding `01, 03` becomes `05, 07`. Gaps
  are legal, and preserving them keeps the rewrite minimal.
- **Idempotent.** After one pass nothing collides, every offset is 0, and a re-run
  changes no file.

Worked example — plan A holds `01–04`, plan B holds `01–03`:

| Plan (sorted) | min | running_max in | offset | result | running_max out |
|---|---|---|---|---|---|
| `2026-01-10_project` | 1 | 0 | 0 | `01–04` unchanged | 4 |
| `2026-03-05_feature-billing` | 1 | 4 | 4 | `01–03` → `05–07` | 7 |

Present the full **old → new ID map**, grouped by plan, before writing anything.

### R3 — Open-PR gate (hard)

Branch names are derived, so nothing stored breaks — but live branches carrying an old
number become orphans, and renaming one with an open PR breaks that PR.

```bash
git branch --list "epic/<oldNN>-*" "story/<oldEE>-*" "fix/<oldEE>-*"
gh pr list --head <branch> --state open --json number 2>/dev/null
```

If any affected branch has an open PR, **stop and list them**. The user merges or closes
first, then re-runs. Never rename a branch out from under an open PR.

### R4 — Rewrite (mechanical, exact)

Only structured targets — every one is deterministic:

| Artifact | Change |
|---|---|
| `epics/NN_<slug>/` | `git mv` to `epics/<new>_<slug>/` (history preserved) |
| `EPIC.md` frontmatter | `epic: NN` → `epic: <new>` |
| Story frontmatter | `id: NN-SS` → `<new>-SS`, and `epic: NN` → `<new>` |
| Story `blocked_by:` | every entry rewritten with **that same plan's offset** |

`blocked_by` is unambiguous because a v5 project cannot express a cross-plan dependency —
every existing reference is intra-plan by construction, so the owning plan's offset is
always the right one.

`issue:` numbers are integers and are **never** touched.

**Apply the whole map at once, never one number at a time.** A plan's old and new ranges
can overlap — `01→03` alongside `03→05` — so a sequence of independent substitutions
re-hits a value an earlier one just wrote (`03` becomes `05`, then `07`). Two rules:

- **Folders:** rename in two passes through a temporary prefix
  (`NN_slug` → `TMPnew_slug` → `new_slug`), so a new name never lands on an old folder
  that has not moved yet.
- **Frontmatter:** rewrite each file in **one pass**, matching every `epic:`, `id:` and
  `blocked_by:` number against the complete map and substituting each occurrence exactly
  once. Never loop the map issuing one `sed` per number.

Verify after the rewrite: every `id` is unique project-wide and every `blocked_by` entry
resolves. `ck-doctor` checks both (`epic ids`, `story ids`, `dependencies`).

### R5 — Prose references (confirm, never blind-rewrite)

`ROADMAP.md`, the overviews, and story bodies mention IDs in free text, where a blind
`\d\d-\d\d` substitution would also hit dates and version strings.

Grep the affected plans for candidates, present each **with its suggested replacement**,
and apply only what the user confirms. R4's structured rewrites are never gated this way;
only prose is.

### R6 — Branch renames (offer)

For affected local branches that cleared R3, offer `git branch -m <old> <new>`. Local and
reversible. Decline leaves an orphan branch, which `ck-doctor`'s branch check reports.

### R7 — Record for the report

Carry into Phase 6: the full ID map, plans left unchanged, branches renamed or skipped,
prose edits applied or declined, and every story whose `issue:` is set — their published
issue titles still carry the **old** `[EE-SS]` token.

Those stale tokens are **cosmetic only**: `ship` resolves an issue by the frontmatter
`issue:` number and never by title. Migration writes **nothing** to GitHub, so the whole
run stays local and revertable by `git reset --hard <sha>`.

## PHASE 5: REGENERATE + STAMP

1. **Regenerate indexes** from the new frontmatter:
   ```bash
   ck-index
   ```
   This writes every `tasks/<slug>/STORIES_INDEX.md` and `tasks/FEATURE_INDEX.md` from
   the source of truth. Never hand-write these.
2. **Stamp** `tasks/VERSION.md` with `layout: v6` per the
   [version gate](../../references/version-gate.md) (`mkdir -p tasks` first if needed).
   This is the **final** step — only after conversion succeeded.
3. **Commit** all conversions in one commit:
   `git add -A && git commit -m "chore: migrate ck-code project to v6 layout"`.

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
- **Epic renumbering** (Phase R): the full old → new ID map grouped by plan, or "none —
  epic numbers were already unique". Then, when anything moved:
  - plans left unchanged (offset 0), named explicitly;
  - branches renamed, and any skipped for an open PR;
  - prose ID references rewritten, and any the user declined;
  - stories whose `issue:` is set — their published issue titles still carry the old
    `[EE-SS]` token. Say plainly that this is cosmetic (`ship` resolves by issue number,
    never by title) and that migration wrote nothing to GitHub.
- Confirm `tasks/VERSION.md` now reads `layout: v6` and the indexes regenerated.
- Rollback reminder: `git reset --hard <pre-migration-sha>`.

After a **lite** migration, add the items listed under "Report additions" in
[references/lite-migration.md](references/lite-migration.md) — the ID map above all, since
every task ID in the project changed.

## RULES

- **Never run on a dirty tree** — Phase 0 refuses; migration must be one revertable commit.
- **Never delete a story body, journal doc, or design record** — convert in place; only `DESIGN_LEDGER.md` is removed (its state moves to the `design:` flag).
- **Always relay `ck-index: WARN` lines** printed by `ck-index` — a skipped story is invisible in every generated view while its file still exists ([stories-index.md](../../references/stories-index.md)).
- **Never hand-write an index** — always regenerate with `ck-index` (Phase 5).
- **Never stamp `layout: v6` before conversion succeeds** — the stamp is the final step.
- **Always list unparseable files** in the report — a skipped file must be visible, never silent.
- **Idempotent** — an already-v6 project re-stamps and regenerates with no other change; Phase R finds no collision and rewrites nothing.
- **Never run Phases 2–4 on a v4 project** — its stories, epics and docs are already correct; v4 → v6 is Phase S, Phase R, and the stamp.
- **Never run Phases 2–4 on a v5 project** — v5 → v6 is Phase R plus the stamp; Phase S joins only when Phase 1 found nested skill folders the v5 stamp should have ruled out.
- **Always run Phase R on every path** — a v3 conversion can surface collisions too, and the stamp must never claim v6 over colliding epic numbers.
- **Never renumber the oldest plan** — it takes offset 0 so its merged branches and published issues stay valid (R2).
- **Never rename a branch that has an open PR** — R3 stops and lists them instead.
- **Never blind-rewrite an ID in prose** — R4's frontmatter and folder rewrites are mechanical; prose is confirmed occurrence by occurrence (R5), because `\d\d-\d\d` also matches dates and versions.
- **Never rewrite the map one number at a time** (R4) — old and new ranges can overlap, so a per-number loop re-hits values it just wrote. Folders move through a temp prefix; frontmatter is one pass against the whole map.
- **Never write to GitHub during a migration** — stale `[EE-SS]` issue titles are reported, never edited; the run stays local and revertable.
- **Never renumber around a plan folder with no overview file** — it is invisible to the plan list and would leave a fresh collision; R1 stops and reports it.
- **Always move skill folders with `git mv`, never copy-then-delete** — the whole folder moves, siblings included, and history survives.
- **Never overwrite an existing flat skill folder** — a collision is a half-migrated project; stop and report it (S2).
- **Never merge a lite plan into an existing v4 plan folder** — `tasks/PLAN.md` alongside `tasks/*/epics/` is a half-migrated project; stop and report it.
- **Never write epics or stories before the L2 grouping is confirmed** — the ID map changes every task ID, so the user sees it first.
- **Never invent architecture detail in a lite migration** — feature docs are stubs; `/ck-code:design` fills them.
- **Never leave `tasks/PLAN.md` live after a lite migration** — the rename is what stops a competing `/ck-code-lite:build` and clears the version-gate marker.
- **Never edit `.claude/settings.json` without the Swap confirmation**, and never touch a key other than the two `enabledPlugins` entries.
