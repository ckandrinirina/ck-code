# Legacy → v6 Conversion (pre-v6 projects only)

Read by `migrate` **only** when its Phase 1 probe found a `LEGACY` marker, or a
`layout:` stamp older than `v6`. It brings a v3, v4 or v5 project, or a v6/v7 project
carrying v5 leftovers, up to the **v6 shape**: story frontmatter, unique epic numbers,
flat team-skill folders. It then commits, and `migrate` runs `ck-migrate v7` for the
rest. `ck-migrate` refuses a dirty tree and a pre-v6 project, which is why this stage
commits first and never tries to reach v7 itself.

Everything here is structural and keeps each file's body. The v7 target is defined in
[`data-model.md`](../../../references/data-model.md).

## Contents

- [L0 — Which phases run](#l0--which-phases-run)
- [Phase 2 — Stories](#phase-2--stories-v3-only)
- [Phase 3 — Epics and architecture docs](#phase-3--epics-and-architecture-docs-v3-only)
- [Phase 4 — v3 artifacts](#phase-4--v3-artifacts-v3-only)
- [Phase S — Flatten the team-skill folders](#phase-s--flatten-the-team-skill-folders)
- [Phase R — Renumber colliding epics](#phase-r--renumber-colliding-epics)
- [Phase V — Stamp and commit the v6 stage](#phase-v--stamp-and-commit-the-v6-stage)
- [Report items](#report-items)
- [Rules](#rules)

## L0 — Which phases run

Decide from what is on disk, and report the verdict before converting anything:

| Source | Evidence | Phases |
|---|---|---|
| **v3** (or older) | a story file with no `id:` frontmatter, a `Schema: v1/v2` index, or `docs/architecture/DESIGN_LEDGER.md` | 2, 3, 4, S, R, V |
| **pre-v3 docs** (adds to v3) | `docs/architecture/features/*.md` flat docs, or `components.md` / `api-contracts.md` / `database-schema.md` / `data-flow.md` layer docs | 3b joins Phase 3 |
| **v4** | `layout: v4` and every story starts with `---` | S, R, V |
| **v5** | `layout: v5` | R, V (S too when nested folders exist; the stamp overstated the layout) |
| **v6/v7 stamp with a leftover** | a nested-skill or colliding-epic marker on an otherwise current project | only S and/or R, whichever marker fired, then V |

**Phase R runs on every legacy path**, last before V: a v3 conversion can surface
collisions too, and v6 must never be claimed over colliding epic numbers.

**Never run Phases 2–4 on a v4 or v5 project.** Its stories, epics and docs are already
correct.

**Dry run:** every phase below still runs its read-only part and prints what it *would*
write. Nothing is created, moved, deleted, stamped, renamed or committed.

## Phase 2 — Stories (v3 only)

For every `tasks/*/epics/NN_<slug>/stories/*.md`, prepend frontmatter derived from the v3
prose, and leave the body intact.

**Dispatch decision first.** The unit is one epic folder holding at least one story:

```bash
find tasks -type f -path 'tasks/*/epics/*/stories/*.md' | sed 's|/stories/[^/]*$||' | sort -u | wc -l
```

Announce the branch before converting any story. At **≥3 such epics**, fan out per the
[subagent-fanout contract](../../../references/subagent-fanout.md): one investigation
agent per epic (`model: haiku`) returns each story's extracted frontmatter as structured
data, and the **orchestrator** writes every file. A story an agent cannot parse comes back
in an `unparsed` list and is handled inline. Below 3, convert inline and say so.

| Frontmatter key | v3 source | Conversion |
|---|---|---|
| `id` | `# Story EE-SS: …` heading, or the `EE-SS` filename/index | keep `EE-SS` |
| `title` | text after `# Story EE-SS:` | strip the `Story EE-SS:` prefix |
| `epic` | parent folder `epics/NN_<slug>/` | `NN` |
| `status` | `> **Status:** X` line | `TODO`→`todo`, `IN PROGRESS`→`in-progress`, `DONE`→`done`, `SKIP`→`skip`, `BUG`→`bug` |
| `size` | the epic's `## Stories` row, or a `Size:` line | `S`/`M` kept; `L`/`XL`→`M`, flagged "was L/XL, consider splitting" |
| `blocked_by` | `## Dependencies` section (story IDs) | `[id, ...]`; none → `[]` |
| `files` | `## Files to Create/Modify` table (backticked paths) | `[path, ...]`; none → `[]` |
| `issue` | a `#NNN` in the body; else a `gh issue list` match on the `[EE-SS]` title tag | the number, or empty |
| `pr` | — | empty. `ck-project backfill` recovers it from the linked issue afterwards |
| `delivery` | — | empty |
| `prior_status` | the Bug Report's `Prior status:` (only when `status: bug`) | the recorded status, else empty |

One `key: value` per line, inline `[…]` lists, no block scalars. The frontmatter goes
above the existing `# Story …` heading; acceptance criteria, notes and summaries stay
as they are. Remove the in-body `> **Status:** …` line when it sits cleanly on its own
line (a stale second copy); leave it when removing it would disturb prose. The frontmatter
wins either way.

**Dry run:** name every story file with the block that would be prepended, plus every
story that could not be parsed.

## Phase 3 — Epics and architecture docs (v3 only)

**3a — EPIC.md.** Add the seven v7 epic keys, the same a freshly planned epic carries
([`plan/references/templates.md`](../../plan/references/templates.md)), and emit all
seven even when empty. A present key tells the next skill the field exists to fill.

| Key | v3 source |
|---|---|
| `epic` | parent folder `NN` |
| `slug` | folder slug (`NN_<slug>` → `<slug>`); the owning feature-doc folder name when one exists, so the `EPICS_INDEX` Docs cell links |
| `title` | the epic title heading |
| `description` | the `Goal:` line or first description sentence, no `\|` |
| `issue` | a `#NNN` in the epic body, else empty |
| `pr` | empty |
| `delivery` | empty |

Never write `integration:` on an epic; the level is a plan property that `ck-migrate`
records in `OVERVIEW.md`. Remove the `## Stories` table, which is now a generated view.
Keep every other authored section, `## Dependencies` included: it records why one epic
waits on another.

**3b — pre-v3 architecture docs** (only when L0 found them). Mechanical, link-preserving:

1. **Flat doc → subfolder.** `features/<slug>.md` → `features/<slug>/index.md`
   (`mkdir -p`, then `git mv`). Rewrite its relative links one hop deeper:
   `../_shared.md` → `../../_shared.md`, `../folder-structure.md` → `../../folder-structure.md`.
2. **Layer docs → per-feature.** Split `components.md` / `api-contracts.md` /
   `database-schema.md` / `data-flow.md`: each component, endpoint, table or flow goes to
   the feature that owns it, and anything two or more features share goes to `_shared.md`.
   Move the originals to `docs/architecture/archive/`. Never delete them.
3. When a piece's owner is ambiguous, list the ambiguous pieces and ask before assigning.
   Never guess silently.

**3c — design flag and ledger.** Give every `features/<slug>/index.md` this frontmatter:

```markdown
---
slug: <slug>
design: planned
---
```

`design` is `planned` when the feature has an epic or story in `tasks/`, else `pending`.
Fold in `DESIGN_LEDGER.md` when present (a `planned` row → `planned`, a `pending` row →
`pending`), then delete `DESIGN_LEDGER.md`. It is the one file this conversion removes.

**Dry run:** list each `EPIC.md` with the keys it would gain and whether its `## Stories`
table would go, each flat-doc move, each layer doc and the feature docs it would split
into, and the ledger deletion.

## Phase 4 — v3 artifacts (v3 only)

- Hand-maintained `STORIES_INDEX.md` / `FEATURE_INDEX.md` need no action here.
  `ck-migrate v7` untracks them and regenerates the views.
- Dated journal or delta docs (`features/<slug>/YYYY-MM-DD_*.md`, design records) stay in
  place as inert history. Never delete them; say in the report that nothing writes them.

## Phase S — Flatten the team-skill folders

`/ck-code:team` once wrote `.claude/skills/experts/<role>/SKILL.md` and
`.claude/skills/guides/<tech>/SKILL.md`. Claude Code only discovers
`.claude/skills/<name>/SKILL.md`, so none of them was ever a registered skill. A no-op
when no nested folder exists.

**S1 — enumerate (read-only):**

```bash
ls -d .claude/skills/experts/*/ .claude/skills/guides/*/ 2>/dev/null
```

**S2 — collision check (hard).** Targets are `.claude/skills/expert-<role>/` and
`.claude/skills/guide-<tech>/` (`guides/conventions/` → `guide-conventions/`). If any
target already exists, the project is half-migrated: stop, list every colliding pair, and
never merge or overwrite.

**S3 — move** the whole folder, siblings and history included:

```bash
for d in .claude/skills/experts/*/; do git mv "$d" ".claude/skills/expert-$(basename "$d")"; done
for d in .claude/skills/guides/*/;  do git mv "$d" ".claude/skills/guide-$(basename "$d")";  done
rmdir .claude/skills/experts .claude/skills/guides 2>/dev/null
```

`rmdir`, never `rm -rf`: it refuses when a file escaped the loop. If it refuses, list the
remainder and stop.

**S4 — names and stale paths.** The directory name is the command, so a `name:` that
disagrees with its new folder fails silently. Fix every mismatch, then rewrite surviving
nested paths to the flat form:

```bash
grep -H '^name:' .claude/skills/expert-*/SKILL.md .claude/skills/guide-*/SKILL.md
grep -rln 'skills/experts/\|skills/guides/' .claude/skills/ CLAUDE.md docs/ 2>/dev/null
```

Leave every other line of each skill untouched, the `ck-code:team GENERATED` marker
included.

**S5 — triggers for old generations.** Build and fix load an expert or guide only through
its own `paths:` / `keywords:` frontmatter. An old generation carrying neither is never
matched. For each such skill that still carries the `ck-code:team GENERATED` marker, add
the anchors below as inline lists (`paths: ["server/**", "api/**"]`) when its slug appears in the tables. A skill
without the marker is a hand-written one: list it, never edit it. List any slug the
tables do not cover, and recommend `/ck-code:team --regenerate` for all of them in the
report. `expert-qa`, `expert-qa-project`, `expert-analyst` and `guide-conventions` load
unconditionally and need no trigger.

| Expert | `paths:` | `keywords:` |
|---|---|---|
| `expert-frontend` | `mobile/**`, `app/**`, `components/**`, `screens/**`, `ui/**` | frontend, UI, component, screen |
| `expert-backend` | `server/**`, `api/**`, `backend/**`, `services/**` | API, endpoint, server, handler |
| `expert-devops` | `docker/**`, `.github/**`, `ci/**`, `deploy/**` | deploy, CI, docker, pipeline |
| `expert-security` | `auth/**` | auth, secret, crypto, payment |
| `expert-database` | `**/migrations/**`, `**/*.sql`, `models/**` | schema, migration, database |

| Guide | `paths:` |
|---|---|
| `guide-rust` | `**/*.rs` |
| `guide-cpp` | `**/*.cpp`, `**/*.h`, `**/*.hpp` |
| `guide-typescript` | `**/*.ts`, `**/*.tsx` |
| `guide-react-native` | `mobile/**/*.tsx` |
| `guide-python` | `**/*.py` |
| `guide-go` | `**/*.go` |
| `guide-java` | `**/*.java`, `**/*.kt` |
| `guide-swift` | `**/*.swift` |

These tables are anchors for slugs older generations happened to produce, not a roster.
Never infer that a skill exists because it appears here; only S1's `ls` decides that.

**Dry run:** run S1, S2 and S4's greps, then print the `git mv` pairs, the `name:`
mismatches, the stale paths and the S5 trigger lines that would be written.

## Phase R — Renumber colliding epics

An epic number, and therefore a story `id`, must be unique across every plan
([`data-model.md`](../../../references/data-model.md#epic-and-story-numbers-are-globally-unique)).
A no-op when no number is used by more than one plan.

**Dry run:** R1, R2, R3 and R5's grep are read-only. Run them and print the full old → new
map, the R3 result and the R4 rewrite table. No `git mv`, no frontmatter or prose edit, no
branch rename.

### R1 — Detect (read-only)

List the plans, sorted by folder name (plan folders are dated, so the sort is
chronological), and every epic folder:

```bash
find tasks -mindepth 2 -maxdepth 2 \( -name OVERVIEW.md -o -name PROJECT_OVERVIEW.md -o -name FEATURE_OVERVIEW.md \) \
  | sed 's|/[^/]*$||' | sort -u
find tasks -mindepth 3 -maxdepth 3 -type d -path 'tasks/*/epics/*' | sort
```

`find`, never a `tasks/*/…` glob: an unmatched glob aborts under zsh and would report no
epics on a project that has some. A plan with no numbered epic folders is skipped: it
takes no offset.

**Divergence guard (hard).** A directory holding `epics/` but no overview file is
invisible to the plan list while still contributing story ids. If one exists, stop and
list it. The user adds the overview file or moves the folder, then re-runs.

### R2 — Compute offsets

Walk the plans in sorted order with `running_max` starting at 0:

```
offset(plan) = max(0, running_max + 1 - min(epic numbers of plan))
new(NN)      = NN + offset
running_max  = max(running_max, largest new(NN) in this plan)
```

- The oldest plan never renumbers, so its merged branches and published issues stay valid.
- A plan already above the running max keeps its numbers (offset 0).
- Gaps are kept, not densified: `01, 03` becomes `05, 07`.
- Idempotent: after one pass every offset is 0.

| Plan (sorted) | min | running_max in | offset | result | running_max out |
|---|---|---|---|---|---|
| `2026-01-10_project` | 1 | 0 | 0 | `01–04` unchanged | 4 |
| `2026-03-05_feature-billing` | 1 | 4 | 4 | `01–03` → `05–07` | 7 |

Present the full old → new id map, grouped by plan, before writing anything.

### R3 — Open-PR gate (hard)

```bash
git branch --list "epic/<oldNN>-*" "story/<oldEE>-*" "fix/<oldEE>-*"
gh pr list --head <branch> --state open --json number 2>/dev/null
```

If any affected branch has an open PR, stop and list them. The user merges or closes them
first, then re-runs. Never rename a branch out from under an open PR.

### R4 — Rewrite (mechanical)

| Artifact | Change |
|---|---|
| `epics/NN_<slug>/` | `git mv` to `epics/<new>_<slug>/` |
| `EPIC.md` frontmatter | `epic: NN` → `epic: <new>` |
| Story frontmatter | `id: NN-SS` → `<new>-SS`, `epic: NN` → `<new>` |
| Story `blocked_by:` | every entry rewritten with **that same plan's** offset |

A pre-v6 project cannot express a cross-plan dependency, so the owning plan's offset is
always right for `blocked_by`. `issue:` numbers are never touched.

Apply the whole map at once. Old and new ranges can overlap (`01→03` beside `03→05`), so
a sequence of substitutions re-hits values it just wrote:

- **Folders** move in two passes through a temporary prefix
  (`NN_slug` → `TMPnew_slug` → `new_slug`).
- **Frontmatter** is rewritten in one pass per file, each `epic:`, `id:` and `blocked_by:`
  number matched against the complete map once. Never one `sed` per number.

### R5 — Ids in prose (confirm, never blind-rewrite)

`ROADMAP.md`, the overviews and story bodies mention ids in free text, where `\d\d-\d\d`
also matches dates and versions. Grep the affected plans, present each candidate with its
suggested replacement, and apply only what the user confirms.

### R6 — Branch renames (offer)

For affected local branches that cleared R3, offer `git branch -m <old> <new>`. Declining
leaves an orphan branch, which `ck-doctor` reports.

### R7 — Carry into the report

The full id map, plans left unchanged, branches renamed or skipped, prose edits applied
or declined, and every story whose `issue:` is set: its published issue title still
carries the old `[EE-SS]` token. That is cosmetic, because `ship` resolves an issue by
its number, never its title. Nothing is written to GitHub.

## Phase V — Stamp and commit the v6 stage

1. **Stamp only when needed.** When `tasks/VERSION.md` is absent or its `layout:` is older
   than `v6`, write it as below. A `v6` or `v7` stamp is left alone: never write a lower
   layout over a higher one.

   ```markdown
   <!-- AUTO-GENERATED by ck-code. DO NOT EDIT BY HAND. -->

   layout: v6
   ```

2. **Do not run `ck-index`.** `ck-migrate v7` regenerates the views once the tree is v7.
3. **Commit the stage**, the tree having been clean when the run started:

   ```bash
   git add -A && git commit -m "chore(ck-code): convert the project to layout v6"
   ```

   On a v6/v7-stamped project that only needed S or R, the message is
   `chore(ck-code): repair pre-v6 leftovers`.

Then return to `migrate`, which runs `ck-migrate v7` and folds this commit into the final
one.

**Dry run:** print the stamp that would be written and the commit message. Run neither.

## Report items

- Stories: N found → N converted; every status re-spelled (count) and every `L`/`XL`
  re-sized to `M` (by id, so the user can split them).
- Every story file that could not be parsed, listed for manual review.
- Epics converted, `DESIGN_LEDGER.md` retired, journal docs left inert.
- Skill folders flattened, one line per move, or "none". These are now real Claude Code
  skills: `/expert-<role>` is invocable and guides auto-load after a restart. S5 triggers
  added, hand-written skills listed, and the `/ck-code:team --regenerate` advice.
- The Phase R items from R7, or "epic numbers were already unique".
- For a v3 conversion, `ck-project backfill` recovers `pr:` from the linked issues.

## Rules

- **Never run Phases 2–4 on a v4 or v5 project.**
- **Always run Phase R on every legacy path.**
- **Never delete a story body, journal doc or design record.** Only `DESIGN_LEDGER.md` goes.
- **Always list unparseable files.** A skipped file is never silent.
- **Never overwrite an existing flat skill folder** (S2). Move folders with `git mv`, never copy-then-delete.
- **Never edit a team skill without the `ck-code:team GENERATED` marker** (S5).
- **Never renumber the oldest plan**, and never renumber around a plan folder with no overview file.
- **Never rename a branch that has an open PR** (R3).
- **Never rewrite the id map one number at a time** (R4).
- **Never blind-rewrite an id in prose** (R5). Ask first.
- **Never write to GitHub.**
- **Never write a lower layout over a higher stamp**, and never stamp `v7` here: `ck-migrate` does.
