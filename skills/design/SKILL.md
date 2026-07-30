---
name: design
description: Use when turning a project spec or feature description into feature-scoped architecture docs under docs/architecture/ (a self-contained doc per feature + shared globals), or when maintaining those docs — `optimize` (token diet — dedup shared content into _shared.md) or `sync` (scaffold feature docs missing from FEATURE_INDEX). Argument is a spec path, or `optimize`/`sync`. Runs before `plan`.
argument-hint: "[path-to-spec | optimize | sync]"
effort: high
allowed-tools: Bash(ck-index*) Bash(git status*) Bash(mkdir*)
---

# Design — Architecture Documenter & Maintainer

Turn a specification into **feature-scoped** architecture documentation ready for
development, and keep that documentation cheap to read as the project grows.

The architecture is a few **global** docs (overview, folder-structure, tech-stack,
`_shared.md`, configuration, dev-guide) plus one **self-contained feature doc** per
feature at `docs/architecture/features/<slug>/index.md`. Each feature doc carries
frontmatter `slug: <slug>` and `design: pending`; a later `build`/`fix` story routes to
the one doc it needs. There are **no journal/delta docs and no `DESIGN_LEDGER.md`** in
v5 — git is the design history, and the `design:` flag (which `plan` flips to `planned`)
is the whole design→plan bridge. The retired layer docs (`components.md`,
`api-contracts.md`, `database-schema.md`, `data-flow.md`) are not generated — their
content lives in each feature's doc so a story reads only that doc.

**Four modes** (chosen by `$ARGUMENTS`):

- **New Project** (spec path, or empty) — generate global docs + one feature doc per feature.
- **Feature** (spec path, docs already exist) — add or extend one feature doc, globals kept consistent.
- **optimize** (maintenance) — measure per-doc tokens, dedup repeated content into `_shared.md`.
- **sync** (maintenance) — scaffold feature docs for features in `FEATURE_INDEX` that lack one.

## ROUTING CHECK (do first)

This skill turns a spec into **architecture docs** (before `plan`) and maintains them.
If the request is actually something else, STOP and recommend the better skill:

