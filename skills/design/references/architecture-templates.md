# Architecture Document Templates

Reference templates for the files generated in Phase 3 of the design skill.
Use exactly as shown, filling placeholders with project-specific content derived
from the spec and user answers.

The architecture is **feature-scoped**: global docs describe the whole system, and
each feature owns a self-contained slice (`features/<slug>/index.md`) holding its own
components, APIs, data, and flows. Per-increment / per-fix changes are journaled as
dated delta docs beside it (`features/<slug>/YYYY-MM-DD_<id>_<short>.md`) while
`index.md` stays the canonical current truth. Cross-cutting infra lives once in `_shared.md`.
The retired layer docs (`components.md`, `api-contracts.md`, `database-schema.md`,
`data-flow.md`) are no longer generated — their content lives in feature docs.

---

## README.md (Index)

**File:** `docs/architecture/README.md`

```markdown
# Architecture Documentation

> Auto-generated from [original spec path] on [date]
> Original specification is the source of truth and was not modified.

## Global Documents

| Document                                   | Description                                                |
| ------------------------------------------ | ---------------------------------------------------------- |
| [overview.md](overview.md)                 | Project vision, goals, and target users                    |
| [folder-structure.md](folder-structure.md) | Complete project directory tree                            |
| [tech-stack.md](tech-stack.md)             | Languages, frameworks, and versions                        |
| [\_shared.md](_shared.md)                  | Cross-cutting infra: auth, base entities, shared utilities |
| [configuration.md](configuration.md)       | Config files, environment variables                        |
| [dev-guide.md](dev-guide.md)               | Prerequisites, setup, build, and run instructions          |

## Feature Documents

Each owns a self-contained slice; `FEATURE_INDEX.Docs` routes a story to one.

| Feature          | Document                                                             |
| ---------------- | -------------------------------------------------------------------- |
| [Feature 1 Name] | [features/feature-1-slug/index.md](features/feature-1-slug/index.md) |
| [Feature 2 Name] | [features/feature-2-slug/index.md](features/feature-2-slug/index.md) |

## Source

- **Original spec:** [path]
- **Generated:** [date]
- **Gaps remaining:** [count or "None"]

## Changelog

- [date] — [what feature doc was added/extended]
```

---

## overview.md

```markdown
# Project Overview

## Vision

[What the project does and the problem it solves - 1-2 paragraphs]

## Goals

- [Goal 1]
- [Goal 2]
- [Goal 3]

## Target Users

- [User type 1]: [what they do with the system]
- [User type 2]: [what they do with the system]

## Key Constraints

- [Constraint 1]
- [Constraint 2]

## Scope

### In Scope

- [Item]

### Out of Scope / Future

- [Item]
```

---

## folder-structure.md

```markdown
# Project Folder Structure

## Overview

[Brief explanation of how the project is organized]

## Directory Tree

[Complete ASCII tree with per-directory annotations]

## Key Directories Explained

### [directory]

[1-2 sentences: what it contains and why]

## Conventions

- [Naming convention for files]
- [Where tests live relative to source]
- [Where configuration goes]
```

**Important:** If the original spec already defines a folder structure, use it as the
base and refine/expand it. If not, propose one based on the tech stack and industry
best practices (research via context7/WebSearch if needed).

---

## tech-stack.md

```markdown
# Tech Stack

## Overview

| Layer   | Technology | Version   | Purpose           |
| ------- | ---------- | --------- | ----------------- |
| [Layer] | [Tech]     | [Version] | [Why this choice] |
| ...     | ...        | ...       | ...               |

## [Component/Layer Name]

### Language & Runtime

- **Language:** [language] [version]
- **Runtime:** [runtime if applicable]

### Frameworks

- **[Framework]** [version]: [purpose]

### Build Tools

- **[Tool]** [version]: [purpose]

### Key Libraries

| Library | Version | Purpose   |
| ------- | ------- | --------- |
| [lib]   | [ver]   | [purpose] |

## Shared / Cross-Cutting

### Communication

- **[Protocol]:** [where used, e.g., "between server and engine"]

### Serialization

- **[Format]:** [where used]

### Development Tools

- [Tool]: [purpose]
```

---

## features/&lt;slug&gt;/index.md (Feature Doc)

**File:** `docs/architecture/features/<slug>/index.md` — one per feature (= one epic).
Self-contained: holds everything a `build`/`fix` story for this feature needs, so the
story never opens another feature's doc. `<slug>` matches the epic folder slug so
`FEATURE_INDEX.Docs` can route to it. Per-increment / per-fix changes are journaled as
dated sibling docs (`features/<slug>/YYYY-MM-DD_<id>_<short>.md`, see template below);
`index.md` stays the canonical current truth that readers route to.

