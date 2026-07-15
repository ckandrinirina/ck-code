---
name: build
description: Use when implementing a single story from `tasks/` end-to-end with TDD, or when a `status: bug` story handed off by `/ck-code:fix` needs its recorded fix implemented (Bug-Fix Mode). Argument is an optional story-file path; with no argument, picks the next ready story or open bug interactively.
argument-hint: "[path-to-story.md]"
---

# Build — TDD Story Implementation Orchestrator

Implements a single story from `tasks/` using Test-Driven Development, SOLID principles,
and automated QA. Cycle: plan → test (RED) → implement (GREEN) → refactor → QA → complete.
A `status: bug` story handed off by `/ck-code:fix` runs in **Bug-Fix Mode** (Phase 1.3.5).

Story state lives in **story-file YAML frontmatter** (the single source of truth); the index
views are **generated read-only** — this skill changes frontmatter, then regenerates. See [`data-model.md`](../../references/data-model.md).

References: [output-blocks.md](references/output-blocks.md) (compact per-phase present templates) · [examples.md](references/examples.md) (worked dialogues: interactive menu, bug-fix loop) · [tdd-walkthrough.md](references/tdd-walkthrough.md) (SOLID templates, test mappings, quality checks, JUCE rules) · [story-template.md](references/story-template.md) (story-body blocks) · [completion.md](references/completion.md) (Phase 8 summary fields, Files Touched precision, bug-fix sub-loop) · [bug-fix-mode.md](references/bug-fix-mode.md) (implementing a `fix`-recorded bug — per-phase deltas) · [parallel-switch.md](references/parallel-switch.md) (Phase 1.4 explicit-path epic-wave offer) · [native-commands.md](../../references/native-commands.md) (`/goal`, `/fast`, `/code-review` pairings).

**Read each reference at most once per run** — `output-blocks.md` and `tdd-walkthrough.md` are cited from many phases; load each once, keep it resident, and reuse it.

## ROUTING CHECK (do first)

This skill TDD-implements **one story**. If the request is something else, STOP and
recommend the better skill:

