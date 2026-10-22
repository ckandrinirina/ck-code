# Story Cycle — the builder's procedure (Phases 1.7–8.6)

The procedure that builds one story, test first. `ck-code:story-implementer` reads it once,
from the path its dispatch prompt names, and follows it whole. `build` runs it in its own
context only in the SINGLE-STORY DISPATCH fallback (no `Agent` tool). An orchestrating `build`
never reads it: `SKILL.md` decides, verifies and gates, and this file is the work. The
numbers are `build`'s phase numbers, so `SKILL.md 3.5`, `8.5` and `8.7` still name the
orchestrator's gates.

## Placement — delegated

The dispatch prompt begins `MODE: delegated` and names the story path, the `Base SHA` and, on
a solo dispatch, the branch. The run is already on the branch it must work on. Fan-out puts
it in its own harness-created worktree. A solo wave or a single-story dispatch puts it on the
branch the orchestrator checked out in the main checkout, and the prompt asks for the branch
guard first. The branch is not this run's to choose, and there is no user to ask.

| Phase | Delegated behaviour |
|---|---|
| Start (1.3) | `Read` the story file at the given path. This is the run's only full body `Read`. From the frontmatter: `id`, `title`, `epic`, `size`, `files`, `status`, `prior_status`. From the body: `## Description`, `## Acceptance Criteria`, `## Implementation Tasks`, `## Technical Notes`. Read `ROADMAP.md` only when the Technical Notes cite it. A missing file returns `status: blocked`. |
| 1.3.5 | `status: bug` → **Bug-Fix Mode** ([bug-fix-mode.md](bug-fix-mode.md)): the recorded Fix Plan is the work and `fix`'s failing reproduction test is the RED target. `status: bug` without a `DIAGNOSED` Bug Report → return `status: blocked`. |
| 1.5 | Skipped. The orchestrator already claimed the issue. |
| 1.6 / 8.6 | `ck-story set … --no-sync`, then `ck-story files` against the prompt's `Base SHA`, on **this story's frontmatter only**. Never regenerate an index or commit a view. The orchestrator regenerates once on the target. 1.6 is normally a no-op, because the orchestrator flipped the story to `in-progress` before dispatch, so finding it there is not drift. In Bug-Fix Mode the story never goes from `bug` to `in-progress`. |
| 3.2 / 3.5 | Present the plan and ask no question. Never create, switch, rebase or reset a branch. The prompt's `Settled:` line binds like a user's answer. An ambiguity it leaves open that blocks progress returns `status: blocked`. Never guess it. |
| 4–6.2 | Unchanged. RED still gates GREEN. |
| 6.3 + 7 | **One run**, as Phase 7 says below. Never delegate to `qa-validator`, because the orchestrator runs one per story. |
| 8.5 | Skipped. The orchestrator runs manual sign-off: once per wave after it lands, or at S6 for a single story. A resume carrying a manual-test or QA report runs the 8.5.3 Bug-Fix Sub-Loop ([completion.md](completion.md)) or the QA fixes on the same branch, commits, and returns the verdict again. |
| 8.7 | No ship. Commit after **every** TDD cycle, so an early stop still leaves resumable work, then return the [verdict](#return). |
| `Background:` | One line per foreground e2e setup. Before RED, convert each per [`background-tests.md`](../../../references/background-tests.md), confirm `ck-headless` prints OK, and commit it alone as `test(e2e): run e2e suites in the background`. It is not story scope: log it under `## Unplanned Changes`, and leave it out of QUICK's step-up count. |

Uncommitted work cannot be merged or resumed, and on a solo run it leaves the shared branch
dirty for the orchestrator. Commit messages are conventional (`test(EE-SS):`, `feat(EE-SS):`)
with **no AI references** ([`no-ai-references.md`](../../../references/no-ai-references.md)).
Stage explicit paths only. Never run `ck-index`, `git checkout -b`, `git switch -c`,
`git rebase`, `git reset` or any `git worktree` command.

**Inline fallback** (a `build` with no `Agent` tool): the user is present. Phases 1.3–1.6 already
ran in `SKILL.md`, 3.2 may ask, 3.5 runs `SKILL.md`'s gate, 6.3 and 7 stay separate (with
no `Agent` tool to dispatch it, 7 runs its commands inline),
`ck-story` runs without `--no-sync`, and 8.5 and 8.7 run in `SKILL.md`.

