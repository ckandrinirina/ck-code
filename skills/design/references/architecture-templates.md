# Architecture Document Templates

Reference templates for the files generated in Phase 3 of the design skill.
Use exactly as shown, filling placeholders with project-specific content derived
from the spec and user answers.

The architecture is **feature-scoped**: global docs describe the whole system, and
each feature owns a self-contained slice (`features/<slug>.md`) holding its own
components, APIs, data, and flows. Cross-cutting infra lives once in `_shared.md`.
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

These describe the whole system and are read on demand, not per story.

| Document                                   | Description                                                |
| ------------------------------------------ | ---------------------------------------------------------- |
| [overview.md](overview.md)                 | Project vision, goals, and target users                    |
| [folder-structure.md](folder-structure.md) | Complete project directory tree                            |
| [tech-stack.md](tech-stack.md)             | Languages, frameworks, and versions                        |
| [\_shared.md](_shared.md)                  | Cross-cutting infra: auth, base entities, shared utilities |
| [configuration.md](configuration.md)       | Config files, environment variables                        |
| [dev-guide.md](dev-guide.md)               | Prerequisites, setup, build, and run instructions          |

## Feature Documents

Each feature owns a self-contained slice (its components, APIs, data, and flows).
A `build`/`fix` story reads only its feature doc (+ `folder-structure.md`, + `_shared.md`
when noted) — never the whole architecture. The `tasks/FEATURE_INDEX.md` `Docs` column
routes a story to the right one.

| Feature          | Document                                                 |
| ---------------- | -------------------------------------------------------- |
| [Feature 1 Name] | [features/feature-1-slug.md](features/feature-1-slug.md) |
| [Feature 2 Name] | [features/feature-2-slug.md](features/feature-2-slug.md) |

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

[Complete ASCII tree with annotations]

Example:
project-name/
├── component-a/ # [Purpose of this component]
│ ├── src/
│ │ ├── main.ext # [Entry point description]
│ │ ├── module1/ # [Module purpose]
│ │ └── module2/ # [Module purpose]
│ ├── tests/
│ └── config.ext
├── component-b/ # [Purpose]
│ └── ...
├── shared/ # [Shared code/types/protos]
│ └── ...
├── docs/
├── scripts/
└── README.md

## Key Directories Explained

### component-a/

[2-3 sentences about what this contains and why]

### component-b/

[2-3 sentences]

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

## features/&lt;slug&gt;.md (Feature Doc)

**File:** `docs/architecture/features/<slug>.md` — one per feature (= one epic).
Self-contained: holds everything a `build`/`fix` story for this feature needs, so the
story never opens another feature's doc. `<slug>` matches the epic folder slug so
`FEATURE_INDEX.Docs` can route to it.

```markdown
# [Feature Name]

> Feature doc — self-contained. A story for this feature reads THIS file
> (+ folder-structure.md, + \_shared.md when noted), not the other feature docs.

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
- [Auth middleware](../_shared.md#auth--middleware)
- [Base User entity](../_shared.md#base-entities--core-schema)

## Changelog
[Append-only write-back deltas from build/fix — newest last.]
- [date] · [story id] — [one-line: component/endpoint/table/flow added or changed]
```

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

### [Config File 1] (e.g., server/config.toml)

**Purpose:** [What this configures]
**Format:** [TOML/JSON/YAML/ENV]
```

[Full example configuration with comments explaining each field]

```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| [field] | [type] | [default] | [description] |

### [Config File 2]
...

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| [VAR_NAME] | Yes/No | [default] | [description] |

## Platform-Specific Configuration

### [Platform 1] (e.g., macOS)
- [Specific config notes]

### [Platform 2] (e.g., Windows)
- [Specific config notes]

## Secrets Management
- [How secrets/credentials are handled]
- [What should NEVER be committed]
```

---

## dev-guide.md

````markdown
# Developer Guide

## Prerequisites

### Required Software

| Software   | Version    | Install Command   |
| ---------- | ---------- | ----------------- |
| [Software] | [version]+ | [install command] |

### Platform-Specific Prerequisites

#### [Platform 1]

```bash
[Installation commands]
```
````

#### [Platform 2]

```bash
[Installation commands]
```

## Setup

### 1. Clone the Repository

```bash
git clone [repo-url]
cd [project-name]
```

### 2. [Build/Install Step]

```bash
[commands]
```

### 3. [Next Step]

```bash
[commands]
```

## Running the Application

### Startup Order

[If order matters, explain why and list the order]

```bash
# Step 1: [description]
[command]

# Step 2: [description]
[command]
```

### Quick Start Script

```bash
[If applicable, a one-command start]
```

## Development Workflow

### Running Tests

```bash
[test commands per component]
```

### Debugging

- [How to enable debug mode]
- [Useful debug commands or tools]

### Code Style

- [Linting tools and commands]
- [Formatting tools and commands]

## Troubleshooting

### [Common Issue 1]

**Symptom:** [what you see]
**Fix:** [how to fix]

### [Common Issue 2]

...

```

```
