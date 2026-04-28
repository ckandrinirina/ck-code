# Conversational Q&A Scripts and Presentation Blocks

Reference dialogues and presentation templates used by the design skill across
its phases. The skill must reproduce these blocks (filling placeholders) when it
reaches the corresponding step.

---

## Mode Detection — Existing Project Prompt (Feature Mode entry)

When `docs/architecture/` already exists with files, present:

```
## Existing Project Detected

I found existing architecture documentation in docs/architecture/.
Existing docs: [list files found]

How would you like to proceed?

A) ADD FEATURE — Extend the architecture docs with a new feature
   (I'll read existing docs as context and only add/update what's needed)

B) FULL REFRESH — Regenerate all architecture docs from scratch
   (Existing docs will be backed up to docs/architecture/backup_YYYY-MM-DD/)

C) I'm working on a different project — treat this as new
```

Branching:
- **A (ADD FEATURE):** Read all `docs/architecture/*.md`, read spec from `$ARGUMENTS`, ask "What new feature or capability do you want to add?", then continue Phase 1 with feature-scoped analysis.
- **B (FULL REFRESH):** `mv docs/architecture docs/architecture/backup_YYYY-MM-DD`, proceed New Project Mode.
- **C:** Proceed New Project Mode.

---

## Phase 1 — Coverage Assessment Presentation

```
## Specification Assessment

Your spec covers [X]/12 dimensions clearly.

| Dimension | Status |
|-----------|--------|
| ... | CLEAR |
| ... | PARTIAL - [what's vague] |
| ... | MISSING |

I'll ask you some questions to fill the gaps. This will take [N] rounds
of 2-3 questions each, focused on the PARTIAL and MISSING areas.

Ready to start? YES / SKIP (generate with what we have)
```

If user replies SKIP → jump to Phase 3, mark gaps with `[TO BE DEFINED]`.

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

After gathering answers, map impact to specific docs (e.g., new endpoints → api-contracts.md, new tables → database-schema.md).

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

**(New Project Mode):**

```
## Architecture Docs to Generate

**Output:** docs/architecture/
**Files:** [list of files that will be created]

Note: Your original specification at [path] will NOT be modified.

Proceed? YES / NO / ADJUST
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

Note: Existing content will be preserved. New feature sections will be
clearly marked with a "## [Feature Name]" header or appended to
the relevant existing sections.

Proceed? YES / NO / ADJUST
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
| components.md | Created |
| data-flow.md | Created |
| api-contracts.md | Created |
| database-schema.md | Created |
| configuration.md | Created |
| dev-guide.md | Created |

### Gaps Remaining
[List any dimensions marked as [TO BE DEFINED], or "None - all dimensions covered"]

### Next Steps
1. Review the generated docs in docs/architecture/
2. Fill in any [TO BE DEFINED] placeholders
3. Run `/ck-code:plan` to generate epics and stories from this architecture
```

**(Feature Mode):**

```
## Architecture Documentation Updated

**Feature:** [feature name]
**Location:** docs/architecture/

| File | Action |
|------|--------|
| components.md | UPDATED - added [component name] |
| api-contracts.md | UPDATED - added [N] new endpoints |
| database-schema.md | UPDATED - added [table name] |
| features/YYYY-MM-DD_feature.md | CREATED - full feature spec |
| README.md | UPDATED - changelog entry added |
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
2. Run `/ck-code:plan` to generate epics and stories for this feature
```

---

## Feature Mode — README Changelog Entry Format

When a feature update affects `docs/architecture/README.md`, append:

```
## Changelog
- [date]: Added [feature name] — updated [list of files]
```