> **Relative links:** `index.md` sits two levels under `docs/architecture/`, so
> links to `_shared.md` and sibling globals use `../../` (e.g. `../../_shared.md`,
> `../../folder-structure.md`) — two hops up from `features/<slug>/` to
> `docs/architecture/`.

```markdown
# [Feature Name]

> Self-contained — a story reads this (+ folder-structure.md, + \_shared.md when noted), not other feature docs.

## Summary

[One paragraph: what this feature does and its boundary — where it ends and a
neighbouring feature or shared infra begins.]

## Components

[Components / services / modules OWNED by this feature, with responsibilities.
Omit shared infra — link to _shared.md under "Shared dependencies" instead.]

### [Component Name]

- **Type:** [service, module, UI, worker, etc.]
- **Purpose:** [1-2 sentences]
- **Responsibilities:**
  - [Responsibility]
- **Depends on:** [other components in this feature, or shared infra]

## API

[Endpoints / contracts this feature exposes or consumes. Feature-owned only.]

### [Endpoint / Action]

- **Direction / Method:** [GET /roles, Client → Server, etc.]
- **Description:** [what it does]
- **Request / Response:** [shape or schema]

## Data

[Tables / entities / migrations OWNED by this feature. Shared/base tables go in
_shared.md; reference them here.]

### [Table / Entity]

| Column | Type   | Constraints      | Description   |
| ------ | ------ | ---------------- | ------------- |
| [col]  | [type] | [PK/FK/NOT NULL] | [description] |

## Flows

[Key data/control flows internal to this feature.]

### [Flow Name]
```

Step 1: [Actor] → [Action] → [Component]
Step 2: [Component] → [Transform] → [Output]

```

## Shared dependencies
[Bullet links into _shared.md for cross-cutting pieces this feature relies on —
do not duplicate their content here.]
- [Auth middleware](../../_shared.md#auth--middleware)
- [Base User entity](../../_shared.md#base-entities--core-schema)

## Changelog
[Append-only write-back deltas from build/fix — newest last. Each line links the
dated delta doc that records the full change narrative.]
- [date] · [story id] — [one-line: component/endpoint/table/flow added or changed] · [./YYYY-MM-DD_<id>_<short>.md](./YYYY-MM-DD_<id>_<short>.md)
```

---

## features/&lt;slug&gt;/YYYY-MM-DD\_&lt;id&gt;\_&lt;short&gt;.md (Increment / Fix Delta Doc)

**File:** `docs/architecture/features/<slug>/YYYY-MM-DD_<id>_<short>.md` — one per
`build` story or `fix` that changed the feature's documented surface. Written by
`build` (Phase 8.6b) and `fix` (Phase 8.3b) **in addition to** updating `index.md`.
It is an append-only journal entry (the change narrative); it is NOT routed to by
readers — `index.md` always holds the consolidated current truth. `<id>` is the story
or bug ID; `<short>` is a 2–4 word kebab slug of the change.

```markdown
# [date] · [story/bug ID] — [short title]

> Delta journal for feature **[slug]**. The consolidated state lives in
> [index.md](./index.md); this file records what this one change added or altered.

## What changed

[1–3 sentences: the component/endpoint/table/flow added, changed, or removed.]

## Why

[1–2 sentences: the story goal or bug this addressed.]

## Surface touched

- **Components / API / Data / Flows:** [the matching `index.md` section(s) updated]
- **Shared:** [`../../_shared.md` section, if cross-cutting — else "none"]
```

---

## features/&lt;slug&gt;/YYYY-MM-DD_design\_&lt;short&gt;.md (Design Record)

**File:** `docs/architecture/features/<slug>/YYYY-MM-DD_design_<short>.md` — written by
`design` whenever it adds a new feature or designs a change to an existing one, **in
addition to** writing/updating `index.md`. It narrates what was designed and is the
human-readable companion to the matching `DESIGN_LEDGER.md` row. Append-only history;
NOT auto-read by `build`/`fix`. `<short>` is a 2–4 word kebab slug of the design.

