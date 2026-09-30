---
name: verify
description: Use when the user wants to manually test a whole feature, plan or epic before promoting it — a checklist of every human check to run, resuming a test session, recording pass or fail results, or reporting an issue found while testing. Not for explaining code (use explain) or for a bug found outside a test session (use fix). Argument is an optional `tasks/<plan>` path, `--epic NN`, or a feature name, plus `--all` to retest every item including passed ones.
argument-hint: "[tasks/<plan> | --epic NN | <feature name>] [--all]"
effort: medium
allowed-tools: Bash(ck-story get*) Bash(ck-plan get*) Bash(ck-view*) Bash(git status*) Bash(git diff*) Bash(git log*) Bash(git branch*) Bash(git rev-parse*) Bash(git add*) Bash(git commit*) Bash(ls*) Bash(find*) Bash(grep*) Bash(awk*) Skill
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/no-ai-guard.sh"
---

# Verify — Whole-Feature Manual Test Checklist

Builds one checklist of every manual test a feature needs, walks the tester through it, and
records each result in `tasks/<plan>/CHECKLIST.md`. A pass ticks the story's human-check box.
An issue is recorded, then handed to `/ck-code:fix`, which diagnoses it against the right story
and writes the bug. A re-run resumes the checklist where the last session stopped. With `--all`,
it retests every item, passed ones included.

`build` 8.5 checks one story as it lands. `verify` checks the assembled feature: the human
checks that had to wait (a deploy, a sandbox, a later epic), plus the cross-story journeys no
single story owns.

References: [checklist-format.md](references/checklist-format.md) (the `CHECKLIST.md`
contract) · [`data-model.md`](../../references/data-model.md) ·
[`skill-invocation.md`](../../references/skill-invocation.md) ·
[`workflow-map.md`](../../references/workflow-map.md).

## ROUTING CHECK (do first)

- The user only wants to know how a feature works or how to test it, with nothing recorded →
  `/ck-code:explain <feature>`
- A bug reported outside a test session → `/ck-code:fix`
- No story in scope is `done` yet → `/ck-code:build` first

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).

## PHASE 0: VERSION GATE (hard gate)

Layout stamp: !`cat "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tasks/VERSION.md" 2>/dev/null || echo "ABSENT — no tasks/VERSION.md"`

`layout: v7` → **PASS**. Anything else runs the shared
[version gate](../../references/version-gate.md) (HARD GATE). Never read or write project
state before it passes.

## PHASE 1: RESOLVE SCOPE

| Argument | Scope |
|---|---|
| `tasks/<plan>` | that plan |
| `--epic NN` | the plan owning `tasks/*/epics/NN_*/` (zero-pad `NN`), with items filtered to epic `NN`. The checklist file is still the plan's |
| free text | match its keywords against `docs/architecture/features/*/` slugs and `EPIC.md` `slug:`/`title:` lines, as `explain` FEATURE MODE F.1 does. One plan → that plan. Several, or none → list them and stop |
| empty | the plans that have a `CHECKLIST.md` with open items, or `done` stories with an unticked human check. Exactly one → use it. Several → `AskUserQuestion`. None → say so and stop |

`--all` combines with any row above. It changes only which items the session walks (3.1),
never how the checklist is built.

`--epic` without a two-digit number is an error. Say so and stop. Never guess a plan.

## PHASE 2: BUILD OR REFRESH THE CHECKLIST

### 2.1 Read (one parallel batch)

- `tasks/<plan>/OVERVIEW.md` (title, `integration:`), and `CHECKLIST.md` when it exists
- every `EPIC.md` and story file in scope: frontmatter `id`, `title`, `status`, `files:`,
  and the Acceptance Criteria
- the feature doc `docs/architecture/features/<slug>/index.md` (slug from the epics), for its
  `## Flows` and setup facts. Skip it if absent

That batch is the whole of Phase 2's reading. Source files are read later, per item, in 3.2.
Never dispatch a subagent and never explore the codebase here.

### 2.2 Derive items

1. **Human checks.** Each acceptance criterion of a `done` story whose text contains
   `human check` (any case) becomes one item, whether or not it is ticked. An already-ticked one
   enters as `pass` with Result `pass (recorded in story)`, so the checklist starts from the truth.
2. **Stories with no human check.** Each `done` story without one gets one item derived from
   its most observable criterion, Source `NN-SS criterion`.
3. **Journeys.** Each `## Flows` entry of the feature doc that crosses two or more stories
   becomes one item that walks the flow end to end, Source `journey · …`.
4. **Not yet testable.** Stories not `done` are listed, never itemized.

Write each new item as an **outline**, from the 2.1 batch alone: heading, Source,
What this checks, a one-line Expected from the criterion, and `- **Steps:** outline`.
It is detailed later in 3.2, when it comes up. Steps are click-and-look through the running
app. An automated test command is a valid step only for a headless surface, as `plan` 3.1
allows.

### 2.3 Write

With no `CHECKLIST.md`, write it from the template. With one, apply the refresh merge rules.
Both are in [checklist-format.md](references/checklist-format.md). Then print the summary:
`C items · P pass · F fail · B blocked · T todo`, plus a **Retest** list (`fail` items whose
story is back at `done`) and a **Waiting on fix** list (`fail` items whose story is at `bug`).

## PHASE 3: RUN THE SESSION

### 3.1 Order

