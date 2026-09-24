---
name: migrate
description: Use when a change-producing skill's version gate has blocked an older ck-code project (layout v6 or earlier), when the user asks to upgrade a project to layout v7, when the same epic number is used by more than one plan folder, when team-generated skills sit in nested .claude/skills/experts/ or guides/ folders, or when a ck-code-lite project (tasks/PLAN.md) should move to the full ck-code workflow.
argument-hint: "[--dry-run]"
effort: medium
allowed-tools: Bash(ck-migrate*) Bash(ck-bootstrap*) Bash(ck-index*) Bash(ck-doctor*) Bash(git status*) Bash(git add*) Bash(git commit*) Bash(git mv*) Bash(git branch*) Bash(git rev-parse*) Bash(git ls-files*) Bash(gh pr list*) Bash(gh issue list*) Bash(find*) Bash(grep*) Bash(ls*) Bash(awk*) Bash(date*) Bash(mkdir*) Bash(mv*) Bash(rm*) Bash(rmdir*) Skill
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/no-ai-guard.sh"
---

# Migrate — Upgrade a Project to the v7 Layout

Converts an older ck-code project, or a ck-code-lite project, to the **v7 layout**
([`data-model.md`](../../references/data-model.md)): a plan record in each
`tasks/<plan>/OVERVIEW.md`, generated views kept out of git, and a stable
`tasks/VERSION.md` stamp. The [version gate](../../references/version-gate.md) of every
change-producing skill routes older projects here. This skill never gates itself.

Three paths, chosen by Phase 1:

| Path | Source | How |
|---|---|---|
| **V6** | a v6 project | `ck-migrate v7`, the tested deterministic converter |
| **LEGACY** | v3, v4 or v5, or v5 leftovers on a newer stamp | [references/legacy-v6.md](references/legacy-v6.md) up to v6, then `ck-migrate v7` |
| **LITE** | a ck-code-lite `tasks/PLAN.md` | [references/lite-migration.md](references/lite-migration.md), straight to v7 |

Every path ends in **one revertable commit**. Rollback is `git reset --hard <sha>` with
the SHA Phase 0 records. `--dry-run` makes the whole run read-only.

## PROGRESS TRACKING

Open a `TodoWrite` list as the first action of Phase 0, one todo per phase this run will
execute. Flip each to `in_progress` when it starts and `completed` when its gate passes,
and drop a phase the routing skips. Never batch the updates to the end.

## PHASE 0: SAFETY GATE (hard)

1. **Resolve `--dry-run` first.** With it, announce `Dry run: reporting only, nothing will
   be written.` and carry the flag into every phase. A dry run needs no clean tree and
   skips steps 2–3.
2. **Clean tree required.** Run `git status --porcelain`. Ignore untracked generated
   views (`tasks/EPICS_INDEX.md`, `tasks/.gitignore`, `tasks/*/STORIES_INDEX.md`), which
   a v7 session may have written; `ck-migrate` ignores the same. Anything else → STOP and
   ask the user to commit or stash first.
3. **Record the rollback SHA** with `git rev-parse HEAD` and report it. Nothing is
   committed here. Phase 5 compares `HEAD` against it.

## PHASE 1: DETECT AND PREVIEW (read-only)

