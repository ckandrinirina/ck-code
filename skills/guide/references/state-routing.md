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
| `indexes` | `tasks/EPICS_INDEX.md` **and** at least one `tasks/*/STORIES_INDEX.md` |
| `ds_linked` | `docs/architecture/design-system/` exists |
| `ds_pending` | specs whose `.metadata.json` still reads `"awaiting-link"` (meaningful only when `ds_linked=0`) |

## What it counts

Every `tasks/*/STORIES_INDEX.md` row, `SKIP` excluded, applying
[The Ready rule](../SKILL.md#the-ready-rule) with `blocked_by` resolved across **all**
plans (story ids are unique project-wide):

| Count | Row |
|---|---|
| `ready` | `TODO` and every `Blocked by` id resolves to `DONE` or `SKIP` |
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

Like every `ck-view` mode, `state` first regenerates a missing or stale view. The views are
gitignored projections of frontmatter, so this changes nothing git tracks and
`/ck-code:guide` stays read-only. Row 5 below (`!indexes`) therefore fires only when that
regeneration could not run (`ck-view` prints a `WARN` on stderr).

## The routing table

First matching row wins; `ck-view state` prints exactly one as `RECOMMEND:` + `WHY:`. The
two right-hand columns are the script's output, verbatim (`<N>` is the count, with
`story`/`stories` agreeing).

| State | `RECOMMEND:` | `WHY:` |
|---|---|---|
| `!architecture && !specs` | `/ck-code:spec "<feature description>"` | no spec and no architecture — start with a stakeholder-friendly spec, or skip to /ck-code:design <spec-file> if a written spec already exists |
| `!architecture` | `/ck-code:design <spec-file>` | specs exist but no architecture docs — refine the spec into architecture |
| `!team_skills` | `/ck-code:team` | architecture exists but no project-tailored expert/guide skills |
| `!tasks` | `/ck-code:plan <spec-file>` | architecture and team skills exist but nothing is planned |
| `!indexes` | `/ck-code:track` | tasks/ exists but the generated indexes are missing — track regenerates them |
| `bug > 0` | `/ck-code:track next` | `<N>` open bug(s) — a diagnosed bug outranks new work (Bug-Fix Mode) |
| `ready > 0` | `/ck-code:track next` | `<N>` ready stor(y/ies) to implement |
| `in_progress > 0` | `/ck-code:ship <story-path>` | `<N>` in-progress stor(y/ies) and nothing else ready |
| `unshipped > 0` | `/ck-code:ship <story-path>` | `<N>` finished stor(y/ies) with no PR — nothing is on the trunk until they ship |
| `done > 0` | `/ck-code:track progress` | all work is done (`<in_review>` still awaiting merge) — review the milestones or plan the next increment |
| otherwise | `/ck-code:plan` | tasks/ exists but carries no story rows — re-check tasks/<slug>/ |

Each row implies every row above it did not match, so `ready > 0` already means `bug == 0`,
and so on. What `/ck-code:guide` adds on top (never instead):

- `bug > 0` / `ready > 0` → the follow-up is `/ck-code:build <path>` from `track next`'s
  `NEXT:` line.
- `in_progress > 0` → `/ck-code:build <story-path>` resumes the story instead, when it is not
  finished yet.
- `done > 0` → the next plan starts with `/ck-code:spec` or `/ck-code:plan`.
- Any stale-looking bookkeeping (a merged PR the view still shows as `PR #<n>`) → mention
  `/ck-code:doctor --fix`, which reconciles delivery with GitHub.