- No stakeholder spec yet and you want one → `/ck-code:spec` (first)
- Breaking work into epics/stories → `/ck-code:plan` (design comes first)
- Project is on a pre-v5 layout (nested team skills, layer/flat docs, no frontmatter) → `/ck-code:migrate`

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:team`.

**Reuse-first:** read the existing docs & spec first, reuse before rebuilding, and design the
simplest thing that meets the requirement — see [`reuse-first.md`](../../references/reuse-first.md).

---

## PROGRESS TRACKING

Open a `TodoWrite` list as the **first action of Phase 0** — one todo per phase this run will
actually execute — then flip each to `in_progress` when it starts and `completed` when its
gate passes. Drop a phase that mode routing skips; never leave it pending. A long run's only
view into where it is comes from this list, so update it as you go and never batch the
updates to the end.

## PHASE 0: VERSION GATE (hard gate, inline)

The stamp is injected at skill-load time — **do not spend a `Read` on it**:

Layout stamp: !`cat "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tasks/VERSION.md" 2>/dev/null || echo "ABSENT — no tasks/VERSION.md"`

Reads `layout: v5` → **PASS**, proceed. Anything else (including `ABSENT`) → run the
shared [version gate](../../references/version-gate.md) (HARD GATE) — it detects a pre-v5
layout, offers `/ck-code:migrate`, and stamps. Never read or write project state before
this PASSes.

Applies in ALL modes, and runs **once, in the orchestrator** — never inside a fan-out subagent.

---

## MODE ROUTING

Read `$ARGUMENTS`:

- `optimize` → go to **PHASE O** (skip the design flow).
- `sync` → go to **PHASE S** (skip the design flow).
- a spec path, or empty → the **design flow** below (New Project / Feature).

A maintenance mode is a hard scope — never run `optimize`/`sync` work in a design run, or
vice versa.

---

## INPUT (design flow)

Spec file path comes from `$ARGUMENTS`.

**If empty:** look for `docs/specifications.md`, `docs/spec.md`, `SPEC.md`,
`docs/requirements.md`. If found, confirm with the user. If not, ask whether to (A) give a
path or (B) be guided through creating one from scratch.

**If the file does not exist:** tell the user and ask for the correct path.

---

## EFFORT (design flow)

This skill pins `effort: high`: up to the full 5 Q&A rounds, research every named
technology via context7, and deep component/data-flow detail plus cross-cutting concerns
(scaling, failure modes, observability) in each doc. Depth never means length — the
size budget in CONTENT SHAPE below still binds.

---

## MODE DETECTION (New Project vs Feature)

Both probes below are independent — run them in **one parallel tool-call message** (or a
single batched Bash probe), never two round-trips:

1. Glob `docs/architecture/` — does it exist with files?
2. Check `tasks/` for prior plans, and the codebase for source beyond docs.

```
IF docs/architecture/ exists AND has files → FEATURE MODE
ELSE                                        → NEW PROJECT MODE
```

**Feature Mode entry:** present the existing-project **AskUserQuestion** gate (options
ADD FEATURE / FULL REFRESH / DIFFERENT PROJECT) from
[references/qna-examples.md](references/qna-examples.md) and branch:

- **ADD FEATURE:** read the architecture context per Phase 1.1b (globals + README index
  only — NOT every feature doc), read the spec, ask what feature to add, continue Phase 1
  feature-scoped.
- **FULL REFRESH:** back up existing docs to a timestamped sibling
  (`cp -r docs/architecture "docs/architecture.backup-$(date +%Y-%m-%d)"`), then proceed as
  New Project Mode.
- **DIFFERENT PROJECT:** proceed as New Project Mode.

---

## PHASE 1: READ & ASSESS THE SPECIFICATION

### 1.1 Read the Specification

Read the entire file. If it is non-English, process it in its original language but
produce all output in English.

### 1.1b (Feature Mode) Read Existing Architecture Context

BEFORE assessing coverage, token-frugally. Steps 1–2 are independent — issue the global-doc
Reads and the source Glob in **one parallel tool-call message**:

1. Read the global docs (`overview.md`, `tech-stack.md`, `folder-structure.md`,
   `_shared.md`) and the `README.md` index — **NOT** every feature doc. From the index,
   read only the feature doc(s) the new feature will integrate with.
2. Read existing source structure with Glob.
3. Build a model of what exists and what the new feature must integrate with.

New feature docs must be consistent with the existing architecture.

### 1.2 Assess Coverage

Score each of these 12 dimensions as CLEAR / PARTIAL / MISSING. A dimension the spec or an
existing doc already answers is CLEAR — reuse that answer; never manufacture a gap to fill:

Project vision & goals · Target users · System architecture · Folder structure · Tech stack & versions · Component breakdown · Data flow · API contracts · Database schema · Configuration · Build & run instructions · Non-functional requirements

### 1.3 Present Assessment

Show the coverage table, then ask — via **AskUserQuestion** (Start Q&A / Skip) — whether to
begin refinement. For the exact table block see
[references/qna-examples.md](references/qna-examples.md). On Skip, jump to Phase 3 and
generate using only what is available, marking gaps `[TO BE DEFINED]`.

---

## PHASE 2: CONVERSATIONAL REFINEMENT

Fill gaps and clarify ambiguities through adaptive questioning.

- Ask **2-3 questions per round** maximum; start with the highest-impact MISSING dimensions.
- For PARTIAL dimensions, target the vague parts. For CLEAR ones, do not re-ask — confirm and reuse.

### Question Sets

- **Feature Mode:** use the feature-scoped set (Scope & Integration, Architecture,
  Boundaries). Map impact into the **single feature doc** `features/<slug>/index.md`: new
  endpoints → `## API`, new tables → `## Data`, new components → `## Components`, new flows
  → `## Flows`. Truly cross-cutting infra (shared auth, base tables) goes in `_shared.md`
  and is linked from the feature doc.
- **New Project Mode:** use the priority-ordered bank (Architecture & Components → Tech
  Stack → Data Flow & APIs → Database & State → Configuration → Build & Run →
  Non-Functional).

Full wording of every question and the CLEAR/PARTIAL confirmation phrasing:
[references/qna-examples.md](references/qna-examples.md).

### Research During Refinement

When the user names specific technologies, use context7 (MCP, else `npx -y @upstash/context7`
CLI) or WebSearch to verify current structure conventions and recommended config patterns.

### Refinement Loop

After each round: summarize what was learned, check remaining gaps, ask the next round if
any. Maximum **5 rounds**; then generate, marking remaining gaps `[TO BE DEFINED]`.

---

## PHASE 3: GENERATE ARCHITECTURE DOCUMENTATION

### 3.1 Confirm Before Writing

Present the pre-generation plan (New Project vs Feature content) and confirm via
**AskUserQuestion** (Proceed / Adjust / Cancel). For the exact blocks see
[references/qna-examples.md](references/qna-examples.md).

### 3.2 Create Directory

```bash
mkdir -p docs/architecture
```

### (Feature Mode) Update Strategy

1. **Never delete or overwrite existing content.** Only add or extend.
2. **One feature = one doc.** Write/extend `docs/architecture/features/<slug>/index.md`
   from the Feature Doc template (`mkdir -p` the `<slug>/` folder first). New feature →
   Write the file with frontmatter `slug: <slug>` + `design: pending`; existing feature →
   Read it, Edit the relevant section, and set its frontmatter `design: pending` (design
   changed, so it is unplanned again until `plan` re-flips it). The `<slug>` matches the
   planned epic slug so the generated `FEATURE_INDEX.Docs` routes to it.