- An **un-triaged** bug in shipped code → `/ck-code:fix` first (it diagnoses, writes the failing test + Fix Plan, and flips the story to `status: bug`). A story **already at `status: bug`** is triaged — implement it here in Bug-Fix Mode (Phase 1.3.5).
- 3+ independent ready stories with empty `blocked_by` → `/ck-code:parallel-build`.
- No story exists for the work yet → `/ck-code:plan` first.

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:ship`.

## INPUT

`$ARGUMENTS` is an optional path to a story markdown file. If provided: read and
validate. If empty: enter interactive selection (Phase 1.2).

---

## PHASE 0: VERSION GATE (hard, before any project read/write)

Read `tasks/VERSION.md` (Tier-1 fast path). If it exists AND its `layout:` line reads
`layout: v4` → **PASS**, proceed. If it is missing or the layout differs, run the full
[version-gate.md](../../references/version-gate.md) procedure (Tier-2 detection → stamp
or BLOCK-and-route-to-`/ck-code:migrate`). Never read or write project state before this
gate passes.

---

## PHASE 1: STORY SELECTION

### 1.1 If Story Path Provided

Read the story at `$ARGUMENTS`. Validate its frontmatter (`id`, `title`, `epic`,
`status`, `size`) and that it has a body with Acceptance Criteria. If invalid or missing,
tell the user and stop.

### 1.2 If No Story Path (Interactive — index-driven)

**1.2.0 Feature gate (read `tasks/FEATURE_INDEX.md` FIRST).** Before any story index,
Read `tasks/FEATURE_INDEX.md` and apply the feature-selection gate in
[`feature-index.md`](../../references/feature-index.md): regenerate it with
`"${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh"` if missing or lacking the `GENERATED` header;
compute the unfinished set (`Status` ≠ `DONE`); **0** → all features done, suggest
`/ck-code:plan`, stop; **1** → auto-select and announce it; **2** → fall through (no
prompt); **> 2** → `AskUserQuestion` "Which feature do you want to build?" (single-select,
one option per unfinished feature; each row's `Docs` column routes its feature doc). The
chosen feature's `Plan` + `NN` scope the story index read below. Interactive mode only —
an explicit `$ARGUMENTS` path skips this.

1. Read the chosen feature's `tasks/<Plan>/STORIES_INDEX.md` and filter to its epic `NN`.
   Regenerate first if it is missing or lacks the `GENERATED` header
   ([`stories-index.md`](../../references/stories-index.md)), then re-read.
2. Filter to actionable rows: `Status: TODO` whose every `Blocked by` ID resolves to
   `Status: DONE`, **plus every `Status: BUG` row** (a triaged bug from `/ck-code:fix`,
   always actionable → Bug-Fix Mode). Surface `BUG` rows first with a 🐛 marker — an open
   bug in shipped code outranks new work.
3. Sort by epic, then story number, then size (S < M).
4. **Detect whole-epic options:** group ALL not-`DONE` rows by epic (`NN`); any epic with
   > 1 non-DONE story is a wave candidate.
5. **Detect the parallel-safe set:** if ≥ 2 stories are ready, build a **touched-files
   map** by reading **only** each ready story's frontmatter `files:` list in one batched
   Bash call — never a full body `Read`, never a glob of all stories:

   ```bash
   # READY = each ready story's `File` column (from STORIES_INDEX), prefixed with its plan root
   for f in $READY; do
     echo "== $f"
     awk 'FNR==1&&$0!="---"{exit} FNR==1{next} $0=="---"{exit} /^files:/{sub(/^files:[ \t]*/,"");print}' "$f"
   done
   ```

   Group the `files:` paths so no two stories share a file. The largest conflict-free
   group of ≥ 2 is the **recommended parallel set** — the preferred default. Keep this map:
   Phase 2 reuses the selected story's `files:` for skill matching; only Phase 1.3 issues a
   full `Read` (for the one selected story).
6. **Present the menu and route the choice** per [examples.md](references/examples.md):
   recommended parallel set (⚡, when ≥ 2) → epics → single stories. The selection is the
   one confirmation — parallel/epic routes hand off to `parallel-build` (which does not
   re-prompt); a single story proceeds to 1.3 (Phase 1.4 then skips its offer). If none
   ready, say so + which deps are missing (suggest `/ck-code:plan` if the index is empty).

### 1.3 Load Story Context

Once a story is selected, `Read` the full story file — this is the **only** full body
`Read` of the run. From **frontmatter**: `id`, `title`, `epic`, `size`, `blocked_by`,
`files` (the touched-files set Phase 2 matches skills against — from the 1.2 map if it ran),
`issue`, `status`, `prior_status`. From the **body**: `## Description`,
`## Acceptance Criteria`, `## Implementation Tasks` (if present), `## Technical Notes`. Read
these sections as authored prose — never awk-slice headings. Read `ROADMAP.md` ONLY if the
Technical Notes reference it explicitly.

### 1.3.5 Mode Detection — Story vs Bug-Fix

- **Bug-Fix Mode** — frontmatter `status: bug` (fix leaves a `## Bug Report` with
  `Status: DIAGNOSED` and a Fix Plan, and records the pre-bug status in `prior_status`).
  Follow [bug-fix-mode.md](references/bug-fix-mode.md) for the per-phase deltas: the recorded
  **Fix Plan** (not the acceptance criteria) is the work; the failing reproduction test `fix`
  left is the RED target; completion fills the Bug Report **Resolution** and restores
  `prior_status` instead of writing an Implementation Summary. If `status: bug` but there is
  no `DIAGNOSED` Bug Report, STOP — tell the user to run `/ck-code:fix <story>` (the tree
  drifted from diagnosis). Skip the epic-wave offer (1.4).
- **Story Mode** — normal fresh-story implementation. Continue below.

