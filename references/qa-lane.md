# The QA lane — one background run, nobody waits

Nobody sits in front of a running suite. Each piece of work is checked by **one** run, on the
committed code, in a checkout of its own (the *lane*), while the build goes on. The only place
that waits is the [gate](#the-gate) before something leaves the machine. Read by `build` (S5,
P7–P9) and `ship`.

Why one run: measured over three weeks, builders spent 58 h and QA agents 39 h in front of
`ck-qa`, the same suite ran two or three times per story, and 47 of 102 QA failures were review
findings reported only after the suite had ended.

## Who runs what

| Who | Runs | Never |
| --- | --- | --- |
| the builder | its own test files in RED / GREEN / refactor, then the [own check](../skills/build/references/story-cycle.md#63-own-check) once | the suite, the build, another story's tests |
| the reviewer (`ck-code:qa-validator`, `Mode: review`) | nothing: criteria, scans, architecture, read from the diff | any command |
| the lane | the scoped suite, lint, typecheck and build of the commit, once | — |
| `ship` | the heavy suites the user chose ([heavy-tests.md](heavy-tests.md)) | — |

## Start it

Right after the integrity gate, **in one message**: the start, the reviewer dispatch, and the
wait as a background Bash call. Nothing here waits.
A call the harness refuses in that message is sent again on its own.

```bash
cd <component> && ck-qa start <id> --base <Base SHA> [--parallel] test="@ck-affected {base} [--area] --command '<full row>' '<row narrowed>'" lint='<full lint row>' types='<typecheck row>' build='<build row>'
```

```bash
cd <component> && ck-qa wait <id> --end      # Bash run_in_background: true — its end notifies you
```

- The rows and the scope are [qa-scope.md](../skills/build/references/qa-scope.md)'s. `{base}` is
  resolved in the lane: the last commit that passed this command, never older than `--base`, and
  reaching back over a run that has not passed. `@` means the output of the command is the
  command to run. Write both literally; never expand them here.
- One start per component or code repository, each with its own id (`02-05-web`). An `&&` row
  that shares a build lock is one label, without `--parallel`.
- The lane checks the **commit**, so a file nobody `git add`ed fails there. Editing, committing,
  switching branch and building the next story never disturb it.
- **Check forms only**: a label that rewrites tracked files fails (`eslint --fix`, a formatter,
  `jest -u`), because it would vouch for code nobody committed. A script that does (`"lint": "eslint
  --fix"`) is replaced by its check form.
- A newer start of the same commands replaces one still queued: `SUPERSEDED` (exit 4) is not a
  failure, the newer run covers it.
- `STARTED … leave it alone` (the lane is `off` here): do not edit this checkout until the run
  ends.
- `ck-qa start` refused (no git, no commit) → `ck-qa run` with the same labels, in the
  foreground, and say so.

## While it runs

| May go on | Must wait for green |
| --- | --- |
| review fixes, the manual-test question, conflict analysis, the merge into the epic branch | `ship`'s push, any PR, `--promote`, anything on the trunk |
| the next wave or story — **one ahead**: wave N+1 is dispatched while wave N's run is pending | wave N+2, until wave N is green |

Say it in one line when moving on: `QA: 02-05 running in the background — going on with wave 3.`
Never report the run, the epic or the story as finished while a run is pending: say what is
pending.

**Nothing left to do but the run** → end the turn with that line; the background call's
notification resumes it. Under `--auto`, or when no background Bash is available, run
`ck-qa wait <id>` in the foreground until it ends instead. Never write a wait loop.

## When it ends

- **`ck-qa: PASS`** → one line, and carry on.
- **`FAIL — setup: …`** → no test ran. The lane lacks something the checkout has. A step the
  project documents (a codegen script) → `.ck-qa-lane` with `setup: <command>`, committed, and
  `ck-qa gate --again`. Otherwise `.ck-qa-lane` with `off`, committed and named in the report.
- **`BASELINE`** → the label fails exactly as it did at `--base`, with no new failure line: not this
  work's, and not red. It goes into the PR body like `WAIVED`. The lane works it out itself: a red
  label is run again on the base, and only what is new is listed under `new since`. A chained command
  (`a && b`) is never compared: give each check its own label where the stack allows it.
- **`FAIL` on a test the diff cannot reach** → `ck-qa gate --again` once. It passes → name the
  flaky test in the report. It fails again → a real failure.
- **`FAIL`** → fix forward on the branch the code is on. A `lesson:` line is tried first.
  - Single story: `SendMessage` the same agent the failing labels, the excerpt and the log path.
  - Wave already merged: one `ck-code:story-implementer` solo on `$TARGET`, as for a manual-test
    `ISSUES` ([parallel-mode.md § P8](../skills/build/references/parallel-mode.md#p8--merge-regenerate-verify)),
    with the same three and the wave's commits. A later **fan-out** wave in flight does not hold
    it back, since `$TARGET`'s checkout is free. A later **solo** wave does: the fix goes right
    after it returns, before its review.
  - Then `ck-qa start` again with the same labels and `--base`. **Cap 3** red runs for the same
    work, then escalate `FIX MANUALLY / ACCEPT AS-IS / ABORT` (`--auto`: stop the run, set the
    stories it implicates back with `ck-story set <path> status=in-progress --no-sync` (a bug
    story: `status=bug prior_status=<prior_status>`), commit that, and report).
    `ACCEPT AS-IS` → `ck-qa waive <id> "<the user's reason>"`, the one way past a red run.

## The gate

```bash
ck-qa gate --base <what this branch merges into>
```

| Prints | Then |
| --- | --- |
| `gate GREEN`, `gate NONE` | go on |
| `gate PENDING — <ids>` | `ck-qa wait <id> --end` as a background call; prepare the PR text meanwhile |
| `gate UNCHECKED` | code changed after the last pass, or a run was lost: `ck-qa gate --again --base <…>`, then as PENDING |
| `gate RED` | nothing leaves the machine: name the run, fix it as above |

`WAIVED` and `BASELINE` lines go into the PR body, word for word. A commit that touches only `tasks/`, `docs/`
or Markdown never voids a pass. In a workspace of several code repositories, run it in each.

**At the start of a `build` run** (S1, P1), the same call picks up what an interrupted session
left: `RED` → that fix comes before new work; `UNCHECKED` → `--again` in the background.

## The lane itself

One per repository under `~/.ck-qa/lanes` (`CK_QA_LANE_DIR`), a detached worktree locked as
`ck-qa lane`: never a story's worktree, never swept, reported or removed as one. Its
`node_modules` are copies, copy-on-write where the disk can; build output is real. It stays
warm for the next run. `ck-qa lane-free` removes it, as does 7 days without use.

## Rules

- **Never wait on a suite while there is other work**, and never poll one.
- **Never run the suite in a builder, a reviewer or the orchestrating context.**
- **Never push, open a PR, promote or land on the trunk without `gate GREEN` or `NONE`.**
- **Never go more than one wave ahead of a run that is not green.**
- **Never read `SUPERSEDED`, `PENDING` or a missing result as green**, and never `waive` without
  the user's answer.