3. **Cross-cutting only** goes in `_shared.md`: infra 2+ features reuse — add it there and
   link it from the feature doc's `## Shared dependencies`; never duplicate it into the doc.
4. **README.md index:** add the new feature doc to the Feature Documents table.

### 3.3 – 3.10 Generate Each Architecture Document

Generate the files below in `docs/architecture/`. The exact template for each lives in
[references/architecture-templates.md](references/architecture-templates.md) — use it
verbatim, filling placeholders with project-specific content from the spec and answers.

First identify the **feature list** from the spec (the same features `plan` will turn into
epics). Each becomes one `features/<slug>/index.md` (frontmatter `slug` + `design: pending`).
Then generate:

| Step | File                                                                         | Template section                             |
| ---- | ---------------------------------------------------------------------------- | -------------------------------------------- |
| 3.3  | `README.md` (index)                                                          | README.md (Index)                            |
| 3.4  | `overview.md`                                                                | overview.md                                  |
| 3.5  | `folder-structure.md`                                                        | folder-structure.md                          |
| 3.6  | `tech-stack.md`                                                              | tech-stack.md                                |
| 3.7  | `_shared.md` (cross-cutting infra)                                           | \_shared.md                                  |
| 3.8  | `features/<slug>/index.md` — **one per feature**; take the [3.8a](#38a-feature-doc-dispatch-decision-new-project-mode--decide-before-writing-step-38) dispatch decision **first** | features/&lt;slug&gt;/index.md (Feature Doc) |
| 3.9  | `configuration.md`                                                           | configuration.md                             |
| 3.10 | `dev-guide.md`                                                               | dev-guide.md                                 |

**Feature list note:** derive features from the spec's capability breakdown. Pick a short
`<slug>` per feature (e.g. `roles`, `customer`, `billing`) and reuse it as the epic slug so
`FEATURE_INDEX.Docs` lines up. Put a component/table/endpoint in `_shared.md` (not a feature
doc) only when **two or more** features rely on it.

**folder-structure.md note:** see the **Important** note under its template — spec-defined
structure is the base; otherwise propose one from the tech stack.

### 3.8a Feature-doc dispatch decision (New Project Mode — decide before writing step 3.8)

Each `features/<slug>/index.md` is self-contained, so per-feature docs parallelize. On a New
Project run, author the globals AND `_shared.md` (steps 3.3–3.7) **first** so `_shared.md` is
frozen, then count the feature list and announce the branch **before writing any feature
doc** (`Fan-out: 5 features ≥ 3 → dispatching 5 agents.`):

- **≥3 independent features** → dispatch one `general-purpose` Agent per feature following
  [../../references/subagent-fanout.md](../../references/subagent-fanout.md) (artifact
  variant, `model: sonnet`), all in a single message. Pass each agent the frozen
  `_shared.md`, its `<slug>`, its spec slice, and `references/architecture-templates.md`
  (used verbatim); it writes ONLY its own `features/<slug>/` directory, with frontmatter
  `slug` + `design: pending`.
- **<3 features** → write them inline; say so in one line.

The orchestrator writes the shared `README.md` index rows once post-merge (never in a
subagent). Feature Mode extends one doc, so it always stays sequential.

### 3.11 Regenerate the feature index

After feature docs are written, regenerate the read-only views so `FEATURE_INDEX.Docs`
picks up any doc that matches an existing epic slug:

```bash
ck-index
```

At greenfield time there are no epics yet, so the script exits cleanly with nothing to
route; `plan` fills the `Docs` column when it creates the epics. In Feature Mode (epics
already exist) it resolves the new doc's `Docs` cell immediately. Never hand-edit an index.

---

## PHASE 4: SUMMARY

Present a final summary block (New Project: created files, gaps remaining, next steps —
Feature: UPDATED/CREATED/UNCHANGED files, impact, next steps). Exact blocks:
[references/qna-examples.md](references/qna-examples.md).

The final next step is: run `/ck-code:team` to generate the expert and guide skills from
these docs. Then `/ck-code:plan` reads each feature doc's `design: pending` flag to pick up
the unplanned work this run added and flips it to `planned`.

---

## PHASE O: OPTIMIZE (maintenance)

The token diet. Operates on the existing feature docs + `_shared.md` — never invents
content, only restructures and reports. Dedup rules and the token report format live in
[references/maintenance-playbook.md](references/maintenance-playbook.md).

1. **Detect state (read-only):** Glob `docs/architecture/*.md` and
   `docs/architecture/features/*/index.md`. If `docs/architecture/` does not exist, tell
   the user to run `/ck-code:design` first and stop.
2. **Measure** — report a per-doc token estimate (playbook format) and a total. Count the
   feature docs from step 1 and announce the branch **before measuring the first one**:
   at **≥3 feature docs**, dispatch one **read-only** `general-purpose` Agent per
   `features/<slug>/index.md` (investigation variant, `model: haiku`) per
   [../../references/subagent-fanout.md](../../references/subagent-fanout.md); each returns
   `{token estimate, candidate shared sections}` and writes nothing. Merge here. Below 3
   docs, measure inline. All writes stay sequential in the orchestrator.
3. **Dedup** — find content that appears in 2+ feature docs (shared components, base tables,
   common middleware). Move one canonical copy to `_shared.md` under the right heading and
   replace each occurrence with a link under `## Shared dependencies`. Keep feature-specific
   extensions in the feature doc — hoist only the shared core.
4. **Prune** — flag sections that are empty, stale `[TO BE DEFINED]`, or duplicate the global
   docs; remove redundant prose, keep tables/lists. Confirm (AskUserQuestion) before deleting
   any non-empty content.
5. **Right-size** — if a feature doc really covers two features, propose a split; on
   confirmation create the second doc + a note for the user to wire the new slug into `plan`.
6. **Reindex** — if any feature doc was created/renamed, run
   `ck-index` and update the `README.md` index.
7. Report before/after token totals per doc and the total saved (playbook format).

---

## PHASE S: SYNC (maintenance)

Bring the doc set into lockstep with `FEATURE_INDEX` — the "as the project grows" pass. This
does **not** do layout migration (flat→subfolder, legacy layer docs) — that is `/ck-code:migrate`.

1. **Detect state:** read `tasks/FEATURE_INDEX.md`. If missing or lacking the generated
   header, regenerate it (`ck-index`) then read it. If
   `docs/architecture/` does not exist, tell the user to run `/ck-code:design` and stop.
2. For each feature (epic) in `FEATURE_INDEX`, check whether
   `docs/architecture/features/<slug>/index.md` exists.
3. **Missing** → `mkdir -p features/<slug>/` and scaffold `features/<slug>/index.md` from the
   Feature Doc template (frontmatter `slug` + `design: pending`, header + section stubs + a
   `[TO BE DEFINED]` note), using the epic's description for `## Summary`. Do NOT invent
   component/API/data detail — leave stubs for a real `design`/`build` pass to fill.
4. **Slug drift** → if a feature doc exists under a different slug than its epic (e.g. design
   used `roles`, plan's epic is `role-management`), rename the `features/<slug>/` folder to
   the epic slug and fix inbound links. Confirm (AskUserQuestion) before renaming on
   ambiguous drift.
5. **Reindex** — run `ck-index` so each generated
   `FEATURE_INDEX.Docs` cell resolves to the doc, and update the `README.md` Feature
   Documents table.
6. Report: docs scaffolded, renamed, and any features still lacking real design content (the
   stubs) so the user knows what needs a `/ck-code:design` pass.

---

## CONTENT SHAPE

Which sections a doc includes (and when to omit one) is a template concern — follow
**Conditional content** in
[references/architecture-templates.md](references/architecture-templates.md).

**Size budget:** a feature doc is a lookup sheet a story reads before building, not a
spec — target **≤ 250 lines**; `_shared.md` **≤ 150**. Spend lines on contracts
(components, API shapes, data, flows) and cut narrative; a doc that cannot fit is covering
two features (split it — `optimize` step 5) or restating globals/`_shared.md` (link
instead). Every line here is re-read by every story that touches the feature.

---

## RULES

- **Never modify the original specification file** — it is read-only input.
- **Never write the feature docs inline when ≥3 features are in scope** (3.8a) — count and
  announce the dispatch decision before the first doc, never after the last. Same rule for
  the `optimize` measurement pass (PHASE O step 2).
- **Never invent information** — mark anything undetermined `[TO BE DEFINED]`; `sync`
  scaffolds stubs only, it does not author technical detail.
- **Never write a `DESIGN_LEDGER.md`, design-record, or dated delta/journal doc** — v5 has
  none; the feature-doc `design:` flag and git are the history. Every feature doc `design`
  writes or updates is left `design: pending`; `plan` flips it to `planned`.
- **Always relay `ck-index: WARN` lines** printed by `ck-index` — a skipped story is invisible in every generated view while its file still exists ([stories-index.md](../../references/stories-index.md)).
- **Never hand-edit a generated view** (`FEATURE_INDEX.md`, `STORIES_INDEX.md`) — change the
  feature docs / story frontmatter and regenerate with `ck-index`.
- **Never delete non-empty content in a maintenance run** without confirming first; `optimize`
  restructures and measures, it does not silently drop content.
- **Never hardcode** — derive everything from the spec and the user's answers.
- **Always write project-specific content**, each file self-contained and cross-referenced.
- **Always output in English**, regardless of the spec's language.