### 1.4 Epic-Wave Offer (explicit-path only, before status change)

Runs ONLY for an explicit `$ARGUMENTS` story path — **skip** when the 1.2 menu ran or
non-interactively. Never auto-pull parallel-safe peers. If the story's epic still has > 1
non-DONE story, ask (`AskUserQuestion`): build-whole-epic-in-waves
(`Skill("ck-code:parallel-build", "--epic NN")`, status stays `todo`, exit) vs stay on this
story (→ 1.5); if only this story remains, skip silently. Detail:
[parallel-switch.md](references/parallel-switch.md).

### 1.5 Detect Linked GitHub Issue

The story's `issue:` frontmatter field is the linkage (v4 uses the number, never a
title-substring match). If `issue:` is set, present `Linked GitHub Issue: #<n>`; if empty,
present `No linked issue found`. Store the number for `/ck-code:ship`. No `gh` search needed.

### 1.6 Set Status → in-progress (frontmatter + regenerate)

**Bug-Fix Mode:** skip this phase — the story stays `bug` through the fix and is restored
to `prior_status` at Phase 8.6. Do NOT flip `bug → in-progress`.

Edit the story-file frontmatter: `status: todo` → `status: in-progress`. Then regenerate the
views in the same phase:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh" tasks/<slug>
```

That is the whole mutation — the generator recomputes every view from frontmatter, so there
is no index cell, `EPIC.md`, or rollup to touch, and no per-worktree special-casing (a
`parallel-build` agent edits only its own frontmatter; the orchestrator regenerates on merge).

---

## PHASE 2: SKILL DETECTION & CONTEXT LOADING (BLOCKING GATE)

**Mandatory — blocks Phase 3. Never plan or write code until it completes.** Done ONLY when
all three hold: (1) the `ls` of project skills ran, (2) every detected-and-present skill was
`Read`, and (3) the "Skills loaded for this implementation" block was shown to the user.
`expert-qa` is always detected (+ `expert-analyst` for bug-fix flows), and
`guide-conventions` always loads when present. If skills exist but you loaded none, stop and
re-run — a non-empty project must never reach Phase 3 with zero skills loaded, else Phases
5/6 "follow loaded skills" silently become no-ops.

**Skip-fast:** if `.claude/skills/experts/` and `.claude/skills/guides/` are both absent
there are no project skills — read `docs/architecture/folder-structure.md` + the story's
feature doc (+ `_shared.md` when cross-cutting), tell the user "No project skills — run
`/ck-code:team` to generate them", show the "Skills loaded" block as empty, and proceed to
Phase 3 without reading `skill-detection.md`.

Match skills against the **selected story's `files:` set** already in context — prefer narrow
`paths` matches over broad `keywords` matches so an unrelated body is never `Read` on a keyword
coincidence (every body loaded here stays resident through Phases 5–6).

Otherwise, follow [`skill-detection.md`](../../references/skill-detection.md): read the
story's **feature doc** (`folder-structure.md` + the feature doc named in the
`FEATURE_INDEX` `Docs` column, + `_shared.md` when cross-cutting; if the doc is missing, fall
back and suggest `/ck-code:design`), detect required experts and guides, load each
(filesystem check → warn on truly-missing, template in
[output-blocks.md](references/output-blocks.md)), and **report the loaded experts/guides to
the user before Phase 3 — never load skills silently**. Batch all arch-doc reads and skill
loads into parallel tool-call messages.

---

## PHASE 3: IMPLEMENTATION PLANNING

Create a SOLID-compliant plan **before writing any code.**

### 3.1 Research (if needed)

Only when the story needs current docs: use context7 (MCP tools) for framework docs and
WebSearch for uncommon patterns. Don't research well-known basics.

### 3.2 Clarify Ambiguities

If any acceptance criterion is vague, ask the user 1-2 targeted questions — never about
things already clear in the story or architecture docs.

### 3.3 Design with SOLID

Plan the implementation applying each SOLID principle (S, O, L, I, D). Fill out the SOLID
Analysis template in [tdd-walkthrough.md](references/tdd-walkthrough.md): single
responsibility per file/class, open/closed extension points, Liskov-substitutable new types,
focused interfaces, dependency inversion via injection. Every principle addressed before
moving on.

### 3.4 Create Subtasks

**Seed from the story's `## Implementation Tasks` section when present** (authored by
`plan`) — fold those ordered tasks in rather than inventing generic ones; if absent, use the
default breakdown. Track subtasks on **Claude Tasks** (TaskCreate; template in
[tdd-walkthrough.md](references/tdd-walkthrough.md)), each blocked by the previous: tests →
implementation → refactor → QA → completion. If Task tools are unavailable, fall back to an
in-session checklist (never written to the story file) — never skip the breakdown.
**Never persist the plan itself to the story file** — the file records only frontmatter
status, the final summary, and unplanned changes.

