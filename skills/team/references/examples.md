# Output Examples

Long-form example outputs for the team skill. The skill itself references
these for the exact phrasing of its plan and post-generation summary.

---

## Project Context Block (built in Phase 1.5)

```markdown
## Project Context (auto-generated — do not edit manually)

**Project:** [name]
**Description:** [one-liner]
**Architecture:** [type, e.g., client-server with 3 components]

**Components:**

- [Component 1]: [tech] — [purpose]
- [Component 2]: [tech] — [purpose]
- ...

**Tech Stack:**

- [Layer]: [technology] [version]
- ...

**Key Patterns:**

- Communication: [protocols used]
- Serialization: [formats used]
- Database: [engine + ORM]
- Testing: [framework(s)]
- Build: [tools]

**Folder Structure:**
[Condensed tree of key directories, max 20 lines]

**Architecture Docs:** docs/architecture/
**Specification:** [path]
**Task Plans:** [tasks/ folders if any]
```

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

### House Conventions

**guide-conventions:** captured — naming, file/folder structure, code style,
architectural rules. PROTECTED: `--regenerate` never touches it.

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

Run `/ck-code:team --regenerate` after:
- Updating docs/architecture/ (new components, tech changes)
- Upgrading framework versions (to refresh best practices)
- Adding new technologies to the project

Regeneration is **merge-safe**: it refreshes only team-owned skills, preserves every
PROTECTED file (`guide-conventions`, custom `--new` skills) and every `MANUAL` fence.
```

---

## Phase 0 State Table

Shown when existing skills are found and `--regenerate` is not set.

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
| guide-rust         | .claude/skills/guide-rust/SKILL.md          | ✓ exists (owned)          |
| guide-react-native | .claude/skills/guide-react-native/SKILL.md  | ✗ missing                 |
| guide-grpc         | .claude/skills/guide-grpc/SKILL.md          | ? extra (tech not detected) |
| guide-conventions  | .claude/skills/guide-conventions/SKILL.md   | ● protected (house rules)   |

**Summary:** 2 missing, 1 extra, 6 owned, 1 protected.

Then ask via **AskUserQuestion** (see Existing-Skills Gate above):
A) Generate missing only  B) Regenerate all (merge-safe)  C) Abort
```

Legend: **owned** = carries the team GENERATED marker (refreshable on `--regenerate`).
**protected** = no marker (`--conventions`, `--new`, or user-unmarked) — never overwritten,
never counted as EXTRA. **? extra** = an owned skill for a technology no longer in
tech-stack.md; never deleted automatically — the user decides.
