# Heavy tests — slow suites run once per PR, not in the build

A suite that needs a database, a container, a running server or a browser is **heavy**. One of
92 serial DB specs cost about 11 h of waiting in two weeks, because every story and every QA pass
re-ran part of it. `build` never runs a heavy suite. It writes and marks the specs, and `ship`
asks before the PR.

## `.ck-heavy-tests` — the declaration

At the root of the **code** repository (a workspace of several repositories has one in each):

```
db: prisma/tests/**/*.e2e.spec.ts | npm run test:e2e:db -- {files}
http: test/*.e2e-spec.ts | npm run test:e2e -- {files}
```

`name: globs | command`, one suite a line. The command runs from the repo root and takes
`{files}`. One that starts with `cd <dir> && ` gets them relative to `<dir>`. A runner that
accepts no paths gets no `{files}` and always runs whole. `none` alone on a line says nothing
here is heavy, and is never asked about again.

`ck-affected` drops every declared file from story and area scope. When the component's default
test command would still collect them, add that runner's exclusion to the row
(`--exclude '<glob>'` on vitest, `--testPathIgnorePatterns` on jest, `--ignore-glob` on pytest).

### Undeclared suites (once per repository, before the first dispatch)

`ck-heavy detect`, run in each code repository the story or wave touches, prints `CANDIDATE` lines
for slow suites nobody declared. `ck-heavy: OK` adds nothing. Otherwise write the suite lines they
imply (the config's `include` or `testMatch` gives the globs, the script gives the command) and
put **one question** in the run's existing `AskUserQuestion`, showing those lines: **Keep them out
of the build** (recommended) / **Run them in the build** (writes `none`). With no slot left in that
call, ask on the next run. Under `--auto`, take the recommended answer and name it in the report.
Commit the file with the run's first `chore` commit on the work branch. In another repository,
where the run has no such commit, it is its own commit: `chore(tests): declare the heavy suites`.

## In the build

- **Mark the spec.** Every heavy test file a story adds or edits names the story in a comment near
  its top, in the file's own syntax: `// ck-heavy: 69-03`. Append to the ids already there
  (`// ck-heavy: 69-03 75-05`), never replace one. A spec owned by a whole epic, such as an
  end-to-end journey, may read `epic-69`. Never edit a file only to mark it.
  `ck-heavy unmarked <base> <id>` must print nothing before the story is done.
- **Run only the file you wrote or edited**, for RED and for GREEN, one file at a time:

  ```bash
  ck-qa run 69-03-heavy db="$(ck-heavy command db only prisma/tests/late-recovery-request.e2e.spec.ts)"
  ```

  Run it from the repo root. Re-run it only after a change meant to turn it green. A spec no
  run has passed leaves its criterion unchecked, and the story is not done. A spec that cannot
  run here (no Docker, no service) is reported as **not run**, never as passed.
- **Never run another heavy file**, not as a regression check, at 6.3, or because a migration
  changed. `FULL` from `ck-affected` means the full rows of the fast suites only.
- **QA never runs one.** 6.3, 7, P7, S5 and P8 take no heavy label, and a full row that chains a
  heavy suite is replaced by its fast part. A criterion proved only by a heavy spec passes on the
  builder's own `ck-qa` run of that file plus the spec's assertions, cited by `file:line`: the one place a builder's run is QA's evidence. `not run` is NEEDS FIXES unless
  the user accepts it.
- **An E2E epic's story** follows the same rules: its own journey specs run one file at a time,
  the rest wait for the PR.
- Report `Heavy tests: 2 marked, run at the PR` in the story's summary.

## At the PR — one question

`ship` asks **once per PR into the trunk**: at level `story` with the story's PR, at `epic` and
`plan` with the epic's or plan's promotion PR. A story merged into its epic branch, a *Commit only*
and an `--auto` build ask nothing, and the specs wait, marked, for the PR that carries them.

```bash
ck-heavy scope <base> <id>…
```

Run it in each code repository of the change. `<base>` is `git merge-base HEAD origin/<trunk>`, and
the ids are the story (`69-03`), the epic number (`69`), or every epic number of the plan.
`ck-heavy: NONE` → no question. Otherwise add **one question** to the confirmation already being
asked (3.3, or §6.5's promotion question), "Run the heavy tests before the PR?", with the counts:

1. `Linked only (3 files)` (recommended): marked with these ids, or changed on this branch
2. `Affected (16 files)`: plus every heavy file that imports the change. Drop this option when it
   equals linked or whole
3. `Whole suite (92 files)`
4. `Skip`

A linked count of 0 drops option 1. Then, on the branch the PR opens from, after the commit and
**before the push**, run every suite with a non-zero count in one call, without `--parallel`:

```bash
ck-qa run heavy db="$(ck-heavy command db linked <base> 69)"
```

Every call gets a 600000 ms timeout. On `ck-qa: RUNNING`, `ck-qa wait heavy` until it prints a
result.

| Result | Then |
|---|---|
| `PASS` | push and open or update the PR |
| `FAIL` | **do not push.** The commit stays. Show the failing specs with their marker's story and stop: `/ck-code:fix` for a defect, then ship again (a re-run needs only the failed files: `ck-heavy command <suite> only <file>…`) |
| an environment error (no Docker, port taken) | say so and ask again: retry, or skip |
| `Skip` | push, and the PR body carries the line below |

A skipped or partial run is never silent. The PR body ends (above any `Closes` footer) with one
plain line: `Database and end-to-end tests: not run before this PR.` or `… : run for this change
only.` Phase 7 reports the same.