### 3.5 Confirm Plan + Branch (single gate)

Present the plan (template in [output-blocks.md](references/output-blocks.md)), then run
`git branch --show-current` and ask **one** `AskUserQuestion` that both confirms the plan and
chooses where the work lands:

- **New branch** — `git checkout -b story/<EE>-<SS>-<slug>` (or `fix/<EE>-<SS>-<slug>` for a
  bug story); slug = kebab-case of the title. Verify with `git branch --show-current`.
- **Current branch `<name>`** — ship will commit here. Omit this option when `<name>` is
  `main`/`develop` (implementation on protected branches is forbidden).
- **Adjust plan** — revise the plan, then re-ask.

Record the chosen branch — the ship phase reuses it (no second branch prompt). Nothing is
touched in Phase 4 until this gate returns a branch.

---

## PHASE 4: TDD — WRITE TESTS FIRST (RED PHASE)

Write failing tests that define expected behavior **before any implementation.**

### 4.1 Start Test Task

Mark the test-writing task `in_progress` (TaskUpdate).

### 4.2 Determine Test Structure

Read existing test files to learn conventions: file naming (`.test.ts`, `_test.rs`,
`test_*.py`), location (co-located, `__tests__/`, `tests/`), framework, assertion style,
mock/stub patterns. Follow loaded guide skills.

### 4.3 Write Tests from Acceptance Criteria

For EACH acceptance criterion, write at least one test (worked mapping in
[tdd-walkthrough.md](references/tdd-walkthrough.md)). Also cover **edge cases** (empty input,
boundaries, max limits), **error scenarios** (invalid input, connection failures, timeouts),
and **integration points** when the story connects two components.

### 4.4 Run Tests — Confirm RED

Run the suite. **Expected: ALL new tests FAIL.** If a new test passes without implementation,
it is likely wrong (testing something that already exists or is trivially true) — fix it.
Present the RED Phase Complete block (output-blocks). Mark the test task `completed`.

---

## PHASE 5: IMPLEMENTATION (GREEN PHASE)

Write the **minimum** code to make ALL tests pass.

### 5.1 Start Implementation Tasks

Mark the first implementation task `in_progress`. **Guard:** confirm the Phase 2 "Skills
loaded" block was shown this run. If not, stop and run Phase 2 now — implementation must apply
the loaded experts/guides.

### 5.2 Implement

Order: (1) create new files from the story's `files:`; (2) modify existing files;
(3) run tests after each significant change; (4) stop as soon as all tests pass — don't
over-engineer. **Rules:** follow the Phase 3 SOLID plan + loaded guide/expert standards; reuse
existing code (check `docs/architecture/`, scan files); write the simplest code that passes;
comment only non-obvious logic. **Log unplanned changes incrementally** — any file touched
outside the story's `files:` set gets one line in a `## Unplanned Changes` body section in the
same Edit pass: `- <path> — <what> — <why>`. Record at the moment of change; empty section =
omit the heading.

### 5.3 Run Tests — Confirm GREEN

