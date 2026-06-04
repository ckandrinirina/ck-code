---
name: to-issues
description: Use when the user wants to push a `tasks/` plan into GitHub Issues, at a chosen granularity — one issue for the whole feature, one issue per epic, or one issue per story. Argument is an optional `tasks/<slug>/` path and `--mode feature|epics|stories`. Requires `gh` CLI authenticated.
argument-hint: "[tasks-folder-path] [--mode feature|epics|stories]"
disable-model-invocation: true
allowed-tools: Bash(gh *) Bash(sleep *)
---

# To-Issues — Publish a Plan to GitHub Issues

Reads a generated tasks/ folder and creates GitHub Issues at the granularity the
user picks: a single feature issue, one issue per epic, or the full epic+story
hierarchy.

## PREREQUISITES

- The `gh` CLI must be installed and authenticated (`gh auth status`)
- The current directory must be a git repository with a GitHub remote
- A tasks/ folder must exist with the structure created by `project-architect`

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

Run the shared [version gate](../../references/version-gate.md) before any architecture-doc or `tasks/FEATURE_INDEX.md` read/write; on BLOCK (pre-v3), offer `/ck-code:doc-optimizer upgrade` and stop until it PASSes (or the user declines). `tasks/VERSION.md` = `layout: v3` is the cheap fast path.

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

Create only the labels the chosen mode needs (`--force` updates if they exist):

```bash
# feature mode
gh label create "feature" --color "0E8A16" --description "Whole-feature tracking issue" --force

# epics mode (and stories mode)
gh label create "epic" --color "6F42C1" --description "Epic-level issue" --force

# stories mode only
gh label create "story" --color "0075CA" --description "Implementation story" --force
gh label create "size/S" --color "C2E0C6" --description "Small story" --force
gh label create "size/M" --color "BFDADC" --description "Medium story" --force
gh label create "size/L" --color "FEF2C0" --description "Large story" --force
gh label create "size/XL" --color "F9D0C4" --description "Extra large story" --force
```

---

## PHASE 5: CREATE ISSUES (branch by mode)

### 5A — MODE `feature` (single issue)

Create one issue holding the entire plan. Epics become sections; stories become
a nested task-list under each epic.

```bash
gh issue create \
  --title "Feature: [Project Name]" \
  --label "feature" \
  --body "$(cat <<'BODY'
## Overview
[Summary from PROJECT_OVERVIEW.md]

## Epic 01: [Epic Title]
[Epic goal/description]
- [ ] [01-01] [Story title] (S)
- [ ] [01-02] [Story title] (M)

## Epic 02: [Epic Title]
[Epic goal/description]
- [ ] [02-01] [Story title] (L)

## Acceptance Criteria
[Top-level criteria from PROJECT_OVERVIEW.md]
BODY
)"
```

Capture the single issue number. Done — skip to Phase 6.

### 5B — MODE `epics` (one issue per epic)

For each epic (in order), create one issue. Its stories are an in-body checklist;
no separate story issues are created.

```bash
gh issue create \
  --title "Epic [NN]: [Epic Title]" \
  --label "epic" \
  --body "$(cat <<'BODY'
## Description
[From EPIC.md]

## Goals
[From EPIC.md]

## Stories
- [ ] [EE-01] [Story title] (S)
- [ ] [EE-02] [Story title] (M)

## Acceptance Criteria
[From EPIC.md]
BODY
)"
```

Add `sleep 1` between each issue creation. Capture every epic issue number.
Done — skip to Phase 6.

### 5C — MODE `stories` (full hierarchy)

**Step 1 — epic issues.** For each epic, create an issue with story placeholders:

```bash
gh issue create \
  --title "Epic [NN]: [Epic Title]" \
  --label "epic" \
  --body "$(cat <<'BODY'
## Description
[From EPIC.md]

## Goals
[From EPIC.md]

## Stories
- [ ] #TBD - [Story 01 title]
- [ ] #TBD - [Story 02 title]

## Acceptance Criteria
[From EPIC.md]
BODY
)"
```

Capture each epic issue number → store `epic slug -> issue number`. `sleep 1` between calls.

**Step 2 — story issues.** For each story (epic order, then story order):

```bash
gh issue create \
  --title "[EE-SS] [Story Title]" \
  --label "story" \
  --label "size/M" \
  --body "$(cat <<'BODY'
## Parent Epic
Belongs to #[epic-issue-number] - [Epic Title]

## Description
[From story file]

## Acceptance Criteria
[From story file]

## Technical Notes
[From story file]

## Files to Create/Modify
[Table from story file]

## Dependencies
[From story file]

## Size: [S/M/L/XL]
BODY
)"
```

Capture each story issue number. `sleep 1` between calls.

**Step 3 — link epics to stories.** Edit each epic issue, replacing the `#TBD`
placeholders with the real story issue numbers so GitHub tracks completion:

```bash
gh issue edit [epic-issue-number] \
  --body "[updated body with real issue numbers in the Stories checklist]"
```

Result:

```
## Stories
- [ ] #42 - Set up project scaffolding
- [ ] #43 - Implement WebSocket gateway
```

---

## PHASE 6: SUMMARY

Present results for the mode that ran:

```
## Published to GitHub Issues

**Repository:** [owner/repo]
**Mode:** [feature | epics | stories]

[feature]  #[num] - Feature: [Project Name]

[epics]
- #[num] - Epic 01: [Title]
- #[num] - Epic 02: [Title]

[stories]
### Epic Issues
- #[num] - Epic 01: [Title]
### Story Issues
- #[num] - [01-01] [Title] (S) -> Epic #[num]

### Quick Links
- All issues: [repo URL]/issues
- Features: [repo URL]/issues?q=label:feature
- Epics:    [repo URL]/issues?q=label:epic
- Stories:  [repo URL]/issues?q=label:story

**Total:** [count] issues created
```

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
- **Order matters in `stories` mode** — create all epics first so their issue numbers exist for story cross-references and the linking step.
- **Always pause between API calls** — `sleep 1` between every `gh` call; GitHub rate-limits issue creation strictly.
- **Preserve markdown fidelity** — keep all formatting from the original tasks/ files in issue bodies.
- **Reusable** — works with any tasks/ folder generated by `project-architect`, regardless of project type.

---

## NEXT

Run `/ck-code:track next` to find the first ready story (no blockers), then `/ck-code:build [path]` to implement it.
