# Track — Output Contract (rendered by `ck-view`)

These are **not templates for the model to fill** — `scripts/ck-view.sh` renders every one
of them from `STORIES_INDEX.md` / `FEATURE_INDEX.md`, and `/ck-code:track` relays its
stdout verbatim. This file is the documented shape of that output: read it when a field
needs explaining or when the renderer is being changed, never to render a dashboard by
hand. Bracketed values mark what the script substitutes.

Changing a layout here means changing `scripts/ck-view.sh` in the same commit — the script
is the implementation, this file is its contract.

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
  [x] 01-01: [Title] (S) — DONE · merged
  [x] 01-02: [Title] (M) — DONE · PR #457
  [x] 01-06: [Title] (S) — DONE · not shipped
  [>] 01-03: [Title] (M) — IN PROGRESS
  [ ] 01-04: [Title] (M) — TODO (ready)
  [~] 01-05: [Title] (S) — TODO (blocked by 01-03)
  [🐛] 01-07: [Title] (S) — BUG · merged

[... continue for all epics ...]

### Summary
- DONE · merged: [count] stories          # on [trunk branch]
- DONE · in review: [count] stories       # PR open
- DONE · not shipped: [count] stories     # no PR yet
- IN PROGRESS: [count] stories
- TODO (ready): [count] stories
- TODO (blocked): [count] stories
- BUG: [count] stories

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

Emit one **By Size** row per size actually present in the index (`S` and `M`).

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

Showing status for: ALL plans
```
