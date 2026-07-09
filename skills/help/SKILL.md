---
name: help
description: Use to look up ck-code command syntax, expected outputs, and the full workflow order. Static reference — to route a plain-language task to a skill use `/ck-code:advise`, for a state-aware next-step recommendation use `/ck-code:start`.
argument-hint: "[command-name]"
effort: low
disallowed-tools: Write, Edit, NotebookEdit
---

# ck-code — Command Reference

Run the [version gate](../../references/version-gate.md) in hint-only mode (never block).

The workflow graph, hand-offs, output locations, "when to use which", and the
misuse-redirect matrix all live in
[`workflow-map.md`](../../references/workflow-map.md) — read it rather than restating it.
This file is the per-command syntax.

If `$ARGUMENTS` names a command, print only that row plus its examples.

## Commands

| Command | Argument | Purpose | Writes |
| --- | --- | --- | --- |
| `start` | — | Inspect project state, recommend the next step | read-only |
| `advise` | `[task description]` | Route a plain-language task to the best-fit skill | read-only |
| `help` | `[command]` | This reference | read-only |
| `pre-spec` | `[description \| notes-file \| slug \| issue-url]` | Draft or adjust a stakeholder-facing spec | `docs/specs/` (+ issue) |
| `design` | `<spec-file>` | Spec → architecture docs | `docs/architecture/` |
| `team` | `[--basic\|--standard\|--max] [--check\|--regenerate]` | Architecture → expert + guide skills | `.claude/skills/` |
| `convention` | `[new expert\|guide <slug>] [adjust <slug>]` | Capture house conventions into `guide-conventions` | `.claude/skills/` |
| `plan` | `<spec-file>` | Architecture → epics, stories, roadmap | `tasks/` |
| `quick-story` | `[brief] [--epic NN]` | Add one small story to an existing plan | story + indexes |
| `to-issues` | `[tasks-path] [--mode feature\|epics\|stories]` | Publish the plan to GitHub Issues | GitHub only |
| `track` | `[status\|next\|progress]` | Progress dashboard / next ready story | read-only |
| `build` | `[story-path]` | TDD-implement one story end-to-end | source, tests, story |
| `parallel-build` | `[story-ids...] \| --epic NN` | Implement several ready stories in worktrees | branches per story |
| `fix` | `[story-path]` | Diagnose + minimally fix a bug, with a regression test | source, tests, story |
| `ship` | `[story-path]` | Commit, open PR, update linked Issues | git + GitHub |
| `sync` | `[tasks/<slug> \| --all]` | Reconcile indexes and epics with story files | indexes |
| `doc-optimizer` | `[upgrade\|migrate\|sync\|optimize]` | Migrate or slim architecture docs | `docs/architecture/` |
| `explain` | `[file-or-concept]` | Explain what was built and how to verify it | read-only |

## Examples

```
/ck-code:advise "fix the login crash"              # → recommends /ck-code:fix
/ck-code:pre-spec docs/notes/feature-draft.md      # create spec from notes
/ck-code:pre-spec intelligent-bot-system           # adjust an existing spec
/ck-code:design docs/specifications.md
/ck-code:team --regenerate                         # refresh after architecture changes
/ck-code:plan docs/new-feature.md                  # feature-scoped plan
/ck-code:track next                                # next ready story
/ck-code:build                                     # interactive story picker
/ck-code:parallel-build 02-05 03-01                # two independent stories
/ck-code:parallel-build --epic 02                  # whole epic, in waves
/ck-code:fix                                       # pick from implemented stories
/ck-code:ship                                      # standalone commit (no story)
```

## Setup sequences

```
# First time
/ck-code:design docs/specifications.md → /ck-code:team → /ck-code:plan docs/specifications.md
→ /ck-code:to-issues (optional) → /ck-code:track next → /ck-code:build

# Adding a feature later
/ck-code:pre-spec "describe the feature" (optional) → /ck-code:design docs/new-feature.md
→ /ck-code:team --regenerate → /ck-code:plan docs/new-feature.md → /ck-code:build
```

## Generated skills

`/ck-code:team` derives the expert and guide set **from your architecture** — there is no
fixed list. Experts are invoked directly (e.g. `/expert-backend`); guides
(`guide-rust`, `guide-axum`, …) auto-load when their technology is in scope.
`/ck-code:convention` owns `guide-conventions`.
