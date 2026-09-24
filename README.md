# ck-code — Spec-Driven Workflow Plugin for Claude Code

> Turn a project specification into architecture docs, an implementation plan, and a TDD-driven build/ship loop — all from inside [Claude Code](https://www.anthropic.com/claude-code).

**ck-code** is an open-source [Claude Code plugin](https://www.anthropic.com/claude-code) that brings spec-driven development to AI-assisted software engineering. Feed it a project specification and it will:

1. **Design** — refine your spec into a complete set of architecture documents (global docs like folder structure and tech stack, plus one self-contained doc per feature covering its components, APIs, and data), plus an optional Claude Design system cache the build reproduces exactly
2. **Plan** — break the architecture into epics and single-dispatch stories (each sized S/M so one agent finishes it in a pass) with explicit dependencies
3. **Team** — derive a project-tailored team of expert and language-guide skills from your architecture, generating only the roles the project needs, at a depth you choose (`--basic` / `--standard` / `--max`), and capture your own house conventions in the same run (offered at the plan prompt — no second command)
4. **Build** — implement each story using test-driven development (TDD), SOLID principles, and a built-in dev-QA validation loop
5. **Ship** — commit with conventional commits, open a pull request, and auto-update linked GitHub Issues

Whether you're building a new project from scratch or adding a feature to an existing codebase, ck-code keeps the architecture, plan, and implementation in lock-step — so AI-generated code stays grounded in your real design.

## One source of truth, and nothing to commit but the work (v7)

A story's state lives in **one** place: the YAML frontmatter of its story file
(`id, title, epic, status, size, blocked_by, files, issue, pr, delivery, prior_status`).
A plan's own state (its integration level, branch, PR and issue) lives in the frontmatter
of its `OVERVIEW.md`. Everything else is derived.

`STORIES_INDEX.md` and `EPICS_INDEX.md` are **generated views**, and in v7 they are never
committed. `tasks/.gitignore` keeps them out of git. The session-start hook regenerates
them from frontmatter, and so does every reader that finds one missing or older than the
stories it projects. Your history holds the work and its state changes, not a
"regenerate indexes" commit after every story: on a real 12-epic project those made up
113 of 277 commits.

The version stamp is stable too. `tasks/VERSION.md` says `layout: v7` and
`requires: ck-code >= 7.0.0`, and nothing rewrites it except a migration, so updating the
plugin never leaves your tree dirty.

## Done is not shipped

Two independent axes describe a story, because "finished" and "on the trunk branch" are
different facts:

- **`status`** — `todo → in-progress → done` (plus `skip`, `bug`). The work itself.
- **`delivery`** — empty `→ pr → merged`, or `direct`. How far it travelled toward the trunk.

So a story can be `done` with no PR (**Ready to Ship**), `done` with an open PR
(**In Review**), or `done` and merged (**Done**). `ship` records the PR number in `pr:`;
`ck-project sync` asks GitHub what became of it and updates `delivery` — which is why a
PR merged in the browser, with nothing running locally, still lands correctly on the next
sync. It works with or without a GitHub Projects board, and it makes no network call at
all when no recorded PR can still change. Set `trunk_branch:` in `tasks/SETTINGS.md` when your integration branch is not the
repo default.

**Skipped the PR entirely?** Merge a finished story into `main` yourself and push, and
there is no PR for any of that to hang on — before, the card sat in *Ready to Ship* with
the code already shipped. That story is now `delivery: direct` and goes straight to
**Done**, skipping *In Review* and *Ready to Ship*, because both are states a PR passes
through and there was no PR. Every sync finds it: the proof is that `main`'s own copy of
the story file already reads `status: done`, having arrived alongside code — so it still
works after you delete the branch. Work with no such proof (committed straight onto `main`,
no branch left) is reported as a candidate and applied only when you confirm it.

You rarely run it yourself. `ship` reconciles **before** it stages, so a merge that
happened while you were away rides the next commit instead of needing a chore PR of its
own. The session summary counts anything still awaiting confirmation, and
`/ck-code:doctor --fix` runs the whole reconciliation on demand. A story that ships
through an epic or plan PR has that PR's number written onto it, not just inherited.

Dependencies resolve against `status` alone: a blocker is released when it is `done`, or
`skip` (work the plan decided not to do). Work you can build on is finished work, not
merged work.

## One id, one story

**Epic numbers are unique across every plan in your project**, so a story id (`EE-SS`)
names exactly one story anywhere in `tasks/`. Point at work directly and nothing has to
ask you which plan you meant:

```bash
/ck-code:build --epic 07      # the whole epic, in dependency-ordered waves
/ck-code:build 07-02          # one story
```

Through v5, numbering restarted at `01` in each new plan folder, so a second plan could
own the same `01-01` as the first — and `--epic NN`, `blocked_by`, and the
`epic/<NN>-*` branch lookup would quietly pick whichever they found first. Each new epic
is now allocated from the project-wide maximum, so a plan added later starts at `05`
rather than restarting at `01`. A dependency may also point at a story in another
plan, because its id is unambiguous.

If your project already has two plans with colliding numbers, `/ck-code:migrate`
renumbers them — the oldest plan keeps its numbers, so its merged branches and published
issues stay valid.

## Features

- **Spec-driven development workflow** — single source of truth from specification to merged PR
- **Frontmatter-driven story state** — one writable location per story and one record per plan; the views are generated, never hand-maintained, and never committed
- **Deterministic work runs in scripts, not in the model** — the progress dashboards, the next-story pick, the project-state routing and the dependency/file-conflict wave plan are rendered by `ck-view`; a story state change goes through `ck-story`, which writes the frontmatter *and* regenerates the views *and* syncs the board in one call; a plan's record goes through `ck-plan`; QA commands go through `ck-qa`, which runs each one once per code state, runs independent checks concurrently, and lets a later QA step skip a suite that already passed on the identical tree; the v6 → v7 conversion is `ck-migrate`. None of it costs model tokens, one shared library holds every rule the scripts share, and `tests/smoke.sh` drives all of it, the GitHub side included, through a fake `gh`
- **Automatic architecture documentation** — split markdown docs in `docs/architecture/` (overview, folder structure, tech stack, configuration, dev guide, `_shared.md`, plus a self-contained `features/<slug>/index.md` per feature)
- **Epic and story planning** — S/M-sized stories with dependency graphs in `tasks/`
- **GitHub Issues integration** — `plan --publish` pushes the plan, its epics or its stories to GitHub Issues in one `ck-issues` call (rate-limit pacing, `issue:` write-back, epic→story relinking, and native **sub-issue** links that give each epic a progress bar); the created issue number is stored in each story's `issue:` frontmatter, so `ship` links by number (never by fragile title matching). Re-running finishes an interrupted publish — nothing is ever created twice. Starting a story assigns its linked issue to whoever runs `build` (an `--epic NN` run claims the epic issue too), so GitHub shows who owns the work in flight — additive, so an existing assignee is never removed
- **GitHub Projects board sync** — the board is a *generated view* of story frontmatter, like the indexes: `ck-project sync` computes the column each card belongs in from `status` **and** `delivery`, and pushes only the differences, so it can't drift and is safe to re-run. Each sync re-asks GitHub what happened to every recorded PR, so a merge you clicked in the browser lands on the board with nothing running locally — and a story you merged straight to the trunk with no PR at all is detected from git and moved to Done, instead of sitting in Ready to Ship forever. ck-code adapts to whatever columns your board already has (an unmapped role is skipped, never an error) or provisions a seven-column board — Blocked · Todo · In Progress · Ready to Ship · In Review · Bugs · Done — for a new project. `/ck-code:config board` sets it up; `build` and `ship` keep it current, and `/ck-code:doctor --fix` repairs any drift
- **Test-Driven Development (TDD) enforcement** — red/green/refactor cycle, no production code without a failing test first
- **SOLID + redundancy checks** — every implementation is reviewed against the five principles, then its diff is scanned for code the repo already has: reimplementations, copy-paste, dead code, single-caller wrappers, and options no acceptance criterion asked for
- **Clean-code and comment standard** — `build` writes to one shared bar (`references/code-craft.md`): self-explaining names, small functions, idiomatic error handling, and comments only where they say *why*. The refactor phase scans the diff for restating comments, missing rationale, missing doc comments and readability, and QA verifies the scan ran; generated tech guides refine the standard per project, never lower it
- **Project-tailored expert skills** — auto-generated per-project experts and language guides, researched via [context7](https://context7.com). Each one records which version of your tech stack it was written against, so `/ck-code:doctor` and the session start name the ones a stack change made stale, and `/ck-code:team --refresh` regenerates just those. Regeneration is non-destructive: hand-authored and convention skills, and every `MANUAL` block, are preserved
- **Claude Design system fidelity (optional)** — `/ck-code:spec` offers to write a **design brief** you paste into [claude.ai/design](https://claude.ai/design); when the system is ready, hand its URL back with `/ck-code:design ds <url>` — from any session, days later, since the pending link lives on disk and is surfaced at session start. ck-code then caches its tokens and component sources into the repo, generates a `guide-design-system` skill that auto-loads on UI stories, and builds components exactly against it. Fully offline after one sync, and entirely absent from projects that never opt in
- **Parallel multi-story builds** — implement multiple unblocked stories at once in isolated git worktrees (native isolation, structured returns, resumable agents) with conflict analysis before merge. A wave that narrows to a single story drops the worktree and runs one agent straight on the target branch — same delegation, none of the isolation overhead
- **Bug triage that hands off to the backlog** — `fix` diagnoses a bug, writes a failing test + Fix Plan into its story, flips it to `bug`; an easy single-story fix auto-runs `build` (Bug-Fix Mode), while a complex one is recorded for a manual `build` run
- **ck-code is required, and the repo says so** — a ck-code project keeps its plan, stories and architecture in a layout only the `/ck-code:*` commands maintain, so a clone on a machine that never installed the plugin has nothing that can read or write that state — and nothing able to *say* so, because the plugin is what is missing. `ck-bootstrap install` commits a ~1 KB guard (`.claude/ck-code-required.sh`, wired as the project's own `SessionStart` hook) that is silent wherever ck-code is present and stops the session with the install command wherever it is not. It is written automatically the first time a session starts in a stamped project
- **Native Claude Code integration** — `SessionStart`/`UserPromptSubmit`/`PostToolUse` hooks (auto-reload generated experts, inject project status + migration notice, route every free-text prompt to the best-fit skill, config-gated auto-format), a subagent status line for parallel builds, and built-in `/goal`, `/code-review`, `/fast` pairings documented in `references/native-commands.md`
- **RTK-aware command forms (optional)** — [RTK](https://github.com/ckandrinirina/rtk) is a third-party `PreToolUse` hook that filters command output before it reaches context, returning a full test suite as its failures alone. ck-code writes the command forms its hook recognizes (`npm run test`, never the unfilterable `npm test` alias) so the savings need no setup, never hardcodes an `rtk` prefix, and never requires the tool. `/ck-code:doctor` reports whether it is installed and wired. Slow commands (suite, lint, typecheck, e2e) run once per code state into a `$TMPDIR` log that is read instead of re-run. RTK still filters that form, while QA runs through `ck-qa` are capped by its 40-line failure tail instead. See `references/rtk.md`

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

## ck-code is required in a ck-code project

Once a project is planned with ck-code, its state lives in `tasks/` and
`docs/architecture/` in a shape only the `/ck-code:*` commands maintain. Open that repo on
a laptop that never installed the plugin and none of those commands exist — and nothing in
ck-code can point that out, because ck-code is exactly what is absent.

So the project carries the warning itself:

```bash
ck-bootstrap install
```

That writes `.claude/ck-code-required.sh` (~1 KB) and wires it as the project's own
`SessionStart` hook in `.claude/settings.json`, which it also opts into the plugin.
**Commit both.** You rarely run this by hand: the plugin's own session-start hook installs
it the first time a session opens a project carrying `tasks/VERSION.md`, and says so.

The guard reads `tasks/VERSION.md` and looks for ck-code on `PATH`, in the plugin cache and
in `installed_plugins.json`. Where it finds it, it prints nothing at all. Where it does not,
the session opens with:

```
⛔ ck-code is REQUIRED in this project and is not installed. … STOP before doing
   anything else here: do not plan, implement, commit, edit tasks/ or
   docs/architecture/, and never improvise a stand-in for a /ck-code:* command.
   /plugin marketplace add ckandrinirina/ck-code
   /plugin install ck-code@ck-marketplace
```

| Command | What it does |
|---|---|
| `ck-bootstrap install` | write the guard, wire the SessionStart hook, opt the project into the plugin (idempotent) |
| `ck-bootstrap check` | guard version, whether it is wired, and whether it is actually committed |
| `ck-bootstrap remove` | delete the guard and unwire it |

`/ck-code:doctor` reports the same thing as a `bootstrap` row — including the case that
quietly defeats it, a `.claude/` line in `.gitignore` that keeps the guard from ever being
committed.

> **Vendoring was removed in 6.11.0.** Earlier releases could copy the whole plugin into
> `.claude/skills/ck-code/` (`/ck-code:vendor`). That copy loads as `ck-code@skills-dir`, a
> different plugin id from `ck-code@ck-marketplace` — neither shadows the other, so both
> ran and every `/ck-code:*` command appeared twice, one of them frozen at whatever version
> was vendored. If your project still has that folder, delete it along with the
> `ck-code@skills-dir` key in `.claude/settings.json`, then
> `/plugin install ck-code@ck-marketplace`. `doctor` and the session-start hook both
> flag it until you do.

## Upgrading to v7

A project created by ck-code 6.x upgrades in one step:

```bash
/ck-code:migrate
```

`migrate` shows you exactly what will change (`ck-migrate v7 --dry-run`), asks once, and
lands the whole conversion in a single revertable commit. The conversion is a tested
script, not prose the model re-derives, and on a real 12-epic project it came to 16 lines
added and 104 removed:

- each plan's `PROJECT_OVERVIEW.md` or `FEATURE_OVERVIEW.md` becomes `OVERVIEW.md`, with a
  frontmatter record of the plan's integration level (the widest its epics used), its
  branch and its PR. An existing `feat/…` branch is kept, not renamed;
- every `EPIC.md` loses `integration:`, which is a plan property now, and keeps its
  `## Dependencies` prose;
- the views leave git, and `FEATURE_INDEX.md` is regenerated as `EPICS_INDEX.md`;
- `pre-spec.md` becomes `spec.md`, and the design-system metadata moves into
  `manifest.json`;
- `tasks/VERSION.md` becomes `layout: v7` and `requires: ck-code >= 7.0.0`.

It refuses a dirty tree, keeps each file's own formatting, and a second run does nothing.
Every change-producing skill blocks a v6 project until it is migrated, and the session
start says so.

**Older layouts (v3, v4, v5) upgrade with the same command.** `migrate` first brings them
to v6 (frontmatter state, flat team-skill folders, unique epic numbers), then to v7, and
folds both into one commit.

**A teammate still on 6.x** opening your migrated project is told to update the plugin,
never to migrate: the stamp's `requires:` line is what a 6.x session sees first. A layout
newer than the plugin can never be converted down.

## Moving up from ck-code-lite

Same command. When a project outgrows [ck-code-lite](https://github.com/ckandrinirina/ck-code-lite)
— the task list no longer fits one file, or more than one person is planning the work —
run it inside that project:

```bash
/ck-code:migrate
```

It converts the flat `tasks/PLAN.md` into epics and stories (proposing a grouping you
confirm before anything is written), splits `docs/ARCHITECTURE.md` into `docs/architecture/`,
writes the v7 plan record, and marks the lite artifacts superseded rather than deleting them. Status, acceptance
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

Without this entry the plugin stays dormant in that project. `ck-bootstrap install` writes it for you — see [ck-code is required in a ck-code project](#ck-code-is-required-in-a-ck-code-project).

## Settings

Run `/plugin` → ck-code → **settings** to set these; they are stored in your user
`settings.json`, never in the repo, and never need to be exported as environment
variables.

### Model tiers

The three keys below live in [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json)'s
`userConfig`, so they show up as plugin settings rather than needing an env var.

| Setting | Key | Default | What it changes |
|---|---|---|---|
| **Fast tier model** | `model_fast` | `haiku` | model dispatched for trivial mechanical stories and QA command runs |
| **Balanced tier model** | `model_balanced` | `sonnet` | default model for a story implementer in `build` PARALLEL MODE |
| **Advanced tier model** | `model_advanced` | `opus` | model for stories with a high-reasoning signal (novel algorithm, concurrency, security- or perf-critical path) |

Each accepts one of `haiku`, `fable`, `sonnet`, `opus`, offered as fixed choices in `/plugin`
(Claude Code ≥ 2.1.271). Raise the balanced tier for a codebase
where Sonnet consistently underperforms; lower the advanced tier to cap spend on a large epic.

## Permissions and guardrails

Every skill declares `allowed-tools`, so the `git`, `gh`, and `ck-index` calls it makes during
a run are pre-approved for that turn instead of prompting one command at a time. The grant is
narrow (a `build` run cannot `git push`; only `ship` can) and it expires with your next message.

`ship`, `build`, `fix`, `plan`, `migrate`, `spec`, and `doctor` additionally register a skill-scoped
`PreToolUse` hook that blocks any commit, PR, or issue command carrying an AI-authorship
trailer or footer. It matches the trailer *forms* only, so a commit that legitimately
discusses Claude Code is untouched. The rule is
[documented here](references/no-ai-references.md) and enforced by `scripts/no-ai-guard.sh`
— the hook is active only while one of those skills is running.

**SessionStart hook** (`scripts/session-start.sh`) reloads generated skills, regenerates
the views, checks the layout stamp in both directions (an older project is sent to
`migrate`, a newer one or an unmet `requires:` asks you to update the plugin), names
expert or guide skills a stack change made stale, injects the one-line workflow summary,
and — only in a project already stamped `tasks/VERSION.md` —
may run `ck-bootstrap install` when the committed guard is missing or stale. That writes
`.claude/ck-code-required.sh` and adds its `SessionStart` entry to `.claude/settings.json`;
it never touches an unstamped project, so cloning ck-code itself does not trigger it. It
never rewrites a tracked file. See
[ck-code is required in a ck-code project](#ck-code-is-required-in-a-ck-code-project).

**Prompt router** (`scripts/prompt-router.sh`, `UserPromptSubmit`) makes the workflow the
default for every prompt, not only for the ones typed as `/ck-code:*`. In an adopted project
(one with `docs/architecture/`, `docs/specs/`, `tasks/VERSION.md` or a `tasks/*/epics`
folder) it injects [`references/prompt-routing.md`](references/prompt-routing.md) — a
one-screen intent → skill table — as context for each free-text prompt, so "the login form
crashes on submit" runs `/ck-code:fix`, "ship it" runs `/ck-code:ship`, and a one-off edit
no story covers is still made under the project's expert/guide skills. It announces the
chosen skill in one line and invokes it; the prompt is the consent. It stays silent on a
slash command (you already chose), on a reply shorter than 12 characters ("yes", "2" — an
answer to a running skill, which routing would derail), and in any repo that has not
adopted ck-code, so a scratch project never has its prompts routed. Pure local read, always
exits 0.

**`format.sh`** (`PostToolUse` on every `Write`/`Edit`) best-effort formats the file just
touched: `gofmt` and `rustfmt` run whenever installed, no configuration needed — they are
the language standard. `prettier`, `ruff`/`black`, and `shfmt` run only when the project
has opted in (a prettier config file or `package.json` key; a `pyproject.toml`/`ruff.toml`/
`.ruff.toml`/`setup.cfg` carrying `[tool.ruff]`/`[tool.black]`; an `.editorconfig` or
`.shfmt`), so a repo that never asked for one of those formatters never has its style
silently rewritten. Always exits 0 — a missing formatter or an unformattable file never
fails the turn.

**Dispatched subagents** — `story-implementer`, `qa-validator`, `conflict-analyzer` — run
with the full tool set, not a narrowed `allowed-tools` list. Their "never commit, never
push" boundary is a stated constraint in the dispatch prompt, verified by the orchestrator
afterward, not a permission the tool layer enforces for them.

**Nothing leaves the machine** except the `git` and `gh` calls each skill's `allowed-tools`
already names — no telemetry, no other network call, from any skill or hook.

**One plan tree per repo.** `tasks/` must sit at the git root; ck-code does not support more
than one `tasks/` directory in the same repository (a multi-repo project with code and
`tasks/` in different repos is fine — see [Status bar](#status-bar-opt-in-zero-tokens)).

## Troubleshooting

- **Every story in a parallel wave fails QA on a missing `.env` or credential file.** Worktrees
  are bare checkouts with no gitignored files. List those files in `.worktreeinclude` at the
  repo root (gitignore syntax), and Claude Code copies them into each new worktree.
  `/ck-code:doctor` flags the case as a `worktree` WARN.
- **Keep getting a permission prompt for a command a skill runs.** The skill's own
  `allowed-tools` should have pre-approved it — update the plugin (`/plugin update
  ck-code@ck-marketplace`); an older version may be missing that command form.
- **The status line shows nothing on a fresh clone.** The views are not committed; the
  next session start regenerates them, or run `ck-index` now.
- **A story sits at `blocked` and never becomes ready.** Its `blocked_by` ids must
  resolve to `done` or `skip` stories — `/ck-code:doctor` reports one that does not.
- **A PR was merged but the story still shows it in review.** Run `/ck-code:doctor --fix`.
  It asks GitHub about every recorded PR, records work merged with no PR, moves the board
  cards and closes delivered issues, with or without a Projects board.
- **`gh` is unauthenticated.** GitHub calls are skipped with a warning; the local,
  commit-only half of `build`, `ship` and `doctor --fix` still completes.
- **The project is on an older layout.** Run `/ck-code:migrate` — every change-producing
  skill blocks until the project is v7.
- **"This project requires ck-code >= …" or "uses a newer ck-code layout".** A teammate
  migrated it with a newer plugin. Run `/plugin update ck-code@ck-marketplace` and
  restart; never migrate it.
- **Every `/ck-code:*` command is listed twice.** Two enabled copies of the plugin —
  usually `ck-code-lite` left enabled alongside `ck-code`, or a leftover vendored copy
  (see [ck-code is required in a ck-code project](#ck-code-is-required-in-a-ck-code-project))
  — are both registered. Disable the one you are not using.
- **No warning ever appears for an AI-authorship trailer.** `python3` is required for
  the no-AI guard; when it is missing, the session prints one warning and the guard is
  disabled for that session rather than blocking silently.

## Status bar (opt-in, zero tokens)

`scripts/statusline.sh` renders ck-code state in the Claude Code status bar — the plan
you're in, the story you're on (derived from the git branch), and how far each has got:

```
ck-code password-reset 2/5 60% 2⚡ 1✗ · epic 01 auth 2/5 40% · ⚡ 01-03 Password reset flow 5/8 · → epic/01 · ⚙ 01-04, 02-01
```

The line reads **top-down, one level of the plan per segment**, each counted in the unit
below it and each narrower than the last — plan in epics, epic in stories, story in
criteria. Scanning left to right answers *which plan, which epic, which story, how far*
in that order, and no segment repeats what a wider one already said. **Percentages belong to
the plan and the epic only** — the two levels whose ratios summarise many rows; below
them the ratio's own numbers are small enough to read directly.

- **Plan** `password-reset 2/5 60% 2⚡ 1✗` — the plan the branch belongs to, its
  **epics** done / total, and its open (`⚡`) and bug (`✗`) stories. The plan folder's date
  stamp (and the `feature-` prefix older plan folders carry) are dropped; an epic counts as done when every story in it is.
  The percentage is story-weighted, so it moves between epics instead of jumping in fifths.
- **Epic** `epic 01 auth 2/5 40%` — the epic in context, by number and name, counted in
  **stories**.
- **Story** `⚡ 01-03 Password reset flow 5/8` — the story you're on, read from the branch
  name (`story/<EE>-<SS>-…` or `fix/…`), counted in **acceptance criteria**. On an
  `epic/<NN>-…` branch — where an `integration: epic|plan` session sits while its stories
  are built — the epic's own open story is resolved from the index instead (in progress
  before bug). With no story in play the segment is simply absent: this line says where you
  *are*, and `/ck-code:track next` is what recommends where to go. Glyphs: `⚡` in progress ·
  `✓` done · `○` todo · `✗` bug.
- **Target** `→ epic/01` — where a finished story merges, shown only when the plan's
  `integration` is `epic` or `plan` (the `story` default merges to the default branch,
  which everyone already assumes). `→ plan` is appended at `plan` level, and on the epic
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
(plan, epic, story id and title, merge target, worktree ids), green for every done /
total ratio, and yellow or red for status alone (`⚡` open, `✗` bug, and the story glyph).
Colour says what *kind* of value you are looking at, never which level it came from — the
level is already carried by position — so the eye learns the line once instead of once per
segment, and the only thing that interrupts a scan is a real status.

**The branch picks the plan, never the directory alone.** A multi-repo project, whose
code repo sits under the repo that owns `tasks/`, may check out a code repo carrying a
stale plan of its own. Every
ancestor holding a plan is a candidate; the one the branch confirms (matching epic slug, or
a story id backed by the branch slug) wins, and all counts are then scoped to it. A branch
naming work no visible plan owns renders **nothing** — a confident wrong number is worse
than an empty status bar.

With no ck-code branch to go on (`main`, a detached HEAD) there is no one plan to
report, so an idle session falls back to project-wide story counts: `ck-code 12/20 60% 2⚡`.
Only `awk` and `git` are required; the whole line costs ~50ms to draw, and a fan-out now adds
nothing beyond one `git worktree list` — the per-worktree story-file reads are gone.

### Per-agent rows

`scripts/subagent-statusline.sh` ships enabled (a plugin *may* set `subagentStatusLine`)
and renders one row per dispatched agent:

```
⚡ story-02-01 · Implement 02-01 filter service · 5/8 63% · +214/-18 · 159.5k tok
```

`5/8 63%` is that story's acceptance criteria, counted in the agent's own worktree copy of
the story (found by its `id:`, since a worktree carries no view); `+214/-18` is its
diff against the branch the fan-out was cut from. **A row with no diff field has written no
code** — the failure `build` P5 otherwise only catches after the agent claims success.

The row resolves its story the same way the status bar does: the agent's own branch slug
decides which plan's `02-01` is meant, and plans above the worktree are searched too, so a
multi-repo layout (or a stale `tasks/` beside the code) cannot substitute another plan's
story — and with it, another plan's progress.

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
/ck-code:design                            # 2. Architecture docs (finds the spec spec just wrote)
/ck-code:team                              # 3. Create project-tailored experts + guides
/ck-code:plan                              # 4. Epics and stories; asks the integration level once
/ck-code:plan --publish                    # 5. (Optional) push the plan to GitHub Issues
/ck-code:track    next                     # 6. Find the first story to implement
/ck-code:build                             # 7. Start building (TDD + QA)
/ck-code:ship                              # 8. Commit, PR, close Issue
```

Each step offers the next one as a single question, so after `spec` you normally answer
"Run it" four times rather than typing these commands. Not sure what to run? `/ck-code:guide` recommends the next step from project state,
`/ck-code:guide "add a login screen"` routes a plain-language task to the right skill, and
`/ck-code:guide --command build` prints a command's syntax.

## The full workflow

```
/ck-code:spec  →  /ck-code:design  →  /ck-code:team  →  /ck-code:plan  →  /ck-code:plan --publish  →  /ck-code:track
  (optional)                                                                                 ↓
                                                                              /ck-code:build  →  /ck-code:ship
                                                                                         ↑
                              /ck-code:fix  (diagnose bug → bug status)  ─────────────────┘
                              (easy fix auto-runs build; complex hands off to build)
```

| Skill | Purpose | Input | Output |
| --- | --- | --- | --- |
| `/ck-code:spec` | Generate a stakeholder-ready feature spec for review (descriptive, no code/jargon); CREATE + ADJUST modes; offers a Claude Design brief on a UI project | feature description or notes file | `docs/specs/<date>_<slug>/spec.md` and/or GitHub issue |
| `/ck-code:design` | Refine a spec into feature-scoped architecture docs (one self-contained doc per feature + `_shared.md`); with no argument it picks up the spec marked ready for design; also `sync`/`optimize` maintenance modes and `ds [url]` to link a Claude Design system. A tech-stack change hands off to `team --refresh` | spec file (optional) | `docs/architecture/` |
| `/ck-code:team` | Derive per-project expert + guide skills from the architecture (depth `--basic`/`--standard`/`--max`); offers house-rules capture inline (`--conventions` re-runs it alone); `--refresh` regenerates only the skills a stack change made stale, `--regenerate` all of them; `--workflow` runs the big fan-outs as resumable scripted workflows; never overwrites protected skills or `MANUAL` blocks | `docs/architecture/` | `.claude/skills/expert-*/`, `.claude/skills/guide-*/` |
| `/ck-code:plan` | Create epics ordered demo-first (the first epic makes the app runnable over fixture seams, every later epic is demoable on merge), single-dispatch S/M stories a human verifies through the surface, a mandatory final Integration & E2E epic, and a roadmap. Asks the plan's **integration level** once — a PR per story, per epic, or one for the plan. `--quick [brief] [--epic NN]` adds one small story and hands it to `build`; `--publish [--mode plan\|epics\|stories]` pushes the plan to GitHub Issues and stores every issue number in frontmatter | spec or feature doc (optional) | `tasks/YYYY-MM-DD_<slug>/` with an `OVERVIEW.md` record |
| `/ck-code:build` | Implement stories (TDD + QA): one inline, several at once in parallel worktrees (story IDs), or a whole epic in dependency-ordered waves (`--epic NN`); a `bug`-status story runs in **Bug-Fix Mode**. Derives the base branch from the plan's integration level and shows it before cutting, records every file a story touched in its `files:`, and hands a finished parallel epic to `ship --promote` | story file / story IDs / `--epic NN` | source code + tests; story frontmatter; in PARALLEL MODE a branch per story plus a conflict report for waves of ≥ 2 |
| `/ck-code:fix` | Diagnose a bug tied to a story, write a failing test + Fix Plan, flip it to `bug` — then auto-run `build` for an easy fix or hand off when complex. Never writes the source fix itself | story file (optional) | failing test + Bug Report + `bug` status → `build` |
| `/ck-code:ship` | Commit, PR, update GitHub Issues, after one confirmation that shows the files, the message and the PR target together (likely secrets are never staged). Honours the plan's integration level — a PR per story, per epic, or one for the plan — and `--promote` opens the epic or plan PR when a rollup completes. Reconciles merged PRs before staging and generates the `Closes` footer from frontmatter | story file (optional) | commit + PR + issue updates |
| `/ck-code:track` | Progress dashboard + `next` ready-story finder (reads the generated indexes) | — | status, next story, completion % |
| `/ck-code:guide` | Router: no arg → next step from state; free text → best-fit skill; `--command <name>` → syntax (read-only, recommends only) | plain-language task / `--command` | recommended command + prerequisite + next step |
| `/ck-code:migrate` | Upgrade a v6, older (v3–v5) **or ck-code-lite** project to the v7 layout: previews the tested `ck-migrate` conversion, asks once, lands one revertable commit | — | converted project (one commit) |
| `/ck-code:explain` | Explain what was just implemented + manual verification steps; `--epic NN` instead explains that epic's goal and the goal of every story in it | `[file-or-concept]` / `--epic NN` | walkthrough + verification steps, or epic + story goals |
| `/ck-code:doctor` | Health report — layout stamp (older, newer, or an unmet `requires:`), story frontmatter that will not parse, committed or stale views, unresolvable `blocked_by` ids, feature-doc slug drift, stale or invalid team skills, orphan epic branches, board mapping, the ck-code-required guard. `--fix` reconciles delivery, the board and GitHub Issues in one pass (with or without a board), confirms any unproven direct merge, and commits the story files | `[tasks/<slug>] [--quiet] [--fix]` | findings + fixes; with `--fix`, one bookkeeping commit |
| `/ck-code:config` | Project settings in `tasks/SETTINGS.md` — GitHub issue tracking on or off, the trunk branch every PR targets, the GitHub Projects board (create, adopt, re-map, reorder), a plan's integration level, and whether build asks about expert skills | `show` / `board` / `trunk <branch>` / `integration <plan> <level>` / `experts ask\|none` / `on` / `off` | `tasks/SETTINGS.md`, the plan record, board mapping |

## Hand-offs — one click, never a retype

Every arrow in the diagram above is a **hand-off**, and every hand-off asks you exactly
once. You decide whether it happens; what you don't do is retype the command.

Before, saying yes to "next, run build" meant reading the path out of the output and typing
`/ck-code:build tasks/2026-07-11_auth/stories/03-login.md` by hand — then approving a
permission prompt on top. Now it is a single question with the path already filled in:

```
→ [fix → build] /ck-code:build tasks/2026-07-11_auth/stories/03-login.md
  reason: fix plan recorded, story at status: bug

  Run it            takes the reproduction test RED → GREEN per the recorded Fix Plan
  Skip              the story stays at status: bug; run it later
  Change arguments  same skill, different story or flags
```

Three things this guarantees:

- **Skip is always safe.** A skill reaches a valid, resumable state *before* it offers a
  hand-off, so declining never leaves the project half-done.
- **Chains cannot run away.** Maximum depth 5 (enough for spec → design → team → plan →
  publish), and a skill may never invoke one already on
  the chain — so `fix → build → fix` is structurally impossible, not merely discouraged.
- **Read-only stays read-only.** `guide`, `track`, `explain` and `doctor` run with no
  write tools (`doctor --fix` writes only through the ck-code scripts and `git`). They never launch anything themselves; they end with a
  `NEXT:` line the session offers you as the same one-click run.

The biggest win is the version gate. An older project used to cost *two* retypes — type
`/ck-code:migrate`, then retype your original command from memory once it finished. It now
offers migration once and resumes what you were doing, with the arguments you already gave.

The full contract lives in [`references/skill-invocation.md`](references/skill-invocation.md);
which hand-offs exist is the invocation matrix in
[`references/workflow-map.md`](references/workflow-map.md).

## Why ck-code?

If you've used Claude Code on a real project, you've felt the friction: the AI works at file-level but humans plan at architecture-level, and the two drift apart. Specs go stale. Stories get re-implemented. Tests are skipped under deadline pressure.

ck-code closes that gap. The architecture docs, the story plan, the expert skills, and the implementation are all generated from the same spec — and the build loop refuses to ship code without a failing test, a SOLID check, and an explicit story status update. That status lives in exactly one place, so the plan you read is always the plan that's true.

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
│   └── hooks.json                 # SessionStart + UserPromptSubmit(router) + PostToolUse(format)
├── settings.json                  # subagent status line
├── CHANGELOG.md
├── bin/                           # added to the Bash tool's PATH while the plugin is enabled
│   ├── ck-index                   # → scripts/ck-index.sh   (skills call the bare command)
│   ├── ck-view                    # → scripts/ck-view.sh
│   ├── ck-story                   # → scripts/ck-story.sh
│   ├── ck-doctor                  # → scripts/ck-doctor.sh
│   ├── ck-issues                  # → scripts/ck-issues.sh
│   ├── ck-project                 # → scripts/ck-project.sh
│   ├── ck-plan                    # → scripts/ck-plan.sh
│   ├── ck-qa                      # → scripts/ck-qa.sh
│   ├── ck-team                    # → scripts/ck-team.sh
│   ├── ck-migrate                 # → scripts/ck-migrate.sh
│   └── ck-bootstrap               # → scripts/ck-bootstrap.sh
├── workflows/                     # registered Workflow scripts, invoked by name (resumable)
│   ├── team-research.js           # /ck-code:team --workflow, Phase 1.6a
│   └── team-generate.js           # /ck-code:team --workflow, Phase 3.1
├── scripts/
│   ├── lib/ck-common.sh           # the one implementation of every shared rule (sourced)
│   ├── ck-index.sh                # regenerate the views from story frontmatter
│   ├── ck-view.sh                 # render the dashboards / state / wave plan (zero model tokens)
│   ├── ck-story.sh                # set story state + regenerate + sync, in one call
│   ├── ck-doctor.sh               # read-only project health check (/ck-code:doctor)
│   ├── ck-issues.sh               # publish a plan to GitHub Issues (plan --publish)
│   ├── ck-project.sh              # reconcile delivery, the board and GitHub Issues
│   ├── ck-plan.sh                 # read and set a plan's OVERVIEW.md record
│   ├── ck-qa.sh                   # run QA commands once per code state (reuse, parallel, wait past the Bash cap)
│   ├── ck-team.sh                 # the team-skill refresh contract (SOURCES digest)
│   ├── ck-migrate.sh              # deterministic v6 → v7 conversion
│   ├── ck-bootstrap.sh            # the committed ck-code-required guard
│   ├── session-start.sh           # SessionStart hook (reload skills, views, layout check, status)
│   ├── prompt-router.sh           # UserPromptSubmit hook: inject references/prompt-routing.md
│   ├── format.sh                  # PostToolUse auto-format (config-gated)
│   ├── no-ai-guard.sh             # PreToolUse guard: blocks AI trailers in commits/PRs
│   ├── statusline.sh              # opt-in status bar: active story + plan counts
│   └── subagent-statusline.sh
├── skills/
│   ├── spec/                      # stakeholder-ready feature spec (create + adjust)
│   ├── design/                    # spec → feature-scoped architecture docs (+ optimize/sync)
│   ├── team/                      # derive per-project experts + guides (+ conventions)
│   ├── plan/                      # architecture → epics/stories (+ --quick, --publish)
│   ├── build/                     # TDD story implementation (inline, parallel, waves)
│   ├── fix/                       # bug triage → hands off to build
│   ├── ship/                      # commit + PR + Issue updates (+ --promote)
│   ├── track/                     # progress dashboard
│   ├── guide/                     # state/intent/command router
│   ├── migrate/                   # v6, older and ck-code-lite projects → v7
│   ├── doctor/                    # project health report (+ --fix reconciliation)
│   ├── config/                    # tasks/SETTINGS.md, board, integration level
│   └── explain/                   # post-implementation walkthrough
├── tests/                         # smoke.sh (scripts, CI) + evals.sh (skill routing, local)
└── README.md
```

Each skill folder is self-contained: the main `SKILL.md` is the entry point, and any bulky templates or examples live in a `references/` subfolder that loads on demand.

## Per-feature spec folder

```
docs/specs/YYYY-MM-DD_<slug>/
├── spec.md                # Stakeholder-friendly spec (from /ck-code:spec)
├── design-brief.md        # Optional — paste into claude.ai/design to build the design system
└── .metadata.json         # Canonical: eleven keys, fixed order, closed set
                           # (linkedDesign points at docs/architecture/features/<slug>/ after a design pass;
                           #  designSystem tracks the Claude Design link across sessions)
```

`/ck-code:spec` creates these on first run and re-uses them on subsequent invocations to
apply adjustments — keeping the local file and the linked GitHub issue in sync.
`.metadata.json` is generated to one fixed shape every run; `/ck-code:doctor` reports any
file that has drifted from it.

## Compatibility

> **v7 — breaking (layout).** The generated views leave git and regenerate from
> frontmatter; `FEATURE_INDEX.md` is now `EPICS_INDEX.md`. Each plan carries an
> `OVERVIEW.md` record holding its integration level (`story`, `epic` or `plan`, which
> replaces `feature`), branch, PR and issue. `tasks/VERSION.md` is stable
> (`layout: v7`, `requires: ck-code >= 7.0.0`). `/ck-code:sync` became
> `/ck-code:doctor --fix`, `ship --to-issues` became `plan --publish`, and
> `ship --integration` became `config integration`. `/ck-code:migrate` converts a v6
> project in one commit (see [Upgrading to v7](#upgrading-to-v7)).
>
> Earlier breaking releases, all still converted by the same `/ck-code:migrate`: **v6**
> made epic numbers unique across plans; **v5** moved team skills to top-level
> `.claude/skills/expert-*/` and `guide-*/` folders; **v4** moved story state into
> frontmatter. The details are in `CHANGELOG.md`.

- **Claude Code** — required (CLI, IDE extension, or desktop app). **ck-code 7.0.0 is built
  and tested against Claude Code 2.1.280** (checked 2026-09-24). Its newest version-gated
  features, and the release each first appeared in:

  | Feature | Used by | Claude Code |
  |---|---|---|
  | `omitClaudeMd` agent field | `conflict-analyzer` | 2.1.271 |
  | `AGENTS.md` as the project instructions file | `spec`, `team` | 2.1.277 |
  | `experimental.cacheTtl` agent field | all three agents | 2.1.248 |
  | `background` with `context: fork` | `track`, `guide`, `explain`, `doctor` | 2.1.218 |
  | `userConfig` fixed `options` | the three model-tier settings | 2.1.271 |
  | `.worktreeinclude` (project file, optional) | `build` PARALLEL MODE worktrees | 2.1.280 or earlier |
  | `/goal` (recommended, user-typed) | `build` NEXT | 2.1.139 |

  On an older release, update with `claude update`. The Claude Code version each release was
  checked against is recorded here and in the `CHANGELOG.md` entry that raised it.
- **gh CLI** — required for `plan --publish`, the GitHub side of `ship` and `doctor --fix`, and the board
- **git** — required for `build` PARALLEL MODE (uses worktrees)
- **[context7](https://context7.com)** — recommended for `team`, `design`, `plan`, and `build` to fetch up-to-date framework documentation. Either the MCP server or the `ctx7` CLI (`npx -y @upstash/context7 setup`) works.

## Contributing

Issues and pull requests welcome at [github.com/ckandrinirina/ck-code](https://github.com/ckandrinirina/ck-code). If you use the plugin and find a rough edge, please open an issue describing your project type and the command that misfired — concrete examples make the workflow better for everyone.

## License

MIT — see [LICENSE](LICENSE).

## Keywords

Claude Code plugin · spec-driven development · AI coding workflow · TDD with AI · automated architecture documentation · GitHub Issues integration for AI · parallel AI agent builds · Claude agent skills · context7 best practices · AI-assisted software engineering