Run the Tier-2 probe of [`version-gate.md`](../../references/version-gate.md#tier-2--full-detection-only-when-the-stamp-is-missing-or-stale)
verbatim, whatever the stamp says: a v7 stamp does not rule out colliding epics or nested
team skills. Also read the stamp's `layout:` line. The first row that matches wins:

| Probe result | Route |
|---|---|
| `NEWER` | **Refuse.** Print the version gate's NEWER message (update the plugin with `/plugin update ck-code@ck-marketplace`, then restart) and stop. Never convert a newer layout down. |
| `LITE`, and `find tasks -mindepth 2 -maxdepth 2 -name epics` finds a folder | **Stop.** A half-migrated project: report both, never merge a lite plan into an existing plan. |
| `LITE` | **LITE** path, Phase L. |
| `LEGACY`, or `layout:` v1–v5 | **LEGACY** path, Phase 3. |
| `V6`, or no marker with a stamp other than `layout: v7` | **V6** path, Phase 2. |
| no marker and `layout: v7` | Already v7. Report it, run Phase 4 (the guard), then Phase 5. |

A clean v5 project fires only the `V6` marker (its overview files), but `ck-migrate`
refuses a pre-v6 stamp, so the stamp routes it to LEGACY.

**Preview and confirm.** For the V6 path, run `ck-migrate v7 --dry-run` and show its
output whole: every plan record it writes, every epic that loses `integration:`, the
views it untracks, the spec and design-system moves, and the new stamp. For LEGACY and
LITE, name the source generation and the phases that will run. `ck-migrate --dry-run`
cannot preview a pre-v6 tree, so list its six steps from the script header instead.

With `--dry-run`, skip the question and continue in dry-run mode. Otherwise ask once with
`AskUserQuestion`: "Migrate this project to the ck-code v7 layout? It lands as one commit;
rollback is `git reset --hard <sha>`." Options `Migrate` / `Cancel`. Cancel stops the run.

## PHASE 2: V6 → V7

```bash
ck-migrate v7 --commit
```

It commits `chore(ck-code): migrate the project to layout v7`. What it guarantees:

- It keeps each file's formatting. Frontmatter and JSON edits are line edits, so the
  diff shows only the keys that moved.
- Each `PROJECT_OVERVIEW.md` / `FEATURE_OVERVIEW.md` becomes `OVERVIEW.md` with the plan
  record. The level is the widest its epics used (`feature` → `plan`), and mixed levels
  are reported as a `note` line.
- An existing `feat/<plan-folder>` branch (local or on origin) is kept in the record's
  `branch:`. Otherwise a plan-level plan records `plan/<slug>`.
- Each `EPIC.md` loses `integration:` and keeps its `## Dependencies` prose, which
  records why one epic waits on another.
- The views leave git, `tasks/.gitignore` is written, and `ck-index` regenerates them.

Relay every `ck-migrate:` and `ck-index: WARN` line. On `ERROR`, relay it and stop: the
tree may hold a partial conversion, so name `git reset --hard <sha>` as the way back.

**Dry run:** the Phase 1 preview was the whole of it. Go to Phase 5.

## PHASE 3: LEGACY → V6 → V7

1. Open [references/legacy-v6.md](references/legacy-v6.md) and follow it: L0 picks the
   phases, and Phase V ends with its own commit,
   `chore(ck-code): convert the project to layout v6`. That commit exists because
   `ck-migrate` refuses a dirty tree. It is folded away in step 3.
2. Run `ck-migrate v7` **without** `--commit`. It converts the now-v6 tree and stages the
   result. When it prints `already v7 — nothing to do` (a v7 stamp that only needed
   Phase S or R), the legacy commit is the final one: skip step 3.
3. Fold both stages into one commit:

   ```bash
   git commit --amend -m "chore(ck-code): migrate the project to layout v7" \
     -m "Converted from layout <vN>. Plan records in OVERVIEW.md, views out of git, a stable version stamp."
   ```

   The amended commit is the one this run just made and was never pushed, so the whole
   migration stays one revertable commit.

The Phase 2 guarantees and its error handling apply to step 2.

**Dry run:** every legacy phase prints what it would write; `ck-migrate` is not run
because it cannot read a pre-v6 tree. Go to Phase 5.

## PHASE L: LITE → V7

Open [references/lite-migration.md](references/lite-migration.md) before L1; every
mapping, template pointer and banner lives there. Always inline: a lite plan is small by
contract, so nothing fans out.

- **L1 — Read the source.** `docs/ARCHITECTURE.md` whole (one screen by contract), then
  the task rows and headers (`grep -n '^| T-' tasks/PLAN.md`, `grep -n '^## T-'
  tasks/PLAN.md`), each task section by offset.
- **L2 — Grouping (hard gate).** Propose the epics with the `T-NN → EE-SS` column and ask
  (Accept / Single epic / Adjust). Write nothing before the answer; on Adjust, re-present.
- **L3 — Plan folder.** `OVERVIEW.md` with its record, `ROADMAP.md`, one `EPIC.md` per
  epic, one story per task, bodies verbatim. `blocked` tasks become `todo`.
- **L4 — Architecture docs.** Split `docs/ARCHITECTURE.md` into the global docs and write
  one stub feature doc per epic. Never invent detail lite never recorded.
- **L5 — Views, stamp, retire.** Write `tasks/.gitignore`, run `ck-index` (the views stay
  uncommitted), stamp `layout: v7` with `requires: ck-code >= 7.0.0`, rename
  `tasks/PLAN.md` to `tasks/PLAN.superseded.md` with its banner, banner
  `docs/ARCHITECTURE.md`, and offer the `.claude/settings.json` plugin swap (one
  `AskUserQuestion`, applied only on Swap).
- **L6 — Nested team skills.** Only when the probe also fired the nested-skill marker:
  run Phase S of [legacy-v6.md](references/legacy-v6.md#phase-s--flatten-the-team-skill-folders).
- **L7 — Commit** after Phase 4:
  `git add -A && git commit -m "chore(ck-code): migrate the ck-code-lite project to layout v7"`.

**Dry run:** L1 and L2 run as written (the grouping map is the point of the preview).
Then print every file L3–L5 would create, the renames and banners. Create nothing, and
never offer the plugin swap.

## PHASE 4: GUARD

Run `ck-bootstrap check`. When it reports the guard `MISSING` or the hook `NOT wired`,
run `ck-bootstrap install`, then stage `.claude/ck-code-required.sh` and
`.claude/settings.json` into the migration commit: before the L7 commit on the LITE path,
or with `git commit --amend --no-edit` after Phases 2 and 3. A present guard stays as it
is. On an already-v7 project with nothing else to do, commit the guard alone as
`chore(ck-code): install the ck-code-required guard`.

`ck-bootstrap install` sets `"ck-code@ck-marketplace": true` whatever the lite Swap
answer was ([lite-migration.md](references/lite-migration.md#plugin-swap)).

**Dry run:** report what `check` found and whether install would run.

## PHASE 5: VERIFY + REPORT

- The path taken and the source layout, and every line `ck-migrate` printed (plan
  records, levels, kept `feat/` branches, untracked views).
- LEGACY: the [report items of legacy-v6.md](references/legacy-v6.md#report-items).
  LITE: the report additions of [lite-migration.md](references/lite-migration.md#report-additions).
- Run `ck-doctor` and relay any ERROR row. Epic ids, story ids and dependencies must be
  clean after a renumbering.
- Confirm `tasks/VERSION.md` reads `layout: v7` and the guard is committed.
- **Assert the commit landed.** `git rev-parse HEAD` must differ from the Phase 0 SHA, and
  `git status --porcelain` must be empty apart from ignored views. Otherwise print
  `⛔ Migration ran but nothing was committed — the conversion is sitting uncommitted in the working tree.`,
  name the commit command of the path taken, and never report the migration complete.
- Rollback: `git reset --hard <sha recorded in Phase 0>`.
- Nothing was written to GitHub.

**Dry run:** report everything as *would* statements, skip the commit assertion, and end
with `Dry run — no file was written. Re-run /ck-code:migrate without --dry-run to apply.`

## RULES

- **`--dry-run` writes nothing, anywhere**: no file, stamp, `ck-index`, `git mv`, branch rename, settings edit or commit.
- **Never run on a dirty tree** (Phase 0). Untracked generated views do not count.
- **Never commit in Phase 0**; the rollback point is the SHA already at `HEAD`.
- **One revertable commit per migration.** The LEGACY stage commit exists only because `ck-migrate` refuses a dirty tree, and Phase 3 amends it into the final commit.
- **Always assert the commit landed** (Phase 5).
- **Never migrate a `NEWER` layout** — tell the user to update the plugin.
- **Never re-derive what `ck-migrate` does** in prose or by hand; run it, and read its dry-run before the real run.
- **Never load legacy-v6.md** unless Phase 1 found a `LEGACY` marker or a pre-v6 stamp (or L6 needs Phase S).
- **Never write to GitHub during a migration** — stale `[EE-SS]` issue titles are reported, never edited.
- **Never rename a branch that has an open PR** (legacy Phase R3).
- **Never rewrite an id in prose without asking** (legacy Phase R5); `\d\d-\d\d` also matches dates and versions.
- **Never commit a generated view.** `STORIES_INDEX.md` and `EPICS_INDEX.md` stay behind `tasks/.gitignore`.
- **Always relay `ck-index: WARN` lines** — a skipped story is invisible in every view while its file still exists.
- **Never merge a lite plan into an existing plan folder**, never write epics before the L2 grouping is confirmed, and never leave `tasks/PLAN.md` live after a lite migration.
- **Never edit `.claude/settings.json` without the Swap confirmation**, and never touch a key other than the two `enabledPlugins` entries. `ck-bootstrap install` is exempt, so the report names the final value of both keys.