Start with the `## Before you test` steps, printed once. Then the **Retest** items, then `todo`
and `blocked`, in `C-NN` order. With `--epic NN`, only that epic's items and the journeys that
touch it. Items **Waiting on fix** are skipped: their fix has not landed.

With `--all`, `pass` and `skip` items join too, still in `C-NN` order after the Retest
items. This is a full retest, for example after a refactor or before a release. Items
**Waiting on fix** are still skipped.

### 3.2 Detail, then ask

Take the next two items. For each whose Steps read `outline`, or fall short of the
**detail standard** in [checklist-format.md](references/checklist-format.md#writing-an-item--the-detail-standard),
write it in full now, and write it into `CHECKLIST.md`. Ground it by reading that item's
stories' `files:` directly, in one parallel batch, plus a targeted `grep` for a label or string
they do not show. Read nothing else, and never dispatch a subagent. A tester who has never seen
the code must be able to run the item alone, and the item stays terse: exact, never wordy.

Print the two items **in full**, every field exactly as the checklist has it. Never
shorten, merge or paraphrase steps when printing. Then **one** `AskUserQuestion` with one
question per item: **PASS** · **ISSUE** (describe what you saw) · **BLOCKED** (say what is
missing) · **SKIP**. An ISSUE or BLOCKED answer with no description gets one plain follow-up
asking for it. Never record an issue without the tester's own words.

### 3.3 Record (after every batch)

- **PASS** → item `pass` + date. When the Source is `NN-SS human check`, tick that criterion
  in the story file (`- [ ]` → `- [x]`, that line only).
- **BLOCKED** / **SKIP** → the status, date and the tester's words. The story is left alone.
- **ISSUE** → item `fail`, date, the tester's words verbatim. Then go to 3.4.

When the item already had a result (a `--all` retest), the new status and Result replace it and
the previous result is kept inline: `pass 2026-10-02 (was pass 2026-09-30)`. Only the latest
`(was …)` is kept. A retest ISSUE on a ticked human check leaves the tick alone: the bug is
`fix`'s to record.

Update `updated:` in the frontmatter. Then commit the checklist and every story file it ticked,
on the current branch:

```bash
git add tasks/2026-09-24_ariary-paid-games/CHECKLIST.md tasks/2026-09-24_ariary-paid-games/epics/41_soka-stake-integration/stories/02_real-ariary-status-read.md
git commit -m "chore(tasks): record manual verification for ariary-paid-games"
```

Committing after each batch is what makes every later hand-off safe to **Skip** and every
session resumable.

### 3.4 Hand an issue to `fix`

The report is `C-NN — expected <the item's Expected> — saw <the tester's words>`. The item's first story ID names the candidate story. For a journey, pick the story whose
`files:` or criteria best match the tester's words. `fix` Phase 2.5 widens the scope itself.
Hand off per [`skill-invocation.md`](../../references/skill-invocation.md):

```
→ [verify → fix] /ck-code:fix tasks/2026-09-24_ariary-paid-games/epics/41_soka-stake-integration/stories/02_real-ariary-status-read.md --report "C-04 — expected the real N/10 counter on the fifth card — saw the fixture 3/10 after sign-in"
  reason: C-04 failed during manual verification
```

- **Run it**: `fix` diagnoses the issue against that story and writes the bug (`status: bug`),
  using the report instead of re-asking it.
- **Skip**: the item stays `fail`. Run the printed command later.
- **Change arguments**: a different story.

When `fix` returns, append `→ fix NN-SS` to the item's Result, commit it, and continue at 3.2
with the next items. When `fix` fails, report the failure and stop, per the contract.

## PHASE 4: CLOSE

Print the final summary (2.3 format) and the open items by `C-NN`. When nothing is open, say
the feature is verified and name its promotion as a plain next step:
`/ck-code:ship --promote tasks/<plan>` at level `plan`, `--promote --epic NN` at level `epic`,
nothing at level `story`. It is a recommendation, not a hand-off. When items remain open,
the command to resume is `/ck-code:verify tasks/<plan>`, and `--all` retests everything.

## RULES

- **Never** write the checklist anywhere but `tasks/<plan>/CHECKLIST.md`, and never under any
  format but [checklist-format.md](references/checklist-format.md).
- **Never** delete, renumber or reuse a `C-NN`, or overwrite a recorded Result on refresh.
  Only a tester's answer in a session replaces a Result, and the previous one stays as `(was …)`.
- **Never** walk `pass` or `skip` items without `--all`.
- **Never** record a result the tester did not give, and never mark an item `pass` to close a
  session.
- **Never** edit a story beyond ticking the one human-check line a PASS covers. Status, bug
  sections and Fix Plans are `fix`'s and `build`'s. Only `fix` sets `status: bug`.
- **Never** diagnose or fix an issue here. Record it in the tester's words and hand it to `fix`.
- **Never** hand off before the checklist and ticked stories are committed.
- **Never** invent a screen, route, command or flow. Every step is grounded in a file read.
- **Never** print a vague step or outcome ("check it works", "displays correctly"). Every item
  meets the detail standard before it is printed.
- **Never** dispatch a subagent, and never read source beyond the current batch's stories'
  `files:` plus a targeted `grep`. Detail is written just in time, two items at a time.
- **Never** stage a generated view (`STORIES_INDEX.md`, `EPICS_INDEX.md`).
- **Never** reference AI, Claude, or generated-by notes in a commit —
  [full rule](../../references/no-ai-references.md).
- **Always** output in English.
