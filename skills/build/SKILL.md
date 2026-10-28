---
name: build
description: Use when implementing stories from `tasks/` end-to-end with TDD — one story, several independent stories at once in isolated worktrees, or a whole epic in dependency-ordered waves, optionally unattended. Also implements a bug-status story handed off by `/ck-code:fix` (Bug-Fix Mode). Argument is an optional story path (with `--quick` or `--full`), space-separated story IDs, or `--epic NN`, any of them with `--auto`; with no argument, picks interactively.
argument-hint: "[story-path [--quick|--full]] | [story-ids...] | --epic NN [--auto]"
effort: medium
allowed-tools: Bash(ck-story*) Bash(ck-qa*) Bash(ck-affected*) Bash(ck-headless*) Bash(ck-view*) Bash(ck-index*) Bash(ck-project*) Bash(ck-plan*) Bash(ck-epic*) Bash(ck-bootstrap*) Bash(ck-reclaim*) Bash(ck-replicate*) Bash(git status*) Bash(git diff*) Bash(git log*) Bash(git show*) Bash(git branch*) Bash(git rev-parse*) Bash(git rev-list*) Bash(git merge-base*) Bash(git ls-files*) Bash(git fetch*) Bash(git add*) Bash(git commit*) Bash(git checkout*) Bash(git switch*) Bash(git merge*) Bash(git revert*) Bash(git worktree*) Bash(gh issue*) Bash(ls*) Bash(find*) Bash(grep*) Bash(awk*) Bash(sed*) Skill
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/no-ai-guard.sh"
---

# Build — TDD Story Implementation

Implements stories from `tasks/` using Test-Driven Development, SOLID principles, and
automated QA. Cycle: plan → test-drive one behaviour at a time (RED → GREEN, repeated) → refactor + prune tests → QA → complete.

