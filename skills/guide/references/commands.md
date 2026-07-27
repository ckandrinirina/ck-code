# ck-code — Command Reference (v4)

Per-command syntax for `guide --command`. The workflow graph, hand-offs, output
locations, "when to use which", and the misuse-redirect matrix are the single source
of truth in [`../../../references/workflow-map.md`](../../../references/workflow-map.md) —
read that rather than restating it here. This file is the per-command syntax only.

`guide --command <name>` prints only that command's row plus its examples;
`guide --command` (no name) prints the whole table.

## Commands

| Command | Argument | Purpose | Writes |
| --- | --- | --- | --- |
| `guide` | `[task description] \| --command [name]` | Recommend the next step, route a task to a skill, or look up syntax | read-only |
| `spec` | `[description \| notes-file \| slug \| issue-url]` | Draft or adjust a stakeholder-facing spec | `docs/specs/` (+ issue) |
| `design` | `<spec-file> \| [optimize\|sync]` | Spec → architecture docs; `optimize`/`sync` slim or refresh existing docs | `docs/architecture/` |
| `team` | `[--basic\|--standard\|--max] [--check\|--regenerate]` | Architecture → expert + guide skills; offers house-conventions capture in the same run | `.claude/skills/` |
| `plan` | `<spec-file> \| --quick [brief] [--epic NN]` | Architecture → epics, stories, roadmap; `--quick` adds one small story | `tasks/` (+ regenerated views) |
| `track` | `[status\|next\|progress]` | Progress dashboard / next ready story (regenerates missing views) | read-only |
| `build` | `[story-path]` | TDD-implement one story end-to-end, or a `bug` story's recorded fix (Bug-Fix Mode) | source, tests, story frontmatter + views |
| `parallel-build` | `[story-ids...] \| --epic NN` | Implement several ready stories (or `bug` fixes) in worktrees | branch per story |
| `fix` | `[story-path]` | Diagnose a bug, record it to its story (`status: bug`), route the fix | failing test, Fix Plan, frontmatter + views |
| `ship` | `[story-path] [--issues]` | Commit, open PR, mirror plan/implementation to GitHub Issues | git + GitHub |
| `migrate` | — | Upgrade a pre-v4 **or ck-code-lite** project to the v4 frontmatter layout, then stamp `tasks/VERSION.md` | `tasks/`, `docs/`, `VERSION.md` |
| `explain` | `[file-or-concept]` | Explain what was built and how to verify it | read-only |

## Examples

```
/ck-code:guide                                     # next step from project state
/ck-code:guide "fix the login crash"               # → recommends /ck-code:fix
/ck-code:guide --command build                     # syntax for one command
/ck-code:spec docs/notes/feature-draft.md          # create spec from notes
/ck-code:spec intelligent-bot-system               # adjust an existing spec
/ck-code:design docs/specifications.md
/ck-code:design optimize                            # slim bloated architecture docs
/ck-code:team --regenerate                          # refresh after architecture changes
/ck-code:plan docs/new-feature.md                   # feature-scoped plan
/ck-code:plan --quick "add rate-limit header"       # one small story
/ck-code:track next                                 # next ready story
/ck-code:build                                      # interactive story picker
/ck-code:parallel-build 02-05 03-01                 # two independent stories
/ck-code:parallel-build --epic 02                   # whole epic, in waves
/ck-code:fix                                        # pick from implemented stories
/ck-code:ship                                       # commit + PR + issue updates
```

## Setup sequences

```
# First time
/ck-code:design docs/specifications.md → /ck-code:team → /ck-code:plan docs/specifications.md
→ /ck-code:track next → /ck-code:build → /ck-code:ship

# Adding a feature later
/ck-code:spec "describe the feature" (optional) → /ck-code:design docs/new-feature.md
→ /ck-code:team --regenerate → /ck-code:plan docs/new-feature.md → /ck-code:build

# Upgrading an older project
/ck-code:migrate    # converts a pre-v4 layout, regenerates indexes, stamps VERSION.md

# Moving up from ck-code-lite
/ck-code:migrate    # tasks/PLAN.md → epics/stories, docs/ARCHITECTURE.md → docs/architecture/
```

## Generated skills

`/ck-code:team` derives the expert and guide set **from your architecture** — there is
no fixed list. Experts are invoked directly (e.g. `/expert-backend`); guides
(`guide-rust`, `guide-axum`, …) auto-load when their technology is in scope. `team` also
owns `guide-conventions`, which captures the project's house rules — it is offered at the
plan prompt of a normal run, so `--conventions` is only needed to (re)capture it on its own.
