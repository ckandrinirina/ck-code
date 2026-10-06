# ck-code Dependencies — What init Checks

Phase 2.1 of `init` reports one row per tool below. It **never installs anything**; the
hint column is what the user runs. "Required" means some ck-code command fails without the
tool. "Optional" means ck-code degrades cleanly without it.

| Tool      | Level    | What ck-code uses it for                                                                           | Missing → hint                                                                                                 |
| --------- | -------- | -------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `git`     | required | every skill: branches, worktrees, the stamp's repo root, `ship`                                    | install git from your OS package manager                                                                       |
| `awk`     | required | every `ck-*` script (BWK awk and gawk both work)                                                   | ships with macOS and every Linux; install `gawk` if absent                                                     |
| `python3` | required | `ck-bootstrap` merges `.claude/settings.json`; the no-AI commit guard; `ck-checklist import`       | install Python 3 (`brew install python`, `apt install python3`)                                                |
| `gh`      | optional | `ship` PRs, `plan --publish` issues, the GitHub Project board, `doctor --fix`                      | `brew install gh` / [cli.github.com](https://cli.github.com)                                                   |
| `gh auth` | optional | same as `gh`; only checked when `gh` is present                                                    | `gh auth login`                                                                                                |
| context7  | optional | `team` researches current best practice per technology                                             | add the context7 MCP server, or keep `npx` on PATH for its CLI; without either, `team` falls back to WebSearch |
| `npx`     | optional | the context7 CLI fallback                                                                          | install Node.js                                                                                                |
| `jq`      | optional | `statusline.sh --install` edits `settings.json` as JSON                                            | `brew install jq` / `apt install jq`                                                                           |
| `rtk`     | optional | filters test, git and gh output before it reaches context ([`rtk.md`](../../../references/rtk.md)) | install rtk, then `rtk init`. A `rtk` without a `gain` subcommand is a different tool                          |

## Report format

```
Dependencies
  git        present   required
  awk        present   required
  python3    MISSING   required  → install Python 3 (brew install python)
  gh         present   optional  (authenticated)
  context7   present   optional  (MCP)
  jq         missing   optional  → brew install jq
  rtk        missing   optional  → install rtk, then rtk init
```

A missing required tool gets one `⚠` line above the table naming what will not work until
it is installed. A missing optional tool is never a warning.
