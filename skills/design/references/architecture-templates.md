# Architecture Document Templates

Reference templates for the files generated in Phase 3 of the design skill.
Use exactly as shown, filling placeholders with project-specific content derived
from the spec and user answers.

---

## README.md (Index)

**File:** `docs/architecture/README.md`

```markdown
# Architecture Documentation

> Auto-generated from [original spec path] on [date]
> Original specification is the source of truth and was not modified.

## Documents

| Document | Description |
|----------|-------------|
| [overview.md](overview.md) | Project vision, goals, and target users |
| [folder-structure.md](folder-structure.md) | Complete project directory tree |
| [tech-stack.md](tech-stack.md) | Languages, frameworks, and versions |
| [components.md](components.md) | Component descriptions and responsibilities |
| [data-flow.md](data-flow.md) | How data moves between components |
| [api-contracts.md](api-contracts.md) | API definitions (REST, WebSocket, gRPC, etc.) |
| [database-schema.md](database-schema.md) | Database tables, relations, and models |
| [configuration.md](configuration.md) | Config files, environment variables |
| [dev-guide.md](dev-guide.md) | Prerequisites, setup, build, and run instructions |

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

[Complete ASCII tree with annotations]

Example:
project-name/
├── component-a/             # [Purpose of this component]
│   ├── src/
│   │   ├── main.ext         # [Entry point description]
│   │   ├── module1/         # [Module purpose]
│   │   └── module2/         # [Module purpose]
│   ├── tests/
│   └── config.ext
├── component-b/             # [Purpose]
│   └── ...
├── shared/                  # [Shared code/types/protos]
│   └── ...
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

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| [Layer] | [Tech] | [Version] | [Why this choice] |
| ... | ... | ... | ... |

## [Component/Layer Name]

### Language & Runtime
- **Language:** [language] [version]
- **Runtime:** [runtime if applicable]

### Frameworks
- **[Framework]** [version]: [purpose]

### Build Tools
- **[Tool]** [version]: [purpose]

### Key Libraries
| Library | Version | Purpose |
|---------|---------|---------|
| [lib] | [ver] | [purpose] |

## Shared / Cross-Cutting

### Communication
- **[Protocol]:** [where used, e.g., "between server and engine"]

### Serialization
- **[Format]:** [where used]

### Development Tools
- [Tool]: [purpose]
```

---

## components.md

```markdown
# System Components

## Architecture Diagram

[ASCII diagram showing all components and their connections]

## Components

### [Component 1 Name]
- **Type:** [service, library, app, engine, etc.]
- **Technology:** [language/framework]
- **Purpose:** [what it does - 1-2 sentences]
- **Responsibilities:**
  - [Responsibility 1]
  - [Responsibility 2]
- **Exposes:** [APIs, ports, interfaces]
- **Depends on:** [other components or external services]

### [Component 2 Name]
...

## Component Interaction Matrix

| From \ To | Component A | Component B | Component C |
|-----------|-------------|-------------|-------------|
| Component A | - | [protocol] | - |
| Component B | [protocol] | - | [protocol] |
| Component C | - | [protocol] | - |
```

---

## data-flow.md

```markdown
# Data Flow

## High-Level Flow

[ASCII diagram showing the main data flow through the system]

## Detailed Flows

### [Flow 1 Name] (e.g., "User sends command from mobile")
```
Step 1: [Actor] → [Action] → [Component]
Step 2: [Component] → [Transform/Process] → [Component]
Step 3: [Component] → [Action] → [Output/Result]
```
**Payload:** [What data is sent at each step]
**Latency target:** [if specified]

### [Flow 2 Name]
...

## Message Formats

### [Message Type 1]
```json
{
  "field": "type and description",
  "field": "type and description"
}
```

### [Message Type 2]
...

## State Management
[How state is managed across components - databases, caches, in-memory, etc.]
```

---

## api-contracts.md

```markdown
# API Contracts

## [API Layer 1] (e.g., WebSocket API)

### Connection
- **Protocol:** [WebSocket/REST/gRPC]
- **Port:** [port]
- **Serialization:** [JSON/Protobuf/MessagePack]

### Endpoints / Actions

#### [Action/Endpoint 1]
- **Direction:** [Client → Server / Server → Client / Bidirectional]
- **Description:** [What it does]
- **Request:**
```
[Request format/schema]
```
- **Response:**
```
[Response format/schema]
```

#### [Action/Endpoint 2]
...

## [API Layer 2] (e.g., gRPC Internal API)

### Service Definition
```protobuf
[Proto definition or equivalent contract]
```

### Methods

#### [Method 1]
- **Description:** [What it does]
- **Request:** [Message type and fields]
- **Response:** [Message type and fields]

## Error Handling
- [Error code/type]: [When it occurs, how to handle]
```

---

## database-schema.md

```markdown
# Database Schema

## Overview
- **Database:** [Engine, e.g., SQLite, PostgreSQL]
- **ORM/Driver:** [e.g., sqlx, Prisma, TypeORM]
- **Location:** [Where DB is stored/hosted]

## Entity Relationship Diagram

[ASCII diagram showing table relationships]

## Tables

### [Table 1 Name]
**Purpose:** [What this table stores]

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | TEXT/INT | PK | [description] |
| name | TEXT | NOT NULL | [description] |
| ... | ... | ... | ... |

**Indexes:**
- [index description]

**Relations:**
- [FK relationship description]

### [Table 2 Name]
...

## Migrations
- **Strategy:** [How migrations are managed]
- **Location:** [Where migration files live]

## Seed Data
[If applicable, what initial data is needed]
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

```markdown
# Developer Guide

## Prerequisites

### Required Software
| Software | Version | Install Command |
|----------|---------|-----------------|
| [Software] | [version]+ | [install command] |

### Platform-Specific Prerequisites

#### [Platform 1]
```bash
[Installation commands]
```

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
