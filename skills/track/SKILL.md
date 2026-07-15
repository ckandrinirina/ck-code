---
name: track
description: Use to view project progress, list ready stories, or pick the next one to implement. Argument is `status` (default), `next`, or `progress`.
argument-hint: "[status|next|progress]"
effort: low
disallowed-tools: Write, Edit, NotebookEdit
---

# Story Tracker — Project Progress Dashboard

Scans all stories in `tasks/` and presents a live view of project progress,
story statuses, and recommendations for what to implement next.

## INPUT

`$ARGUMENTS` determines the command:

| Command             | What It Does                                     |
| ------------------- | ------------------------------------------------ |
| (empty) or `status` | Full status dashboard with all stories           |
| `next`              | Suggest the next story ready for implementation  |
| `progress`          | Epic completion percentages and overall progress |

## PHASE 1: SCAN STORIES (index-driven)

**This phase runs for ALL commands.**

Read `tasks/VERSION.md`. If `layout: v3` → proceed silently. Otherwise run the [version gate](../../references/version-gate.md) in hint-only mode: emit one line — `ℹ pre-v3 doc layout — run /ck-code:doc-optimizer upgrade` — and continue read-only. Never block.

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

For each row in the index, mark it as `ready` if `Status: TODO` AND every ID in `Blocked by` resolves to `Status: DONE` in the same table, **or if `Status: BUG`** (a triaged bug from `/ck-code:fix` is always actionable — `build` implements its recorded fix). Mark as `blocked` otherwise. A `BUG` row is `ready`-with-a-🐛 — surface it distinctly.

### 1.4 Epic Aggregation (lazy)

Group rows by their `Epic` column to compute per-epic completion counts (DONE / total). Only Read the per-epic `EPIC.md` files if the user requested `progress` mode and you need the epic's full title or metadata that's not in the index.

## PHASE 2: RENDER

Read only the template for the invoked command from
[`references/dashboard-templates.md`](references/dashboard-templates.md), then fill it
from the Phase 1 scan. Multiple task plans → render each separately (template included).

### `next` — selection algorithm

Filter to ready stories (Phase 1.3), then order by:

1. **Open bugs first** — `Status: BUG` rows outrank all `TODO` work; a diagnosed bug in shipped code should be fixed before new stories (recommend `/ck-code:build <path>`, which enters Bug-Fix Mode).
2. **Epic order** — lower epic number first (foundation before features)
3. **Story order** — lower story number within the epic
4. **Size** — smaller first (`S` before `M`)
5. **Unblocking potential** — prefer stories that unblock the most others

Present the top story (a 🐛 bug if any is open); list the rest under *Also Ready*.

## RULES

- **Never** write, edit, or create any file — this skill is read-only.
- **Never** cache state — every run re-reads the index.
- **Never** fail on a malformed story row — skip it with a one-line warning.
- **Always** output in English.
