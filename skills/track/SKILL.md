---
name: track
description: Use to view project progress, list ready stories, or pick the next one to implement. Argument is `status` (default), `next`, or `progress`.
argument-hint: "[status|next|progress]"
---

# Story Tracker — Project Progress Dashboard

Scans all stories in `tasks/` and presents a live view of project progress,
story statuses, and recommendations for what to implement next.

---

## INPUT

`$ARGUMENTS` determines the command:

| Command | What It Does |
|---------|-------------|
| (empty) or `status` | Full status dashboard with all stories |
| `next` | Suggest the next story ready for implementation |
| `progress` | Epic completion percentages and overall progress |

---

## PHASE 1: SCAN STORIES (index-driven)

**This phase runs for ALL commands.**

### 1.1 Find All Task Plans

Use Glob to find all task plan folders: `tasks/*/PROJECT_OVERVIEW.md` and `tasks/*/FEATURE_OVERVIEW.md`.

If no task plans found:
```
No task plans found in tasks/.
Run /ck-code:plan to generate epics and stories first.
```
→ STOP

### 1.2 Read the Index per Plan

For each plan folder, Read `tasks/<slug>/STORIES_INDEX.md`. The table has every column you need: `Epic`, `ID`, `Title`, `Status`, `Size`, `Blocked by`, `File`.

**Bootstrap check:** if the index is missing or its header is not `<!-- Schema: v1 -->`, follow the bootstrap procedure in [`../../references/stories-index.md`](../../references/stories-index.md), then re-read.

Do NOT glob `tasks/*/epics/*/stories/*.md`. The index is the source of truth for status / size / dependencies. Read individual story files only if `progress` mode needs the Implementation Summary block for velocity calculation (Phase 6 below).

### 1.3 Build Dependency Graph

For each row in the index, mark it as `ready` if `Status: TODO` AND every ID in `Blocked by` resolves to `Status: DONE` in the same table. Mark as `blocked` otherwise.

### 1.4 Epic Aggregation (lazy)

Group rows by their `Epic` column to compute per-epic completion counts (DONE / total). Only Read the per-epic `EPIC.md` files if the user requested `progress` mode and you need the epic's full title or metadata that's not in the index.

---

## COMMAND: status (default)

Present the full dashboard:

```
## Project Progress: [project name from PROJECT_OVERVIEW.md]

**Plan:** [tasks folder name]
**Total:** [X] epics, [Y] stories
**Progress:** [done]/[total] stories ([percentage]%)

[============================-----------] 72%

### Epic 01: [Title] ([done]/[total])
[==========----------] 50%
  [x] 01-01: [Title] (S) — DONE
  [x] 01-02: [Title] (M) — DONE
  [>] 01-03: [Title] (L) — IN PROGRESS
  [ ] 01-04: [Title] (M) — TODO (ready)
  [~] 01-05: [Title] (S) — TODO (blocked by 01-03)

### Epic 02: [Title] ([done]/[total])
[--------------------] 0%
  [~] 02-01: [Title] (L) — TODO (blocked by 01-02)
  [ ] 02-02: [Title] (M) — TODO (ready — 01-02 is done)
  ...

[... continue for all epics ...]

### Summary
- DONE: [count] stories
- IN PROGRESS: [count] stories
- TODO (ready): [count] stories
- TODO (blocked): [count] stories

### Quick Actions
- Next story: /ck-code:build [path to next recommended story]
- Full progress: /ck-code:track progress
```

**Status icons:**
- `[x]` = DONE
- `[>]` = IN PROGRESS
- `[ ]` = TODO (ready — all dependencies met)
- `[~]` = TODO (blocked — waiting on other stories)

---

## COMMAND: next

Find and suggest the next best story to implement.

### Selection Algorithm

1. Filter to `Status: TODO` stories only
2. Remove blocked stories (dependencies not DONE)
3. From remaining, prioritize by:
   a. **Epic order** — lower epic number first (foundation before features)
   b. **Story order** — lower story number within epic first
   c. **Size** — smaller stories first for quick wins (S > M > L > XL)
   d. **Unblocking potential** — prefer stories that unblock the most other stories

### Present Recommendation

```
## Next Story to Implement

**Recommended:** [Story ID] — [Title]
**Epic:** [Epic title]
**Size:** [S/M/L/XL]
**Why this one:** [reason — e.g., "First unblocked story in Epic 01, unblocks 3 other stories"]

### Acceptance Criteria Preview
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

### Files to Touch
- [file list from story]

**Implement now?**
Run: /ck-code:build [full path to story file]

### Also Ready ([count] more)
- [Story ID]: [Title] (Size)
- [Story ID]: [Title] (Size)
- ...
```

If no stories are ready:
```
## No Stories Ready

All remaining TODO stories are blocked by incomplete dependencies.

### Blocking Chain
- [Story X] (IN PROGRESS) blocks: [Story Y], [Story Z]
- [Story A] (TODO) blocks: [Story B], [Story C]

Complete the IN PROGRESS stories first, then more will unblock.
```

---

## COMMAND: progress

Show high-level epic completion with metrics.

```
## Project Progress Report

**Project:** [name]
**Generated:** [date of plan]
**As of:** [today]

### Overall
[================================--------] 80%
[done]/[total] stories complete

### By Size
| Size | Done | Total | Remaining |
|------|------|-------|-----------|
| S | [X] | [Y] | [Z] |
| M | [X] | [Y] | [Z] |
| L | [X] | [Y] | [Z] |
| XL | [X] | [Y] | [Z] |

### By Epic
| Epic | Title | Done | Total | Progress |
|------|-------|------|-------|----------|
| 01 | [Title] | [X] | [Y] | [========--] 80% |
| 02 | [Title] | [X] | [Y] | [====------] 40% |
| 03 | [Title] | [X] | [Y] | [----------] 0% |

### Velocity (if enough data)
- Stories completed: [count]
- Average per day: [estimate based on DONE dates in Implementation Summary]

### Bottlenecks
- [Blocked story count] stories waiting on dependencies
- Biggest blocker: [Story X] — blocks [N] other stories

### Milestone Tracker (from ROADMAP.md)
| Milestone | Status | Epics |
|-----------|--------|-------|
| [Name] | [X]/[Y] epics done | Epic 01, 02 |
| [Name] | [X]/[Y] epics done | Epic 03 |
```

---

## MULTIPLE TASK PLANS

If multiple task plan folders exist in `tasks/` (e.g., full project + feature plans):
- Show each plan separately
- Prefix with the plan folder name
- Feature plans show as: `[Feature] YYYY-MM-DD_feature-xxx`

```
## Project Plans Found

1. tasks/YYYY-MM-DD_<your-project>/ (main project — 4 epics, 18 stories)
2. tasks/YYYY-MM-DD_feature-<feature-name>/ (feature — 2 epics, 7 stories)

Showing status for: ALL (use /ck-code:track status tasks/YYYY-MM-DD_<your-project> to filter)
```

---

## IMPORTANT GUIDELINES

- **Read-only:** This skill only reads story/epic files. It never modifies them.
- **Live data:** Always read files fresh. Never cache or assume state.
- **Graceful handling:** If a story file is malformed, skip it with a warning rather than failing.
- **Reusable:** Works with any project using the `tasks/` folder structure from `project-architect`.
- **Language:** All output in English.