## TOOL-CALL DISCIPLINE

Measured on real delegated runs, model round trips take 60–70% of a story's wall clock,
and 89% of turns issue a single tool call. Speed comes from fewer turns and fewer repeated
commands, never from skipping a check:

- **Batch independent calls.** Every `Read`, `grep`, `ls`, and read-only `git` query that
  does not need another call's result goes into **one message**. Examples: the source files
  a change touches, plus their tests; `git status` beside `git log`. Chain dependent shell
  steps with `&&` in one Bash call rather than across turns.
- **Run slow commands once per code state.** The full suite, lint, typecheck, build, and e2e
  commands are captured to a `$TMPDIR` log and read from there. Never re-run one on an
  unchanged tree to see a different slice of its output
  ([`rtk.md` § Slow commands](../../../references/rtk.md#slow-commands--run-once-read-the-log)).
  The 6.3 check and every QA pass run through `ck-qa`, which stamps each pass with its code
  state so a later step that may reuse it (`--reuse`) skips an identical run
  ([§ QA runs go through `ck-qa`](../../../references/rtk.md#qa-runs-go-through-ck-qa)). A run
  past the 600 s Bash cap (a serial e2e suite) prints `ck-qa: RUNNING`. Continue it with
  `ck-qa wait <id>`, and never start it again or poll its output.
- **Keep the inner loop targeted.** Every RED (4.4) and GREEN (5.2/5.3) of each cycle, and each
  refactoring (6.2) run the story's own test files. Lint only the files the story touched,
  by path, from the package that owns the lint config (`npx eslint src/a.ts src/b.tsx`,
  `ruff check app/x.py`). Never run a package-wide lint and `grep` it for one file: measured
  at 60–120 s a call, it ran up to seven times in one story. A package-wide typecheck runs at
  most once per GREEN subtask, through `ck-qa`, and the build never runs in the inner loop. A
  test run that compiles first (CMake, cargo, Swift, Gradle, Xcode, .NET) goes through `ck-qa`
  too, so worktrees building at once share the machine's CPU slots instead of each taking every
  core ([§ QA runs go through `ck-qa`](../../../references/rtk.md#qa-runs-go-through-ck-qa)). The suite,
  lint, typecheck and build run once through `ck-qa`, at 6.3 and in QA (7), where regressions
  are caught. A linter that takes no file paths waits for 6.3/7 too.
- **Check the story's scope, then only what is left.** The 6.3/7 suite and lint run at
  **story scope**: the affected tests and the changed files, resolved by `ck-affected`. The
  one exception is the **area-scope** backstop, every test of each area the diff reaches
  (never an area it does not), which runs where the regression outside the story's reach is
  caught: P8 once per wave, and the single-story QA (S5) on the story that completes its epic
  and on every story at level `story`. A re-run after a red check or a NEEDS FIXES round runs only the
  failed tests plus those affected since the last run (`ck-qa run <id> --rerun`). Typecheck
  and build are never scoped
  ([qa-scope.md § Affected tests](qa-scope.md#affected-tests--the-story-level-test-command),
  [§ Re-runs after a failure](qa-scope.md#re-runs-after-a-failure--only-what-is-left)).
- **Stay inside the repo.** Never `find /` or search `$HOME`, because each such search hit the
  120 s Bash timeout. A relative link in this skill (`references/story-template.md`)
  resolves against the `Base directory for this skill` line printed when the skill loaded.
  A dependency's types live in the repo's own `node_modules`: the package's, then the root's.

## 1.7 EFFORT ROUTE (from frontmatter `size:`)

LEAN or FULL is fixed by the run that builds the story, never the orchestrator. QUICK is the one
route the orchestrator sets, through the prompt's `Route: QUICK` line.
Scale the *ceremony* to the story, never the guarantees. Read `size:` and fix the route now
— LEAN and FULL govern Phases 3.3, 3.4 and 6.1 only, QUICK the four phases below the table:

| `size:` | Route | 3.3 SOLID | 3.4 Subtasks | 6.1 SOLID review |
|---|---|---|---|---|
| `S` | **LEAN** | 2–4 line note, only the principles actually in play | 3-task chain: tests → implement → QA | targeted spot-check of the principles named in 3.3 |
| `M` (or absent) | **FULL** | full SOLID Analysis template | full 6-task breakdown | full SOLID Compliance Check template |
| `S`, prompt says `Route: QUICK` | **QUICK** | none | 2-task chain: change → check | none |

**QUICK** is decided by the orchestrator, never here: the dispatch prompt's `Route: QUICK`
line, set for a cosmetic `S` story ([SKILL.md § QUICK ROUTE](../SKILL.md#quick-route)). It
changes four phases and nothing else:

- **2** loads `guide-conventions` alone when present. No arch-doc reads, no expert skills, no
  "Skills loaded" block beyond that one line.
- **3** is one line: the change, file by file. No research, no SOLID note.
- **4–5** — when a test asserts the value being changed, edit that test to the new value
  first, see it fail, then change the code. When no test asserts it, write none: a test that
  pins a label catches no bug ([`test-craft.md`](../../../references/test-craft.md)), and the
  change is made directly. A criterion that turns out to change behaviour gets a real RED test
  and ends QUICK.
- **6.1** is skipped, and the three scan references are not loaded. Read the diff once for a
  restating comment or dead code.

6.3 + 7 run unchanged, as the delegated single run at story scope, and the orchestrator
re-checks it at S5.

**QUICK steps up to LEAN by itself** the moment the change outgrows it: the diff (`tasks/` and
a `Background:` commit excluded) reaches more than 3 files or 40 changed lines, adds a file,
touches a manifest, lockfile, config or migration, or needs a behaviour test. Say
`Route: QUICK → LEAN — <reason>`, run Phase 2 in full now, then 6.1 at LEAN, and return
`route: LEAN` so the orchestrator dispatches its QA agent.

**Bug-Fix Mode always uses LEAN** — its scope is the recorded Fix Plan, which is already
narrow. Announce the route in one line (`Route: LEAN (size S)`) so the user can override by
saying so; an explicit user request for a full pass wins over the table.

**The route NEVER skips:** the version gate (0), skill detection + report (2; QUICK reports its
one line), the plan+branch gate (3.5), failing-tests-before-implementation (4; QUICK as above),
the `## Unplanned Changes` log (5.2/6.2), the 6.3 + 7 run and its cap (7), or the manual-test
gate (8.5). A LEAN story
that grows past its `size:` during Phase 5 switches to FULL for 6.1 — say so when it happens.

## PHASE 2: SKILL DETECTION & CONTEXT LOADING (BLOCKING GATE)

Phases 2–8.4 run inside the agent that builds the story (DELEGATED MODE), never in an
orchestrating context — except the SINGLE-STORY DISPATCH fallback.

**Mandatory — blocks Phase 3. Never plan or write code until it completes.** Done ONLY when
all three hold: (1) the `ls` of project skills ran, (2) every detected-and-present skill was
`Read`, and (3) the "Skills loaded for this implementation" block was shown to the user.
`expert-qa` and `expert-qa-project` are always detected (+ `expert-analyst` for bug-fix
flows), and `guide-conventions` always loads when present. If skills exist but you loaded none, stop and
re-run — a non-empty project must never reach Phase 3 with zero skills loaded, else Phases
5/6 "follow loaded skills" silently become no-ops.

Follow [`skill-detection.md`](../../../references/skill-detection.md) end to end — it owns this
phase: the arch-doc reads (Step 1), manifest-driven detection (Steps 2–3), the `ls` +
**team gate** for a project with no skills (Step 4a / 4a.1 — `Run /ck-code:team first`
invokes `Skill({ skill: "ck-code:team" })`, then redo this phase; `Never ask in this project`
writes `experts: none` to `tasks/SETTINGS.md`, and with `experts: none` the gate never fires), the `Read`-only loading (Step 4b),
and the mandatory "Skills loaded" report (Step 5). Do not restate its gates here; run them.

Two build-specific bindings on top of that procedure:

- **Match against the selected story's `files:` set** already in context — prefer narrow
  `paths` matches over broad `keywords` matches so an unrelated body is never `Read` on a
  keyword coincidence (every body loaded here stays resident through Phases 5–6).
- **Batch every arch-doc read and skill load into parallel tool-call messages** — sequential
  reads are the largest avoidable latency in this phase.

---

## PHASE 3: IMPLEMENTATION PLANNING

Create a SOLID-compliant plan **before writing any code.**

**3.1 Research (only if needed).** context7 (MCP) for framework docs, WebSearch for uncommon
patterns — only when the story needs current docs, never for well-known basics.

**3.2 Clarify ambiguities.** If an acceptance criterion is vague, ask 1–2 targeted questions
— never about what the story or architecture docs already make clear.

### 3.3 Design with SOLID

Plan the implementation applying SOLID. Per the 1.7 route: **FULL** fills the SOLID Analysis
template in [tdd-walkthrough.md](tdd-walkthrough.md), every principle addressed
before moving on. **LEAN** writes a 2–4 line note naming only the principles actually at
stake in this story and how each is satisfied; principles with nothing to decide are stated
as such, never silently dropped. Either way the reasoning is explicit before any test is
written.

### 3.4 Create Subtasks

**Seed from the story's `## Implementation Tasks` section when present** (authored by
`plan`) — fold those ordered tasks in rather than inventing generic ones; if absent, use the
default breakdown. Track subtasks on **Claude Tasks** (TaskCreate; per-route chains in
[tdd-walkthrough.md](tdd-walkthrough.md)), each blocked by the previous. If Task
tools are unavailable, fall back to an in-session checklist (never written to the story file)
— never skip the breakdown. **Never persist the plan itself to the story file** — the file
records only frontmatter status, the final summary, and unplanned changes.

### 3.5 Present the Plan

Present the plan (template in [output-blocks.md](output-blocks.md)) and go on to Phase 4.
Delegated, there is no gate: the orchestrator settled the branch before dispatch. In the
inline fallback, this is where `SKILL.md` § 3.5 runs its single gate, which confirms the
plan and picks the base branch before any code.

---

## PHASE 4: TDD — ONE BEHAVIOUR AT A TIME (RED PHASE)

Phases 4 and 5 form **one loop over behaviours**, not two batches. Each cycle writes a
failing test for the next behaviour, then the minimum code to pass it. Never write the whole
suite up front: tests written before the design exists pin guesses, and those guesses become
the over-testing that 6.1 then has to prune. Every test meets
[`test-craft.md`](../../../references/test-craft.md): behaviour through the public surface, and
only the tests a real regression would need.

**4.1 Start the cycle.** Mark the current test-drive task `in_progress` (TaskUpdate).

**4.2 Determine test structure** (first cycle only). Read existing test files to learn
conventions: naming (`.test.ts`, `_test.rs`, `test_*.py`), location (co-located,
`__tests__/`, `tests/`), framework, assertion style, mock/stub patterns. Follow loaded guide
skills. An e2e test launches its browser or app in the background, never in front of the user
([`background-tests.md`](../../../references/background-tests.md)).

**4.3 Write the next test.** Pick the next acceptance criterion (worked mapping in
[tdd-walkthrough.md](tdd-walkthrough.md)) and write **one** test for its
behaviour. Add a test for an edge case, an error or an integration point only when the code
of this cycle will actually branch on it, or when a criterion names it
([`test-craft.md` § What to write](../../../references/test-craft.md#what-to-write)). A small
test that drives a tricky internal step is allowed as scaffolding and gets reviewed at 6.1.

**4.4 Run it — confirm RED.** **Expected: the new test FAILS.** A new test that passes
without implementation is testing something that already exists or is trivially true. Delete
or fix it; never keep it. A red run needs no report of its own; the loop reports once, at
5.3.

---

## PHASE 5: IMPLEMENTATION (GREEN PHASE)

Write the **minimum** code to make the cycle's test pass, then loop back to 4.3.

**5.1 Guard.** On the first cycle, confirm the Phase 2 "Skills loaded" block was shown this
run. If not, stop and run Phase 2 now, because implementation must apply the loaded
experts/guides.

**5.2 Implement.** Write only what the current test needs: create or modify the files from
the story's `files:` as it requires, run the story's test files, and stop as soon as they
pass. Don't over-engineer and don't build ahead of the next test. **Rules:** follow the Phase 3 SOLID plan + loaded guide/expert standards; reuse
existing code (check `docs/architecture/`, scan files); simplest code that passes; write to
the clean-code and comment standard in [`code-craft.md`](../../../references/code-craft.md) —
names that explain themselves, comments only where they say *why*, in the fewest precise
words. **Log unplanned changes
incrementally** — any file touched outside the
story's `files:` set gets one line in a `## Unplanned Changes` body section in the same Edit
pass: `- <path> — <what> — <why>`. Record at the moment of change; empty section = omit the
heading.

**5.3 Run tests — confirm GREEN, then loop.** **Expected: ALL of the story's tests PASS.**
On failure read the output and fix the implementation (NOT the tests, unless a test itself
has a bug); re-run until green, then **return to 4.3** for the next behaviour. When every acceptance
criterion has a passing test, report the loop as **one line** (output-blocks) and mark the
test-drive task(s) `completed`.

---

## PHASE 6: REFACTOR PHASE

Improve quality without changing behavior. **Tests stay green throughout.**

**6.1 SOLID + redundancy review.** Per the 1.7 route: **FULL** reviews all new/modified code
with the SOLID Compliance Check template in [tdd-walkthrough.md](tdd-walkthrough.md),
every principle checked. **LEAN** spot-checks the principles named in the 3.3 note plus any the
diff newly put at stake. Either way, record every violation as an ISSUE to fix in 6.2 — a LEAN
review that uncovers a structural problem escalates to the FULL template before continuing.
**Then run the redundancy scan on the diff** — the five checks in
[`reuse-first.md`](../../../references/reuse-first.md#redundancy-scan-implementation)
(reimplementation, copy-paste, dead code, needless indirection, unasked-for surface), at both
routes, no template. **Then the comment & readability scan** — the four checks in
[`code-craft.md`](../../../references/code-craft.md#comment--readability-scan-implementation)
(restating or wordy comments, missing *why*, doc comments, readability), same diff, same routes.
**Then the test-prune scan** — the five checks in
[`test-craft.md`](../../../references/test-craft.md#test-prune-scan-implementation)
(duplicate, scaffolding, implementation-coupled, trivial or speculative, oversized), run on the
tests this story added or changed, same routes, with its deletion guards. Each hit from any
of the three scans is an ISSUE for 6.2 like any SOLID violation.

**6.2 Apply refactorings.** For each issue: apply the refactoring, run the story's test files (must stay green),
revert and reconsider if they break. Common refactorings: collapse a reimplementation into
the existing code, delete dead code, delete or merge a pruned test, inline a single-caller wrapper, delete a restating
comment, add the missing *why* line, extract function, rename,
introduce interface/trait for dependency inversion, split large functions, move code to the
correct module per `folder-structure.md`. Refactors touching files outside the story's `files:` set
also log to `## Unplanned Changes` (same `- <path> — <what> — <why>` format as 5.2).

**6.3 Final green check.** Resolve the scope first
([qa-scope.md § Affected tests](qa-scope.md#affected-tests--the-story-level-test-command)).
It is **story scope** at level `epic`/`plan`, and **area scope** at level `story` or on the
story that completes its epic. Then run the suite once through `ck-qa`, using the **same
`test=` command string** Phase 7 will hand the validator. For example, story scope is
`ck-qa run EE-SS test='npx vitest run --changed <base> --passWithNoTests'`, and area scope is
`ck-qa run EE-SS test="$(ck-affected <base> --area --command 'npx vitest run' 'npx vitest run {files}')"`. Report REFACTOR as **one line** (output-blocks). This
is where a regression the targeted runs could not see surfaces. On red, fix it and re-run
only what is left: `ck-qa run EE-SS --rerun test='<failed files + affected since ck-qa since
EE-SS test>'` ([§ Re-runs after a failure](qa-scope.md#re-runs-after-a-failure--only-what-is-left)).
A green 6.3, including a green `--rerun`, is stamped on the code state under the full
`test=` command, so Phase 7 reads it instead of running the suite again on the same tree. **Delegated, 6.3 folds
into Phase 7** (see there).

### 6.4 Replica fidelity (UI stories citing an `S-NN` only)

When the acceptance criteria cite a screen of a `docs/replica/<slug>/REPLICA.md`, run
[`replicate.md` § Fidelity loop](../../../references/replicate.md#fidelity-loop) now — shoot,
diff, compare, one fix pass, record the `Fidelity S-NN:` line. Its fix pass changes code after
6.3's green, so re-run the same 6.3 command through `ck-qa run EE-SS --rerun` before Phase 7.
No cited screen → skip, silently.

---

## PHASE 7: QA VALIDATION

QA reviews the work — this is **not** a self-review.

**Always delegate to the `ck-code:qa-validator` agent** (Haiku) — it absorbs the verbose
suite/build/lint output in its own context and returns a compact verdict. The dispatch call —
model, cwd, story path, stack commands, return shape — is
[agent-prompts.md § Inline QA dispatch](agent-prompts.md#inline-qa-dispatch); do
not improvise it. Run the heavy commands inline **only** when that subagent_type is
unregistered or there is no `Agent` tool (the inline fallback), or when delegated (where the orchestrator runs `qa-validator` per story
instead).

Mark the QA task `in_progress`, then follow [`qa-validation.md`](../../../references/qa-validation.md)
— it loads the QA experts, validates every acceptance criterion, runs the suite +
code-quality checks (commands per stack in [tdd-walkthrough.md](tdd-walkthrough.md)),
and checks architecture compliance against the feature doc. Present the QA Report
(output-blocks).

**Nothing may change the tree between 6.3 and this dispatch.** The validator runs with
`--reuse`, so the suite that 6.3 just passed on this exact code state reports `REUSED`, and
lint, typecheck and build still run (concurrently where the stack allows). Any edit in
between is a new state, and the suite simply runs again. The validator still reviews every
acceptance criterion, the architecture and the code quality itself. Only the repeated
command is skipped, never the judgement.

**Delegated, 6.3 and 7 are one run.** Phase 7's command set is the final green check, at
**story scope** against the prompt's `Base SHA`: the affected-tests `test=` and the
changed-file lint, or the full rows when `ck-affected` prints FULL
([qa-scope.md](qa-scope.md#affected-tests--the-story-level-test-command)). Typecheck and build
stay full. Run it with `ck-qa run <id> --parallel …` (no `--reuse`, and no `--parallel` for a
shared build lock). A failing run is followed by a `--rerun` of only what is left
([§ Re-runs](qa-scope.md#re-runs-after-a-failure--only-what-is-left)). Never run the suite at
6.3 and again at 7 on the same tree, because back to back, in one agent, they measure the same
state. Every other check in `qa-validation.md` still runs here. The area scope runs later in
the orchestrator: P8 once per wave, or the scope S5 gives a single story.

**A delegated `QA: FAIL` is a `NEEDS FIXES` verdict** — the agent's verdict line replaces the
inline report's verdict and enters the same loop; never treat it as a separate outcome, and
never re-run the suite here to confirm it.

**Gate — iteration cap = 3.** At iteration 3, escalate `FIX MANUALLY / ACCEPT AS-IS / ABORT`
via `AskUserQuestion` (wording in output-blocks); never silently continue past 3. On NEEDS
FIXES inside the loop: fix each issue → re-run Phase 6, whose 6.3 is a `--rerun` of only the
tests affected since the last pass → re-run this phase with a fresh QA check.

---

## PHASE 8: COMPLETION

### 8.1 Update Story Body — Implementation Summary

**Bug-Fix Mode:** do NOT append an Implementation Summary. Instead fill the Bug Report
`### Resolution` + `### Files Touched` and flip its `Status: DIAGNOSED → FIXED` (templates in
[../fix/references/bug-section-template.md](../../fix/references/bug-section-template.md) Phase
8.1), then continue to 8.6 for the status restore. Full deltas:
[bug-fix-mode.md](bug-fix-mode.md).

Append the Implementation Summary block (template in
[story-template.md](story-template.md)) to the story body. Required fields and the
**mandatory Files Touched precision** (CREATED = path; MODIFIED = `path:lines` via `git diff`)
are in [completion.md](completion.md).

### 8.2–8.4 Checklist, Subtasks, Summary

- **8.2** — mark all acceptance criteria `[x]` in the story body.
- **8.3** — mark every implementation subtask `completed` on Claude Tasks (TaskUpdate);
  subtasks live on Claude Tasks, never the story file.
- **8.4** — `TaskList` to show the completed summary of all tasks.

### 8.5 Manual Test — the orchestrator's gate

Never run here. `SKILL.md` § 8.5 asks the user, at S6 for a single story or once per wave
after the merge. A resume carrying `ISSUES` runs the 8.5.3 Bug-Fix Sub-Loop in
[completion.md](completion.md) on the same branch, commits, and returns the verdict again.

### 8.6 Set Status → done (frontmatter + regenerate + touched files)

**Bug-Fix Mode:** restore `prior_status` (from the Bug Report — normally `done`) instead of
`done`, and clear `prior_status` in the same call. Then 8.7 as usual (`fix/` branch, Bug ID
in commit):

```bash
ck-story set <story-path> status=<prior_status> prior_status=
```

**Story Mode:**

```bash
ck-story set <story-path> status=done
```

**Touch `status` only — never `pr:` or `delivery:`.** They are the second, orthogonal axis
([`data-model.md`](../../../references/data-model.md#two-axes-status-is-work-delivery-is-integration)):
`done` means the work is finished, not that it reached the trunk. `ship` writes `pr`, and
`ck-project sync` promotes `delivery` to `merged`. In Bug-Fix Mode this matters twice — a
defect found in already-merged code keeps `delivery: merged` while it is fixed, and the
restore touches `status`/`prior_status` alone.

`ck-story` regenerates in the same call — recomputing `STORIES_INDEX.md` and the
`EPICS_INDEX.md` rollup (an epic whose stories are all `done` rolls up to `DONE`, or to
`MERGED` once every one of them is on the trunk) and syncing the board. The views stay
local; nothing here stages them.

No index cell-edit, no `EPIC.md` story-table edit — those artifacts do not exist.
The sync moves this story's card to Done and rolls its epic card up
([`github-projects.md`](../../../references/github-projects.md)).
**Delegated, pass `--no-sync`** ([Placement](#placement--delegated)).

**Record the touched files — both modes, same phase.** `files:` was the plan's guess; after
the work it must hold what was actually touched, because parallel conflict detection
(`ck-view waves`) and expert-skill matching read it. Diff against the base recorded at 3.5,
working tree included (inline-fallback work is not committed until `ship`), `tasks/` excluded:

```bash
ck-story files <story-path> $(git diff --name-only "$(git merge-base <base> HEAD)" -- . ':!tasks') $(git ls-files --others --exclude-standard -- . ':!tasks')
```

`ck-story files` merges (sorted, de-duplicated, never shrunk) and touches nothing else — no
regenerate, no sync. An empty diff makes it print a usage error; ignore it.
**Delegated**, diff the committed work against the `Base SHA` the dispatch prompt names
(`git diff --name-only <base-sha>...HEAD -- . ':!tasks'`) and commit the story file with the
last cycle.

---

## RETURN

Delegated, the last message is this block and nothing else. The orchestrator reads the typed
fields, never prose:

```
status:       done | partial | blocked
branch:       <git rev-parse --abbrev-ref HEAD>
commits:      <commits made>
remaining:    [<unmet acceptance criterion>, …]   # [] when status: done
criteria_met: <checked>/<total>
route:        QUICK | LEAN | FULL     # the route the story finished on, after any step-up
```

`done` only when every acceptance criterion is checked and the 6.3 + 7 run is green. A run that
did no work or hit a blocker returns `partial` or `blocked`, never `done`. A missing block is
read as `partial`, and the orchestrator verifies from git either way.

## RULES

- **Never write an implementation file before its behaviour's test was observed failing** (4.4). Trivial boilerplate is exempt, and so is a QUICK value change that no test asserts.
- **Never stay QUICK past a step-up condition**, and never pick QUICK without the prompt's `Route: QUICK` line.
- **Never write an e2e test that opens a window in front of the user**, and never start story code before every `Background:` hit is converted and committed ([`background-tests.md`](../../../references/background-tests.md)).
- **Never edit a test to force GREEN.** Pruning at 6.1/6.2 is not that: it runs on a green suite, only on tests this story added, and never removes the sole test of an acceptance criterion or a bug's reproduction/regression test ([`test-craft.md`](../../../references/test-craft.md#test-prune-scan-implementation)).
- **Never keep a test that would catch no bug another test misses** — duplicates, scaffolding a behaviour test now covers, tests of internals or the framework, and speculative edge cases are pruned at 6.2.
- **Never let the 1.7 effort route skip a guarantee** — it shortens the SOLID write-up, the subtask chain, and the SOLID re-review, and nothing else. The 6.1 redundancy, comment and test-prune scans run in full at LEAN and FULL; QUICK replaces them with one read of its few-line diff, and steps up the moment the diff stops being few-line.
- **Never ship code that reimplements what the repo already has** — 6.1 scans the diff for it, 6.2 collapses it, QA Step 3.5 verifies the scan ran ([`reuse-first.md`](../../../references/reuse-first.md#redundancy-scan-implementation)).
- **Never ship a comment that restates the code or runs longer than it needs, or code that needs one to be read** — 6.1 runs the comment & readability scan, 6.2 fixes each hit, QA Step 3.5 verifies it ran ([`code-craft.md`](../../../references/code-craft.md#comment--readability-scan-implementation)).
- **Never touch a file outside the story's `files:` without logging it** to `## Unplanned Changes` in the same Edit pass (5.2/6.2).
- **Never re-run a slow command on an unchanged tree** — read the `$TMPDIR` log it already wrote ([TOOL-CALL DISCIPLINE](#tool-call-discipline)). The inner loop is targeted: the story's test files, and lint on touched files only. Never run a package-wide lint to check one file, and never build in the inner loop.
- **Never repeat a whole scope after a failure** — re-run the failed tests plus those affected since the last run with `ck-qa run <id> --rerun`, and fall back to the full command only on a crash, a config change or no recorded run ([qa-scope.md § Re-runs](qa-scope.md#re-runs-after-a-failure--only-what-is-left)).
- **Never `find /` or search outside the repo** — resolve this file's links against its own directory and dependency types in the repo's `node_modules`.
- **Never widen a bug fix beyond its recorded Fix Plan** (Bug-Fix Mode).
- **Delegated, never ask, never ship, never run `ck-index`, and never change branch** — and never return `done` without every criterion checked and the 6.3 + 7 run green.
