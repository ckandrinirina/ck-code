---
name: to-issues
description: Use when the user wants to push a `tasks/` plan into GitHub Issues, at a chosen granularity — one issue for the whole feature, one issue per epic, or one issue per story. Argument is an optional `tasks/<slug>/` path and `--mode feature|epics|stories`. Requires `gh` CLI authenticated.
argument-hint: "[tasks-folder-path] [--mode feature|epics|stories]"
disable-model-invocation: true
effort: low
allowed-tools: Bash(gh *) Bash(sleep *)
---

# To-Issues — Publish a Plan to GitHub Issues

Reads a generated tasks/ folder and creates GitHub Issues at the granularity the
user picks: a single feature issue, one issue per epic, or the full epic+story
hierarchy.

## ROUTING CHECK (do first)

This skill mirrors the **plan** into GitHub Issues — it is *not* an alternative to `ship`.
If the request is actually something else, STOP and recommend the better skill:

- Committing / PR-ing implemented code → `/ck-code:ship` (run both; they're sequential)
- No `tasks/` plan exists yet → `/ck-code:plan` (first)

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:track next`.

## PREREQUISITES

- The `gh` CLI must be installed and authenticated (`gh auth status`)
- The current directory must be a git repository with a GitHub remote
- A `tasks/` folder must exist, created by `/ck-code:plan`

---

## INPUT

`$ARGUMENTS` may contain a tasks folder path and/or a `--mode` flag, in any order:
`tasks/YYYY-MM-DD_<your-project> --mode epics`

**Parse the path:**

1. If a `tasks/<slug>/` path is present, use it
2. Else use Glob to find folders matching `tasks/*/PROJECT_OVERVIEW.md`
   - Exactly one → use it (confirm with user)
   - Multiple → list them and ask the user to choose
   - None → tell the user to run `/ck-code:plan` first

**Parse the mode** (`--mode feature|epics|stories`):

- If the flag is present and valid, use it (skip the mode prompt in Phase 3)
- If absent or invalid, ask interactively in Phase 3

---

## GRANULARITY MODES

| Mode      | Issues created                                 | Use when                                                                                                    |
| --------- | ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `feature` | **1** issue for the whole feature              | You want a single tracking issue; epics and stories live inside it as nested checklists                     |
| `epics`   | **1 per epic** (N issues)                      | You track at epic level; stories are listed inside each epic issue as a checklist, no separate story issues |
| `stories` | epic issues **+** 1 per story (full hierarchy) | You implement story-by-story and want linked, individually-trackable story issues                           |

---

## PHASE 0: VERSION GATE (hard gate)

Read `tasks/VERSION.md`. If `layout: v3` → PASS, proceed. Otherwise run the shared [version gate](../../references/version-gate.md) (HARD GATE) — it detects, offers `/ck-code:doc-optimizer upgrade`, and stamps.

---

## PHASE 1: VALIDATE ENVIRONMENT

```bash
gh auth status
gh repo view --json nameWithOwner -q .nameWithOwner
```

If either fails, stop and tell the user what to fix.

---

## PHASE 2: READ PLAN STRUCTURE

1. Read `PROJECT_OVERVIEW.md` to extract the project name and summary
2. Use Glob to find all `epics/*/EPIC.md` files
3. For each epic, use Glob to find all `stories/*.md` files
4. Read each EPIC.md and story file to extract titles, descriptions,
   acceptance criteria, sizes, dependencies, and epic-to-story relationships

Build an in-memory map of the full plan structure.

---

## PHASE 3: SELECT MODE & CONFIRM

**Determine the mode.** If `--mode` was passed in INPUT, use it. Otherwise ask:

```
How do you want to publish this plan?
- feature  → 1 issue for the whole feature (epics + stories as nested checklists)
- epics    → 1 issue per epic ([N] issues; stories as a checklist inside each)
- stories  → epic issues + 1 issue per story ([N] epics + [M] stories)
```

**Then present a mode-specific summary before creating anything:**

```
## GitHub Issues to Create

**Repository:** [owner/repo]
**Project:** [name from PROJECT_OVERVIEW.md]
**Mode:** [feature | epics | stories]

### Labels to Create
[mode-dependent — see Phase 4]

### Issues to Create
[feature]  1 feature issue
[epics]    [N] epic issues
[stories]  [N] epic issues + [M] story issues = [total]

Proceed? YES / NO / DRY-RUN
```

- **YES** — create issues per the chosen mode
- **NO** — abort
- **DRY-RUN** — print exactly what would be created without creating anything

---

## PHASE 4: CREATE LABELS

Create only the labels the chosen mode needs (`--force` updates if they exist). In
`stories` mode add one `size/<S>` label per size actually present in the plan.

```bash
gh label create "feature" --color "0E8A16" --description "Whole-feature tracking issue" --force
gh label create "epic" --color "6F42C1" --description "Epic-level issue" --force
gh label create "story" --color "0075CA" --description "Implementation story" --force
gh label create "size/S" --color "C2E0C6" --description "Small story" --force
gh label create "size/M" --color "BFDADC" --description "Medium story" --force
```

---

## PHASE 5: CREATE ISSUES

Read the section for the chosen mode from
[`references/issue-bodies.md`](references/issue-bodies.md) and follow it. `feature` and
`epics` finish in one step; `stories` runs epics → stories → link.

---

## PHASE 6: SUMMARY

Fill the summary shape from [`references/issue-bodies.md`](references/issue-bodies.md)
for the mode that ran.

---

## ERROR HANDLING

- If `gh issue create` fails for a single issue, report the error and continue with the rest. List all failed issues at the end.
- Add `sleep 1` between every GitHub API call to avoid rate limiting.
- If a label already exists with different settings, `--force` updates it.

## DUPLICATE DETECTION

Before creating issues, check for existing ones matching the mode's labels:

```bash
gh issue list --label "feature" --state all --json title,number
gh issue list --label "epic" --state all --json title,number
gh issue list --label "story" --state all --json title,number
```

If duplicates are found, warn the user and ask: **SKIP** duplicates / **PROCEED**
anyway / **ABORT**.

## RULES

- **Never create issues outside the chosen mode** — `feature` makes exactly 1 issue, `epics` makes no story issues, only `stories` builds the full hierarchy.
- **Never create a story issue before every epic issue exists** — story bodies cross-reference epic numbers.
- **Always `sleep 1` between every `gh` call** — GitHub rate-limits issue creation strictly.
- **Always preserve markdown fidelity** from the original `tasks/` files in issue bodies.

---

## NEXT

Run `/ck-code:track next` to find the first ready story (no blockers), then `/ck-code:build [path]` to implement it.
