---
name: start
description: Use when starting work on a ck-code project and unsure which step to run next. Inspects project state and recommends the next workflow step. Read-only — recommends, never launches.
argument-hint: ""
effort: low
disallowed-tools: Write, Edit, NotebookEdit
---

# Start — ck-code Workflow Orchestrator (Read-Only)

Inspects the current project state and recommends the next skill in the
ck-code workflow. **This skill never invokes another skill, writes files,
or edits state.** It always prints the recommendation and stops; the user
runs the recommended command themselves.

For the full workflow graph and output locations, see
[`../../references/workflow-map.md`](../../references/workflow-map.md).

---

## INPUT

`$ARGUMENTS` is ignored. Run with no arguments.

---

## PHASE 1: INSPECT PROJECT STATE

The read-only project-state probes are **pre-loaded** at skill start via dynamic
context injection — read the snapshot below and do **not** re-run these `ls`/`find`/`gh`
calls as separate tool calls (saves ~5 round-trips per invocation):

!`echo "== specs =="; ls -d docs/specs/*/ 2>/dev/null | head -5; echo "== architecture =="; ls docs/architecture/*.md 2>/dev/null | head -3; echo "== generated skills =="; find .claude/skills -type f -name SKILL.md 2>/dev/null | grep -E "(experts|guides)/" | head -3; echo "== tasks =="; ls -d tasks/*/ 2>/dev/null | head -3; echo "== stories index =="; ls tasks/*/STORIES_INDEX.md 2>/dev/null | head -3; echo "== open story issues =="; gh issue list --label story --state open --json number 2>/dev/null | head -1`

From the pre-loaded snapshot above, record:

- `has_pre_specs` — any line under `== specs ==`
- `has_architecture` — any `.md` line under `== architecture ==`
- `has_team_skills` — any `experts/` or `guides/` SKILL.md line under `== generated skills ==`
- `has_tasks_folder` — any line under `== tasks ==`
- `has_stories_index` — any `STORIES_INDEX.md` line under `== stories index ==`
- `has_published_issues` — the `== open story issues ==` block is non-empty (treat a
  missing/unauthenticated `gh` — i.e. an empty block — as `false`; never block on it)

If the snapshot is empty (no injection support on this host), fall back to running the
same probes as parallel read-only Bash calls.

### 1.5 Story status snapshot (if index exists)

If `STORIES_INDEX.md` exists, Read it and count rows by `Status` column:

- `n_todo` (TODO and not blocked)
- `n_blocked` (TODO with unmet `Blocked by`)
- `n_in_progress` (IN PROGRESS)
- `n_done` (DONE)

Use the same dependency-resolution rule as `track`: a TODO is "ready" iff
every ID in its `Blocked by` cell resolves to `Status: DONE` in the
table. If the index header is not `<!-- Schema: v1 -->`, treat it as
absent (the bootstrap is `track`'s job, not `start`'s).

---

## PHASE 2: RECOMMEND

Apply this decision table top-to-bottom; the **first** matching row is
the recommendation. Print only the matching row's recommendation and
stop.

| State | Recommend |
|---|---|
| `!has_architecture && !has_pre_specs` | **`/ck-code:pre-spec "<feature description>"`** — start with a stakeholder-friendly spec; or skip directly to `/ck-code:design <spec.md>` if you already have a written spec. |
| `!has_architecture` | **`/ck-code:design <spec-file>`** — refine the spec into architecture docs. |
| `has_architecture && !has_team_skills` | **`/ck-code:team`** — generate project-tailored expert + guide skills from the architecture. |
| `has_architecture && has_team_skills && !has_tasks_folder` | **`/ck-code:plan <spec-file>`** — break the architecture into epics, stories, and a roadmap. |
| `has_tasks_folder && !has_stories_index` | **`/ck-code:track`** — bootstrap `STORIES_INDEX.md` from existing story files (track auto-bootstraps, then re-run `/ck-code:start`). |
| `has_tasks_folder && !has_published_issues` *(optional)* | **`/ck-code:to-issues`** — mirror epics/stories to GitHub Issues, **or** skip this and go straight to the next row. |
| `n_todo > 0` | **`/ck-code:track next`** — find the next ready story, then **`/ck-code:build [path]`**. |
| `n_in_progress > 0 && n_todo == 0` | **`/ck-code:ship <story-path>`** — ship the in-progress story (commit + PR + issue updates), or **`/ck-code:build`** to keep going on it. |
| `n_done > 0 && n_todo == 0 && n_in_progress == 0` | **`/ck-code:track progress`** — review the milestone tracker, **or** plan the next feature with **`/ck-code:plan`** / **`/ck-code:pre-spec`**. |
| `has_tasks_folder && n_todo == 0 && n_in_progress == 0 && n_done == 0` | **`/ck-code:plan`** appears not to have produced stories yet — re-check `tasks/<slug>/`. |

### Output format

```
## ck-code: project state

| Check | Value |
|---|---|
| docs/specs/        | <has or — > |
| docs/architecture/ | <has or — > |
| .claude/skills/    | <count of experts/guides or — > |
| tasks/             | <has or — > |
| STORIES_INDEX.md   | <has or — > |
| Stories            | <n_todo TODO ready · n_blocked blocked · n_in_progress IP · n_done done> |
| GitHub story issues| <count open or — > |

## Recommended next step

**`<command>`** — <one-sentence why>

Why this fits: <1–2 sentence reasoning tied to the state above>

(For the full workflow graph: `references/workflow-map.md`.)
```

---

## RULES

- **Never** invoke another skill via the `Skill` tool. This skill is
  read-only and recommends only.
- **Never** write or edit any file. Use Bash for reads only.
- **Never** bootstrap `STORIES_INDEX.md` here — the `track` skill owns
  that. If the index is missing, recommend `/ck-code:track`.
- **Always** print the inspection table even when the recommendation is
  obvious — the table is the user's evidence the recommendation is
  correct.
- **Always** apply the decision table top-to-bottom; never combine rows.
