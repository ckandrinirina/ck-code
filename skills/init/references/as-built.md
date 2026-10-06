# As-Built Architecture — Discovery, Features, Template Deltas

How `init` (EXISTING mode) reads an existing codebase and writes the ck-code architecture
docs that describe it. The templates themselves belong to `design`
([architecture-templates.md](../../design/references/architecture-templates.md)). This file
only adds what changes when the input is code rather than a spec.

## Discovery

Phase 3 runs a bounded survey. Its job is the repo's shape and an inventory of what is
already written, not an understanding of every file. The per-feature agents read deeply
later.

### 1. Existing docs inventory (one probe)

```bash
find . -maxdepth 4 -type f \( -iname 'README*' -o -iname 'ARCHITECTURE*' -o -iname 'CONTRIBUTING*' -o -iname 'DESIGN*' -o -iname 'CLAUDE.md' -o -iname 'AGENTS.md' -o -iname 'openapi*.y*ml' -o -iname 'openapi*.json' -o -iname 'swagger*' -o -iname '*.graphql' -o -iname 'schema.prisma' -o -iname '*.proto' \) -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' 2>/dev/null | sort | head -40
find docs doc adr adrs documentation -type f \( -name '*.md' -o -name '*.mdx' -o -name '*.rst' -o -name '*.adoc' \) 2>/dev/null | sort | head -60
```

Classify each hit as **product** (vision, users, feature list), **architecture** (overview,
ADRs, diagrams), **contract** (OpenAPI, GraphQL, proto, DB schema, migrations), **ops**
(setup, deploy, config) or **agent** (`CLAUDE.md`, `AGENTS.md`, house conventions). Read the
root `README.md` always. Read the others only when they feed a doc Phase 5 writes, product
and architecture docs first. Pass contract files to the feature agents by path instead of
reading them here.

The inventory goes into the README `## Source` block (Template deltas) so a reader can find
the originals. `CLAUDE.md`/`AGENTS.md` conventions are a `/ck-code:team` input. Name them in
the summary, and never copy them into the architecture docs.

### 2. Repo shape (one probe)

```bash
git ls-files | awk -F/ 'NF>2{print $1"/"$2} NF==2{print $1"/"} NF==1{print "./"}' | sort | uniq -c | sort -rn | head -40
```

The file count per top-two-level directory: where the code lives, which folders are
modules, and whether this is a monorepo (`packages/*`, `apps/*`, `services/*`).

### 3. Manifests and stack

Read every manifest at the root and, in a monorepo, one level down: `package.json`,
`pyproject.toml`/`requirements*.txt`, `go.mod`, `Cargo.toml`, `pom.xml`/`build.gradle*`,
`Gemfile`, `composer.json`, `*.csproj`, `pubspec.yaml`, `mix.exs`. Take versions from the
manifest, or the lockfile when the manifest gives only a range. Then read at most one
framework config that changes the picture (`next.config.*`, `vite.config.*`,
`nest-cli.json`, `settings.py`, `docker-compose.yml`).

Build and run commands come from manifest scripts, `Makefile`, `justfile`, `Taskfile`, CI
workflows (`.github/workflows/*.yml`) and the README. Never invent one.

## Features

A **feature** is a cohesive, user- or caller-facing capability that owns its components.
It is never a technical layer: there is no "controllers" feature and no "database" feature.
`plan` later maps one feature to one epic, so use the slug an epic would carry.

Signals, strongest first. Use the first two that apply and cross-check them:

1. **A feature list in the project's own docs** (README "Features", a product doc, ADRs).
   Its names win the slugs.
2. **Domain or module folders**: `src/modules/*`, `src/features/*`, `app/<domain>/`,
   Django apps, Rails resource controllers, Go `internal/<domain>/`, monorepo `packages/*`.
3. **Route or handler groups**: API prefixes (`/auth`, `/billing`), GraphQL root fields, RPC
   services, CLI subcommands.
4. **UI pages or screens** grouped by the domain they serve.
5. **Data model clusters**: tables or entities that change together.

Sizing: aim for **3–12 features**. Over 15 means the grain is too fine, so group by
domain. A single feature that spans most of the code is too coarse, so split it along signal
2 or 3. Auth, base entities, shared middleware, the API client and design tokens that two
or more features use go to `_shared.md`, not into a feature.

Each row in the Phase 4 table: `slug` (short kebab case, reusing the docs' name when
there is one) · feature name · one-line boundary · owned paths (globs) · source doc, if any.

## Template deltas

Use every template verbatim except for these as-built changes.

