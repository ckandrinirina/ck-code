# To-Issues — Issue Body Templates

Read only the section for the mode selected in Phase 3.

Bracketed values are substituted from the plan map built in Phase 2. `sleep 1` between
every `gh` call.

## Mode `feature` — one issue

Epics become sections; stories become a nested task-list under each epic. Capture the
single issue number, then go to Phase 6.

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
- [ ] [02-01] [Story title] (M)

## Acceptance Criteria
[Top-level criteria from PROJECT_OVERVIEW.md]
BODY
)"
```

## Mode `epics` — one issue per epic

Stories are an in-body checklist; no story issues are created. Capture every epic issue
number, then go to Phase 6.

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

## Mode `stories` — full hierarchy

### Step 1 — epic issues (all epics first)

Story numbers do not exist yet, so use `#TBD` placeholders. Store `epic slug -> issue number`.

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

### Step 2 — story issues (epic order, then story order)

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

## Size: [S/M]
BODY
)"
```

### Step 3 — link epics to stories

Replace each `#TBD` with the real story issue number so GitHub tracks completion.

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

## Phase 6 summary shape

```
## Published to GitHub Issues

**Repository:** [owner/repo]
**Mode:** [feature | epics | stories]

[feature]  #[num] - Feature: [Project Name]

[epics]
- #[num] - Epic 01: [Title]

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
