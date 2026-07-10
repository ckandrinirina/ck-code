---
name: design
description: Use to generate architecture documentation (`docs/architecture/`) from a project specification or feature description. Argument is the path to the spec file.
argument-hint: "[path-to-spec-file]"
effort: high
---

# Spec Designer — Specification Refiner & Architecture Documenter

Read a project specification, identify gaps through conversational questioning,
and generate **feature-scoped** architecture documentation ready for development.

The architecture is a few **global** docs (overview, folder-structure, tech-stack,
`_shared.md`, configuration, dev-guide) plus one **self-contained feature doc** per
feature in `docs/architecture/features/<slug>/index.md`. Per-increment / per-fix
changes are journaled as dated sibling docs
(`features/<slug>/YYYY-MM-DD_<id>_<short>.md`); `index.md` stays the canonical truth a
later `build`/`fix` story routes to. The retired layer docs (`components.md`,
`api-contracts.md`, `database-schema.md`, `data-flow.md`) are not generated — their
content lives in each feature's doc so a story reads only the one doc it needs.

**Supports two modes:**

- **New Project Mode:** Generate global docs + one feature doc per feature from a project spec
- **Feature Mode:** Add or extend a single feature doc, keeping the global docs consistent

## ROUTING CHECK (do first)

This skill turns a spec into **architecture docs** — it runs *before* `plan`.
If the request is actually something else, STOP and recommend the better skill:

- No stakeholder spec yet and you want one → `/ck-code:pre-spec` (first)
- Breaking work into epics/stories → `/ck-code:plan` (design comes first)
- Existing architecture docs are bloated or on a stale layout → `/ck-code:doc-optimizer`

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:team`.

**Reuse-first:** read the existing docs & spec first, reuse before rebuilding, and design the
simplest thing that meets the requirement — see [`reuse-first.md`](../../references/reuse-first.md).

---

## EFFORT SCALING

Adapt depth to the current effort level (**${CLAUDE_EFFORT}**):

- **low** — Minimal Q&A; generate the core globals (overview, tech-stack, folder-structure) plus a thin feature doc per identified feature, marking the rest `[TO BE DEFINED]`.
- **medium** (default) — Up to 3 Q&A rounds; generate all applicable docs at standard depth.
- **high / xhigh / max** — Up to the full 5 Q&A rounds; research every named technology via context7; add deep component/data-flow detail plus cross-cutting concerns (scaling, failure modes, observability) to each doc.

---

## INPUT

Spec file path comes from `$ARGUMENTS`.

**If empty:** look for `docs/specifications.md`, `docs/spec.md`, `SPEC.md`, `docs/requirements.md`. If found, confirm with user. If not, ask whether to (A) provide a path or (B) start from scratch and be guided through creation.

**If the file does not exist:** tell the user and ask for the correct path.

---

## PHASE 0: VERSION GATE (hard gate)

Before reading/writing any `docs/architecture/` doc: Read `tasks/VERSION.md`. If `layout: v3` → PASS, proceed. Otherwise run the shared [version gate](../../references/version-gate.md) (HARD GATE) — on a pre-v3 marker it offers `/ck-code:doc-optimizer upgrade` and stops until it PASSes (or the user declines); on greenfield it stamps `tasks/VERSION.md` and passes.

---

## MODE DETECTION

**Goal:** Determine whether this is a new project or a feature addition.

### Detection Steps

1. Check if `docs/architecture/` already exists (Glob)
2. Check if `tasks/` directory exists with prior epics
3. Check the codebase for existing source files beyond just docs

### Decision Logic

```
IF docs/architecture/ exists AND has files:
  → FEATURE MODE (extending an existing project)
ELSE:
  → NEW PROJECT MODE (generating from scratch)
