---
name: doctor
description: Use when checking a ck-code project for problems — a stale layout stamp, story frontmatter that will not parse, generated indexes that disagree with the story files, unresolvable blocked_by dependencies, feature-doc slug drift, unregistered team skills, or orphan epic branches. Read-only; reports each finding with the command that fixes it.
argument-hint: "[tasks/<slug>] [--quiet]"
effort: low
model: haiku
context: fork
agent: Explore
background: false
allowed-tools: Bash(ck-doctor*)
disallowed-tools: Write, Edit, NotebookEdit
---

# Doctor — Project Health Report (Read-Only)

Reports what is broken in **this project**. It writes nothing: every check is a read, and
the index-drift check regenerates into a throwaway copy rather than the project.

The mechanical work lives in `scripts/ck-doctor.sh` — this skill runs it, then explains
what each finding means and which command repairs it. Never re-implement a check here in
prose; the script is the single source of truth for what "broken" means.

## VERSION GATE (hint only)

Never block. The layout stamp is itself check 1 of the report, so a pre-v6 project is
diagnosed rather than refused. See [`version-gate.md`](../../references/version-gate.md).

## PHASE 1: RUN

```bash
ck-doctor
```

Pass `$ARGUMENTS` through verbatim when present — `tasks/<slug>` scopes the plan checks,
`--quiet` drops the `OK` rows. Run it **once**; never loop it, and never re-run a check
by hand to "confirm" a finding.

If the script is missing or non-executable, say so and stop — do not fall back to
improvising the checks in prose, which is exactly the drift this skill exists to catch.

## PHASE 2: PRESENT

Return the script's output **verbatim** first — this skill runs forked, so its result is
relayed and a summary would discard the report. Then add the interpretation below.

Exit status is the verdict: `0` = healthy (warnings allowed), `1` = at least one ERROR.

### 2.1 What each finding means

| Row | ERROR means | Fix |
|---|---|---|
| `layout` | the stamp is missing or pre-v6; every change-producing skill will block | `/ck-code:migrate` |
| `team layout` | skills sit in nested `experts/`/`guides/` folders, so Claude Code registers none of them | `/ck-code:migrate` |
| `stories` | a story's frontmatter will not parse, or its status/size/delivery is outside the vocabulary. `delivery` with no `pr:` is the common one — nothing anchors it, so `ck-project sync` can never re-check whether it merged | fix the frontmatter, then regenerate; `ck-project backfill` recovers a missing `pr:` from the linked issue |
| `indexes` | a generated view disagrees with the story files — usually a hand-edit, or a regenerate that never ran | `ck-index` |
| `epic ids` | the same epic number is used by more than one plan — the v6-defining collision; branches and `blocked_by` are ambiguous | `/ck-code:migrate` (Phase R renumbers) |
| `story ids` | one story id names two stories across plans — breaks `build EE-SS`, `blocked_by`, and branch names | `/ck-code:migrate` (Phase R renumbers) |
| `plan overview` | an `epics/` dir has no `PROJECT_OVERVIEW.md`/`FEATURE_OVERVIEW.md`, so the plan is invisible to `ck-index` and `migrate` yet still feeds dependency checks | add the overview file |
| `plan naming` (WARN) | a hand-made plan folder name contains whitespace — `ck-issues`/`ck-project` silently skip spaced paths | rename to a hyphenated slug |
| `settings` (WARN) | `tasks/SETTINGS.md` has no frontmatter fence, issue tracking is on with no project configured, or the mapped board/columns are gone or unreachable | `/ck-code:config board` |
| `dependencies` | a `blocked_by` id resolves to nothing, a story blocks itself, there is a cycle, or a `done` story still depends on open work | fix `blocked_by` in the frontmatter |
| `feature docs` (WARN) | an epic slug has no `features/<slug>/index.md`, so its `FEATURE_INDEX.Docs` cell is `—` and `build` has no doc to read | `/ck-code:design sync` |
| `team skills` (WARN) | none generated, or one is invalid — `build` and `fix` then run with no project expertise | `/ck-code:team` |
| `branches` (WARN) | an `epic/NN-*` branch has no matching epic folder, usually left by a rename | delete it once merged |
| `design system` (WARN) | a cached design-system card is missing or its content no longer matches the manifest digest, so `build` would copy markup that drifted from its source | `/ck-code:design ds` |
| `board` (WARN) | a Projects card sits in a column the story's `status:` + `delivery:` do not call for — a skill changed frontmatter without syncing, someone dragged a card by hand, or a PR merged since the last sync | `ck-project sync` |

### 2.2 Report

Lead with the verdict in one line (`3 errors — this project will not build until they are
fixed`, or `Healthy — 2 warnings`). Then, **only for rows that are not OK**, give one
short paragraph each: what it means for the user's next command, and the exact command to
run. Order by severity, ERRORs first. Say nothing about OK rows beyond the table already
printed — a clean project deserves a short answer.

Close with the single highest-value next command, never a list of every fix at once.

## RULES

- **Never write, edit, or create any file** — including running `ck-index` against the
  project. The only permitted Bash call is `ck-doctor`, which is itself read-only.
- **Never fix a finding in this skill** — report it and name the command. Repair belongs
  to `migrate`, `design`, `team`, or a deliberate `ck-index` run the user chooses.
- **Never call the `Skill` tool** — this skill runs forked and read-only; an Explore fork
  has no write tools, so the callee would fail at its first file write. Hand off with the
  `NEXT:` line instead.
- **Always** end with one directive line and nothing after it, per
  [`skill-invocation.md`](../../references/skill-invocation.md) —
  `NEXT: /ck-code:<skill> <args>` for the **single most severe** finding that carries a
  repair command. The main session offers it as a one-click run, so the user does not
  retype it. Emit none when the report is clean, and none when the top finding's repair is
  a plain shell command (`ck-index`) rather than a skill — print that command instead.
- **Never restate or re-derive a check in prose** — `ck-doctor` defines what is broken;
  this file only interprets its output.
- **Never summarise the script output away** — return it verbatim, then interpret.
- **Never treat a WARN as a blocker** — warnings are advisory; only an ERROR means the
  project is in a state a change-producing skill will trip over.
- **Always output in English.**

## NEXT

Fix the ERRORs in the order the report lists them, then re-run `/ck-code:doctor` to
confirm a clean bill. With no errors, `/ck-code:track next` picks the next story.
