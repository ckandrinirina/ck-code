# `--to-issues` — what `ck-issues` publishes

Reference for PUBLISH MODE (SKILL.md P2–P5). **You do not build these bodies** —
`ck-issues` assembles them from the plan files and posts them. This file documents what
it emits, so you can describe it before the run and verify it after, plus the summary
shape for P5.

Every section is copied verbatim from the plan file; a section that is empty or absent
is omitted rather than emitted blank.

## Write-back — the v5 linkage

After creating an issue the script writes its number into the matching frontmatter, so
SHIP MODE resolves issues by number instead of by title:

- an **epic** issue → that epic's `EPIC.md` `issue:` (the line is added if absent);
- a **story** issue → that story file's `issue:`.

`ck-index tasks/<slug>` then runs automatically, since frontmatter changed. A file that
already carries an `issue:` is **reused, never republished** — this is what makes a
re-run the correct way to finish an interrupted publish.

## Mode `feature` — 1 issue

Title `Feature: [Project Name]` (the `# ` heading of `PROJECT_OVERVIEW.md`, or
`FEATURE_OVERVIEW.md`), label `feature`. **No write-back** — coarse tracking, so there is
no per-epic or per-story issue to link.

| Section | Source |
|---|---|
| `## Overview` | overview `## Vision`, else `## Overview`, else `## Description` |
| `## Epic NN: Title` (one per epic) | `EPIC.md` frontmatter `description`, then its stories as `- [ ] [EE-SS] Title (SIZE)` |
| `## Acceptance Criteria` | overview `## Acceptance Criteria` |

## Mode `epics` — 1 issue per epic

Title `Epic NN: Title`, label `epic`. Stories are an in-body checklist only; **no story
issues are created**. The padded `[EE-SS]` token lets SHIP MODE (Phase 6.3) flip the
exact item without collisions (`[02-01]` ≠ `[02-10]`).

| Section | Source |
|---|---|
| `## Description` · `## Goals` | same-named `EPIC.md` sections |
| `## Stories` | `- [ ] [EE-SS] Title (SIZE)` per story |
| `## Acceptance Criteria` · `## Technical Notes` | same-named `EPIC.md` sections |

## Mode `stories` — full hierarchy

Epic issues are created **first** (story bodies cross-reference the epic number), each
with `- [ ] #TBD - Title` placeholders. Story issues follow in epic order, then story
order. A final pass rewrites every epic body with the real numbers:

```
## Stories
- [ ] #42 - Set up project scaffolding
- [ ] #43 - Implement WebSocket gateway
```

That relink runs on **every** invocation from the numbers currently in frontmatter, so a
run that died between the story issues and the relink is repaired by re-running.

Story issue — title `[EE-SS] Story Title`, labels `story` and `size/<S|M>`:

| Section | Source |
|---|---|
| `## Parent Epic` | `Belongs to #<epic issue> - <Epic Title>` |
| `## Description` · `## Acceptance Criteria` · `## Technical Notes` | same-named story sections |
| `## Files` · `## Dependencies` | frontmatter `files:` / `blocked_by:`, one bullet per entry |
| `## Size: S\|M` | frontmatter `size:` |

## P5 summary shape

Build it from the script's own output lines — never by re-reading the plan.

```
## Published to GitHub Issues

**Repository:** [owner/repo]
**Mode:** [feature | epics | stories]

[feature]  #[num] - Feature: [Project Name]   (no frontmatter write-back)

[epics]
- #[num] - Epic 01: [Title]   → EPIC.md issue: [num]

[stories]
### Epic Issues
- #[num] - Epic 01: [Title]   → EPIC.md issue: [num]
### Story Issues
- #[num] - [01-01] [Title] (S) -> Epic #[num]   → story issue: [num]

### Quick Links
- All issues: [repo URL]/issues
- Features: [repo URL]/issues?q=label:feature
- Epics:    [repo URL]/issues?q=label:epic
- Stories:  [repo URL]/issues?q=label:story

**Total:** [count] issues created; [k] frontmatter `issue:` fields written; views regenerated.
```

When the script exited `1`, add the failing titles from its stderr and the exact re-run
command underneath — a partial publish is finished by re-running, not by hand-creating
the missing issues.