| Where                            | Change                                                                                                                                                                                                                                                      |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Feature doc frontmatter          | `design: built`, never `pending`                                                                                                                                                                                                                            |
| Feature doc, under the H1        | `> Documented from code at <short-sha> by /ck-code:init.`                                                                                                                                                                                                   |
| Feature doc `## Components`      | each component names its source path in backticks (`src/auth/service.ts`)                                                                                                                                                                                   |
| Feature doc `## API` / `## Data` | from the route definitions and the schema or migrations actually present; each entry names its file                                                                                                                                                         |
| `README.md` header               | `> Documented from the codebase at <short-sha> on <date> by /ck-code:init.` and `> No specification was written; the code is the source of truth.` replace the spec lines                                                                                   |
| `README.md` `## Source`          | `- **Original spec:** none (as-built)` · `- **Source docs:** <inventory paths, or "none">` · `- **Generated:** <date>` · `- **Gaps remaining:** <count>`                                                                                                    |
| `overview.md`                    | Vision, Goals and Target Users come from the README or product docs only. Absent → `[TO BE DEFINED]`. `### In Scope` lists the features. `### Out of Scope / Future` is `[TO BE DEFINED]` unless a doc states it                                            |
| `folder-structure.md`            | the real tree (depth 2–3, from the repo-shape probe) and the conventions observed in it, never a proposed structure                                                                                                                                         |
| `tech-stack.md`                  | real versions from manifests and lockfiles, one `##` per component in a monorepo                                                                                                                                                                            |
| `configuration.md`               | the config files and environment-variable **names** found (`.env.example`, config modules, `process.env.X`, `os.environ`, `os.Getenv`). **Never a value from a real `.env` or a secret.** No config files → skip it as the template's conditional rule says |
| `dev-guide.md`                   | the commands discovered in Discovery § 3, as written in the project                                                                                                                                                                                         |

The size budget from `design`'s CONTENT SHAPE still binds: a feature doc ≤ 250 lines,
`_shared.md` ≤ 150.

## Feature agent

One dispatch per feature, all in one message: `general-purpose`, `model: sonnet`, no
isolation. Fill the `<…>` slots. `<plugin-root>` is the absolute path two levels above this
skill's base directory, since a subagent cannot resolve a relative link. Everything else is
verbatim.

```
You document ONE existing feature of this codebase as a ck-code architecture doc.

Feature: <name> (slug: <slug>) — <one-line boundary>
Owned paths: <globs>
Contract files to read if relevant: <OpenAPI/schema/migration paths, or none>
Source docs that describe it: <paths, or none>
Commit: <short-sha>

Read first, in this order:
1. docs/architecture/_shared.md — FROZEN; link to it, never restate it, never edit it
2. docs/architecture/folder-structure.md and tech-stack.md
3. <plugin-root>/skills/design/references/architecture-templates.md § Feature Doc — the template
4. <plugin-root>/skills/init/references/as-built.md § Template deltas — the as-built changes

Then read the owned source (entry points, routes, services, models, UI) and write exactly
one file: docs/architecture/features/<slug>/index.md (mkdir -p its folder).

Rules:
- Frontmatter `slug: <slug>` and `design: built`.
- Describe only what the code does. Every component, endpoint, table and flow names the file
  it was read from. Anything you cannot determine is [TO BE DEFINED]; never guess.
- Omit ## API, ## Data or ## Flows when they do not apply. Leave no template placeholder.
- Infra this feature uses from _shared.md goes under ## Shared dependencies as a link.
- ≤ 250 lines. Write no other file. Never commit.

Return exactly this JSON and nothing else:
{"slug":"<slug>","status":"ok|failed","path":"docs/architecture/features/<slug>/index.md",
 "lines":<n>,"gaps":["<section: what is undetermined>"],
 "shared_candidates":["<component/table/middleware also used outside this feature>"]}
```

## Summary

```
ck-code init — <MODE>
Project:   <repo name> @ <short-sha>
Layout:    tasks/VERSION.md → v7 (requires ck-code >= <MIN_PLUGIN>)
Guard:     .claude/ck-code-required.sh + .claude/settings.json — <installed | already current>

Dependencies
  <the table from dependencies.md § Report format>

Architecture (as built)          [EXISTING only]
  docs/architecture/README.md, overview.md, folder-structure.md, tech-stack.md,
  _shared.md, configuration.md, dev-guide.md
  features/<slug>/index.md × <n>   (design: built)
  Gaps: <n> [TO BE DEFINED] — <doc: section, …>
  Source docs read: <n> (listed in docs/architecture/README.md § Source)
  Archived: <docs/architecture/archive/…, or none>
  Shared candidates: <list → /ck-code:design optimize, or none>

Commit these (the guard does nothing until it is committed):
  tasks/VERSION.md  tasks/.gitignore  .claude/ck-code-required.sh  .claude/settings.json
  docs/architecture/                 [EXISTING only]

Settings: GitHub issues, trunk branch and board → /ck-code:config
Next: <the Phase 6 hand-off>
```

In EMPTY mode, add one line: `No code yet — init only set up the project. /ck-code:spec
(or /ck-code:design on a spec file) writes the architecture next.`