```

### Feature Mode Activation

When in Feature Mode, present the user with the existing-project prompt (A/B/C
options) and follow its branching logic. For the exact wording, options, and
branch handling see [references/qna-examples.md](references/qna-examples.md).

Branch summary:

- **A (ADD FEATURE):** read the existing architecture context per Phase 1.1b (globals +
  README index only — NOT every feature doc), read the spec, ask "What new feature or
  capability do you want to add?", proceed to Phase 1 with feature-scoped analysis.
- **B (FULL REFRESH):** back up existing docs to
  `docs/architecture/backup_YYYY-MM-DD/`, proceed as New Project Mode.
- **C:** proceed as New Project Mode.

---

## PHASE 1: READ & ASSESS THE SPECIFICATION

**Goal:** Understand what the spec covers and identify what's missing or vague.

### 1.1 Read the Specification

Read the entire file using the Read tool. If the spec is in a non-English language,
process it in its original language but produce all output in English.

### 1.1b (Feature Mode) Read Existing Architecture Context

If in Feature Mode, BEFORE assessing coverage:

1. Read the global docs (`overview.md`, `tech-stack.md`, `folder-structure.md`,
   `_shared.md`) and the `README.md` index — NOT every feature doc. From the index,
   read only the feature doc(s) the new feature will integrate with.
2. Read existing source code structure using Glob
3. Build a mental model of: what exists, what the new feature needs to integrate with

New feature docs must be consistent with the existing architecture.

### 1.2 Assess Coverage

Score each of these 12 dimensions as CLEAR / PARTIAL / MISSING. A dimension the spec or an
existing doc already answers is CLEAR — reuse that answer; never manufacture a gap to fill:

Project vision & goals · Target users · System architecture · Folder structure · Tech stack & versions · Component breakdown · Data flow · API contracts · Database schema · Configuration · Build & run instructions · Non-functional requirements

### 1.3 Present Assessment

Show the user the coverage table and ask whether to start Q&A or SKIP. For the
exact presentation block, see [references/qna-examples.md](references/qna-examples.md).

If the user says SKIP, jump directly to Phase 3 and generate docs using only what's
available, marking gaps with `[TO BE DEFINED]`.

---

## PHASE 2: CONVERSATIONAL REFINEMENT

**Goal:** Fill gaps and clarify ambiguities through adaptive questioning.

### Questioning Strategy

- Ask **2-3 questions per round** maximum
- Start with the highest-impact MISSING dimensions first
- For PARTIAL dimensions, ask targeted questions about the vague parts
- Adapt follow-up questions based on previous answers
- For CLEAR dimensions, do not re-ask — briefly confirm and reuse

### Question Sets

- **Feature Mode:** use the feature-scoped question set (Scope & Integration,
  Architecture, Boundaries). After answers, map impact into the **single feature doc**
  `features/<slug>/index.md` — new endpoints → its `## API`, new tables → its `## Data`, new
  components → its `## Components`, new flows → its `## Flows`. Truly cross-cutting infra
  (shared auth, base tables) goes in `_shared.md` and is linked from the feature doc.
- **New Project Mode:** use the priority-ordered question bank covering
  Architecture & Components → Tech Stack → Data Flow & APIs → Database & State →
  Configuration → Build & Run → Non-Functional Requirements.

For the full wording of every question and the confirmation phrasing for CLEAR
and PARTIAL dimensions, see [references/qna-examples.md](references/qna-examples.md).

### Research During Refinement

When the user mentions specific technologies, use context7 (MCP, else `npx -y @upstash/context7` CLI) or WebSearch to:

- Look up current best practices for project structure
- Verify standard folder conventions for the frameworks mentioned
- Check for recommended configuration patterns

### Refinement Loop

After each round of questions:

1. Summarize what was learned
2. Check if remaining gaps exist
3. If yes, ask the next round
4. If all dimensions are CLEAR or user says "enough", move to Phase 3

Maximum **5 rounds**. If gaps remain after 5 rounds, proceed to generation and
mark remaining gaps with `[TO BE DEFINED]`.

---

## PHASE 3: GENERATE ARCHITECTURE DOCUMENTATION

**Goal:** Create or update the split documentation files in `docs/architecture/`.

### 3.1 Confirm Before Writing

Present a pre-generation confirmation block (different content for New Project
Mode vs. Feature Mode) and wait for YES / NO / ADJUST. For the exact blocks see
[references/qna-examples.md](references/qna-examples.md).

### 3.2 Create Directory

```bash
mkdir -p docs/architecture
```

### (Feature Mode) Update Strategy

When adding or extending a feature in an existing project:

1. **Never delete or overwrite existing content.** Only add or extend.
2. **One feature = one doc.** Write/extend `docs/architecture/features/<slug>/index.md`
   using the Feature Doc template (`mkdir -p` the `<slug>/` folder first). New feature →
   Write the file; existing feature → Read it and Edit the relevant section
   (`## Components` / `## API` / `## Data` / `## Flows`). The `<slug>` should match the
   planned epic slug so `FEATURE_INDEX.Docs` routes to it.
3. **Cross-cutting only** goes in `_shared.md`: if the feature introduces infra that
   other features will reuse (shared middleware, base entities), add it to `_shared.md`
   and link it from the feature doc's `## Shared dependencies` — never duplicate it into
   the feature doc.
4. **README.md index:** add the new feature doc to the Feature Documents table and
   append a `## Changelog` entry. For the changelog format see
   [references/qna-examples.md](references/qna-examples.md).
5. **Append a feature-doc `## Changelog` line** noting what was added (date · source ·
   one line), mirroring the write-back format `build`/`fix` use.
6. **Design record + ledger row** — also run step 3.11 for this feature: write the dated
   design record and append a `pending` row to `DESIGN_LEDGER.md`.

### 3.3 – 3.10 Generate Each Architecture Document

Generate the following files in `docs/architecture/`. The exact template for
each file (markdown structure, tables, sections, placeholders) lives in
[references/architecture-templates.md](references/architecture-templates.md).
Use those templates verbatim, filling placeholders with project-specific
content derived from the spec and user answers.

First identify the **feature list** from the spec (the same features `plan` will turn
into epics). Each becomes one `features/<slug>/index.md`. Then generate:

