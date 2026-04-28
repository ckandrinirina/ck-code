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

```
## Skills to Generate

Based on your project's tech stack and architecture:

### Expert Roles
| Expert | Command | Reason |
|--------|---------|--------|
| Frontend Developer | /expert-frontend | React Native + Expo mobile app detected |
| Backend Developer | /expert-backend | Rust Axum server detected |
| QA Tester | /expert-qa | Always generated |
| Code Analyst | /expert-analyst | Always generated |
| DevOps | /expert-devops | No CI/CD yet — will focus on setup guidance |
| Project Q&A | /expert-qa-project | Always generated |

### Language & Framework Guides (researched via context7)
| Guide | Command | Best Practices Source |
|-------|---------|----------------------|
| C++ (JUCE 8.x) | /guide-cpp | context7 + WebSearch |
| Rust (Axum 0.7) | /guide-rust | context7 + WebSearch |
| React Native (Expo SDK 50+) | /guide-react-native | context7 + WebSearch |
| gRPC / Protobuf | /guide-grpc | context7 + WebSearch |

**Output:**
- .claude/skills/experts/<slug>/SKILL.md
- .claude/skills/guides/<slug>/SKILL.md

Proceed? YES / NO / ADJUST
```

If ADJUST, let user add/remove experts/guides or customize.

---

## Existing-Skills Prompt (Phase 3)

```
Existing generated skills found: [list]
A) REGENERATE ALL — Overwrite with updated project context + fresh research
B) SKIP EXISTING — Only create missing skills
C) ABORT
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
```
