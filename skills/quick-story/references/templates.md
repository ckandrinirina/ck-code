# Quick Story Skill — Templates

Templates used by `/ck-code:quick-story` Phase 4. Substitute the bracketed
fields when writing each artifact. Keep these formats byte-identical to the
plan-skill output so downstream skills (`build`, `track`, `to-issues`, `ship`,
`fix`, `sync`) treat the story like any other.

---

## Story file

Path: `tasks/<slug>/epics/NN_<epic-slug>/stories/SS_<story-slug>.md`.

```markdown
# Story [EE]-[SS]: [Title]

> **Epic:** [Epic Display Name]
> **Size:** [S/M/L/XL]
> **Status:** TODO

## Description
[1–2 sentences expanding the brief: what it implements and why]

## Acceptance Criteria
- [ ] [Criterion 1 — specific, testable]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

## Technical Notes
- [Hint 1 — pattern, library, or migration approach]
- [Hint 2]

## Files to Create/Modify
| Action | File Path | Purpose |
|--------|-----------|---------|
| CREATE | path/to/new/file.ext | [what it does] |
| MODIFY | path/to/existing.ext | [what changes] |

## Dependencies
- **Blocked by:** None
- **Blocks:** None

## Related
- **Epic:** [epic-slug]
```

---

## STORIES_INDEX.md row

Insert at the correct position so rows stay sorted by `ID`. Use cell-only
Edits per `ck-code/references/stories-index.md` — never rewrite the table.

```
| [EE] · [Epic Display] | [EE]-[SS] | [Title] | TODO | [Size] | - | epics/[NN]_[epic-slug]/stories/[SS]_[story-slug].md |
```

---

## EPIC.md story-table row

Append to the `## Stories` table inside `tasks/<slug>/epics/NN_<epic-slug>/EPIC.md`.

```
| [SS] | [Title] | [Size] | TODO |
```
