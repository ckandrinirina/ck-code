# Conversational Q&A Scripts and Presentation Blocks

Reference dialogues and presentation templates used by the design skill across
its phases. The skill must reproduce these blocks (filling placeholders) when it
reaches the corresponding step.

---

## Mode Detection — Existing Project Prompt (Feature Mode entry)

When `docs/architecture/` already exists with files, first show the list of existing docs,
then ask via **AskUserQuestion** — "Existing architecture docs found. How do you want to
proceed?" — with three options:

- **ADD FEATURE** — Extend the docs with a new feature (read existing docs as context, only add/update what's needed).
- **FULL REFRESH** — Regenerate all architecture docs from scratch (existing docs are backed up first).
- **DIFFERENT PROJECT** — Treat this as a new project.

What each answer does is workflow, not script — branch per SKILL.md § "Feature Mode
entry" (ADD FEATURE asks "What new feature or capability do you want to add?" after
reading the globals).

---

## Phase 1 — Coverage Assessment Presentation

Show the table, then gate the next step with **AskUserQuestion** (options **Start Q&A** /
**Skip**):

```
## Specification Assessment

Your spec covers [X]/12 dimensions clearly.

| Dimension | Status |
|-----------|--------|
| ... | CLEAR |
| ... | PARTIAL - [what's vague] |
| ... | MISSING |

I'll ask [N] rounds of 2-3 questions each, focused on the PARTIAL and MISSING areas.
```

On **Skip** → jump to Phase 3, mark gaps with `[TO BE DEFINED]`.

---

## Phase 2 — Feature Mode Question Set

Use these instead of the New Project flow when in Feature Mode.

1. **Feature Scope & Integration**
   - "Describe the new feature in detail. What should it do?"
   - "Which existing components does this feature interact with?"
   - "Does this feature require new components, or does it extend existing ones?"

2. **Feature Architecture**
   - "Does this feature need new API endpoints, database tables, or config?"
   - "Are there new data flows or message types?"
   - "Any new dependencies or libraries needed?"

3. **Feature Boundaries**
   - "What's in scope for this feature vs. future work?"
   - "Any performance, security, or compatibility requirements specific to this feature?"
   - "Does this change affect the existing folder structure?"

After gathering answers, map impact into `features/<slug>/index.md` as specified in
SKILL.md Phase 2 "Question Sets" (endpoints → `## API`, tables → `## Data`, etc.).

---

## Phase 2 — New Project Mode Question Bank (Priority Order)

1. **Architecture & Components** (if MISSING/PARTIAL)
   - "What's the high-level architecture? (monolith, microservices, client-server, etc.)"
   - "What are the main components/services and how do they communicate?"
   - "Do you already have an idea for the folder structure, or should I propose one based on the tech stack?"

2. **Tech Stack** (if MISSING/PARTIAL)
   - "What languages/frameworks are you using for each component?"
   - "Any specific versions or constraints?"
   - "What's the deployment target? (local, cloud, mobile, cross-platform)"

3. **Data Flow & APIs** (if MISSING/PARTIAL)
   - "How does data flow between components? (REST, WebSocket, gRPC, message queue, etc.)"
   - "What are the main API endpoints or message types?"
   - "What serialization format? (JSON, Protobuf, MessagePack, etc.)"

4. **Database & State** (if MISSING/PARTIAL)
   - "What database(s) are you using?"
   - "What are the main entities/tables?"
   - "Any caching layer or state management approach?"

5. **Configuration & Environment** (if MISSING/PARTIAL)
   - "What configuration does the app need? (env vars, config files, etc.)"
   - "Any platform-specific configuration? (macOS vs Windows, dev vs prod)"

6. **Build & Run** (if MISSING/PARTIAL)
   - "What are the prerequisites to build and run?"
   - "Any specific build steps or order of startup?"

