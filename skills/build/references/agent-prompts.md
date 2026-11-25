# Sub-Agent Dispatch, Resume & Return Schema

Prompt templates and the structured return contract for every sub-agent `build` dispatches:
the per-story implementer (P4), its resume (P5), and the [reviewer](#reviewer-s5-and-p7) (S5, P7), plus the
[single-story dispatch](#single-story-dispatch) (S4) and `fix` Phase 4's reproduction.

## The structured return schema (all implementer agents)

Each story agent returns a structured object — the orchestrator reads fields, never
greps prose:

```json
{
  "status": "done | partial | blocked",
  "branch": "<the git branch the work is committed on>",
  "commits": <number of commits made>,
  "remaining": ["<unfinished acceptance criterion>", "…"],
  "criteria_met": "<checked>/<total>",
  "route": "QUICK | LEAN | FULL"
}
```

`status`/`criteria_met` are **hints**. The orchestrator's P5 gate decides "done" objectively
from git (non-empty diff on `branch`, zero unchecked criteria in the story file, clean tree)
plus the review verdict and the background run. `branch` is the field the orchestrator merges — the harness names the
worktree branch, so the agent must report it. On a **solo** dispatch the agent reports the
branch it was placed on and must never have changed it; a `branch` that differs from
`$WORKBRANCH` is branch drift and stops the wave (P5).

## Per-story implementer, fan-out (P4, wave of ≥ 2)

Dispatched with `isolation: "worktree"` (the harness creates and places the worktree —
the agent never runs `git worktree add`, `checkout -b`, `rebase`, or `reset`).

```
subagent_type: ck-code:story-implementer   # falls back to general-purpose
name: story-EE-SS                            # stable — P5 resumes it via SendMessage
model: sonnet                                # literal alias only — see the tier map below
isolation: worktree
description: "Implement story EE-SS: <title>"
prompt: |
  MODE: delegated

  You are implementing story EE-SS in an isolated worktree the harness created for you.

  Story file: <repo-relative story path from the index File column>
  Base SHA: <git rev-parse "$TARGET" after the P4 wave-start commit>
  Cycle: <absolute path of references/story-cycle.md — this skill's base directory + /references/story-cycle.md>
  Settled: <the P3/S2 answers and `--auto` assumptions for this story, or "nothing">
  Main checkout: <$ROOT — the absolute toplevel P1 recorded>

  Your task:
  0. Repo with a `.gitmodules` → `ck-worktree submodules <Main checkout>` once, before any
     build: a fresh worktree's submodules are empty, and it clones each against the main
     checkout's copy instead of N agents cloning from the network at once.
  1. `Read` the Cycle file once and follow it from "Placement — delegated" to "RETURN".
     It owns TDD, SOLID, the scans, the own check and committing. Never run the suite or the
     build: they run in the background after you return. Never load the ck-code:build skill.
  2. **Commit after every TDD cycle / phase** so an early stop still leaves resumable,
     committed work.
  3. At done (8.6), record what you actually touched in your own story, then commit
     the story file with your last cycle:
       ck-story files <story path> $(git diff --name-only <Base SHA>...HEAD -- . ':!tasks')

  Constraints:
  - Edit only files relevant to this story, and only this story's own frontmatter (status
    via `ck-story set … --no-sync`, files via `ck-story files`). Do NOT edit or commit the
    generated views (STORIES_INDEX.md, EPICS_INDEX.md) and do NOT run ck-index — they are
    gitignored, and the orchestrator regenerates them once after merge.

  Return the structured object {status, branch, commits, remaining, criteria_met}. Read
  `branch` from `git branch --show-current`. Report `status: done` only if build finished
  with every criterion checked and the own check green.
```

## Per-story implementer, solo (P4, wave of exactly 1)

The dispatch above, with three deltas — everything else (subagent_type, stable name, model
tiering, `MODE: delegated`, `Cycle:` and `Settled:` lines, task steps, constraints, return object) is identical:

1. **Drop `isolation`.** The agent runs in the main checkout on the branch the orchestrator
   already checked out (`$WORKBRANCH`).
2. **Replace the opening line** with:
   `You are implementing story EE-SS in the main checkout, already on branch <$WORKBRANCH>.`
   `You are the only agent running — no worktree, no peer, nothing to isolate from.`
3. **Insert the branch guard** directly after the `Base SHA:` line (on a solo dispatch that SHA is the P4 base SHA — the same commit):

```
  Branch guard — before your first edit, run `git rev-parse --abbrev-ref HEAD` and confirm
  it prints <$WORKBRANCH>. If it does not, stop and return status "blocked" with the branch
  you found; do not implement. Never run `git checkout -b`, `git switch -c`, `git rebase`,
  `git reset`, or any `git worktree` command — the branch is the orchestrator's to choose.
  Leave the tree clean when you return; uncommitted work fails the integrity gate.
```

The guard replaces the worktree. With no harness-owned worktree holding the agent in place,
this instruction is the only thing keeping it off another branch — never dispatch solo
without it.

## Single-story dispatch

`build` SINGLE-STORY DISPATCH (S4) sends the **solo** dispatch above, with these deltas — the
return object and the resume below are unchanged:

1. **Branch.** `<$WORKBRANCH>` is the story's own `story/…` or `fix/…` branch from S3, not an
   epic `$TARGET`; `Base SHA:` is the S3 `git rev-parse HEAD`. The branch guard is the same.
2. **Replace the opening line** with:
   `You are implementing story EE-SS in the main checkout, already on branch <branch>.`
   `You are the only agent running. Your orchestrator owns QA sign-off, the manual test and shipping.`
3. **Put the S2 answers in `Settled:`** — each acceptance criterion the user clarified and their
   reading of it (or the `--auto` assumption). The agent cannot ask; this is all it gets.
4. **Add the route and any foreground hits** after `Settled:`:
   `Route: QUICK` (or `LEAN`/`FULL`, the route S2 announced), then one
   `Background: FOREGROUND <file>:<line> <kind> — <text>` line per S1 `ck-headless` hit. With
   hits, add: `Convert each Background hit first, per <absolute path of
   ../../references/background-tests.md>, and commit it as its own commit before RED.`
5. **Add one `Heavy: <suite> — <globs>` line per suite** S1's `ck-heavy list` printed, then
   `Never run a heavy file you did not write or edit; mark yours — <absolute path of
   ../../references/heavy-tests.md> § In the build.` A fan-out or solo wave dispatch carries the
   same lines.

A review finding, a red background run or a manual-test report goes back to the **same agent** by `SendMessage`, worded
like the resume below with the findings, the failing labels with their excerpt and log path, or the user's report in place of
`remaining`, and on the same branch in the main checkout.

### Tier map — write the alias, never the tier name

The `Agent` tool's `model` parameter takes a literal alias; ck-code dispatches only `haiku`,
`sonnet` or `opus` (never `fable` without the user's approval). ck-code's tier names are prose
for choosing among them; emitting one as the value is an
invalid call. Translate before dispatch:

| ck-code tier | `model:` value | Use for |
|---|---|---|
| fast | `${user_config.model_fast}` (default `haiku`) | trivial mechanical change, the reviewer |
| balanced | `${user_config.model_balanced}` (default `sonnet`) | **the default** for a story implementer |
| advanced | `${user_config.model_advanced}` (default `opus`) | novel algorithm, concurrency correctness, security/perf-critical path |

Those three placeholders are substituted into this file at load time from the plugin's
`userConfig`, so the table already shows the operator's real choice. They are configured in
`/plugin` → ck-code, not by exporting environment variables. A value that is not one of the
three aliases is invalid — report it rather than dispatching it. On Claude Code ≥ 2.1.271
`/plugin` offers only those three as fixed choices (`userConfig` `options`), so this case
remains only for a value set before that release.

## Background conversion (P1)

PARALLEL MODE P1 dispatches this once, when `ck-headless` printed `FOREGROUND` lines, before any
wave. It runs solo on `$TARGET` in the main checkout. There is no story: the job is the
conversion and nothing else.

```
subagent_type: general-purpose
model: sonnet
description: "Run e2e suites in the background"
prompt: |
  You are in the main checkout on branch <$TARGET>. Before any edit, run
  `git rev-parse --abbrev-ref HEAD`; if it does not print <$TARGET>, change nothing and
  return `blocked: on <branch>`. Never create, switch, rebase or reset a branch.

  These setups open a window in front of the user while tests run:
    <the ck-headless FOREGROUND lines, verbatim>

  Read <absolute path of ck-code/references/background-tests.md> once and apply its
  conversion for each line, merging into the existing code. Change nothing else, and never
  write a `ck-headless: allow` marker. Then:
    1. `ck-headless` must print `ck-headless: OK`.
    2. Run the e2e suite once: `ck-qa run bg --reuse e2e='<the project's e2e command>'`
       (600000 ms Bash timeout; on `ck-qa: RUNNING`, `ck-qa wait bg`). It must pass.
    3. Stage only the files you changed and commit once:
       `test(e2e): run e2e suites in the background`. No AI references.
  Return exactly one line: `converted: <files>` or `blocked: <reason>`.
```

## Resume an incomplete story (P5)

A ◐ incomplete story is **not** re-dispatched — resume the same agent, whose context is
intact, along with its worktree (fan-out) or the main checkout it was working in (solo). For a
solo resume, replace "in the same worktree" with "on the same branch, in the main checkout"
and repeat the branch guard:

```
SendMessage({
  to: "story-EE-SS",
  message: "Your last run stopped before every acceptance criterion was met (remaining:
    <list>). Continue in the same worktree — inspect git log / git status and the story's
    unchecked criteria, finish only the remaining work following the Cycle file you already
    read, commit each cycle, and return the updated {status, branch, commits, remaining,
    criteria_met}. Do not redo completed work.",
  summary: "resume story EE-SS"
})
```

Re-run the P5 gate after each resume; cap 2 rounds. A resume that adds zero commits is
stuck — flag it and stop, never merge it.

## Reviewer (S5 and P7)

One per ✓-complete story, dispatched in the same message as `ck-qa start`
([qa-lane.md](../../../references/qa-lane.md#start-it)) — at P7, as soon as the story clears P5.
It reads; the commands are the lane's. It never waits for them, and they never wait for it.

```
subagent_type: ck-code:qa-validator     # unregistered → review inline instead
model: haiku
description: "Review story EE-SS: <title>"
prompt: |
  Mode: review. Read-only: run no test, build, lint or typecheck command, edit no file.
  They run in the background and are not your evidence.
  Where: <the branch's worktree path (fan-out), or the main checkout>
  Diff: git diff <Base SHA>...<branch>
  Story file: <repo-relative story path>   # acceptance criteria are in its body

  Follow qa-validation.md Steps 0–1 and 3.5–6: load the QA expert skills yourself, verify every
  acceptance criterion with file:line evidence (the implementation and the test that covers it),
  the redundancy/code-craft/test-prune spot-check, architecture compliance, and the design and
  replica fidelity sections when they apply.

  Return, in this order:
    - one line per acceptance criterion: PASS | FAIL | NOT-COVERED, with file:line
    - the Issues Found rows (severity, description, file:line), or "none"
    - exactly one final line:  QA: PASS   or   QA: FAIL — <finding> — <file:line>
```

`QA: FAIL` is a **NEEDS FIXES** verdict: `SendMessage` the findings to the story's builder at
once, without waiting for the background run, then the integrity gate, a new `ck-qa start` on the
new commit, and a new review. Cap 3.

**`fix` Phase 4 variant (reproduction, not review).** Same `subagent_type` and `model`,
but the agent is given the bug description, **may write one minimal
failing test**, and returns `{test path, failure output, root-cause hypothesis}` with no
verdict line. It still never proposes a fix — the Fix Plan is `fix`'s own Phase 5.
