# Track — Output Contract (rendered by `ck-view`)

These are **not templates for the model to fill** — `scripts/ck-view.sh` renders every one
of them from the generated `STORIES_INDEX.md` views (regenerating any missing or stale
view first), and `/ck-code:track` (and, for
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
## Project Progress: [plan name — OVERVIEW.md `title:`, else its first `# ` heading, else the folder]

**Plan:** [plan dir, e.g. tasks/2026-01-10_billing]
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
`delivery: direct` (no PR); `merged` marks `delivery: merged`; `PR #<n>` marks
`delivery: pr` (counted as `in review`); `not shipped` is a `DONE` story with no
`delivery:` set yet. A `BUG` row carries its delivery suffix too, but never `not shipped`.
A `TODO (blocked by …)` row names only the unmet blockers, suffixed ` (unknown)` for an id
that matches no story. A plan with no story rows prints only
`No stories in <plan dir> yet. Run /ck-code:plan to generate them.`

## `next`

```
## Next Story to Implement

**Recommended:** [Story ID] — [Title]
**Epic:** [Epic title]
**Size:** [S/M]
**Why this one:** [one of: "First ready story in [Epic title]",
                    "First ready story in [Epic title]; unblocks [N] other stories", or
                    "Open bug in built code — a diagnosed bug outranks new work (Bug-Fix Mode)"]

### Acceptance Criteria Preview
- [Criterion 1]
- [Criterion 2]
[... up to 6 checklist lines pulled verbatim from the story's ## Acceptance Criteria section;
     "- (no Acceptance Criteria section in the story file)" when the section is absent]

### Files to Touch
- [one line per path in the story's `files:` frontmatter list — nothing when empty]

**Implement now?**
Run: /ck-code:build [full path to story file]

### Also Ready ([count] more)
- [Story ID]: [Title] (Size)[ 🐛 when that candidate is a BUG]

NEXT: /ck-code:build [full path to story file]
```

The pick is the lowest `(rank, story id)` among ready stories across every plan (or only
the plan passed as `tasks/<plan>`): every `BUG` outranks every `TODO`, then the story id
orders by epic and story number. `### Also Ready` and the blank line before it are omitted
entirely when no other story is ready. The final `NEXT: /ck-code:build <path>` line is always printed, even when
`Also Ready` is empty — it is the machine-readable handoff `/ck-code:build` (and wave mode)
parses, so it must stay the last line.

When nothing is ready:

```
## No Stories Ready

All remaining TODO stories are blocked by incomplete dependencies.

### Blocking Chain
- [Story X] ([STATUS]) blocks: [Story Y], [Story Z]

Complete the IN PROGRESS stories first, then more will unblock.
```

When no unfinished story holds another back, the chain is the single line
`- No unfinished story blocks another — nothing is scheduled at all.`

## `progress`

One **By Size** row per size present in the index, in first-seen order (`?` for a story
with no size).

```
## Project Progress Report

**Project:** [plan name, as in `status`]
**Plan:** [plan dir, e.g. tasks/2026-01-10_billing]
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
- [N] stories waiting on dependencies            # "1 story" when N is 1
- Biggest blocker: [Story X] — blocks [N] other stories
  # or "- No unfinished story blocks another" when nothing is blocked

### Milestone Tracker (from ROADMAP.md)
| Milestone | Status | Epics |
|-----------|--------|-------|
| [Name] | [X]/[Y] epics done | Epic 01, 02 |
```

`SKIPPED` stories are excluded here too (same rule as `status`). The Milestone Tracker
section is printed only when the plan's `ROADMAP.md` has a `## Milestones` table whose
second column lists epic numbers present in the plan — it is omitted entirely otherwise. A
milestone's epic counts as done when every non-skipped story in it is `DONE`. There is no Velocity section:
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

When every story of the epic is `DONE` or `SKIP`:

```
Epic [NN] — nothing to build: every story is DONE or SKIP.
```

When no story in the epic can start at all:

```
Epic [NN] — un-startable: no story has all its blockers DONE.

  [ID]  [Title]   ← waiting on [blocker ID, …]
```

## Multiple plans

Printed for `status` and `progress` only when more than one plan exists under `tasks/` and
no single plan was requested. Every plan renders the same way, named by its `OVERVIEW.md`
`title:`.

```
## Project Plans Found

1. tasks/YYYY-MM-DD_<plan-slug>/ — [plan name]
2. tasks/YYYY-MM-DD_<other-plan-slug>/ — [plan name]

Showing: ALL plans

[status or progress output for plan 1]

[status or progress output for plan 2]
```

Each plan's full `status` or `progress` output follows the listing in turn, separated by a
single blank line. With no plan at all under `tasks/`, `status` and `progress` print
`No task plans found in tasks/.` then `Run /ck-code:plan to generate epics and stories first.`
