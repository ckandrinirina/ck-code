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
