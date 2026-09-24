# ck-code smoke tests

`tests/smoke.sh` builds a throwaway v7 project fixture (a real git repo under a temp
dir), puts this plugin's `bin/` on `PATH`, and drives the real scripts against it. It
covers:

- **the shared library** (`scripts/lib/ck-common.sh`): atomic, CRLF-preserving frontmatter
  writes that fail loudly on a missing or unterminated fence, the flow-list parser, the
  version comparator, and the team `SOURCES` digest;
- **views**: `ck-index` output, idempotency, unquoted `blocked_by`, title escaping, the
  `EPICS_INDEX.md` rollup, the views staying out of git, and `session-start.sh` and
  `ck-view` regenerating a missing or stale view;
- **the Ready rule**: a skipped blocker releases its dependant in `ck-view next`,
  `ck-view waves`, `ck-doctor` and the board;
- **`ck-story`, `ck-plan`, `ck-migrate`**: state flips, `files` merging, the plan record,
  and a full v6 → v7 conversion of a synthetic project (formatting kept, second run a
  no-op, a newer layout refused);
- **`ck-project` and `ck-issues` through a fake `gh`** (`tests/fake-gh/gh`, canned JSON,
  every call logged): sync with and without a Projects board, delivery reaching `merged`,
  no network call when no PR can change, issue closing, `Closes` footers, landed work;
- **the hooks**: the status line, the subagent status line, the session-start layout
  check in both directions (older → migrate, newer or unmet `requires:` → update the
  plugin), and the prompt router;
- **constants**: `LAYOUT` agreeing across `version-gate.md`, `session-start.sh` and
  `ck-doctor.sh`, and `plugin.json` meeting `MIN_PLUGIN`;
- `shellcheck -x -S warning` over every script, the library, `bin/*` and the fake `gh`.

`jq`-dependent assertions (the fake `gh` applies `--jq` with it) are skipped with a note
when `jq` is absent.

## Run locally

    bash tests/smoke.sh

## CI

`.github/workflows/ci.yml` runs this script on every push and pull request to
`main`, on both `ubuntu-latest` (with shellcheck installed) and `macos-latest`
(bash 3.2 — the portability check).

## Evals (skill routing) — local only

`tests/evals.sh` runs the `claude plugin eval` suite in `evals/` (Claude Code ≥ 2.1.269).
Each case sends a realistic free-text prompt inside a seeded ck-code project, where
`scripts/prompt-router.sh` injects `references/prompt-routing.md`, and checks with
`tool_used` graders that the right `/ck-code:*` skill is called — and no other.
`noroute-*` cases assert that no skill fires (a question, a one-off edit), and
`prereq-*` that a skill with a missing prerequisite is not entered.

    bash tests/evals.sh                        # 22 cases × 3 runs, pass mark 2 of 3
    bash tests/evals.sh --runs 1               # quick pass (~$2, ~2 min)
    bash tests/evals.sh --case 'route-fix-*'   # one glob per run (the last --case wins)

It runs on your logged-in Claude account (a Max plan works, no API key) and is not in
CI, because every run spends model tokens. Run it after changing a skill `description:`,
`references/prompt-routing.md`, `scripts/prompt-router.sh`, or guide Mode B.

- **Seeded project:** `evals/_fixture/adopted/`, copied into each run's cwd by
  `evals/_fixture/scaffold.sh` (`no-arch` variant drops `docs/architecture/`). It is a v7
  project, so it carries no views; they are regenerated in the run's copy.
- **Grading:** `routes-to-<skill>` matches `ck-code:<skill>` in the Skill call's input;
  `no-other-ck-code-skill` forbids every other `ck-code:` skill, and `passes-*` checks a
  required argument (`--fix`, `--publish`, `--refresh`, `integration`). `route-guide-or-track`
  accepts either: the router table sends "what's next" to `track`, guide Mode B to `guide`.
- **Hook visibility:** the router's context reaches the model but does not appear in the
  eval trace, so no grader asserts that the hook fired — the smoke test covers its output.
- Results land in `evals/results/` (git-ignored).