| Step | File                                                                         | Template section                             |
| ---- | ---------------------------------------------------------------------------- | -------------------------------------------- |
| 3.3  | `README.md` (index)                                                          | README.md (Index)                            |
| 3.4  | `overview.md`                                                                | overview.md                                  |
| 3.5  | `folder-structure.md`                                                        | folder-structure.md                          |
| 3.6  | `tech-stack.md`                                                              | tech-stack.md                                |
| 3.7  | `_shared.md` (cross-cutting infra)                                           | \_shared.md                                  |
| 3.8  | `features/<slug>/index.md` — **one per feature** (components/API/data/flows) | features/&lt;slug&gt;/index.md (Feature Doc) |
| 3.9  | `configuration.md`                                                           | configuration.md                             |
| 3.10 | `dev-guide.md`                                                               | dev-guide.md                                 |

**Feature list note:** derive features from the spec's capability breakdown. Pick a
short `<slug>` per feature (e.g. `roles`, `customer`, `billing`) and reuse it as the
epic slug so the `FEATURE_INDEX.Docs` column lines up. Put a component/table/endpoint in
`_shared.md` (not a feature doc) only when **two or more** features rely on it.

**folder-structure.md note:** see the **Important** note under the folder-structure.md
template — spec-defined structure is the base; otherwise propose one from the tech stack.

### 3.8a (New Project Mode, ≥4 features) Parallel feature-doc fan-out

Each `features/<slug>/index.md` is self-contained, so the per-feature docs parallelize. When
this is a New Project run with **≥4 independent features**, author the globals AND `_shared.md`
(steps 3.3–3.7) **first** so `_shared.md` is frozen, then dispatch one `general-purpose` Agent per
feature following [../../references/subagent-fanout.md](../../references/subagent-fanout.md)
(artifact variant). Pass each agent the frozen `_shared.md` contract, its `<slug>`, its spec slice,
and `references/architecture-templates.md` (used verbatim — no improvising structure); it writes
ONLY its own `features/<slug>/` directory. The orchestrator collects and writes the shared
`README.md` index rows and `DESIGN_LEDGER.md` rows once, post-merge (never inside a subagent), and
the Phase 0 version gate runs only in the orchestrator. Feature Mode (one doc) and specs with
<4 features stay sequential.

### 3.11 Design records + DESIGN_LEDGER (both modes)

For **each feature this run added or changed**, record the design pass so `plan` can
later find unplanned work as a table lookup. Use today's date (`date +%Y-%m-%d`):

1. **Design record** — Write `docs/architecture/features/<slug>/YYYY-MM-DD_design_<short>.md`
   from the **Design Record** template in
   [references/architecture-templates.md](references/architecture-templates.md), where
   `<short>` is a 2–4 word kebab slug of what was designed. Append-only history beside
   `index.md` (not auto-read by later skills).
2. **Ledger row** — Append one row to `docs/architecture/DESIGN_LEDGER.md` (create it from
   the **DESIGN_LEDGER** template in the same reference if missing): `Date` = today,
   `Feature`/`Slug`, `Type` = `new` for a new feature else `update`, `Summary` = one line,
   `Planned?` = `pending`, `Plan ref` = `—`. Never set `planned` here — that is `plan`'s job.

These are journaled in addition to the feature doc; they never replace `index.md`.

---

## PHASE 4: SUMMARY

After all files are written (or updated), present a final summary block. The
content differs between New Project Mode (table of created files, gaps
remaining, next steps) and Feature Mode (table of UPDATED/CREATED/UNCHANGED
files, impact summary, next steps).

For the exact summary blocks, see
[references/qna-examples.md](references/qna-examples.md).

In both modes, the final next step is: run `/ck-code:team` to generate the expert and
guide skills from these docs. Then `/ck-code:plan` generates epics and stories — it reads
`DESIGN_LEDGER.md` to pick up the `pending` rows this run added and flips them to `planned`.

---

## CONDITIONAL CONTENT

Not every section applies to every project. Within a feature doc, **omit** sections that
don't apply rather than leaving empty placeholders:

- **`## Data`** — omit if the feature touches no tables/entities.
- **`## API`** — omit if the feature exposes no endpoints (e.g., a pure CLI feature).
- **`## Flows`** — omit if there is no non-trivial flow to document.

For global docs:

- **`configuration.md`** — Skip if the project has no configuration files.
- **`_shared.md`** — Always create it (even if thin); it is the link target for feature
  docs and the destination for `doc-optimizer`'s dedup pass.

When skipping a **global** file, still list it in `README.md` with a note: "Not
applicable for this project."

---

## RULES

- **Never modify the original specification file** — it is read-only input.
- **Never invent information** — mark anything undetermined `[TO BE DEFINED]`.
- **Never mark a ledger row `planned`** from `design`; every added/changed feature leaves a `pending` row (Phase 3.11) — that is how `plan` knows what remains.
- **Never hardcode** — derive everything from the spec and the user's answers.
- **Always write project-specific content**, not generic prose; each file self-contained, cross-referenced where relevant.
- **Always output in English**, regardless of the spec's language.
