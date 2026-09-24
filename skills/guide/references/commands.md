# ck-code — Command Reference

Per-command syntax for `guide --command`. The workflow graph, hand-offs, output
locations, "when to use which", and the misuse-redirect matrix are the single source
of truth in [`../../../references/workflow-map.md`](../../../references/workflow-map.md) —
read that rather than restating it here. This file is the per-command syntax only.

`guide --command <name>` prints only that command's row plus its examples;
`guide --command` (no name) prints the whole table.

## Commands

| Command | Argument | Purpose | Writes |
| --- | --- | --- | --- |
| `guide` | `[task description \| --command [name]]` | Recommend the next step, route a task to a skill, or look up syntax | read-only |
| `spec` | `[feature-description \| notes-file \| existing-slug \| issue-url]` | Draft or adjust a stakeholder-facing spec | `docs/specs/<date>_<slug>/spec.md` (+ issue) |
| `design` | `[path-to-spec \| optimize \| sync \| ds [design-url]]` | Spec → architecture docs (no argument picks up the newest spec marked ready for design); `optimize`/`sync` slim or scaffold feature docs; `ds [url]` links (or refreshes) a design-system cache | `docs/architecture/` |
| `team` | `[--basic\|--standard\|--max] [--check\|--refresh\|--regenerate] [--conventions] [--new expert\|guide <slug>] [--adjust <slug>] [--workflow]` | Architecture → expert + guide skills; `--refresh` regenerates only the skills whose sources changed, `--regenerate` every generated skill; offers house-conventions capture in the same run | `.claude/skills/` |
| `plan` | `[path-to-spec] \| --quick [brief] [--epic NN] \| --publish [--mode plan\|epics\|stories] [tasks/<plan>]` | Architecture → a plan of epics, stories and a roadmap (asks the integration level once); `--quick` adds one small story; `--publish` publishes a plan to GitHub Issues and writes each number back | `tasks/` (+ Issues for `--publish`) |
| `track` | `[status\|next\|progress]` | Progress dashboard / next ready story | read-only |
| `build` | `[story-path] \| [story-ids...] \| --epic NN` | TDD-implement stories end-to-end — one inline, several in worktrees, or a whole epic in waves; also a `bug` story's recorded fix (Bug-Fix Mode) | source, tests, story frontmatter; a branch per story in PARALLEL MODE |
| `fix` | `[path-to-story.md]` | Diagnose a bug, record it to its story (`status: bug`), route the fix | failing test, Fix Plan, story frontmatter |
| `ship` | `[path-to-story.md] \| --promote [--epic NN \| tasks/<plan>]` | Commit and open or update the PR for a story, a fix or any standalone change; `--promote` opens the epic PR or the whole-plan PR | git + GitHub; story `pr:`/`delivery:` |
| `config` | `[show \| board \| trunk <branch> \| integration <tasks/plan> <story\|epic\|plan> \| on \| off]` | Project settings: issue tracking, the Projects board (create, adopt or re-map), the trunk branch every PR targets, and a plan's integration level | `tasks/SETTINGS.md`, `OVERVIEW.md` + board |
| `doctor` | `[tasks/<plan>] [--quiet] [--fix]` | Report what is broken — layout stamp, story frontmatter, dependencies, feature docs, stale team skills, the committed ck-code-required guard; `--fix` reconciles delivery, the board and Issues with GitHub (incl. work merged straight to the trunk) and commits the changed story files | read-only; `--fix` writes `tasks/` frontmatter, board, Issues |
| `migrate` | `[--dry-run]` | Upgrade a v6, older **or ck-code-lite** project to the v7 layout in one revertable commit (runs the internal `ck-migrate` converter; never call it yourself) | `tasks/`, `docs/`, `.claude/skills/`, `VERSION.md` |
| `explain` | `[file-or-concept] \| --epic NN` | Explain what was built and how to verify it, or `--epic NN` for that epic's goal, its plan's integration level and each story's goal | read-only |

The generated views (`STORIES_INDEX.md`, `EPICS_INDEX.md`) are gitignored and regenerate on
every read, so no command commits them.

## Examples

```
/ck-code:guide                                     # next step from project state
/ck-code:guide "fix the login crash"               # → recommends /ck-code:fix
/ck-code:guide --command build                     # syntax for one command
/ck-code:spec docs/notes/feature-draft.md          # create spec from notes
/ck-code:spec intelligent-bot-system               # adjust an existing spec
/ck-code:design docs/specifications.md
/ck-code:design optimize                            # slim bloated architecture docs
/ck-code:team --refresh                             # refresh skills whose sources changed
/ck-code:plan docs/new-feature.md                   # a second plan (Increment Mode)
/ck-code:plan --publish tasks/2026-01-10_billing     # publish a plan to GitHub Issues
/ck-code:plan --quick "add rate-limit header"       # one small story
/ck-code:track next                                 # next ready story
/ck-code:build                                      # interactive story picker
/ck-code:build 02-05 03-01                          # two independent stories, in worktrees
/ck-code:build --epic 02                            # whole epic, in waves
/ck-code:fix                                        # pick from implemented stories
/ck-code:ship                                       # commit + PR + issue updates
/ck-code:ship --promote --epic 02                   # open the epic PR
/ck-code:config integration tasks/2026-01-10_billing epic   # change a plan's level
/ck-code:doctor --fix                               # reconcile bookkeeping with GitHub
```

## Setup sequences

```
# First time
/ck-code:design docs/specifications.md → /ck-code:team → /ck-code:plan docs/specifications.md
→ /ck-code:track next → /ck-code:build → /ck-code:ship

# Adding a feature later
/ck-code:spec "describe the feature" (optional) → /ck-code:design
→ /ck-code:team --refresh → /ck-code:plan → /ck-code:build
# each step hands off to the next with the path it just wrote — no retyping

# Upgrading an older project
/ck-code:migrate    # v6 or older → v7 in one commit, stamps VERSION.md

# Moving up from ck-code-lite
/ck-code:migrate    # tasks/PLAN.md → epics/stories, docs/ARCHITECTURE.md → docs/architecture/
```

## Generated skills

`/ck-code:team` derives the expert and guide set **from your architecture** — there is
no fixed list. Experts are invoked directly (e.g. `/expert-backend`); guides
(`guide-rust`, `guide-axum`, …) auto-load when their technology is in scope. `team` also
owns `guide-conventions`, which captures the project's house rules — it is offered at the
plan prompt of a normal run, so `--conventions` is only needed to (re)capture it on its own.
