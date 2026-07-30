# `--to-issues` — Issue Body Templates

Used by PUBLISH MODE (SKILL.md Phases P5–P6). Read only the section for the selected
mode. Bracketed values are substituted from the plan map built in Phase P2. `sleep 1`
between every `gh` call.

**Write-back is the v5 linkage.** After creating an issue, write its number into the
matching frontmatter so SHIP MODE can resolve it by number:

- an **epic** issue → `Edit` the epic's `EPIC.md` frontmatter `issue:` line (add it if
  absent);
- a **story** issue → `Edit` that story file's frontmatter `issue:` line.

Then regenerate the views once (SKILL.md P5): `"${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh" tasks/<slug>`.

## Mode `feature` — one issue

Epics become sections; stories become a nested task-list under each epic. Capture the
single issue number, then go to Phase P6. **No frontmatter write-back** (coarse tracking;
there is no per-story or per-epic issue to link).

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

Stories are an in-body checklist; no story issues are created. For each epic issue,
write its number into that epic's `EPIC.md` frontmatter `issue:`. The story checklist
uses the padded bracketed token `[EE-SS]` so SHIP MODE (Phase 6.3) can flip the exact
item without collisions (`[02-01]` ≠ `[02-10]`).

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

Story issue numbers do not exist yet, so use `#TBD` placeholders. Store
`epic slug -> issue number` and write each number into the epic's `EPIC.md` `issue:`.

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

After each `gh issue create`, write the returned number into that story file's
frontmatter `issue:`.

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

## Files
[From story frontmatter `files:`]

## Dependencies
[From story frontmatter `blocked_by:`]

## Size: [S/M]
BODY
)"
```

### Step 3 — link epics to stories

Replace each `#TBD` with the real story-issue number so GitHub tracks completion.

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

### Step 4 — write back & regenerate

Every epic `issue:` (`EPIC.md`) and every story `issue:` (story file) is now set. Run
the generator once so the views reflect the current frontmatter:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh" tasks/<slug>
```

## Phase P6 summary shape

```
## Published to GitHub Issues

**Repository:** [owner/repo]
**Mode:** [feature | epics | stories]

[feature]  #[num] - Feature: [Project Name]   (no frontmatter write-back)

[epics]
- #[num] - Epic 01: [Title]   → EPIC.md issue: [num]

[stories]
### Epic Issues
- #[num] - Epic 01: [Title]   → EPIC.md issue: [num]
### Story Issues
- #[num] - [01-01] [Title] (S) -> Epic #[num]   → story issue: [num]

### Quick Links
- All issues: [repo URL]/issues
- Features: [repo URL]/issues?q=label:feature
- Epics:    [repo URL]/issues?q=label:epic
- Stories:  [repo URL]/issues?q=label:story

**Total:** [count] issues created; [k] frontmatter `issue:` fields written; views regenerated.
```