Run the full suite. **Expected: ALL tests PASS.** If tests fail, read the output and fix the
implementation (NOT the tests, unless a test itself has a bug). Re-run until green. Present the
GREEN Phase Complete block (output-blocks). Mark implementation task(s) `completed`.

---

## PHASE 6: REFACTOR PHASE

Improve quality without changing behavior. **Tests stay green throughout.**

### 6.1 SOLID Review

Review all new/modified code against SOLID using the SOLID Compliance Check template in
[tdd-walkthrough.md](references/tdd-walkthrough.md). Every principle checked. Record any
violation as an ISSUE to fix in 6.2.

### 6.2 Apply Refactorings

For each issue: apply the refactoring, run tests (must stay green), revert and reconsider if
they break. Common refactorings: extract function, rename, introduce interface/trait for
dependency inversion, split large functions, move code to the correct module per
`folder-structure.md`. Refactors touching files outside the story's `files:` set also log to
`## Unplanned Changes` (same `- <path> — <what> — <why>` format as 5.2).

### 6.3 Final Green Check

Run the full suite once more; present the REFACTOR Phase Complete block (output-blocks).

---

## PHASE 7: QA VALIDATION

QA reviews the work — this is **not** a self-review.

**Always delegate to the `ck-code:qa-validator` agent** (Haiku) — it absorbs the verbose
suite/build/lint output in its own context and returns a compact verdict. Run the heavy
commands inline **only** when that subagent_type is unregistered.

Mark the QA task `in_progress`, then follow [`qa-validation.md`](../../references/qa-validation.md)
— it loads the QA experts, validates every acceptance criterion, runs the suite +
code-quality checks (commands per stack in [tdd-walkthrough.md](references/tdd-walkthrough.md)),
and checks architecture compliance against the feature doc. Present the QA Report
(output-blocks).

**Gate — iteration cap = 3.** At iteration 3, escalate `FIX MANUALLY / ACCEPT AS-IS / ABORT`
via `AskUserQuestion` (wording in output-blocks); never silently continue past 3. On NEEDS
FIXES inside the loop: fix each issue → re-run Phase 6 → re-run this phase with a fresh QA
check.

---

## PHASE 8: COMPLETION

### 8.1 Update Story Body — Implementation Summary

**Bug-Fix Mode:** do NOT append an Implementation Summary. Instead fill the Bug Report
`### Resolution` + `### Files Touched` and flip its `Status: DIAGNOSED → FIXED` (templates in
[../fix/references/bug-section-template.md](../fix/references/bug-section-template.md) Phase
8.1), then continue to 8.6 for the status restore. Full deltas:
[bug-fix-mode.md](references/bug-fix-mode.md).

Append the Implementation Summary block (template in
[story-template.md](references/story-template.md)) to the story body. Required fields and the
**mandatory Files Touched precision** (CREATED = path; MODIFIED = `path:lines` via `git diff`)
are in [completion.md](references/completion.md).

### 8.2 Update Acceptance Criteria Checklist

Mark all acceptance criteria `[x]` in the story body.

### 8.3 Mark Subtasks Complete

Mark every implementation subtask `completed` on Claude Tasks (TaskUpdate) — subtasks live on
Claude Tasks, never the story file.

### 8.4 Show Final Task Summary

Use TaskList to show the completed summary of all tasks.

### 8.5 User Manual Testing — REQUIRED GATE

Story stays `in-progress` until the user confirms PASS here. Never set `done` before that.

**8.5.1** Present the manual-testing prompt (template in
[output-blocks.md](references/output-blocks.md)) — scenarios from acceptance criteria + an
edge case. Ask via `AskUserQuestion`: `PASS / ISSUES`.

**8.5.2** On `PASS` → proceed to 8.6.

