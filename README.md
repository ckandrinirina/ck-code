# ck-code — Spec-Driven Workflow Plugin for Claude Code

> Turn a project specification into architecture docs, an implementation plan, and a TDD-driven build/ship loop — all from inside [Claude Code](https://www.anthropic.com/claude-code).

**ck-code** is an open-source [Claude Code plugin](https://www.anthropic.com/claude-code) that brings spec-driven development to AI-assisted software engineering. Feed it a project specification and it will:

1. **Design** — refine your spec into a complete set of architecture documents (global docs like folder structure and tech stack, plus one self-contained doc per feature covering its components, APIs, and data), plus an optional Claude Design system cache the build reproduces exactly
2. **Plan** — break the architecture into epics and single-dispatch stories (each sized S/M so one agent finishes it in a pass) with explicit dependencies
3. **Team** — derive a project-tailored team of expert and language-guide skills from your architecture, generating only the roles the project needs, at a depth you choose (`--basic` / `--standard` / `--max`), and capture your own house conventions in the same run (offered at the plan prompt — no second command)
4. **Build** — implement each story using test-driven development (TDD), SOLID principles, and a built-in dev-QA validation loop
5. **Ship** — commit with conventional commits, open a pull request, and auto-update linked GitHub Issues

Whether you're building a new project from scratch or adding a feature to an existing codebase, ck-code keeps the architecture, plan, and implementation in lock-step — so AI-generated code stays grounded in your real design.

## One source of truth (v5)

In v5, a story's state lives in **one** place: the YAML frontmatter of its story file
(`id, title, epic, status, size, blocked_by, files, issue, prior_status`). The
`STORIES_INDEX.md` and `FEATURE_INDEX.md` you see are **generated read-only views**,
regenerated from that frontmatter by `scripts/ck-index.sh`. Because a view is a pure
function of the frontmatter, it can never drift — so v5 has no reconciler skill and no
hand-edited index tables. To change a story's status, a skill edits the frontmatter and
regenerates; that's it.

## Features

- **Spec-driven development workflow** — single source of truth from specification to merged PR
- **Frontmatter-driven story state** — one writable location per story; indexes are generated, never hand-maintained
- **Automatic architecture documentation** — split markdown docs in `docs/architecture/` (overview, folder structure, tech stack, configuration, dev guide, `_shared.md`, plus a self-contained `features/<slug>/index.md` per feature)
- **Epic and story planning** — S/M-sized stories with dependency graphs in `tasks/`
- **GitHub Issues integration** — `ship --to-issues` pushes epics/stories to GitHub Issues; the created issue number is stored in each story's `issue:` frontmatter, so `ship` links by number (never by fragile title matching)
- **Test-Driven Development (TDD) enforcement** — red/green/refactor cycle, no production code without a failing test first
- **SOLID principle checks** — every implementation is reviewed against the five principles
- **Project-tailored expert skills** — auto-generated per-project experts and language guides, refreshed via [context7](https://context7.com); regeneration is non-destructive (your hand-authored and convention skills are preserved)
- **Claude Design system fidelity (optional)** — link a [claude.ai/design](https://claude.ai/design) design system with `/ck-code:design ds`; ck-code caches its tokens and component sources into the repo, generates a `guide-design-system` skill that auto-loads on UI stories, and builds components exactly against it. Fully offline after one sync, and entirely absent from projects that never opt in
- **Parallel multi-story builds** — implement multiple unblocked stories at once in isolated git worktrees (native isolation, structured returns, resumable agents) with conflict analysis before merge. A wave that narrows to a single story drops the worktree and runs one agent straight on the target branch — same delegation, none of the isolation overhead
- **Bug triage that hands off to the backlog** — `fix` diagnoses a bug, writes a failing test + Fix Plan into its story, flips it to `bug`; an easy single-story fix auto-runs `build` (Bug-Fix Mode), while a complex one is recorded for a manual `build` run
- **Native Claude Code integration** — `SessionStart`/`PostToolUse` hooks (auto-reload generated experts, inject project status + migration notice, config-gated auto-format), a subagent status line for parallel builds, and built-in `/goal`, `/code-review`, `/fast` pairings documented in `references/native-commands.md`

## Install

```bash
# 1) Add this marketplace inside Claude Code
/plugin marketplace add ckandrinirina/ck-code

# 2) Install the ck-code plugin
/plugin install ck-code@ck-marketplace
```

Restart your Claude Code session and the `/ck-code:*` commands are available.

## Update

```bash
/plugin update ck-code@ck-marketplace
```

Then restart your Claude Code session for the updated commands to take effect.

## Upgrading an older project to v5

ck-code stores story state in story-file frontmatter and generates its index views, and
`/ck-code:team` writes each generated skill to its own top-level folder. Projects created
by an older ck-code upgrade in one step:

```bash
/ck-code:migrate
```

`migrate` is one-shot, idempotent, and safe: it refuses a dirty tree and lands every
conversion in a single revertable commit. Every change-producing skill blocks a pre-v5
project until you run it, and the session-start hook reminds you. Pre-v3 projects are
handled too — the converter chains the older layout migrations first.

## Moving up from ck-code-lite

Same command. When a project outgrows [ck-code-lite](https://github.com/ckandrinirina/ck-code-lite)
— the task list no longer fits one file, or more than one person is planning the work —
run it inside that project:

```bash
/ck-code:migrate
```

It converts the flat `tasks/PLAN.md` into epics and stories (proposing a grouping you
confirm before anything is written), splits `docs/ARCHITECTURE.md` into `docs/architecture/`,
and marks the lite artifacts superseded rather than deleting them. Status, acceptance
criteria and ticked checkboxes are carried over, so finished work stays finished; task IDs
change from `T-NN` to `EE-SS` and the report prints the full map. Feature docs are written
as stubs — run `/ck-code:design` afterwards to fill them in.

## Per-project opt-in

Enable the plugin explicitly per project in that project's `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "ck-code@ck-marketplace": true
  }
}
```

Without this entry the plugin stays dormant in that project.

## Settings

Run `/plugin` → ck-code to set these; they are stored in your user `settings.json`, never
in the repo, and never need to be exported as environment variables.

| Setting | Default | What it changes |
|---|---|---|
| **Fast tier model** | `haiku` | model dispatched for trivial mechanical stories and QA command runs |
| **Balanced tier model** | `sonnet` | default model for a story implementer in `build` PARALLEL MODE |
| **Advanced tier model** | `opus` | model for stories with a high-reasoning signal (novel algorithm, concurrency, security- or perf-critical path) |

Each accepts one of `haiku`, `fable`, `sonnet`, `opus`. Raise the balanced tier for a codebase
where Sonnet consistently underperforms; lower the advanced tier to cap spend on a large epic.

## Permissions and guardrails

Every skill declares `allowed-tools`, so the `git`, `gh`, and `ck-index` calls it makes during
a run are pre-approved for that turn instead of prompting one command at a time. The grant is
narrow (a `build` run cannot `git push`; only `ship` can) and it expires with your next message.

`ship`, `build`, `fix`, and `spec` additionally register a skill-scoped `PreToolUse` hook that
blocks any commit, PR, or issue command carrying an AI-authorship trailer or footer. It matches
the trailer *forms* only, so a commit that legitimately discusses Claude Code is untouched. The
rule is [documented here](references/no-ai-references.md) and enforced by
`scripts/no-ai-guard.sh` — the hook is active only while one of those skills is running.

## Status bar (opt-in, zero tokens)

`scripts/statusline.sh` renders ck-code state in the Claude Code status bar — the feature
you're in, the story you're on (derived from the git branch), and how far each has got:

```
ck-code password-reset 2/5 60% 2⚡ 1✗ · epic 01 auth 2/5 40% · ⚡ 01-03 Password reset flow 5/8 · → epic/01 · ⚙ 01-04, 02-01
```

The line reads **top-down, one level of the plan per segment**, each counted in the unit
below it and each narrower than the last — feature in epics, epic in stories, story in
criteria. Scanning left to right answers *which feature, which epic, which story, how far*
in that order, and no segment repeats what a wider one already said. **Percentages belong to
the feature and the epic only** — the two levels whose ratios summarise many rows; below
them the ratio's own numbers are small enough to read directly.

- **Feature** `password-reset 2/5 60% 2⚡ 1✗` — the feature the branch belongs to, its
  **epics** done / total, and its open (`⚡`) and bug (`✗`) stories. The plan folder's date
  stamp and `feature-` prefix are dropped; an epic counts as done when every story in it is.
  The percentage is story-weighted, so it moves between epics instead of jumping in fifths.
- **Epic** `epic 01 auth 2/5 40%` — the epic in context, by number and name, counted in
  **stories**.
- **Story** `⚡ 01-03 Password reset flow 5/8` — the story you're on, read from the branch
  name (`story/<EE>-<SS>-…` or `fix/…`), counted in **acceptance criteria**. On an
  `epic/<NN>-…` branch — where an `integration: epic|feature` session sits while its stories
  are built — the epic's own open story is resolved from the index instead (in progress
  before bug). With no story in play the segment is simply absent: this line says where you
  *are*, and `/ck-code:track next` is what recommends where to go. Glyphs: `⚡` in progress ·
  `✓` done · `○` todo · `✗` bug.
- **Target** `→ epic/01` — where a finished story merges, shown only when the epic's
  `integration` is `epic` or `feature` (the `story` default merges to the default branch,
  which everyone already assumes). `→ feat` is appended at `feature` level, and on the epic
  branch itself only that promotion target is shown — naming the branch you are on is noise.
- **Live work** `⚙ 01-04, 02-01` — every story a worktree is building right now, sorted by
  id. Named rather than counted: `2 wt` says work is happening somewhere, the ids say which
  stories are moving. The session's own checkout is excluded — its story is the segment just
  before — and only `story/`/`fix/` worktrees count, since a checkout parked on an epic branch
  is somewhere you work, not something running. `+N` marks worktrees whose branch carries no
  story id (`⚙ 1 wt` when none can be named), so the segment never under-reports what is
  checked out.

**One colour per role, identical at every level** — dim for structure (the `ck-code` mark,
the `epic` / `⚙` labels, separators) and for every percentage, cyan for identity
(feature, epic, story id and title, merge target, worktree ids), green for every done /
total ratio, and yellow or red for status alone (`⚡` open, `✗` bug, and the story glyph).
Colour says what *kind* of value you are looking at, never which level it came from — the
level is already carried by position — so the eye learns the line once instead of once per
segment, and the only thing that interrupts a scan is a real status.

**The branch picks the feature, never the directory alone.** Story ids and epic numbers are
unique per plan, not across plans, so a `tasks/` holding several features can offer more
than one answer for one branch — and a multi-repo project, whose code repo sits under the
repo that owns `tasks/`, may check out a code repo carrying a stale plan of its own. Every
ancestor holding a plan is a candidate; the one the branch confirms (matching epic slug, or
a story id backed by the branch slug) wins, and all counts are then scoped to it. A branch
naming work no visible plan owns renders **nothing** — a confident wrong number is worse
than an empty status bar.

With no ck-code branch to go on (`main`, a detached HEAD) there is no one feature to
report, so an idle session falls back to project-wide story counts: `ck-code 12/20 60% 2⚡`.
Only `awk` and `git` are required; the whole line costs ~50ms to draw, and a fan-out now adds
nothing beyond one `git worktree list` — the per-worktree story-file reads are gone.

### Per-agent rows

`scripts/subagent-statusline.sh` ships enabled (a plugin *may* set `subagentStatusLine`)
and renders one row per dispatched agent:

```
⚡ story-02-01 · Implement 02-01 filter service · 5/8 63% · +214/-18 · 159.5k tok
```

`5/8 63%` is that story's criteria, counted in that agent's own worktree; `+214/-18` is its
diff against the branch the fan-out was cut from. **A row with no diff field has written no
code** — the failure `build` P5 otherwise only catches after the agent claims success.

The row resolves its story the same way the status bar does: the agent's own branch slug
decides which plan's `02-01` is meant, and plans above the worktree are searched too, so a
multi-repo layout (or a stale `tasks/` beside the code) cannot substitute another feature's
story — and with it, another feature's progress.

A percentage can only ever mean "boxes ticked": criteria are the sole progress signal with
a denominator, and the implementing agent ticks them as it goes, so read it as direction,
not as a measurement.

**It costs nothing.** The status bar is drawn by the terminal, never by the model, so
progress stays visible without spending output tokens or filling the context window —
which is exactly why ck-code keeps its *printed* per-phase output to one line each.

Claude Code only reads `statusLine` from user or project settings (a plugin's own
`settings.json` may set `subagentStatusLine`, not `statusLine`), so this one is opt-in:

```bash
CK=$(find ~/.claude/plugins -type d -name ck-code | head -1)

"$CK"/scripts/statusline.sh --install              # ~/.claude/settings.json
"$CK"/scripts/statusline.sh --install --project    # .claude/settings.json
"$CK"/scripts/statusline.sh --install --force      # replace an existing statusLine
```

Install writes an absolute path, keeps every other setting, and backs the file up;
without `--force` it refuses to overwrite a `statusLine` you already have. It sets
`refreshInterval: 5` so `/ck-code:build` PARALLEL MODE worktrees show up while the
main session is idle.

Already have a status line? Pipe the same stdin JSON into the script and interpolate its
output as one segment — it prints nothing outside a ck-code project, so the segment simply
disappears. Outside a ck-code project, or before `plan` has generated an index, it stays
silent. `jq` is optional and only `--install` requires it.

## Quick start — first-time setup in a new project

```bash
/ck-code:spec     docs/notes.md            # 1. (Optional) stakeholder-ready feature spec
/ck-code:design   docs/specifications.md   # 2. Generate architecture docs
/ck-code:team                              # 3. Create project-tailored experts + guides
/ck-code:plan     docs/specifications.md   # 4. Generate epics and stories
/ck-code:ship --to-issues                  # 5. (Optional) push the plan to GitHub Issues
/ck-code:track    next                     # 6. Find the first story to implement
/ck-code:build                             # 7. Start building (TDD + QA)
/ck-code:ship                              # 8. Commit, PR, close Issue
```

Not sure what to run? `/ck-code:guide` recommends the next step from project state,
`/ck-code:guide "add a login screen"` routes a plain-language task to the right skill, and
`/ck-code:guide --command build` prints a command's syntax.

## The full workflow

```
/ck-code:spec  →  /ck-code:design  →  /ck-code:team  →  /ck-code:plan  →  /ck-code:ship --to-issues  →  /ck-code:track
  (optional)                                                                                  ↓
                                                                              /ck-code:build  →  /ck-code:ship
                                                                                         ↑
                              /ck-code:fix  (diagnose bug → bug status)  ─────────────────┘
                              (easy fix auto-runs build; complex hands off to build)
```

| Skill | Purpose | Input | Output |
| --- | --- | --- | --- |
| `/ck-code:spec` | Generate a stakeholder-ready feature spec for review (descriptive, no code/jargon); CREATE + ADJUST modes | feature description or notes file | `docs/specs/` and/or GitHub issue |
| `/ck-code:design` | Refine a spec into feature-scoped architecture docs (one self-contained doc per feature + `_shared.md`); also `sync`/`optimize` maintenance modes | spec file | `docs/architecture/` |
| `/ck-code:team` | Derive per-project expert + guide skills from the architecture (depth `--basic`/`--standard`/`--max`); offers house-rules capture inline at the plan prompt (`--conventions` re-runs it alone); `--workflow` runs the big research/generation fan-outs as resumable scripted workflows; regeneration is non-destructive | `docs/architecture/` | `.claude/skills/expert-*/`, `.claude/skills/guide-*/` |
| `/ck-code:plan` | Create epics, single-dispatch S/M stories, a mandatory final Integration & E2E epic, and a roadmap; `--quick [brief] [--epic NN]` adds one small story to an existing epic | spec file | `tasks/YYYY-MM-DD_<slug>/` (stories carry frontmatter) |
| `/ck-code:build` | Implement stories (TDD + QA): one inline, several at once in parallel worktrees (story IDs), or a whole epic in dependency-ordered waves (`--epic NN`); a `bug`-status story runs in **Bug-Fix Mode** (implements the recorded Fix Plan, restores the story to `done`) | story file / story IDs / `--epic NN` | source code + tests; regenerated index views; in PARALLEL MODE a branch per story plus a conflict report for waves of ≥ 2, or commits straight on the target branch for a single-story wave |
| `/ck-code:fix` | Diagnose a bug tied to a story, write a failing test + Fix Plan, flip it to `bug` — then auto-run `build` for an easy fix or hand off when complex. Never writes the source fix itself | story file (optional) | failing test + Bug Report + `bug` status → `build` |
| `/ck-code:ship` | Commit, PR, update GitHub Issues. Honours the epic's **integration level** — a PR per story, per epic, or one per feature — merging story branches up the hierarchy and offering promotion when a rollup completes (`--promote` runs that gate later, `--integration` sets the level). `--to-issues [--mode feature\|epics\|stories]` publishes the plan to Issues and stores each issue number in story frontmatter | story file (optional) | commit + PR + issue updates; merged/promoted branches |
| `/ck-code:track` | Progress dashboard + `next` ready-story finder (reads the generated indexes) | — | status, next story, completion % |
| `/ck-code:guide` | Router: no arg → next step from state; free text → best-fit skill; `--command <name>` → syntax (read-only, recommends only) | plain-language task / `--command` | recommended command + prerequisite + next step |
| `/ck-code:migrate` | One-shot, idempotent upgrade of a pre-v5 **or ck-code-lite** project to the v5 layout (frontmatter + generated indexes + flat team-skill folders); stamps `tasks/VERSION.md` | — | converted project (one commit) |
| `/ck-code:explain` | Explain what was just implemented + manual verification steps | — | walkthrough + verification steps |
| `/ck-code:doctor` | Health report for the project — layout stamp, story frontmatter that will not parse, generated indexes drifted from the stories, unresolvable `blocked_by` ids, feature-doc slug drift, unregistered team skills, orphan epic branches. Names the command that fixes each finding (read-only) | `[tasks/<slug>] [--quiet]` | findings + fixes; exit 1 on any error |

## Why ck-code?

If you've used Claude Code on a real project, you've felt the friction: the AI works at file-level but humans plan at architecture-level, and the two drift apart. Specs go stale. Stories get re-implemented. Tests are skipped under deadline pressure.

ck-code closes that gap. The architecture docs, the story plan, the expert skills, and the implementation are all generated from the same spec — and the build loop refuses to ship code without a failing test, a SOLID check, and an explicit story status update. In v4, that status lives in exactly one place, so the plan you read is always the plan that's true.

## Layout

```
ck-code/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/                        # ck-code-specific subagents
│   ├── qa-validator.md
│   ├── conflict-analyzer.md
│   └── story-implementer.md
├── references/                    # cross-skill shared contracts (version gate, data model,
│                                  # skill detection, subagent fan-out, QA, workflow map, …)
├── hooks/
│   └── hooks.json                 # SessionStart + PostToolUse(format) registrations
├── settings.json                  # subagent status line
├── CHANGELOG.md
├── bin/                           # added to the Bash tool's PATH while the plugin is enabled
│   ├── ck-index                   # → scripts/ck-index.sh   (skills call the bare command)
│   └── ck-doctor                  # → scripts/ck-doctor.sh
├── workflows/                     # registered Workflow scripts, invoked by name (resumable)
│   ├── team-research.js           # /ck-code:team --workflow, Phase 1.6a
│   └── team-generate.js           # /ck-code:team --workflow, Phase 3.1
├── scripts/
│   ├── ck-index.sh                # regenerate the index views from story frontmatter
│   ├── ck-doctor.sh               # read-only project health check (/ck-code:doctor)
│   ├── session-start.sh           # SessionStart hook (reload skills, status, migrate notice)
│   ├── format.sh                  # PostToolUse auto-format (config-gated)
│   ├── no-ai-guard.sh             # PreToolUse guard: blocks AI trailers in commits/PRs
│   ├── statusline.sh              # opt-in status bar: active story + plan counts
│   └── subagent-statusline.sh
├── skills/
│   ├── spec/                      # stakeholder-ready feature spec (create + adjust)
│   ├── design/                    # spec → feature-scoped architecture docs (+ optimize/sync)
│   ├── team/                      # derive per-project experts + guides (+ conventions)
│   ├── plan/                      # architecture → epics/stories (+ --quick single story)
│   ├── build/                     # TDD story implementation (inline, parallel, waves)
│   ├── fix/                       # bug triage → hands off to build
│   ├── ship/                      # commit + PR + Issue updates (+ --to-issues)
│   ├── track/                     # progress dashboard
│   ├── guide/                     # state/intent/command router
│   ├── migrate/                   # pre-v5 → v5 and ck-code-lite → v5 converter
│   └── explain/                   # post-implementation walkthrough
└── README.md
```

Each skill folder is self-contained: the main `SKILL.md` is the entry point, and any bulky templates or examples live in a `references/` subfolder that loads on demand.

## Per-feature spec folder

```
docs/specs/YYYY-MM-DD_<slug>/
├── pre-spec.md            # Stakeholder-friendly version (from /ck-code:spec)
├── .metadata.json         # Slug, GitHub issue link, status, language
└── feature-spec.md        # (later, optional) Design-pass output
```

`/ck-code:spec` creates these on first run and re-uses them on subsequent invocations to
apply adjustments — keeping the local file and the linked GitHub issue in sync.

## Compatibility

> **v5 — breaking (team skills only).** `/ck-code:team` now writes each generated skill to
> its own top-level folder — `.claude/skills/expert-<role>/` and `guide-<tech>/` — instead of
> nesting them under `experts/` and `guides/`. Claude Code discovers project skills at
> `.claude/skills/<skill-name>/SKILL.md` and takes the command name from that directory, so
> the nested files were never registered as skills: `/expert-<role>` did not exist and no
> guide ever auto-loaded outside a ck-code `build`/`fix`. `/ck-code:migrate` moves the folders
> with `git mv` (history preserved) and re-stamps `tasks/VERSION.md` to `layout: v5`. Stories,
> epics, and architecture docs are untouched — a v4 project needs only this one step. Restart
> Claude Code afterwards so it picks up the new top-level directories.
>
> **v4 — breaking.** ck-code v4 stores story state in story-file frontmatter and generates
> its `STORIES_INDEX.md` / `FEATURE_INDEX.md` views. It no longer reads the v3 layout
> (prose `Status:` headers, hand-maintained `Schema: v1/v2` index tables, `EPIC.md` story
> tables, `DESIGN_LEDGER.md`, `L`/`XL` sizes). Every change-producing skill runs a **version
> gate** first: on a pre-v5 project it blocks and offers `/ck-code:migrate`, a one-shot,
> idempotent converter that rewrites the layout and stamps `tasks/VERSION.md`. Run it once
> and your project is v5. The same gate catches a **ck-code-lite** project (`tasks/PLAN.md`)
> and routes it to the same command.

- **Claude Code** — required (CLI, IDE extension, or desktop app)
- **gh CLI** — required for `ship --to-issues` and `ship` GitHub Issue features
- **git** — required for `build` PARALLEL MODE (uses worktrees)
- **[context7](https://context7.com)** — recommended for `team`, `design`, `plan`, and `build` to fetch up-to-date framework documentation. Either the MCP server or the `ctx7` CLI (`npx -y @upstash/context7 setup`) works.

## Contributing

Issues and pull requests welcome at [github.com/ckandrinirina/ck-code](https://github.com/ckandrinirina/ck-code). If you use the plugin and find a rough edge, please open an issue describing your project type and the command that misfired — concrete examples make the workflow better for everyone.

## License

MIT — see [LICENSE](LICENSE).

## Keywords

Claude Code plugin · spec-driven development · AI coding workflow · TDD with AI · automated architecture documentation · GitHub Issues integration for AI · parallel AI agent builds · Claude agent skills · context7 best practices · AI-assisted software engineering
