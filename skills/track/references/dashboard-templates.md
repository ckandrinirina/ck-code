# Track — Output Contract (rendered by `ck-view`)

These are **not templates for the model to fill** — `scripts/ck-view.sh` renders every one
of them from `STORIES_INDEX.md` / `FEATURE_INDEX.md`, and `/ck-code:track` (and, for
`waves`, `/ck-code:build`) relays its stdout verbatim. This file is the documented shape of
that output: read it when a field needs explaining or when the renderer is being changed,
never to render a dashboard by hand. Bracketed values mark what the script substitutes.

Changing a layout here means changing `scripts/ck-view.sh` in the same commit — the script
is the implementation, this file is its contract.

## Status icons

- `[x]` DONE · `[>]` IN PROGRESS · `[ ]` TODO (ready) · `[~]` TODO (blocked) ·
  `[-]` SKIPPED · `[🐛]` BUG

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
  [x] 01-06: [Title] (S) — DONE · merged (direct)
  [x] 01-08: [Title] (S) — DONE · not shipped
  [>] 01-03: [Title] (M) — IN PROGRESS
  [ ] 01-04: [Title] (M) — TODO (ready)
  [~] 01-05: [Title] (S) — TODO (blocked by 01-03)
  [-] 01-09: [Title] (S) — SKIPPED
  [🐛] 01-07: [Title] (S) — BUG · merged

[... continue for all epics ...]

### Summary
- DONE · merged: [count] stories          # on trunk, delivery: merged or direct
- DONE · in review: [count] stories       # delivery: pr, PR open
- DONE · not shipped: [count] stories     # done, no delivery yet
- IN PROGRESS: [count] stories
- TODO (ready): [count] stories
- TODO (blocked): [count] stories
- BUG: [count] stories
- SKIPPED: [count] stories (excluded from totals)   # only printed when > 0

### Quick Actions
- Next story: /ck-code:track next
- Full progress: /ck-code:track progress
```

`SKIPPED` stories are excluded from every count above (`Total`, `Progress`, the epic
`(done/total)` pairs) — they are listed in their epic with the `[-]` icon but never counted
as done or outstanding work. `merged (direct)` marks a story that reached the trunk with
`delivery: direct` (no PR); `merged` marks `delivery: merged`; `not shipped` is a `DONE`
story with no `delivery:` set yet.

## `next`

```
## Next Story to Implement

**Recommended:** [Story ID] — [Title]
**Epic:** [Epic title]
**Size:** [S/M]
**Why this one:** [reason — e.g., "First ready story in 01; unblocks 3 other stories", or
                    "Open bug in built code — a diagnosed bug outranks new work (Bug-Fix Mode)"]

### Acceptance Criteria Preview
- [Criterion 1]
- [Criterion 2]
[... up to 6 checklist lines pulled verbatim from the story's ## Acceptance Criteria section;
     "- (no Acceptance Criteria section in the story file)" when the section is absent]

### Files to Touch
- [one line per path in the story's `files:` frontmatter list]

**Implement now?**
Run: /ck-code:build [full path to story file]

### Also Ready ([count] more)
- [Story ID]: [Title] (Size)[ 🐛 when that candidate is a BUG]

NEXT: /ck-code:build [full path to story file]
```

`### Also Ready` and the trailing blank line before it are omitted entirely when no other
story is ready. The final `NEXT: /ck-code:build <path>` line is always printed, even when
`Also Ready` is empty — it is the machine-readable handoff `/ck-code:build` (and wave mode)
parses, so it must stay the last line.

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
**Plan:** [tasks folder name]
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

### Bottlenecks
- [Blocked story count] stories waiting on dependencies
- Biggest blocker: [Story X] — blocks [N] other stories
  # or "- No unfinished story blocks another" when nothing is blocked

### Milestone Tracker (from ROADMAP.md)
| Milestone | Status | Epics |
|-----------|--------|-------|
| [Name] | [X]/[Y] epics done | Epic 01, 02 |
```

`SKIPPED` stories are excluded here too (same rule as `status`). The Milestone Tracker
section is printed only when the plan's `ROADMAP.md` has a `## Milestones` table listing
epic numbers per row — it is omitted entirely otherwise. There is no Velocity section:
`ck-view.sh` computes no completion-rate estimate.

## `waves`

`ck-view waves --epic NN` (relayed verbatim by `/ck-code:build` wave mode — see
`skills/build/references/wave-mode.md`):

```
Epic [NN] — Wave plan ([N] stories, depth [D]):

  Wave 1  (parallel)  [ID]   [Title]                  [Size]
                       [ID]   [Title]                  [Size]   ← needs [blocker ID]
  Wave 2  (solo)       [ID]   [Title]                  [Size]   🐛 Bug-Fix Mode

UNSCHEDULABLE (excluded — blocker never resolves):
  [ID]  [Title]   ← waiting on [blocker ID, …]

Note: [N] waves means [N] sequential merge+dispatch cycles — heavy token use. Consider re-scoping.

PLAN: tasks/<slug>
```

`(parallel)` labels a wave with 2+ stories, `(solo)` a wave with exactly one — that shape is
what dispatch (parallel-mode.md P4) acts on. The `← needs …` suffix appears only on a row
still waiting on an unmet blocker scheduled in the same or a later wave (never on a row
whose blockers are already `done`); `🐛 Bug-Fix Mode` appears only on `BUG` rows. The
`UNSCHEDULABLE` block and the `Note:` line each appear only when they apply (an unschedulable
story, or more than 3 waves). The final `PLAN: <plan dir>` line is always printed — it is the
machine-readable trailer, always the last line, mirroring `next`'s `NEXT:` trailer.

When no story in the epic can start at all:

```
Epic [NN] — un-startable: no story has all its blockers DONE.

  [ID]  [Title]   ← waiting on [blocker ID, …]
```

## Multiple task plans

Printed only when more than one plan exists under `tasks/` and no single plan was
requested; feature plans render as `[Feature] YYYY-MM-DD_feature-xxx`.

```
## Project Plans Found

1. tasks/YYYY-MM-DD_<your-project>/ — [project name]
2. tasks/YYYY-MM-DD_feature-<feature-name>/ — [feature name]

Showing: ALL plans

[status or progress output for plan 1]

[status or progress output for plan 2]
```

Each plan's full `status` or `progress` output follows the listing in turn, separated by a
single blank line.
