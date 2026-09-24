# Plan Skill — Roadmap & Presentation Formats

Formatting templates for the plan-confirmation view, the generated `ROADMAP.md`, and the
post-generation summaries.

---

## Phase 4 Plan Confirmation Format

Shown to the user before any files are written. Present this text, then gate with one
`AskUserQuestion` call (**Proceed** / **Adjust** / **Cancel**, plus the integration-level
question for a new plan folder — SKILL.md Phase 4).

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

### Ordering Strategy
Demo-first — [Epic NN] (the first built) makes the app runnable; surface epics follow, each
demoable on merge; backend epics replace their seams behind an unchanged click path.
(Headless project: "Foundation-first — no user-facing surface.")

### How a Human Verifies
Every story, backend included, is checked by running the app — no manual API client.
Backend stories re-run the click path of the surface story whose seam they replace and
see real data.

### First Runnable Demo
After **Epic [NN]**: [what a human can click, run, or call, and with which command]

### Suggested Implementation Order
1. [Epic/story] - [reason]
2. [Epic/story] - [reason]
...

### Stubbed Seams
- `[seam path]` — stubbed by [EE-SS], replaced by [EE-SS]

### Output Location
tasks/YYYY-MM-DD_[slug]/
```

The epic numbers above (`Epic 01`, `Epic 02`, the final `NN_integration-e2e`) are
**illustrative shape only**. Real numbers are allocated from the project-wide maximum
(`plan` 3.1), so a second plan folder in an existing project starts at whatever comes next —
`Epic 07`, not `Epic 01`. Never renumber a plan to make it match this example.

The ordering strategy is shown so **Adjust** can change it; do not add a separate prompt
for it. A "First Runnable Demo" later than the first epic built is mis-ordered (`plan` 3.1)
— fix it before presenting.

`AskUserQuestion` — "Proceed with generating this plan?" → **Proceed** (Phase 5) /
**Adjust** (ask what to change, loop to Phase 3) / **Cancel** (stop, write nothing). In the
same call, for a new plan folder: "How should this plan's work be reviewed?" → **story**
(each story its own PR into the trunk — Recommended for small plans) / **epic** (one PR
per epic) / **plan** (one PR for the whole plan).

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

## Stub Ledger

Every fixture-backed seam the demo-first ordering introduces, and the story that removes it.
An empty table means the plan ships no stubs; a row with no **Replaced by** is a planning bug.

| Seam (file)  | Contract         | Stubbed by | Replaced by | Demo it unblocks |
| ------------ | ---------------- | ---------- | ----------- | ---------------- |
| [path]       | [type/function]  | [EE-SS]    | [EE-SS]     | [what renders]   |

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

The first milestone is the runnable demo — name the command that starts it and what a human
sees. A milestone whose deliverable no one can exercise is mis-ordered (see `plan` 3.1).
Every later milestone names the click path or command that shows its work; none is
verified through a manual API client (`plan` 3.2).
```

---

## Phase 6 Summary Formats

### New Project Mode Summary

```
## Plan Generated Successfully

**Mode:** New Project
**Location:** tasks/YYYY-MM-DD_[project-slug]/
**Integration:** [story | epic | plan] — change later with /ck-code:config integration
**Epics:** [count]
**Stories:** [total count]

### Quick Stats
- S stories: [count]
- M stories: [count]

(Every story is sized S/M — single-dispatch. Views regenerated from frontmatter.)

### Next Steps
1. Review the generated plan in tasks/
2. Adjust stories or sizing as needed
3. `/ck-code:plan --publish tasks/YYYY-MM-DD_[project-slug]` to publish to GitHub Issues (optional)
4. Start with `/ck-code:build` (pass several story IDs to build independent stories at once)
```

### Increment Mode Summary

```
## Plan Generated Successfully

**Mode:** Increment
**Plan:** [plan title]
**Location:** tasks/YYYY-MM-DD_[slug]/
**Integration:** [story | epic | plan] — change later with /ck-code:config integration
**Epics:** [count]
**Stories:** [total count]

### Integration Points
- Existing components affected: [list]
- New components introduced: [list]
- Cross-references to earlier plans: [list of dependencies on existing stories/epics]

### Quick Stats
- S stories: [count]
- M stories: [count]

### Next Steps
1. Review the plan in tasks/
2. `/ck-code:plan --publish tasks/YYYY-MM-DD_[slug]` to publish to GitHub Issues (optional)
3. Start with `/ck-code:build` on the first story in the roadmap
```

### Increment Mode — Continue Existing Plan Summary

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
3. `/ck-code:plan --publish tasks/[existing-folder]` to publish the new epics to GitHub
   Issues (entries already published are reused, never duplicated)
```
