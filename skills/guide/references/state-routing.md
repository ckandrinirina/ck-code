# MODE A state routing — the spec `ck-view state` implements

`scripts/ck-view.sh state` is the only implementation of everything below. This file is
its contract: read it to **explain** a verdict, or when changing the routing — never to
re-derive a recommendation by hand, which is exactly the token cost the script removes.
A change here means a change to `scripts/ck-view.sh` in the same commit.

## What it probes

| Flag | True when |
|---|---|
| `specs` | count of `docs/specs/*/` |
| `architecture` | any `*.md` exists under `docs/architecture/` |
| `team_skills` | count of `.claude/skills/expert-*/` + `.claude/skills/guide-*/` |
| `tasks` | count of `tasks/*/` |
| `indexes` | `tasks/FEATURE_INDEX.md` **and** at least one `tasks/*/STORIES_INDEX.md` |
| `ds_linked` | `docs/architecture/design-system/` exists |
| `ds_pending` | specs whose `.metadata.json` still reads `"awaiting-link"` (meaningful only when `ds_linked=0`) |

## What it counts

Every `tasks/*/STORIES_INDEX.md` row, `SKIP` excluded, applying
[The Ready rule](../SKILL.md#the-ready-rule) with `blocked_by` resolved across **all**
plans (story ids are globally unique in v6):

| Count | Row |
|---|---|
| `ready` | `TODO` and every `Blocked by` id resolves to `DONE` |
| `bug` | `BUG` — always actionable |
| `blocked` | `TODO` with an unmet `Blocked by` |
| `in_progress` | `IN PROGRESS` |
| `done` | `DONE` |

Then the `Delivery` column, which answers a different question — how far finished work
travelled toward the trunk:

| Count | Row |
|---|---|
| `unshipped` | `DONE` with an empty Delivery (`-`): finished, no PR opened |
| `in_review` | Delivery `PR #<n>` |
| `merged` | Delivery `MERGED` or `DIRECT` |

`ck-view state` never runs `ck-index`: `/ck-code:guide` writes nothing, and a missing index
is itself a routing signal (row 5 below).

## The routing table

First matching row wins; `ck-view state` prints exactly one as `RECOMMEND:` + `WHY:`.

| State | Recommend |
|---|---|
| `!architecture && !specs` | **`/ck-code:spec "<feature description>"`** — start with a stakeholder-friendly spec; or skip to `/ck-code:design <spec-file>` if you already have a written spec. |
| `!architecture` | **`/ck-code:design <spec-file>`** — refine the spec into architecture docs. |
| `architecture && !team_skills` | **`/ck-code:team`** — generate project-tailored expert + guide skills. |
| `architecture && team_skills && !tasks` | **`/ck-code:plan <spec-file>`** — break the architecture into epics, stories, and a roadmap. |
| `tasks && !indexes` | **`/ck-code:track`** — regenerates the missing generated views, then re-run `/ck-code:guide`. |
| `bug > 0` | **`/ck-code:track next`** → **`/ck-code:build <path>`** — an open bug outranks new work (Bug-Fix Mode). |
| `ready > 0` | **`/ck-code:track next`** → **`/ck-code:build [path]`** — implement the next ready story. |
| `in_progress > 0 && ready == 0` | **`/ck-code:ship <story-path>`** — ship the in-progress story, or **`/ck-code:build`** to keep going. |
| `unshipped > 0 && ready == 0 && in_progress == 0 && bug == 0` | **`/ck-code:ship <story-path>`** — finished stor(ies) have no PR yet; nothing is on the trunk until they do. |
| `done > 0 && ready == 0 && in_progress == 0 && bug == 0` | **`/ck-code:track progress`** — review the milestone tracker, or plan the next feature with **`/ck-code:plan`** / **`/ck-code:spec`**. Note `in_review` stor(ies) still awaiting merge, if any. |
| `tasks && all counts == 0` | **`/ck-code:plan`** appears not to have produced stories — re-check `tasks/<slug>/`. |