**8.5.3** On `ISSUES` → enter the Bug-Fix Sub-Loop (eight ordered steps in
[completion.md](references/completion.md) § 8.5.3): regression test (red) → minimum fix
(green) → **mandatory** re-run of Phase 6 + Phase 7 → mark the `## Manual-Test Bugs` entry
`FIXED` → re-prompt at 8.5.1. **Cap = 3 cycles**; on the 3rd, escalate `FIX MANUALLY / ACCEPT
AS-IS / ABORT` (template in [examples.md](references/examples.md)). Never continue past 3.

### 8.6 Set Status → done (frontmatter + regenerate)

**Bug-Fix Mode:** restore `prior_status` (from the Bug Report — normally `done`) instead of
`done`: frontmatter `status: bug` → `status: <prior_status>`, then clear `prior_status`. Then
8.7 as usual (`fix/` branch, Bug ID in commit).

**Story Mode:** Edit the frontmatter: `status: in-progress` → `status: done`.

Then regenerate the views in the same phase — one call recomputes `STORIES_INDEX.md` and the
`FEATURE_INDEX.md` rollup (a feature whose stories are all `done` rolls up to `DONE`
automatically):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh" tasks/<slug>
```

No index cell-edit, no `EPIC.md` story-table edit — those artifacts do not exist in v4.

### 8.7 Ship (Commit + PR + Issue Updates)

Present the ship options (output-blocks) via `AskUserQuestion`: **SHIP** — invoke
`/ck-code:ship` with the story file path (handles branch, staging, commit, PR, and GitHub
Issue updates); **SKIP** — don't commit yet; remind the user they can run
`/ck-code:ship [story-path]` later.

---

## HARD GATES (cross-phase contract, in phase order)

- **0** — version gate PASSes (`layout: v4`) before any project read/write.
- **1.2.0** — feature index read first; ask when > 2 features unfinished.
- **1.2** — interactive selection prefers the parallel set; an explicit arg is single-story.
- **2** — skills detected, `Read`, and reported BEFORE any planning or code.
- **3.5** — plan + branch confirmed in one gate before any code; never `main`/`develop`.
- **3.3 + 6.1** — SOLID applied at design, verified after refactor.
- **4** — failing tests before implementation (trivial boilerplate exempt).
- **5.2 / 6.2** — off-plan touches logged to `## Unplanned Changes` in the same Edit pass.
- **7** — QA delegated to `qa-validator`; iteration cap = 3, then escalate.
- **8.5** — manual-test gate; bug-fix loop cap = 3.
- **1.3.5 (Bug-Fix Mode)** — implement only the recorded Fix Plan; the failing repro test is
  the RED target; restore `prior_status`, never an Implementation Summary. `status: bug`
  without a `DIAGNOSED` Bug Report → STOP (run `/ck-code:fix`).

## RULES

- **Never store status anywhere but story frontmatter**, and never hand-edit `STORIES_INDEX.md`,
  `FEATURE_INDEX.md`, or `EPIC.md` — change `status:`, then run `ck-index.sh` in the same phase
  (the two are one atomic mutation).
- **Never write a delta/journal doc** — commits are the history. The story body carries only
  the Implementation Summary, Unplanned Changes, and (bug flow) the Bug Report.
- **Never derive "done" from an agent's self-report** — derive it from git + the QA verdict.
- **Never plan or write code before Phase 2 loads and reports the project skills.**
- **Never write failing implementation before RED**, and never edit a test to force GREEN.
- **Never implement on `main` or `develop`.**
- **Never widen a bug fix beyond its recorded Fix Plan** (Bug-Fix Mode).
- Story frontmatter is the source of truth. All output is English regardless of story language.

## NEXT

After manual-test PASS (8.5), run `/ck-code:ship <story-path>` to commit, open the PR, and
update the linked GitHub Issue. If more stories remain, follow with `/ck-code:track next`.

**Native speed-ups (optional, user-driven — see [native-commands.md](../../references/native-commands.md)):**
`/goal "all acceptance criteria in <story> pass and the suite is green"` autonomises the
Phase 7–8 loops; `/fast` suits **`S`** stories (off for `M`/SOLID-heavy); `/code-review --fix`
is a deeper pre-ship diff pass.
