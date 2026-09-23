# ck-code smoke tests

`tests/smoke.sh` builds a throwaway v6 project fixture (a real git repo under a
temp dir), puts this plugin's `bin/` on `PATH`, and drives the real scripts against
it: `ck-index`, `ck-view` (status/next/progress/waves/state), `ck-doctor` (whole-
project and single-plan), `ck-story` (get/set round-trip), `ck-bootstrap check`, and
the three hook scripts (`statusline.sh`, `session-start.sh`,
`subagent-statusline.sh`) fed their expected stdin JSON.

It asserts behaviour `references/data-model.md`, `references/stories-index.md`,
`references/feature-index.md` and `skills/build/references/wave-mode.md` document as
correct: unquoted `blocked_by` in `STORIES_INDEX.md`, `next`/`waves` dependency
resolution, wave file-conflict splitting, the `MERGED`/`IN PROGRESS` feature
rollup, `ck-doctor` plan scoping, `ck-story`'s `ck-index: WARN` passthrough, title
escaping (`|` / `"`), and `ck-index` idempotency. It also runs
`shellcheck -x -S warning` over `scripts/*.sh` and `bin/*` when shellcheck is on
`PATH`, and skips jq-only assertions with a note when `jq` is absent.

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

    bash tests/evals.sh                        # 19 cases × 3 runs, pass mark 2 of 3
    bash tests/evals.sh --runs 1               # quick pass (~$2, ~2 min)
    bash tests/evals.sh --case 'route-fix-*'   # one glob per run (the last --case wins)

It runs on your logged-in Claude account (a Max plan works, no API key) and is not in
CI, because every run spends model tokens. Run it after changing a skill `description:`,
`references/prompt-routing.md`, `scripts/prompt-router.sh`, or guide Mode B.

- **Seeded project:** `evals/_fixture/adopted/`, copied into each run's cwd by
  `evals/_fixture/scaffold.sh` (`no-arch` variant drops `docs/architecture/`). Regenerate
  its indexes with `ck-index` after editing a story in it.
- **Grading:** `routes-to-<skill>` matches `ck-code:<skill>` in the Skill call's input;
  `no-other-ck-code-skill` forbids every other `ck-code:` skill. `route-guide-or-track`
  accepts either: the router table sends "what's next" to `track`, guide Mode B to `guide`.
- **Hook visibility:** the router's context reaches the model but does not appear in the
  eval trace, so no grader asserts that the hook fired — the smoke test covers its output.
- Results land in `evals/results/` (git-ignored).
