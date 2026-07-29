# Plan Skill — Roadmap & Presentation Formats

Formatting templates for the plan-confirmation view, the generated `ROADMAP.md`, and the
post-generation summaries.

---

## Phase 4 Plan Confirmation Format

Shown to the user before any files are written. Present this text, then gate with
`AskUserQuestion` (**Proceed** / **Adjust** / **Cancel**).

```
## Project Plan: [Project Name]

### Epics ([count] total)

**Epic 01: [Name]** ([story count] stories)
  - 01: [Story title] (Size) [dependencies if any]
  - 02: [Story title] (Size)
  ...

**Epic 02: [Name]** ([story count] stories)
  - 01: [Story title] (Size) [blocked by 01-...]
  ...

[... all epics, including the final NN_integration-e2e epic ...]

### Suggested Implementation Order
1. [Epic/story] - [reason]
2. [Epic/story] - [reason]
...

### Output Location
tasks/YYYY-MM-DD_[project-slug]/
```

`AskUserQuestion` — "Proceed with generating this plan?" → **Proceed** (Phase 5) /
**Adjust** (ask what to change, loop to Phase 3) / **Cancel** (stop, write nothing).

---

## ROADMAP.md Template

```markdown
# Implementation Roadmap: [Project Name]

## Dependency Graph

[ASCII diagram showing epic dependencies]

## Recommended Implementation Order

### Phase 1: [Phase Name]

**Goal:** [What this phase achieves]

1. **[Epic/Story ID]** - [Title] ([Size])
   - [Why this comes first]
2. **[Epic/Story ID]** - [Title] ([Size])
   - [Dependency or reason]

### Phase 2: [Phase Name]

...

## Parallelization Opportunities

- [Story A] and [Story B] can be developed simultaneously because [reason]
- [Epic X] backend work can overlap with [Epic Y] frontend work

## Critical Path

The longest sequential chain is:
[Story] -> [Story] -> [Story] -> ...

## Risk Areas

| Risk     | Impact            | Mitigation        |
| -------- | ----------------- | ----------------- |
| [Risk 1] | [High/Medium/Low] | [How to mitigate] |

## Milestones

| Milestone | Epics Included | Deliverable     |
| --------- | -------------- | --------------- |
| [Name]    | Epic 01, 02    | [What's usable] |
| [Name]    | Epic 03        | [What's added]  |
```

---

## Phase 6 Summary Formats

### New Project Mode Summary

```
## Plan Generated Successfully

**Mode:** New Project
**Location:** tasks/YYYY-MM-DD_[project-slug]/
**Epics:** [count]
**Stories:** [total count]

### Quick Stats
- S stories: [count]
- M stories: [count]

(Every story is sized S/M — single-dispatch. Indexes regenerated from frontmatter.)

### Next Steps
1. Review the generated plan in tasks/
2. Adjust stories or sizing as needed
3. Use `/ck-code:ship` to publish to GitHub Issues (optional)
4. Start with `/ck-code:build` (pass several story IDs to build independent stories at once)
```

### Feature Mode — Add Feature Summary

```
## Feature Plan Generated Successfully

**Mode:** Add Feature
**Feature:** [feature name]
**Location:** tasks/YYYY-MM-DD_feature-[feature-slug]/
**Epics:** [count]
**Stories:** [total count]

### Integration Points
- Existing components affected: [list]
- New components introduced: [list]
- Cross-references to main plan: [list of dependencies on existing stories/epics]

### Quick Stats
- S stories: [count]
- M stories: [count]

### Next Steps
1. Review the feature plan in tasks/
2. Use `/ck-code:ship tasks/YYYY-MM-DD_feature-[slug]` to publish to GitHub Issues
3. Start with `/ck-code:build` on the first story in the feature roadmap
```

### Feature Mode — Continue Existing Plan Summary

```
## Plan Extended Successfully

**Mode:** Continue Existing Plan
**Location:** tasks/[existing-folder]/
**New epics added:** [count] (numbered [NN] to [MM])
**New stories added:** [total count]
**Total plan now:** [total epics] epics, [total stories] stories

### What Was Added
- Epic [NN]: [Title] ([story count] stories)
- Epic [MM]: [Title] ([story count] stories)

### Next Steps
1. Review the new epics in tasks/[existing-folder]/epics/
2. ROADMAP.md has been updated with the new epics
3. Use `/ck-code:ship` to publish the new epics to GitHub Issues
```
