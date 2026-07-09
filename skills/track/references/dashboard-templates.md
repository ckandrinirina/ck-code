# Track — Output Templates

One template per command. Read only the one the invoked command needs.

Bracketed values are substituted from the index scan; never print them literally.

## Status icons

- `[x]` DONE · `[>]` IN PROGRESS · `[ ]` TODO (ready) · `[~]` TODO (blocked)

## `status`

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
  [>] 01-03: [Title] (M) — IN PROGRESS
  [ ] 01-04: [Title] (M) — TODO (ready)
  [~] 01-05: [Title] (S) — TODO (blocked by 01-03)

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

## `next`

```
## Next Story to Implement

**Recommended:** [Story ID] — [Title]
**Epic:** [Epic title]
**Size:** [S/M]
**Why this one:** [reason — e.g., "First unblocked story in Epic 01, unblocks 3 other stories"]

### Acceptance Criteria Preview
- [ ] [Criterion 1]
- [ ] [Criterion 2]

### Files to Touch
- [file list from story]

**Implement now?**
Run: /ck-code:build [full path to story file]

### Also Ready ([count] more)
- [Story ID]: [Title] (Size)
```

When nothing is ready:

```
## No Stories Ready

All remaining TODO stories are blocked by incomplete dependencies.

### Blocking Chain
- [Story X] (IN PROGRESS) blocks: [Story Y], [Story Z]

Complete the IN PROGRESS stories first, then more will unblock.
```

## `progress`

Emit one **By Size** row per size actually present in the index (normally `S` and `M`;
legacy plans may still carry `L`/`XL`).

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

### By Epic
| Epic | Title | Done | Total | Progress |
|------|-------|------|-------|----------|
| 01 | [Title] | [X] | [Y] | [========--] 80% |
| 02 | [Title] | [X] | [Y] | [----------] 0% |

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
```

## Multiple task plans

Show each plan separately, prefixed by its folder name; feature plans render as
`[Feature] YYYY-MM-DD_feature-xxx`.

```
## Project Plans Found

1. tasks/YYYY-MM-DD_<your-project>/ (main project — 4 epics, 18 stories)
2. tasks/YYYY-MM-DD_feature-<feature-name>/ (feature — 2 epics, 7 stories)

Showing status for: ALL (use /ck-code:track status tasks/YYYY-MM-DD_<your-project> to filter)
```
