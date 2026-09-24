# Output Examples

Long-form example outputs for the team skill. The skill itself references
these for the exact phrasing of its plan and post-generation summary.

---

## Project Context Section (resolved in Phase 1.5)

What an expert carries in place of a copied context block — links only, resolved for
`expert-backend` in a Rust + React Native project:

```markdown
<!-- ck-code:team GENERATED — /ck-code:team may overwrite this file on --refresh or --regenerate. Delete this line to protect manual edits. -->
<!-- ck-code:team SOURCES 3f9a1c07be42 -->

# Expert: Senior Backend Developer

You are a senior backend developer working on **cklavier**.

## Project context

Read these on demand; they are the source of truth and this skill never copies them.

- [`docs/architecture/overview.md`](../../../docs/architecture/overview.md) — what cklavier is and who uses it
- [`docs/architecture/tech-stack.md`](../../../docs/architecture/tech-stack.md) — languages, frameworks, versions
- [`docs/architecture/folder-structure.md`](../../../docs/architecture/folder-structure.md) — where code lives; this role owns `server/` (the Axum API)
- Feature docs — `docs/architecture/features/<slug>/index.md`, found through the `Docs`
  column of `tasks/EPICS_INDEX.md` or the feature-doc index in `docs/architecture/README.md`
```

Never paste the stack table, component list or folder tree here: `design` edits those docs,
and a frozen copy would keep advising against the old architecture until the next refresh.

---

## Plan Presentation (Phase 2.4)

The roles below are **derived from this project**, not a fixed list — include any
project-specific role the domain warrants, and only the skills the project needs.
State the resolved tier in the header.

```
## Skills to Generate  (tier: standard)

Derived from your project's architecture and tech stack:

### Expert Roles
| Expert | Command | Why this project needs it |
|--------|---------|---------------------------|
| Frontend Developer | /expert-frontend | React Native + Expo mobile app (mobile/) |
| Backend Developer | /expert-backend | Rust Axum server (server/) |
| Database Engineer | /expert-database | sqlx + migrations/ detected |
| Security Engineer | /expert-security | JWT auth + secrets in _shared.md |
| QA Tester | /expert-qa | Always (testing) |
| Code Analyst | /expert-analyst | Always (review) |
| Project Q&A | /expert-qa-project | Always (project knowledge) |

### Language, Framework & Library Guides (researched via context7)
Guides cover idiomatic libraries too — not just languages and frameworks.
| Guide | Command | Best Practices Source |
|-------|---------|----------------------|
| Rust (Axum 0.7) | /guide-rust | context7 + WebSearch |
| React Native (Expo SDK 50+) | /guide-react-native | context7 + WebSearch |
| Zustand (state idiom) | /guide-zustand | context7 + WebSearch |
| i18next (namespaces, plurals) | /guide-i18next | context7 + WebSearch |

**Output:**
- .claude/skills/expert-<slug>/SKILL.md  (each with paths/keywords for auto-load)
- .claude/skills/guide-<slug>/SKILL.md

Preserved (PROTECTED — no GENERATED marker, never overwritten):
- .claude/skills/guide-conventions/SKILL.md  (hand-authored house rules)

Skipped — handled as guides under an existing expert, not as standalone experts:
analytics, i18n, styling, API-contract (guide-over-expert rule). Skipped at this
tier: expert-performance, expert-docs. Re-run with --max to widen the guide set.

House conventions: FOUND (protected)      ← or: NOT CAPTURED YET
```

Both questions go in ONE **AskUserQuestion** call; Q2's options depend on the probe:

```
Q1 — Plan
  ( ) Proceed          generate the skills above
  ( ) Adjust           add/remove/customize first
  ( ) Cancel

Q2 — House conventions            [NOT captured yet]      [already exists — protected]
  ( ) Capture now  ← recommended    |  ( ) Keep as-is  ← default
  ( ) Skip                          |  ( ) Refresh & merge
```

---

## Existing-Skills Gate (Phase 0.5 — AskUserQuestion)

When existing skills are found and `MISSING` is non-empty, ask via **AskUserQuestion**
(single question, one option each). PROTECTED files (no GENERATED marker) are never in
scope — they are preserved whatever the choice.

```
Existing team-owned skills found; N missing for this tier. Choose:
A) Generate missing only — create only the [list], leave the rest
B) Regenerate all — refresh team-owned skills with fresh research (merge-safe:
   PROTECTED files and MANUAL fences are preserved)
C) Abort
```

Add one line to option B only when `guide-design-system` is on disk and
`docs/architecture/design-system/` is not — the one case where B removes a skill:

```
   note: guide-design-system will be REMOVED — its cache
   (docs/architecture/design-system/) no longer exists
```

---

## Post-Generation Summary (Phase 4.2)

