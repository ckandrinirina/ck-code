---
name: advise
description: Use when the user describes a task in plain language but doesn't know which ck-code skill to run — recommends the best-fit skill (and the workflow step before/after it) from a free-text description. Read-only entry point; recommends, never launches. Argument is a description of what the user wants to do.
argument-hint: "[describe what you want to do]"
effort: low
disallowed-tools: Write, Edit, NotebookEdit
---

# Advise — Intent-Driven Skill Router (Read-Only)

The plain-language entry point for users who don't know which ck-code skill to
run. The user describes a task in their own words; this skill maps that intent
to the best-fit skill, names the prerequisite step if one is missing, and prints
the exact command to run. **It never invokes another skill, writes files, or
edits state** — it recommends and stops.

Difference from its siblings:

- **`advise`** (this skill) — routes from a *free-text task description* ("I want
  to fix the login crash" → `/ck-code:fix`).
- **`start`** — routes from *project state* ("what's the next step given where the
  project is?"). Use when there's no specific task in mind.
- **`help`** — *static* command reference and syntax lookup.

The full workflow graph and the "am I the right skill?" misuse matrix live in
[`../../references/workflow-map.md`](../../references/workflow-map.md) — the single
source of truth this skill routes against.

---

## INPUT

`$ARGUMENTS` is a free-text description of what the user wants to do.

- **Provided:** classify it (Phase 1) and recommend (Phase 3).
- **Empty:** ask exactly one question — *"In one or two sentences, what do you
  want to do?"* — then continue. Do not interrogate further.

---

## PHASE 1: CLASSIFY THE INTENT

Match the description to one intent row. Pick the **single best** fit; if two are
plausible, the higher row wins and the other becomes the "Alternative" in the output.

| The user is describing… | Recommend |
|---|---|
| Aligning stakeholders, a non-technical spec, "what should this feature do" | `/ck-code:pre-spec` |
| Architecture, tech choices, "how should this be built", data/flow design | `/ck-code:design` |
| Tailoring expert/guide skills to the project's stack | `/ck-code:team` |
| Capturing the project's own coding conventions / house rules | `/ck-code:convention` |
| Breaking work into epics, stories, a roadmap; "plan the project/feature" | `/ck-code:plan` |
| Adding one small story or a quick tweak to an existing plan | `/ck-code:quick-story` |
| Publishing the plan to GitHub Issues for tracking | `/ck-code:to-issues` |
| Project status, progress, "which story is next" | `/ck-code:track` |
| Implementing a story / building a feature that already has a story | `/ck-code:build` |
| Building several independent ready stories at once | `/ck-code:parallel-build` |
| A bug, crash, regression, "something is broken" in shipped code | `/ck-code:fix` |
| Committing, opening a PR, "ship it", delivering finished work | `/ck-code:ship` |
| Index/epics drifted out of sync with story files | `/ck-code:sync` |
| Explaining what was just built or how to verify it | `/ck-code:explain` |
| Architecture docs are bloated, or a doc-layout migration is needed | `/ck-code:doc-optimizer` |
| "I don't have a task — just tell me what's next" | `/ck-code:start` |

If nothing matches, say so plainly and recommend `/ck-code:start` (state-aware) or
`/ck-code:help` (full command list). Never invent a skill that isn't in this table.

---

## PHASE 2: PREREQUISITE CHECK (only when the match is build/fix/ship/plan/team)

A recommendation is wrong if its prerequisite is missing. For implementation-stage
intents, run these read-only probes **in parallel** and adjust the recommendation:

!`echo "== architecture =="; ls docs/architecture/*.md 2>/dev/null | head -1; echo "== tasks =="; ls -d tasks/*/ 2>/dev/null | head -1; echo "== stories index =="; ls tasks/*/STORIES_INDEX.md 2>/dev/null | head -1`

Apply the first matching rule:

| Intent | If… | Recommend instead (prerequisite first) |
|---|---|---|
| `build` / `quick-story` | no `tasks/` plan exists | `/ck-code:plan` (then build) |
| `plan` | no `docs/architecture/` exists | `/ck-code:design` (then plan) |
| `team` | no `docs/architecture/` exists | `/ck-code:design` (then team) |
| `ship` | no implemented work on the branch | `/ck-code:build` or `/ck-code:fix` (then ship) |
| `fix` | the "bug" is actually new functionality | `/ck-code:build` (add a story via `/ck-code:quick-story`) |

Skip this phase entirely for read-only intents (`track`, `explain`, `help`, `start`).

---

## PHASE 3: RECOMMEND

Print exactly this block and stop:

```
## ck-code: what to run

You want to: <one-line restatement of the user's task>

→ **`<recommended command>`**
  <one-sentence why this skill fits>

Prerequisite: <command + why, or "none — you're ready">
Next step:    <the skill that typically follows, per workflow-map>
Alternative:  <second-best command + when it would be the right call, or omit if unambiguous>
```

Keep it to that block — no extra prose. The user runs the command themselves.

---

## RULES

- **Never** invoke another skill via the `Skill` tool — this skill is read-only and
  recommends only.
- **Never** write or edit any file. Use Bash for read-only probes only.
- **Always** route against [`../../references/workflow-map.md`](../../references/workflow-map.md)
  — never recommend a command not in the Phase 1 table.
- **Always** name the prerequisite when the recommended skill has an unmet one
  (Phase 2) — a recommendation whose prerequisite is missing is a wrong answer.
- **Always** print exactly the Phase 3 block; ask at most one clarifying question
  (only when `$ARGUMENTS` is empty).