7. **Non-Functional Requirements** (if MISSING/PARTIAL)
   - "Any performance targets? (latency, throughput)"
   - "Security considerations?"
   - "Platform/browser compatibility?"

### Confirmation phrasing for already-covered dimensions

- CLEAR: "Your spec already defines [dimension] clearly. I'll use that as-is."
- PARTIAL: "Your spec mentions [what's there] but doesn't cover [what's missing]. Can you clarify?"

---

## Phase 3.1 — Pre-Generation Confirmation

Show the plan block, then gate with **AskUserQuestion** (options **Proceed** / **Adjust** /
**Cancel**).

**(New Project Mode):**

```
## Architecture Docs to Generate

**Output:** docs/architecture/
**Files:** [list of files that will be created]

Note: Your original specification at [path] will NOT be modified.
```

**(Feature Mode):**

```
## Architecture Docs to Update

**Feature:** [feature name/description]
**Output:** docs/architecture/

**Files to UPDATE** (new sections appended, existing sections preserved):
- [file.md]: Adding [what] section
- [file.md]: Extending [what] section

**Files to CREATE** (new, feature didn't exist before):
- [file.md]: [why needed]

**Files UNCHANGED** (not affected by this feature):
- [file.md]

Note: Existing content is preserved. New feature sections are clearly marked with a
"## [Feature Name]" header or appended to the relevant existing sections.
```

---

## Phase 4 — Final Summary Blocks

**(New Project Mode):**

```
## Architecture Documentation Generated

**Location:** docs/architecture/
**Files created:** [count]

| File | Status |
|------|--------|
| README.md | Created |
| overview.md | Created |
| folder-structure.md | Created |
| tech-stack.md | Created |
| _shared.md | Created |
| features/[slug-1]/index.md | Created |
| features/[slug-2]/index.md | Created |
| configuration.md | Created |
| dev-guide.md | Created |

### Gaps Remaining
[List any dimensions marked as [TO BE DEFINED], or "None - all dimensions covered"]

### Next Steps
1. Review the generated docs in docs/architecture/
2. Fill in any [TO BE DEFINED] placeholders
3. Run `/ck-code:team` to generate expert + guide skills from this architecture
4. Then `/ck-code:plan` to generate epics and stories
```

**(Feature Mode):**

```
## Architecture Documentation Updated

**Feature:** [feature name]
**Location:** docs/architecture/

| File | Action |
|------|--------|
| features/[slug]/index.md | CREATED - self-contained feature doc (frontmatter design: pending; components/API/data/flows) |
| _shared.md | UPDATED - added [shared infra] (only if 2+ features reuse it) |
| README.md | UPDATED - added feature to the Feature Documents index |
| overview.md | UNCHANGED |
| ... | ... |

### Impact Summary
- New components: [count]
- New API endpoints: [count]
- New DB tables: [count]
- New config entries: [count]
- Affected existing components: [list]

### Next Steps
1. Review the updated docs in docs/architecture/
2. Run `/ck-code:team` to refresh expert + guide skills for this feature's stack
3. Then `/ck-code:plan` to generate epics and stories for this feature
```

---

## Design system offer

Appended as one extra option to an existing New Project Mode refinement round. Never a
standalone prompt.

```
Question: Do you want UI built against a Claude Design system?
Header:   Design system
Options:
  - Link a design system — I have one at claude.ai/design. ck-code caches it in the repo
    and builds every component against its exact tokens and markup.
  - Skip — build UI from the architecture docs alone. You can link one later with
    /ck-code:design ds.
```

## DS Sync Report

```
=== DESIGN SYSTEM SYNC ===
Project:    [name] ([projectId])
Started at: Tier [0|1] ([reason])
Result:     [up to date — 1 call | 3 cards added, 1 changed, 0 removed]
Tokens:     [n] extracted ([m] low-confidence — confirm the ⚠️ rows)
Cached:     [n] cards, [size]
Next:       ['/ck-code:team --regenerate' on first sync | nothing to do]
```