```
## Skills Generated

**Project:** [project-name]
**Research source:** context7 (MCP or `ctx7` CLI) + WebSearch
**Date:** [date]

### Expert Roles
| Expert | Command | Tech Focus |
|--------|---------|------------|
| Frontend Developer | /expert-frontend | [tech] |
| Backend Developer | /expert-backend | [tech] |
| QA Tester | /expert-qa | [frameworks] |
| Code Analyst | /expert-analyst | [languages] |
| DevOps | /expert-devops | [tools] |
| Project Q&A | /expert-qa-project | Full project knowledge |

### Language & Framework Guides
| Guide | Command | Version | Research Source |
|-------|---------|---------|----------------|
| [Language] | /guide-[slug] | [ver] | context7 |
| [Framework] | /guide-[slug] | [ver] | context7 + WebSearch |
| ... | ... | ... | ... |

### Design System

<!-- this section only when guide-design-system was written, refreshed, or removed;
     omit it entirely otherwise — most projects have no design system -->

**guide-design-system:** generated from `docs/architecture/design-system/index.md`
([N] tokens, [N] components). Auto-loads on UI paths; exempt from the guide line budget
because its tables are verbatim data.

<!-- other outcomes, one line, pick the one that happened:
     refreshed — tables re-copied from the current cache
     REMOVED — docs/architecture/design-system/ was deleted, so the guide went with it
     preserved unchanged — marker removed by you, so the refresh left it alone
       (its cache is gone; delete the skill when you are done with it)  -->

### House Conventions

**guide-conventions:** captured — naming, file/folder structure, code style,
architectural rules. PROTECTED: `--refresh` and `--regenerate` never touch it.

<!-- other outcomes, one line, pick the one that happened:
     refreshed — merged with your existing rules; untouched sections kept
     preserved unchanged — existing guide left as-is
     skipped — run `/ck-code:team --conventions` to capture them later  -->

### How to Use

**Expert roles** (invoke directly):
- `/expert-frontend` — "Implement the instrument browser component"
- `/expert-backend` — "Add a new WebSocket endpoint for volume control"
- `/expert-qa` — "Write tests for the preset manager"
- `/expert-analyst` — "Review the MIDI arranger module for issues"
- `/expert-devops` — "Set up CI/CD for the Rust server"
- `/expert-qa-project` — "How does the chord detection work?"

**Language guides** (auto-loaded by Claude when working with that language):
- Claude automatically uses /guide-rust when writing Rust code
- Claude automatically uses /guide-cpp when working on C++ files
- No manual invocation needed — they provide background knowledge

### Regeneration

- `/ck-code:team --refresh` after `tech-stack.md` or `folder-structure.md` changes —
  refreshes only the skills `ck-team stale` lists (`/ck-code:design` offers it)
- `/ck-code:team --regenerate` after a framework upgrade the docs do not show — refreshes
  every owned skill with fresh research
- `/ck-code:team` after adding a technology — generates the missing guides

Both refreshes are **merge-safe**: they touch only team-owned skills, preserve every
PROTECTED file (`guide-conventions`, custom `--new` skills) and every `MANUAL` fence.
```

---

## Phase 0.5 State Table

Shown when existing skills are found and neither `--refresh` nor `--regenerate` is set.

```
## Skill State Audit

Based on tech-stack.md, expected skills vs. current state:

### Expert Skills
| Skill | Path | Status |
|-------|------|--------|
| expert-frontend   | .claude/skills/expert-frontend/SKILL.md   | ✓ exists  |
| expert-backend    | .claude/skills/expert-backend/SKILL.md    | ✓ exists  |
| expert-qa         | .claude/skills/expert-qa/SKILL.md         | ✓ exists  |
| expert-analyst    | .claude/skills/expert-analyst/SKILL.md    | ✓ exists  |
| expert-devops     | .claude/skills/expert-devops/SKILL.md     | ✗ missing |
| expert-qa-project | .claude/skills/expert-qa-project/SKILL.md | ✓ exists  |

### Language & Framework Guides
| Guide              | Path                                         | Status                    |
|--------------------|----------------------------------------------|---------------------------|
| guide-typescript   | .claude/skills/guide-typescript/SKILL.md    | ✓ exists (owned)          |
| guide-rust         | .claude/skills/guide-rust/SKILL.md          | ✓ exists (owned, stale)   |
| guide-react-native | .claude/skills/guide-react-native/SKILL.md  | ✗ missing                 |
| guide-grpc         | .claude/skills/guide-grpc/SKILL.md          | ? extra (tech not detected) |
| guide-conventions  | .claude/skills/guide-conventions/SKILL.md   | ● protected (house rules)   |
| guide-design-system | .claude/skills/guide-design-system/SKILL.md | ⊘ cache deleted → will be REMOVED |

**Summary:** 2 missing, 1 extra, 6 owned (1 stale sources), 1 protected, 1 cache-deleted.

The `guide-design-system` row appears only when that skill or its cache exists; omit it
entirely on a project with no design system.

Then ask via **AskUserQuestion** (see Existing-Skills Gate above):
A) Generate missing only  B) Regenerate all (merge-safe)  C) Abort
```

Legend: **owned** = carries the team GENERATED marker (refreshable on `--refresh`/`--regenerate`).
**owned, stale** = `ck-team stale` lists it — written against an older `tech-stack.md` or
`folder-structure.md`; `--refresh` rewrites it.
**protected** = no marker (`--conventions`, `--new`, or user-unmarked) — never overwritten,
never counted as EXTRA. **? extra** = an owned skill for a technology no longer in
tech-stack.md; never deleted automatically — `--refresh` offers it for deletion (multi-select,
nothing pre-selected) and the user decides. **⊘ cache deleted** = the one
auto-removal in the whole skill: an *owned* `guide-design-system` whose
`docs/architecture/design-system/` cache has been deleted (THE MERGE RULE step 4). No other
slug is ever deleted without asking, and a *protected* `guide-design-system` is `● protected`.