**Every story is implemented by a sub-agent — never in this context.** **One story** —
an explicit path, a single menu pick, or a hand-off from `/ck-code:fix` or
`/ck-code:plan --quick` — runs Phase 1 here, then [SINGLE-STORY DISPATCH](#single-story-dispatch)
hands the [story cycle](#the-story-cycle-phases-1786) to one solo agent on its own branch;
**more than one** runs through [PARALLEL MODE](#parallel-mode) (one worktree agent per story,
dependency-ordered waves). Every gate below still applies. `--auto` runs either to the end
with no question ([INPUT](#input)). A cosmetic `S` story takes the [QUICK ROUTE](#quick-route),
which skips the ceremony a label change does not need and none of the checks. No test run ever
opens a window in front of the user ([background-tests.md](../../references/background-tests.md)). A `status: bug` story runs in **Bug-Fix Mode** (Phase 1.3.5)
inside whichever agent builds it. Argument shapes: [INPUT](#input).

Story state lives in **story-file YAML frontmatter** (the single source of truth); the index
views are **generated, gitignored and never committed** — this skill changes frontmatter
through `ck-story`, which regenerates them, and commits only story files. The plan record
(`tasks/<plan>/OVERVIEW.md`) is read with `ck-plan get`. See [`data-model.md`](../../references/data-model.md).

References for this context: [output-blocks.md](references/output-blocks.md) (compact present templates) · [examples.md](references/examples.md) (worked dialogues: interactive menu, bug-fix loop) · [agent-prompts.md](references/agent-prompts.md) (dispatch/resume prompts, return schema) · [native-commands.md](../../references/native-commands.md) (`/goal`, `/fast`, `/code-review` pairings). The builder's references (`story-cycle.md`, `tdd-walkthrough.md`, `completion.md`, `story-template.md`, `bug-fix-mode.md`, `qa-scope.md`) are the agent's to read, never this context's.

Parallel-mode references, read **only** when two or more stories are in scope: [parallel-mode.md](references/parallel-mode.md) (orchestration detail for P1–P9) · [wave-mode.md](references/wave-mode.md) (wave planning) · [conflict-format.md](references/conflict-format.md) (table/integrity/conflict/QA/summary formats).

**Read each reference at most once per run**, keep it resident, and reuse it.

## ROUTING CHECK (do first)

This skill **TDD-implements stories** from `tasks/`. If the request is actually
something else, STOP and hand off per
[`skill-invocation.md`](../../references/skill-invocation.md) — one question, arguments
already filled, never a command the user must retype:

- An **un-triaged** bug in shipped code → offer `/ck-code:fix <bug details>` (it diagnoses, writes the failing test + Fix Plan, and flips the story to `status: bug`). A story **already at `status: bug`** is triaged — implement it here in Bug-Fix Mode (Phase 1.3.5).
- No story exists for the work yet → offer `/ck-code:plan --quick <brief>` (it adds the one story, or routes to full planning when no epic exists to attach to).

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:ship`.

## INPUT

`$ARGUMENTS` is empty, a story path, space-separated story IDs, or `--epic NN`, any of them
optionally with `--auto`:

- **A story path** (`tasks/<slug>/epics/02_<epic>/stories/05_<story>.md`) — Phase 1 for that
  one story, then [SINGLE-STORY DISPATCH](#single-story-dispatch). Validate it before anything
  else (Phase 1.1).
- **Two or more story IDs** (`02-05 02-07`) — PARALLEL MODE, one wave.
- **`--epic NN`** — PARALLEL MODE over every non-`done` story of that epic, in
  dependency-ordered waves.
- **Empty** — interactive selection (Phase 1.2), which also offers the parallel set and
  whole-epic waves.
- **`--auto`** — the same run with **no `AskUserQuestion` until it ends**. Every question takes
  its recommended answer, announced in one line (`Auto: <decision>`) where it would have been
  asked ([parallel-mode.md § Auto mode](references/parallel-mode.md#auto-mode----auto)). The
  scope is **one epic**, never more. `--auto` alone means `--epic NN --auto` for the epic the
  1.2.0 gate would pick, and when several are unfinished, the lowest-numbered one that has a
  ready story, announced. With a story path it is a SINGLE-STORY DISPATCH whose S2 and S6 take
  their auto defaults. The manual test is **deferred, never dropped**: the run ends with the
  checklist and `/ck-code:verify`. Nothing is shipped or promoted under `--auto`.
- **`--quick` / `--full`** (story path only) — `--quick` asks for the [QUICK ROUTE](#quick-route),
  still subject to its eligibility check; `--full` never takes it. Without either, S2 decides.

A dispatch prompt beginning `MODE: delegated` means this run **is** the agent another
`build` run dispatched — read [DELEGATED MODE](#delegated-mode) and nothing else.

---

## PROGRESS TRACKING

Open a task list as the **first action of Phase 0** — one task per phase (`TaskCreate`;
`TodoWrite` only where the session has no `TaskCreate`) this run will
actually execute — then flip each to `in_progress` when it starts and `completed` when its
gate passes. Drop a phase that mode routing skips; never leave it pending. A long run's only
view into where it is comes from this list, so update it as you go and never batch the
updates to the end.

## TOOL-CALL DISCIPLINE

Model round trips are most of a build's wall clock. Batch every independent `Read`, `grep`,
`ls` and read-only `git` query into **one message**, and chain dependent shell steps with `&&`
in one Bash call. Never `find /` or search `$HOME`. A relative link in this skill
(`references/story-cycle.md`) resolves against the `Base directory for this skill` line
printed when the skill loaded. The builder's own discipline (the targeted inner loop, the
run-once `ck-qa` logs, story versus area scope) lives in
[story-cycle.md](references/story-cycle.md#tool-call-discipline).


## PHASE 0: VERSION GATE (hard, before any project read/write)

The stamp is injected at skill-load time — **do not spend a `Read` on it**:

Layout stamp: !`cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && cat tasks/VERSION.md 2>/dev/null || ls tasks/PLAN.md 2>/dev/null | sed 's/^/LITE — /' | grep . || echo "ABSENT — no tasks/VERSION.md"`

Reads `layout: v7` → **PASS**, proceed. Anything else (including `ABSENT`) → run the
shared [version gate](../../references/version-gate.md) (HARD GATE) — it detects an older
or newer layout, offers `/ck-code:migrate` (older only), and stamps a greenfield project. Never read or write project state before
this PASSes.

`LITE — tasks/PLAN.md` → a ck-code-lite project, so the wrong plugin, not an old layout:
[redirect to ck-code-lite](../../references/version-gate.md#lite--redirect-to-ck-code-lite) —
print its `↪` line, run `ck-code-lite:build` with only the `T-NN`, `--waves`, `--auto`, `--quick` and `--full` arguments, and **stop**. Never offer to run `/ck-code:migrate` for it.

---

## PHASE 1: STORY SELECTION

### 1.0 Settle number clashes (no question)

Before any story is resolved or any branch is cut:

```bash
ck-epic resolve
```

It renumbers a local, not-yet-started epic whose number another plan on another branch
already uses ([`data-model.md`](../../references/data-model.md#epic-and-story-numbers-are-globally-unique)). Relay its lines.
A `moved <old> <new>` line whose `<old>` prefixes `$ARGUMENTS` means the story moved: use
the path under `<new>` from here on, and an `EE` in a story id or `--epic NN` given as
`<old>`'s number now reads as the new one. The renumbered files stay uncommitted under
`tasks/` — S1 allows that, and they are committed with the story. Never stop over a
`WARN`. `ck-epic: command not found` is a stale `PATH`, never a reason to skip this step:
re-run it as `"${CLAUDE_PLUGIN_ROOT}"/bin/ck-epic resolve` ([`stories-index.md`](../../references/stories-index.md#a-ck--command-not-found)).

### 1.1 If Story Path Provided

Read the story at `$ARGUMENTS`. Validate its frontmatter (`id`, `title`, `epic`,
`status`, `size`) and that it has a body with Acceptance Criteria. If invalid or missing,
tell the user and stop.

Explicit **story IDs** or `--epic NN` instead of a path skip to
[PARALLEL MODE](#parallel-mode) P1 — resolve each ID against the index there, never here.

### 1.2 If No Story Path (Interactive — index-driven)

**1.2.0 Epic gate (read `tasks/EPICS_INDEX.md` FIRST).** Before any story index, run
the epic-selection gate in [`epics-index.md`](../../references/epics-index.md) — it
owns the regenerate condition, the unfinished-set rule, and the 0/1/2/>2 branches; do not
restate them here. The chosen epic's `Plan` + `NN` scope the story index read below.
Interactive mode only — explicit `$ARGUMENTS` skips this.

1. Read the chosen epic's `tasks/<Plan>/STORIES_INDEX.md` and filter to its epic `NN`.
   The view is gitignored, so a fresh clone has none: run `ck-index tasks/<Plan>` first if it
   is missing or lacks the `GENERATED` header
   ([`stories-index.md`](../../references/stories-index.md)), then re-read. **In the
   two-unfinished-epics case** the gate chose nothing, so read *each* unfinished epic's
   `tasks/<Plan>/STORIES_INDEX.md` (they may be the same file) and filter each to its own
   epic `NN`; every step below stays per-epic, and the menu shows both epics' rows.
2. Filter to actionable rows. A story is **ready** when `status: todo` and every `blocked_by`
   story is `done` or `skip`, or when `status: bug` (a triaged bug from `/ck-code:fix` →
   Bug-Fix Mode). Surface `BUG` rows first with a 🐛 marker — an open bug in shipped code
   outranks new work. An `IN PROGRESS` row is **not ready**; list it separately with ↻ as a
   resume entry (an interrupted run left it there). Picking it names it explicitly, so it is
   resumed, never re-started.
3. Sort by epic, then story number, then size (S < M).
4. **Detect whole-epic options:** group every row that is neither `DONE` nor `SKIP` by epic
   (`NN`); any epic with > 1 such story is a wave candidate. A `SKIP` story is deliberately
   out of scope and never counts toward a wave.
5. **Detect the parallel-safe set:** if ≥ 2 stories are ready in one epic, run
   `ck-view waves --epic NN`. Its **Wave 1** is the largest conflict-free group of ready
   stories — the **recommended parallel set** and the preferred default — computed from
   each story's frontmatter `files:` list without reading a single body. Never derive that
   grouping by hand. PARALLEL MODE P2 re-runs the same command for the full plan; Phase 2
   reuses the selected story's `files:` for skill matching, read at 1.3.
6. **Present the menu and route the choice** per [examples.md](references/examples.md):
   recommended parallel set (⚡, when ≥ 2) → epics → single stories. The selection is the
   one confirmation — parallel and epic choices enter [PARALLEL MODE](#parallel-mode) at P1
   with the scope already resolved (P3 does not re-ask which stories); a single story
   proceeds to 1.3 (Phase 1.4 then skips its hint) and on to SINGLE-STORY DISPATCH. If none ready, say so + which deps are
   missing (suggest `/ck-code:plan` if the index is empty).

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
  drifted from diagnosis). Skip the epic-wave hint (1.4).
- **Story Mode** — normal fresh-story implementation. Continue below.

### 1.4 Epic-Wave Hint (explicit-path only, no question)

Runs ONLY for an explicit `$ARGUMENTS` story path — **skip** when the 1.2 menu ran, in
Bug-Fix Mode, under `--auto`, or non-interactively. Never ask and never auto-pull
parallel-safe peers: an explicit single-story request is respected, and batch routing
belongs to the 1.2 menu.

Count the selected story's epic (`NN`) rows in `STORIES_INDEX.md` whose `Status` is neither
`DONE` nor `SKIP`, this story excluded. Zero → print nothing. Otherwise print one line and
continue to 1.5:

```
Epic NN has K more open stories — /ck-code:build --epic NN builds them in dependency-ordered waves.
```

### 1.5 Detect and Claim the Linked GitHub Issue

The story's `issue:` frontmatter field is the linkage (the number, never a
title-substring match). If `issue:` is set, present `Linked GitHub Issue: #<n>` and claim it
for the account running the build:

```bash
gh issue edit <n> --add-assignee @me
```

`--add-assignee` is additive — an assignee already on the issue is never removed, so a
teammate's claim survives. The call is never fatal: no `gh` auth, no GitHub remote, or an
account GitHub refuses to assign (assignees need repo access) is one reported line, then
carry on building.

If `issue:` is empty, present `No linked issue found` — no `gh` search, `/ck-code:ship`
re-reads the number from frontmatter itself.

Only an orchestrating context claims: this 1.5 before a single-story dispatch, or the whole
wave at P4 before cutting worktrees ([parallel-mode.md](references/parallel-mode.md)). A
builder never repeats it.

### 1.6 Set Status → in-progress (frontmatter + regenerate)

**Bug-Fix Mode:** skip this phase — the story stays `bug` through the fix and is restored
to `prior_status` at 8.6 by the builder. Do NOT flip `bug → in-progress`.

One call flips the frontmatter and regenerates both views:

```bash
ck-story set <story-path> status=in-progress
```

`ck-story` validates the value against the `status` enum, writes the `status:` line, then
runs `ck-index` and `ck-project sync` for that story's plan — the three steps that must
never be half-done. That is the whole mutation: the generator recomputes every view from
frontmatter, so there is no index cell, `EPIC.md`, or rollup to touch, and the views are
never staged (they are gitignored). The board is one more generated view
([`github-projects.md`](../../references/github-projects.md)): `ck-project` is a no-op when
the project has no `tasks/SETTINGS.md` or `github_issues` is off, and a board failure never
blocks the build — report it and continue. Because this flip happens before dispatch (here, or
at P4 for a wave), the builder's own 1.6 finds `in-progress` already and changes nothing.

---

## SINGLE-STORY DISPATCH

One story, from any entry point — an explicit path, a single 1.2 pick, a `/ck-code:fix`
AUTO-BUILD, a `/ck-code:plan --quick` hand-off. This context ran Phase 1 (1.1–1.6) and now
**decides, verifies and gates**; one `ck-code:story-implementer` agent runs the
[story cycle](#the-story-cycle-phases-1786) delegated, on the story's own branch. Its source reads, TDD loop and suite output stay in
its context and are discarded on return; this one sees only the verdict. It is PARALLEL MODE's
solo dispatch with a story branch in place of `$TARGET`, so the level is never switched — at
level `story` the branch still ships its own PR into `<trunk>`.

**Fallback, the only inline path:** when this context has no `Agent` tool (this `build` is
itself running inside a sub-agent), `Read` [story-cycle.md](references/story-cycle.md) and run
it here, as its **Inline fallback** line says. Never fall back for any other reason.

**S1 — Clean start.** `git status --porcelain`. Uncommitted paths are allowed only under
`tasks/` (the story file — 1.6's flip, or a story `plan --quick` just wrote), ck-code's own
guard (`.claude/ck-code-required.sh`, `.claude/settings.json` — `ck-bootstrap` writes them and
never commits) and, in Bug-Fix Mode, the reproduction test the Bug Report names (`fix` leaves
it for build to commit). Any other dirty path stops the run — list the paths and ask the user
to commit or stash them; the integrity gate (S5) needs a tree only the agent changes.

In the same call, `ck-headless`. Its `FOREGROUND` lines go into the dispatch prompt as
`Background:`, and the builder converts them first, without asking
([background-tests.md](../../references/background-tests.md)). `ck-headless: OK` adds nothing.

**S2 — Route, then one question.** Fix the route first ([QUICK ROUTE](#quick-route)) and
announce it in one line. Then resolve the base exactly as Phase 3.5 does (same batched call,
`resolve_base`, same four signals, same level rule — an objection to the derived base is a
level change: name `/ck-code:config integration` and stop). Then **one `AskUserQuestion`, at
most 4 questions** — the agent cannot ask anything, so everything is settled here:

- **Where the work lands** — the 3.5 option table, with **Cancel** in place of *Adjust plan*.
  There is no plan to confirm: the agent plans at Phase 3 itself, as in PARALLEL MODE.
- **Team gate** — QUICK never asks it. Otherwise, when no `expert-*`/`guide-*` skill exists and `tasks/SETTINGS.md` does not say
  `experts: none` (the three options of [parallel-mode.md § P3](references/parallel-mode.md#p3--team-gate-and-confirmation)).
- **Criteria ambiguity** (Story Mode) — only a genuinely vague acceptance criterion; the
  answer goes into the dispatch prompt.
- **Design pending** — a UI story while the Claude Design link is still pending: the question
  and its three answers from [`design-system.md` § Pending at build
  time](../../references/design-system.md#pending-at-build-time). A pasted URL links it here,
  before S3.

**`--auto`:** S1 still stops on a dirty path, but it reports the paths and asks nothing. S2
asks no question. It takes the recommended base option, continues without experts when the
team gate would fire (named in the final report), takes the narrowest reading of a vague
criterion that matches the existing code (passed as `Settled: assumed <reading>`), and builds
a pending-design UI story without the design.

**S3 — Cut and record the base.** Run the chosen option's branch command (`story/…`, or
`fix/…` for a bug story); the S1-allowed uncommitted paths travel with the checkout.
Commit them as the branch's first commit, and skip the commit when nothing is staged:

```bash
git add <the S1-allowed paths: story file, guard files, reproduction test>
git commit -m "chore(tasks): start EE-SS"     # Bug-Fix Mode: test(EE-SS): reproduce <Bug ID>
git rev-parse --abbrev-ref HEAD && git rev-parse HEAD   # the branch, then the Base SHA
```

**S4 — Dispatch.** Announce `Single: EE-SS → dispatching 1 agent on <branch>.`, then one
`Agent` call per [agent-prompts.md § Single-story dispatch](references/agent-prompts.md#single-story-dispatch)
— model tier per [parallel-mode.md § Model tier](references/parallel-mode.md#model-tier--by-reasoning-complexity-never-size)
(QUICK takes the fast tier), plus the `Route:` line and any `Background:` lines.
Never edit a file in this context while it runs.

**S5 — Verify, then QA.** Run the solo integrity gate of
[parallel-mode.md § P5](references/parallel-mode.md#p5--integrity-and-resume) against the S3
Base SHA, with the branch from S3 as `$WORKBRANCH` (Bug-Fix Mode: the Bug Report's `**Status:** FIXED`
line replaces the unchecked-criteria grep). Its classes and the 2-round resume cap
apply unchanged; branch drift is a hard stop. On ✓ complete with `route: QUICK`, verify here
instead of dispatching ([QUICK ROUTE](#quick-route) S5). Otherwise dispatch `ck-code:qa-validator`
per [agent-prompts.md § Inline QA dispatch](references/agent-prompts.md#inline-qa-dispatch), at
the single-story scope of
[§ Affected tests](references/qa-scope.md#affected-tests--the-story-level-test-command)
against the Base SHA. **`QA: FAIL` is NEEDS FIXES:** `SendMessage` the same agent the failing
criteria and excerpt, let it fix and commit, then re-run S5. Cap = 3 QA iterations, then
escalate `FIX MANUALLY / ACCEPT AS-IS / ABORT` (wording in
[output-blocks.md](references/output-blocks.md)). Under `--auto` the cap ends the run instead:
the branch is kept, the story goes back to `in-progress` — its builder already committed `done`,
so run `ck-story set <story-path> status=in-progress --no-sync` (Bug-Fix Mode: `status=bug
prior_status=<prior_status>`) and commit it on the branch as `chore(tasks): EE-SS back to
in-progress — QA failed` — and the report says why.

**S6 — Manual gate and hand-off, here.** Run Phase 8.5 in this context (both questions, one
call). On QUICK the prompt is one or two steps that show the change, such as the screen and
the label it should now read. **PASS** — the agent already wrote `done` (or the restored `prior_status`) and `files:`
with `--no-sync` and committed them, so only regenerate and sync, then apply the 8.7 answer:

```bash
ck-index tasks/<Plan> && ck-project sync tasks/<Plan>
```

**ISSUES** — `SendMessage` the same agent the report; it runs the 8.5.3 Bug-Fix Sub-Loop on its
branch and commits. Then S5 again and re-ask; cap = 3 cycles. `/ck-code:ship` then pushes the
already-committed branch — it has nothing left to stage.

**`--auto`:** the gate is deferred, never dropped. Regenerate and sync as on PASS, print the
8.5.1 manual-testing steps as the run's checklist, and end with `/ck-code:ship <story-path>` as
the next step. The ship answer is always SKIP, and nothing is pushed.

---

## QUICK ROUTE

For a story whose whole change is cosmetic: a label, copy, a style or token, an icon, a
constant. It keeps every check that can catch a broken change and drops the ceremony that
cannot. It runs only through SINGLE-STORY DISPATCH, never in PARALLEL MODE.

**Eligible only when all of these hold**, read from the 1.3 load (no extra read):

- `size: S`, Story Mode. A bug story is never QUICK.
- Every acceptance criterion changes a literal or presentational value: text, a label, a
  class, a style, a token, an icon, a constant. None adds behaviour, a branch, state, an API
  or data shape, persistence, an auth or permission rule, a dependency or a migration.
- `files:` names at most 3 paths, and none is a manifest, lockfile, CI, test-runner config
  or migration.
- Not a UI story whose design link is pending (S2 still has to ask about it).

**Who decides.** `--full` → never QUICK. `--quick` on a story that fails a condition →
`Route: FULL — --quick refused: <condition>`. Otherwise an eligible story takes it unasked:
`Route: QUICK — <what changes>, size S, N files (pass --full to override).` `--auto` changes
nothing here.

**S2 – S4.** The team gate is never asked. The dispatch carries `Route: QUICK`, on the fast
tier. The builder's QUICK deltas live in
[story-cycle.md § 1.7](references/story-cycle.md#17-effort-route-from-frontmatter-size). It
steps up to LEAN itself when the change grows, and returns its final route.

**S5 — verify here, no QA agent.** When the verdict says `route: QUICK`, run in this context
the exact command line the [Inline QA dispatch](references/agent-prompts.md#inline-qa-dispatch)
would hand the validator, at the same scope, with `--reuse`:
`ck-qa run EE-SS --reuse [--parallel] test='…' lint='…' typecheck='…' build='…'`. The builder's
green run on this exact tree reports `REUSED`. Anything else runs and prints one line. `FAIL`
is NEEDS FIXES, the same loop and cap as a validator `QA: FAIL`. A verdict with any other route
gets the `qa-validator` dispatch as usual.

---

## THE STORY CYCLE (Phases 1.7–8.6)

The work itself lives in [story-cycle.md](references/story-cycle.md): the effort route (1.7),
skill detection (2), planning (3), the RED → GREEN loop (4–5), refactor and the three scans (6),
QA (7) and completion (8.1–8.4, 8.6). This orchestrating context never reads it. The dispatch
prompt hands its absolute path to every `ck-code:story-implementer` agent, which reads it
once instead of loading this skill
([agent-prompts.md](references/agent-prompts.md)). The one exception is the SINGLE-STORY
DISPATCH fallback, a `build` with no `Agent` tool: `Read` it then and follow its
**Inline fallback** line. The gates this context keeps are 3.5 (the base), 8.5 (the manual test)
and 8.7 (the ship hand-off), below.

---

## 3.5 BASE BRANCH — Confirm Plan + Base Branch (single gate)

**Never start on whatever branch this run was launched from.** Resolve the base first, in one
batched call. The integration level is the **plan's**, read from its record — this skill never
asks for it (`plan` sets it once; `/ck-code:config integration` changes it):

```bash
git fetch origin --quiet
git branch --show-current
git branch --list "story/<EE>-<SS>-*" "fix/<EE>-<SS>-*"
ck-plan get tasks/<Plan> integration branch
```

The level derives the base: `story` → `<trunk>`; `epic` → `epic/<NN>-<slug>` (cut from
`<trunk>`); `plan` → `epic/<NN>-<slug>` cut from the plan branch, which is the record's
`branch:` (cut from `<trunk>`). An empty `integration:` reads as `story`.

`resolve_base(...)`
([`branch-topology.md`](../../references/branch-topology.md#start-point--the-base-a-new-story-branch-is-cut-from))
returns the suggested base; that section also owns the four signals that change it — an open
epic PR the story would silently join, a base behind its remote, another story's branch
checked out, and "I don't want this on `<trunk>`". Do not restate them here; run them.

Present the plan **and** `Base: <branch> — <reason>` (template in
[output-blocks.md](references/output-blocks.md)), then ask **one** `AskUserQuestion` that
confirms the plan and picks where the work lands. `AskUserQuestion` takes **at most 4 options**
— offer the resolved base first, then the highest-ranked alternatives that actually exist for
this project, and always keep **Adjust plan** last (the user can type any other base via
*Other*):

| Option | Offered when | Effect |
|---|---|---|
| **New branch from `<base>`** | always (recommended) | `git checkout -b story/<EE>-<SS>-<slug> <base>` — `fix/…` for a bug story, slug = kebab-case of the title; creates the parent chain first if absent ([Creation](../../references/branch-topology.md#creation)). Verify with `git branch --show-current` |
| **Resume `story/<EE>-<SS>-*`** | that branch already exists | `git checkout` it — never re-cut a branch that has commits |
| **Sync base from `origin/<base>` first** | the base is behind its remote | `git merge origin/<base>` on the base, then cut |
| **Current branch `<name>`** | `<name>` is a legal base (`resolve_base` step 3) | ship commits here. **Never** offered for `main`/`develop`/`<trunk>`, nor for another story's branch |
| **Adjust plan** | always | revise the plan, then re-ask |

**The base follows the level; build never changes the level.** An objection to the derived base
— wanting this work off `<trunk>` under a `story`-level plan, or straight onto `<trunk>` under an
`epic`/`plan`-level plan — is a level change, not a base pick: name
`/ck-code:config integration tasks/<Plan> <epic|plan>` (or `story`), and stop. When build is
re-run, 3.5 re-resolves the base from the new level. A hand-picked base with a stale level leaves
`ship` opening the PR against the wrong target.

Record the chosen branch — the ship phase reuses it (no second branch prompt). Nothing is
touched in Phase 4 until this gate returns a branch. **SINGLE-STORY DISPATCH runs this base
resolution in the orchestrator at S2** (no plan to confirm there), and the inline fallback runs
the whole gate. A delegated builder never runs it: it is already on the branch the
orchestrator chose, and it only presents its plan ([story-cycle.md](references/story-cycle.md) 3.5).

## 8.5 MANUAL TEST — REQUIRED GATE

Asked in this context only: at S6 for a single story, once per wave on the target after the
merge (P8, where every merged story sits together), or in the inline fallback, where the story
stays `in-progress` until PASS. A delegated builder never runs it. Under `--auto` it is
deferred to the run's final checklist, never dropped.

**8.5.1** Present the manual-testing prompt (template in
[output-blocks.md](references/output-blocks.md)) — scenarios from acceptance criteria + an
edge case. Then ask **both** gate questions in a **single `AskUserQuestion` call** (the 8.7
ship choice is already known here, so asking it separately costs a needless round-trip):

1. "Manual test result?" → `PASS` / `ISSUES`.
2. "If it passes, ship now?" → `SHIP` / `SKIP`.

Q2's answer is **used only when Q1 is `PASS`** — on `ISSUES` discard it and go to 8.5.3
(re-ask both after the fix loop). This is the only place the two gates merge; never
pre-ask a gate whose outcome could change the work in between.

**8.5.2** On `PASS` → proceed to 8.6, then apply the Q2 answer at 8.7 without re-asking.

**8.5.3** On `ISSUES` → enter the Bug-Fix Sub-Loop (eight ordered steps in
[completion.md](references/completion.md) § 8.5.3): regression test (red) → minimum fix
(green) → **mandatory** re-run of Phase 6 + Phase 7 → mark the `## Manual-Test Bugs` entry
`FIXED` → re-prompt at 8.5.1. **Cap = 3 cycles**; on the 3rd, escalate `FIX MANUALLY / ACCEPT
AS-IS / ABORT` (template in [examples.md](references/examples.md)). Never continue past 3.

## 8.7 SHIP — Commit + PR + Issue Updates

Apply the ship answer already collected at 8.5.1 Q2 — **do not ask again**: **SHIP** —
hand off to `/ck-code:ship` with the story file path per
[`skill-invocation.md`](../../references/skill-invocation.md) (handles branch, staging,
commit, PR, and GitHub Issue updates); **SKIP** — don't commit yet; remind the user they can run
`/ck-code:ship [story-path]` later. Only ask here if 8.5.1 ran without Q2 (e.g. a
non-interactive caller). A delegated builder never ships — it commits on its branch and
returns its verdict — and neither does a `--auto` run.

---

## PARALLEL MODE

Stories of **one epic**, dispatched wave by wave. This context **decides, verifies, and
merges** — it never builds, tests, or reads source itself; a sub-agent's context is discarded
on return, this one is re-paid every turn.

**Every story in this mode is implemented by a dispatched agent — never inline here.**

**Isolation follows wave width, not mode.** A wave holding **≥ 2** stories fans out one
worktree agent per story (`isolation: "worktree"`), then conflict-checks and merges them. A
wave holding **exactly one** story is dispatched **solo**: one agent in the **main checkout**,
no worktree, no cross-branch conflict stage, nothing to merge between branches. A worktree
exists to keep concurrent agents off each other's files; with no peer there is nothing to
isolate from, and the cold dependency install it forces is pure cost.

**Scope is exactly one epic — never a whole plan.**

**First action of this mode: `Read` [parallel-mode.md](references/parallel-mode.md).** It owns
P1–P9 — the P-step map with each step's non-negotiable, the exact commands, the resume prompt,
the `--auto` table, the classification rules, the cleanup contract — and is mandatory,
not a lookup: nothing here substitutes for it. It pulls in its own companions as needed
([agent-prompts.md](references/agent-prompts.md) dispatch/resume prompts + return schema ·
[wave-mode.md](references/wave-mode.md) wave planning ·
[conflict-format.md](references/conflict-format.md) report shapes). Dispatches also follow the
shared contract in [subagent-fanout.md](../../references/subagent-fanout.md) — single-message
dispatch, explicit `model:` on every call, typed-schema returns — and P4 **announces the
decision** before the first dispatch (`Fan-out: N stories → dispatching N agents.`, or
`Solo: 1 story → dispatching 1 agent on <branch> (no worktree).`).

The four gates that bind even before that read: **P1** checks out and verifies `$TARGET`
before any dispatch, and never lets it be the trunk (a `story`-level plan switches to `epic`
at P3, or the run cancels) · **P3** never dispatches into a project with zero skills without
asking, unless `tasks/SETTINGS.md` says `experts: none` or the run is `--auto` (agents cannot prompt) · **P5** derives "done" from git, never from an agent's self-report ·
**P7/P8** never accept work that has not returned `QA: PASS`.

---

## DELEGATED MODE

A dispatch prompt beginning `MODE: delegated` means this run **is** a builder that another
`build` dispatched (a wave member or a single-story dispatch), loaded through the skill
rather than the [story-cycle.md](references/story-cycle.md) path. `Read` story-cycle.md and
follow it from **Placement — delegated** to **RETURN**. Skip every phase of this file.

---

## HARD GATES (cross-phase contract, in phase order)

- **0** — version gate PASSes (`layout: v7`) before any project read/write.
- **1.2.0** — epics index read first; ask when > 2 epics unfinished.
- **1.2** — interactive selection prefers the parallel set; an explicit path is single-story.
- **1.7, 2, 3.3, 4, 5.2, 6.1, 7, 8.6 — the builder's gates**, owned by
  [story-cycle.md](references/story-cycle.md): effort route scales ceremony only; skills
  detected, `Read` and reported before any code (zero project skills → the team gate, asked by
  this context at S2/P3 unless `experts: none`); SOLID at design and after refactor; each
  behaviour's test fails before its implementation; off-plan touches logged to
  `## Unplanned Changes`; QA cap 3; `files:` records what the story actually touched.
- **SINGLE-STORY DISPATCH** — one story is built by one solo agent on its own branch, never in
  the orchestrating context; S1 clean start, S2 one question, S5 integrity from git + QA, S6
  manual gate here. Inline only when this context has no `Agent` tool.
- **QUICK ROUTE** — eligibility checked, never assumed; QUICK skips the QA agent, never the
  QA commands, RED where a test covers the change, or the manual gate.
- **Background tests** — `ck-headless` runs before dispatch; every `FOREGROUND` hit is
  converted before story code; every test runs through `ck-qa`.
- **3.5** — plan and base branch confirmed in one gate before any code (single-story dispatch: base only, at S2); the base is **derived from the plan's `integration:` (`ck-plan get`), resolved and shown with its reason**, never inherited from the branch this run was launched on; never `main`/`develop`. The level is never asked here.
- **8.5** — manual-test gate; bug-fix loop cap = 3. Under `--auto`, deferred to the final
  checklist, never dropped.
- **1.3.5 (Bug-Fix Mode)** — implement only the recorded Fix Plan; the failing repro test is
  the RED target; restore `prior_status`, never an Implementation Summary. `status: bug`
  without a `DIAGNOSED` Bug Report → STOP (run `/ck-code:fix`).
- **P1 / P3 (PARALLEL MODE)** — `$TARGET` is resolved, created, checked out and verified
  before any dispatch, and it is **never the trunk**: a `story`-level plan switches to
  `integration: epic` (`ck-plan set`) through the P3 question, or the run cancels. This mode never commits or
  merges on `main`/`develop`/`<trunk>`.
- **P3 / P4 / P5 / P7 (PARALLEL MODE)** — team gate asked once per batch; every story
  implemented by an agent, worktrees only for waves of ≥ 2; "done" derived from git; nothing
  merged or accepted without `QA: PASS`.

## RULES

- **Never skip 1.0 because `ck-epic` is not found** — re-run it as `"${CLAUDE_PLUGIN_ROOT}"/bin/ck-epic resolve`; a skipped resolve builds on an epic number another plan already owns.
- **Never store status anywhere but story frontmatter**, and never hand-edit `STORIES_INDEX.md`
  or `EPICS_INDEX.md` — run `ck-story set <story-path> status=<value>`, which writes the field and regenerates
  in the same phase (one atomic mutation; [`github-projects.md`](../../references/github-projects.md)).
- **Never stage or commit a generated view** — `STORIES_INDEX.md` and `EPICS_INDEX.md` are
  gitignored and disposable; a stale one is regenerated on the next read. Commits carry story
  files (and `OVERVIEW.md` when the level changed), never views.
- **Never edit `EPIC.md` or `OVERVIEW.md` by hand** — the plan's level changes only through
  `ck-plan set tasks/<Plan> integration=<level>` (build writes it only at the PARALLEL MODE P3
  switch; 3.5 names `/ck-code:config integration` instead), followed by `ck-project sync tasks/<Plan>` in the **same phase**; `pr:`/`delivery:`
  belong to `ship`.
- **Always relay `ck-index: WARN` lines** printed by `ck-index` — a skipped story is invisible in every generated view while its file still exists ([stories-index.md](../../references/stories-index.md)).
- **Never write a delta/journal doc** — commits are the history. The story body carries only
  the Implementation Summary, Unplanned Changes, and (bug flow) the Bug Report.
- **Never reference AI, Claude, or generated-by notes** in a commit, branch name, or any git artefact — [full rule](../../references/no-ai-references.md).
- **Never derive "done" from an agent's self-report** — derive it from git + the QA verdict.
- **Never let an issue claim block the build, and never remove an existing assignee** — the
  claim (1.5, and P4 for a wave) is best-effort bookkeeping with `--add-assignee`; a `gh`
  failure is one reported line, not a stop.
- **Never treat the checked-out branch as the base** — resolve it (3.5), show it with its
  reason, and offer the alternatives; the launch branch is a legal base only when it is the one
  that resolved ([`branch-topology.md`](../../references/branch-topology.md#start-point--the-base-a-new-story-branch-is-cut-from)).
- **Never keep work off `<trunk>` by picking a different base** — name
  `/ck-code:config integration tasks/<Plan> <level>` and stop, or `ship` targets `<trunk>` from
  the stored level regardless.
- **Never run a story-scope pass without an area-scope run after it** — P8 once per wave, the single-story S5 QA on the story that completes its epic and on every story at level `story`. Never narrow P8 below area scope, and never scope typecheck or build. Scope comes from `ck-affected`, never from reading imports; it prints FULL for repo-root config, migrations, fixtures, env files or a bare lockfile ([§ Affected tests](references/qa-scope.md#affected-tests--the-story-level-test-command)).
- **Never `find /` or search outside the repo.**
- **Never take the QUICK ROUTE on a story that fails one eligibility condition**, for a bug
  story, or in PARALLEL MODE, and never skip its S5 `ck-qa` run — QUICK drops ceremony, never
  a check.
- **Never let a test open a window in front of the user** — convert every `ck-headless` hit
  before story code, never ask whether to, and never run an e2e command outside `ck-qa`
  ([background-tests.md](../../references/background-tests.md)).
- **Never ask under `--auto`, and never ship, promote or push under it** — every question takes its recommended answer, announced; the manual test is deferred to the final checklist and `/ck-code:verify`, never dropped. Hard stops still stop the run; they are reported, not asked ([parallel-mode.md § Auto mode](references/parallel-mode.md#auto-mode----auto)).
- **Never hand a builder this skill** — every dispatch names [story-cycle.md](references/story-cycle.md) by absolute path, and the builder's rules live there.
- **Never implement a story in an orchestrating context** — one story goes to SINGLE-STORY DISPATCH, several to PARALLEL MODE; source reads, the TDD loop and suite output belong to the agent. The only inline path is a context with no `Agent` tool.
- Story frontmatter is the source of truth. All output is English regardless of story language.

### Parallel mode

The "Non-negotiable" column of the P-step map ([parallel-mode.md](references/parallel-mode.md))
is the rest of this contract; these four are the traps it does not carry.

- **Never send an explicitly-requested single story through PARALLEL MODE** — a story path, a
  single 1.2 pick, or a `fix`/`plan --quick` hand-off takes SINGLE-STORY DISPATCH on its own
  branch, so the plan's level is never switched for it. `--epic NN` is the exception: it always
  orchestrates, dispatching even a lone remaining story solo (P4).
- **Never cut a worktree for a one-story wave** — solo dispatch runs in the main checkout.
- **Never leave a merged story's worktree standing** — remove it before `git branch -d`, after `ck-reclaim` (or its test containers and volumes outlive it in the Docker VM); `git worktree prune` deletes nothing. A worktree kept for a held, blocked or conflicted story is passed to `ck-reclaim`, which frees its build output and Docker containers and keeps its source.
  Worktrees are for concurrency; without a peer they buy nothing and cost a cold install.
- **Never build, test, lint, or read source in the orchestrator context** — it sees counts,
  names, statuses, SHAs, and structured returns only. Every implementation is a sub-agent.
- **Never let a dispatched agent run `ck-index` or edit a generated index** — it changes
  only its own story's frontmatter (`status`, `files:`); this context runs `ck-index` and
  `ck-project sync` once per wave after merge and commits no view.
- **Never span epics in one run** — every wave and every batch is scoped to a single epic.

## NEXT

After manual-test PASS (S6 / 8.5) — or after the checklist of a `--auto` run — run `/ck-code:ship <story-path>` to push the committed
branch, open the PR, and update the linked GitHub Issue. After a PARALLEL MODE run the stories sit merged on an epic
branch, so P9 hands off (one ask) to `/ck-code:ship --promote --epic NN` — never ship each
story. If more stories remain, follow with `/ck-code:track next`.

**Native speed-ups (optional, user-driven — see [native-commands.md](../../references/native-commands.md)):**
`/goal "all acceptance criteria in <story> pass and the suite is green"` autonomises the
QA and manual-test loops; `/fast` suits **`S`** stories (off for `M`/SOLID-heavy); `/code-review --fix`
is a deeper pre-ship diff pass; `/simplify` catches the cross-story duplication one story's 6.1
cannot see — after a wave merges, not per story.