```markdown
# [date] · design — [short title]

> Design record for feature **[slug]**. Consolidated state lives in
> [index.md](./index.md); this file records what this design pass added or changed.
> Ledger row: `docs/architecture/DESIGN_LEDGER.md`.

## Type

[new | update | fix] — [new feature / change to an existing feature / design-level fix]

## What was designed

[2–4 sentences: the components, APIs, data, or flows this design introduces or alters.]

## Why

[1–2 sentences: the goal or gap this design addresses.]

## Planning status

Not yet planned — listed as `pending` in `DESIGN_LEDGER.md`. `/ck-code:plan` turns
it into epics/stories and flips the ledger row to `planned`.
```

---

## DESIGN_LEDGER.md (Design → Plan Bridge)

**File:** `docs/architecture/DESIGN_LEDGER.md` — a single chronological ledger of every
design addition and whether it has been turned into a plan yet. `design` appends rows
(`pending`); `plan` reads it to find unplanned work and flips rows to `planned`. It
answers "what has been designed but not yet planned?" as a table lookup — build status
stays in `tasks/FEATURE_INDEX.md`, not here. Schema v1. The template and the columns
below are the single source — `plan` and `doc-optimizer` reference them, never redefine.

```markdown
# Design Ledger

<!-- AUTO-GENERATED by ck-code (design, plan, doc-optimizer). DO NOT EDIT BY HAND. -->
<!-- Schema: v1 -->

| Date       | Feature | Slug    | Type   | Summary                       | Planned? | Plan ref |
| ---------- | ------- | ------- | ------ | ----------------------------- | -------- | -------- |
| 2026-06-01 | Auth    | auth    | new    | JWT login + refresh tokens    | planned  | 02_auth  |
| 2026-06-10 | Billing | billing | update | add proration to plan changes | pending  | —        |
```

Column rules:

- **Date** — `YYYY-MM-DD` the design pass ran (matches the design-record filename).
- **Feature** / **Slug** — the feature display name and its `<slug>` (the feature-doc folder).
- **Type** — `new` | `update` | `fix` (new feature / change to an existing one / design-level fix).
- **Summary** — one line: what this design adds or changes.
- **Planned?** — `pending` (designed, not yet planned) | `planned` (an epic/plan now covers it). Never tracks build completion — that is `FEATURE_INDEX.Status`.
- **Plan ref** — the `tasks/<slug>` plan folder (or `NN_slug` epic) that planned it, set by `plan` when it flips the row to `planned`; `—` while `pending`.

Rows are append-only and ordered oldest-first. The two HTML comments are mandatory.
`design` appends a `pending` row per design pass; `plan` flips the matching row(s) to
`planned` and fills `Plan ref`; `doc-optimizer upgrade` scaffolds the file if missing,
backfilling already-built features as `planned`.

---

## \_shared.md

**File:** `docs/architecture/_shared.md` — cross-cutting infrastructure used by more
than one feature. Feature docs link here instead of duplicating it. `doc-optimizer
optimize` hoists content that appears in multiple feature docs into this file.

```markdown
# Shared / Cross-Cutting

> Infra used by multiple features. Feature docs link here instead of duplicating.
> A story reads this only when its feature doc's "Shared dependencies" points to a
> section here.

## Auth & middleware

[Authentication, authorization, guards, request middleware shared across features.]

## Base entities / core schema

[Tables/entities multiple features build on — User, Account, audit columns, etc.]

## Shared utilities & libraries

[Cross-cutting helpers, clients, error types, logging.]

## Conventions

[Project-wide patterns every feature follows — error handling, pagination, naming.]
```

---

## configuration.md

```markdown
# Configuration

## Configuration Files

### [file, e.g. server/config.toml]

**Purpose:** [what it configures] · **Format:** [TOML/JSON/YAML/ENV]

| Field   | Type   | Default   | Description   |
| ------- | ------ | --------- | ------------- |
| [field] | [type] | [default] | [description] |

## Environment Variables

| Variable   | Required | Default   | Description   |
| ---------- | -------- | --------- | ------------- |
| [VAR_NAME] | Yes/No   | [default] | [description] |

## Secrets

- [How secrets are handled; what must NEVER be committed]
```

---

## dev-guide.md

````markdown
# Developer Guide

## Prerequisites

| Software   | Version    | Install           |
| ---------- | ---------- | ----------------- |
| [Software] | [version]+ | [install command] |

## Setup

```bash
git clone [repo-url] && cd [project-name]
[build / install commands]
```

## Running

[Startup order, if it matters, then the command(s) to run each component.]

```bash
[run commands]
```

## Testing

```bash
[test commands per component]
```

## Troubleshooting

- **[Symptom]** — [fix]
````
