---
name: verify
description: Use when the user wants to manually test a whole feature, plan or epic before promoting it — a checklist of every human check to run, resuming a test session, recording pass or fail results, or reporting an issue found while testing. Not for explaining code (use explain) or for a bug found outside a test session (use fix). Argument is an optional `tasks/<plan>` path, `--epic NN`, or a feature name, plus `--all` (retest passed items too) or `--recheck` (reset, retest from scratch).
argument-hint: "[tasks/<plan> | --epic NN | <feature name>] [--all | --recheck]"
effort: medium
allowed-tools: Bash(ck-checklist*) Bash(ck-story get*) Bash(ck-plan get*) Bash(ck-view*) Bash(git status*) Bash(git diff*) Bash(git log*) Bash(git branch*) Bash(git rev-parse*) Bash(git add*) Bash(git commit*) Bash(ls*) Bash(find*) Bash(grep*) Bash(awk*) Skill
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/no-ai-guard.sh"
---

# Verify — Whole-Feature Manual Test Checklist

Builds one checklist of every manual test a feature needs, walks the tester through it, and
records each result: an index `tasks/<plan>/CHECKLIST.md` plus one file per item, grouped by epic
like the stories (`checklist/NN_<epic-slug>/C-NN_<slug>.md`, cross-epic journeys in
`checklist/journeys/`), state in YAML frontmatter. A pass ticks the story's human-check box.
An issue is recorded, then handed to `/ck-code:fix`, which diagnoses it against the right story
and writes the bug. The session is stored too, so a re-run — in this chat or a new one —
resumes at the next item. With `--all`, it retests every item, passed ones included. With
`--recheck`, it first resets every item to `todo`, passes inherited from ticked story checks
included, so the tester reruns the whole checklist from step 1.

The checklist is optional: only this skill creates it, never another skill or a plan step.

**Every state change goes through `ck-checklist`** (commands in
[checklist-format.md](references/checklist-format.md)). This skill edits only Markdown bodies.

`build` 8.5 checks one story as it lands. `verify` checks the assembled feature: the human
checks that had to wait (a deploy, a sandbox, a later epic), plus the cross-story journeys no
single story owns.

