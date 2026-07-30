# Architecture Document Templates

Reference templates for the files generated in Phase 3 of the design skill.
Use exactly as shown, filling placeholders with project-specific content derived
from the spec and user answers.

The architecture is **feature-scoped**: global docs describe the whole system, and
each feature owns a self-contained slice (`features/<slug>/index.md`) holding its own
components, APIs, data, and flows. `index.md` always holds the canonical current truth —
in v5 there are **no dated delta/journal docs and no `DESIGN_LEDGER.md`**; git is the
history and the feature-doc `design:` frontmatter flag is the design→plan bridge.
Cross-cutting infra lives once in `_shared.md`. The retired layer docs (`components.md`,
`api-contracts.md`, `database-schema.md`, `data-flow.md`) are no longer generated — their
content lives in feature docs.

## Conditional content

Within a feature doc, **omit** sections that don't apply rather than leaving empty
placeholders:

- **`## Data`** — omit if the feature touches no tables/entities.
- **`## API`** — omit if the feature exposes no endpoints (e.g. a pure CLI feature).
- **`## Flows`** — omit if there is no non-trivial flow to document.

For global docs:

- **`configuration.md`** — skip if the project has no configuration files.
- **`_shared.md`** — always create it (even if thin); it is the link target for feature
  docs and the destination for the `optimize` dedup pass.

When skipping a **global** file, still list it in `README.md` with a note: "Not applicable
for this project."

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
story never opens another feature's doc. `index.md` is the canonical current truth — v5
writes no dated delta/journal siblings. `<slug>` matches the epic folder slug so
`FEATURE_INDEX.Docs` can route to it.

The **YAML frontmatter is mandatory** (see [`data-model.md`](../../../references/data-model.md)):
`slug:` is the feature key; `design:` is `pending` when `design` has written/updated the doc
but `plan` has not yet turned it into epics/stories, and `planned` once `plan` has. `design`
always writes `pending`; only `plan` flips it to `planned`.

> **Relative links:** `index.md` sits two levels under `docs/architecture/`, so
> links to `_shared.md` and sibling globals use `../../` (e.g. `../../_shared.md`,
> `../../folder-structure.md`) — two hops up from `features/<slug>/` to
> `docs/architecture/`.

```markdown
---
slug: [slug]
design: pending
---

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
```

`index.md` holds current truth only — no per-change changelog. What changed and when is
recorded by git commits, not by the doc. `build`/`fix` in v5 write only story files, never
back into the feature doc.

---

## \_shared.md

**File:** `docs/architecture/_shared.md` — cross-cutting infrastructure used by more
than one feature. Feature docs link here instead of duplicating it. `design`'s `optimize`
mode hoists content that appears in multiple feature docs into this file.

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