References: [checklist-format.md](references/checklist-format.md) (the checklist
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
| empty | the plans with an open session (`session_scope:` set in `CHECKLIST.md`), else those with open items (`ck-checklist count` > 0), else those with `done` stories holding an unticked human check. Exactly one → use it. Several → `AskUserQuestion`. None → say so and stop |

`--all` or `--recheck` combines with any row above. Each changes only which items the session
walks (3.1), never how the checklist is built. Both together mean `--recheck`.

**Older layouts.** When `CHECKLIST.md` holds `### C-NN` headings and no `format: 2`, or any
`ck-checklist` command says the items are ungrouped, run `ck-checklist import tasks/<plan>` first, relay its WARN lines, and commit the conversion
(`git add` the paths it prints) as `chore(tasks): convert the checklist of <plan> to format 2`.

`--epic` without a two-digit number is an error. Say so and stop. Never guess a plan.

## PHASE 2: BUILD OR REFRESH THE CHECKLIST

### 2.1 Read (one parallel batch)

- `tasks/<plan>/OVERVIEW.md` (title, `integration:`), and `ck-checklist summary` +
  `ck-checklist list` when `CHECKLIST.md` exists (never read every item file)
- every `EPIC.md` and story file in scope: frontmatter `id`, `title`, `status`, `files:`,
  and the Acceptance Criteria
- the feature doc `docs/architecture/features/<slug>/index.md` (slug from the epics), for its
  `## Flows` and setup facts. Skip it if absent

That batch is the whole of Phase 2's reading. Source files are read later, per item, in 3.2.
Never dispatch a subagent and never explore the codebase here.

### 2.2 Derive items

1. **Human checks.** Each acceptance criterion of a `done` story whose text contains
   `human check` (any case) becomes one item, whether or not it is ticked. An already-ticked one
   enters as `pass` (`new --recorded`), so the checklist starts from the truth.
2. **Stories with no human check.** Each `done` story without one gets one item derived from
   its most observable criterion, Source `NN-SS criterion`.
3. **Journeys.** Each `## Flows` entry of the feature doc that crosses two or more stories
   becomes one item that walks the flow end to end, Source `journey · …`.
4. **Not yet testable.** Stories not `done` are listed, never itemized.

Create each new item with `ck-checklist new`, from the 2.1 batch alone: `--title`,
`--stories`, `--source`, `--criterion` (the human-check line's exact text, without `- [ ]`),
`--checks`, a one-line `--expected`, and `--recorded` for an already-ticked human check.
It is detailed later in 3.2, when it comes up. Steps are click-and-look through the running
app. An automated test command is a valid step only for a headless surface, as `plan` 3.1
allows.

### 2.3 Write

With no `CHECKLIST.md`, run `ck-checklist init tasks/<plan> --feature <slug> --title "<plan title>"`,
then fill its `## Before you test` body. With one, apply the refresh merge rules. Both are in
[checklist-format.md](references/checklist-format.md). Items come from 2.2 through `ck-checklist new`.
Then print `ck-checklist summary` as it outputs it: counts, **Retest**, **Waiting on fix**, session.

## PHASE 3: RUN THE SESSION

### 3.1 Start or resume

- **An open session, and the arguments did not change its scope** (no `--epic`/`--all`, or
  the same ones) → **resume**. Say `Resuming session N at <next C-NN> (last answered C-NN)`.
  `--recheck` never resumes.
- **`--recheck`** → `ck-checklist start tasks/<plan> [--epic NN] --recheck`. It resets every
  item in scope to `todo` (each previous result kept as `was`) and leaves a fail still waiting
  on its fix as it is. Relay its lines, then commit the paths on its `stage:` line as
  `chore(tasks): reset the checklist of <plan> for a full recheck`. Story ticks stay: the next
  pass finds them already ticked, and a fail goes to `fix` as usual.
- **Otherwise** → `ck-checklist start tasks/<plan> [--epic NN] [--all]`.

Print the index's `## Before you test` steps once. Then `ck-checklist next tasks/<plan>`
gives the items in order: Retest, then `todo` and `blocked` (plus `pass` and `skip` with
`--all`, a full retest after a refactor or before a release), epic by epic with journeys last,
by `C-NN` within an epic, only epic `NN` with `--epic`. When the next item opens a new epic,
say so in one line (`Epic 42 — <title>`) before printing it. Items **Waiting on fix** and items already answered this session never come up.
Never reorder or pick items by hand.

### 3.2 Detail, then ask

Read the two item files `next` printed. For each at `detail: outline`, or short of the
**detail standard** in [checklist-format.md](references/checklist-format.md#writing-an-item--the-detail-standard),
write its body in full now, then `ck-checklist set tasks/<plan> C-NN detail=full`. Ground it by reading that item's
stories' `files:` directly, in one parallel batch, plus a targeted `grep` for a label or string
they do not show. Read nothing else, and never dispatch a subagent. A tester who has never seen
the code must be able to run the item alone, and the item stays terse: exact, never wordy.

Print the two items **in full**, every field exactly as the checklist has it. Never
shorten, merge or paraphrase steps when printing. Then **one** `AskUserQuestion` with one
question per item: **PASS** · **ISSUE** (describe what you saw) · **BLOCKED** (say what is
missing) · **SKIP**. An ISSUE or BLOCKED answer with no description gets one plain follow-up
asking for it. Never record an issue without the tester's own words.

### 3.3 Record (after every batch)

One `ck-checklist record` per answer, the tester's words verbatim:

```bash
ck-checklist record tasks/2026-09-24_ariary-paid-games C-04 pass
ck-checklist record tasks/2026-09-24_ariary-paid-games C-05 fail "the counter still shows 3/10 after sign-in"
```

`pass`, `fail` (ISSUE), `blocked`, `skip`. The script dates the result, keeps the previous one
as `was`, moves the session cursor, and on a pass of an `NN-SS human check` ticks that line in
the story. A retest ISSUE on a ticked human check leaves the tick alone: the bug is `fix`'s to
record. Relay any WARN it prints. An ISSUE then goes to 3.4.

Then commit every path the `stage:` lines printed, on the current branch:

```bash
git add tasks/2026-09-24_ariary-paid-games/CHECKLIST.md tasks/2026-09-24_ariary-paid-games/checklist/41_soka-stake-integration/C-04_real-ariary-counter-after-sign-in.md tasks/2026-09-24_ariary-paid-games/epics/41_soka-stake-integration/stories/02_real-ariary-status-read.md
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

When `fix` returns, run `ck-checklist set tasks/<plan> C-NN fix=NN-SS`, commit the item, and
continue at 3.2 with `ck-checklist next`. When `fix` fails, report the failure and stop, per the contract.

## PHASE 4: CLOSE

When `next` prints `nothing left in this session`, run `ck-checklist close tasks/<plan>` and
commit the index. When the tester stops early, leave the session open: the next run resumes it.
Print `ck-checklist summary` and the open items by `C-NN`. When nothing is open, say
the feature is verified and name its promotion as a plain next step:
`/ck-code:ship --promote tasks/<plan>` at level `plan`, `--promote --epic NN` at level `epic`,
nothing at level `story`. It is a recommendation, not a hand-off. When items remain open,
the command to resume is `/ck-code:verify tasks/<plan>`, `--all` retests everything, and
`--recheck` resets the checklist for a clean retest from the start.

## RULES

- **Never** write the checklist anywhere but `tasks/<plan>/CHECKLIST.md` and
  `tasks/<plan>/checklist/`, and never under any format but [checklist-format.md](references/checklist-format.md).
- **Never** edit checklist frontmatter by hand. IDs, statuses, results, ticks and the session
  go through `ck-checklist`; this skill writes only Markdown bodies.
- **Never** create a checklist outside a `/ck-code:verify` run. It is optional.
- **Never** delete, renumber or reuse a `C-NN`, or overwrite a recorded result on refresh.
  Only a tester's answer in a session, or a `--recheck` the tester asked for, replaces a
  result, and the previous one stays as `was`.
- **Never** pick or reorder items by hand. The order is `ck-checklist next`'s.
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
