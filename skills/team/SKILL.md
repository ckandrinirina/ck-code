---
name: team
description: Use to generate project-tailored expert skills and technology guides (languages, frameworks, and idiomatic libraries) from architecture docs. Depth flag `--basic|--standard|--max` sets how many skills to generate (default `--standard`); `--check` audits only, `--regenerate` refreshes all.
argument-hint: "[--basic|--standard|--max] [--check|--regenerate]"
disable-model-invocation: true
effort: high
---

# Generate Experts — Project-Tailored Expert Skill Factory

Reads the project architecture documentation and generates a set of specialized
expert skills, each deeply aware of the project's tech stack, patterns, folder
structure, and conventions.

**What it produces:**

- `.claude/skills/experts/<role>/SKILL.md` — expert persona skills (invoked as `/expert-<role>`)
- `.claude/skills/guides/<tech>/SKILL.md` — language/framework guide skills (auto-loaded by Claude)

**Auto-loaded by:** `/ck-code:build` and `/ck-code:fix`. Re-run with
`--regenerate` after architecture or framework upgrades to refresh project
context and research.

## ROUTING CHECK (do first)

This skill turns **architecture docs** into expert + guide skills.
If the request is actually something else, STOP and recommend the better skill:

- No `docs/architecture/` exists yet → `/ck-code:design` (first)
- Capturing *house* conventions team can't research → `/ck-code:convention`

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:plan`.

## INPUT

`$ARGUMENTS` can include a path to the architecture docs folder (default:
`docs/architecture/`), one **depth flag**, and/or one **mode flag**.

**Depth flags** (how many skills to generate — see Phase 2's `Tier` column):

- `--basic` — core experts (`frontend`, `backend`, `qa`, `analyst`, `qa-project`)
  - one guide per detected language. Smallest set.
- `--standard` — **default.** Core + strongly-signalled specialists
  (`devops`, `security`, `database`) + language and major-framework guides.
- `--max` — every applicable expert AND every guide: all specialists
  (`performance`, `api`, `mobile`, `data`, `docs` — each still detection-gated),
  plus framework, protocol, and tooling guides.

The resolved tier is carried through Phases 0.5–3 as `TIER` and decides the
EXPECTED skill set everywhere. If no depth flag is passed, `TIER = standard`.

**Mode flags** (what to do with that set):

- `--check` — audit which skills are missing/present **for the resolved tier**, then stop (no generation)
- `--regenerate` — overwrite all previously generated skills with fresh versions

A depth flag and a mode flag can be combined (e.g. `--max --check` audits the full catalog).

---

## PHASE 0: VERSION GATE (hard gate)

Run the shared [version gate](../../references/version-gate.md) before any architecture-doc or `tasks/FEATURE_INDEX.md` read/write; on BLOCK (pre-v3), offer `/ck-code:doc-optimizer upgrade` and stop until it PASSes (or the user declines). `tasks/VERSION.md` = `layout: v3` is the cheap fast path. This runs unconditionally, before the detection step below.

---

## PHASE 0.5: DETECT EXISTING STATE

**Runs after the version gate. Skip entirely if:** `--regenerate` is set OR no skills exist yet.

```
skills_exist = any .claude/skills/experts/*/SKILL.md
             OR any .claude/skills/guides/*/SKILL.md

IF NOT skills_exist OR --regenerate:
  → Proceed to Phase 1 normally (generation mode: ALL)

IF skills_exist AND NOT --regenerate:
  1. Quick-read docs/architecture/tech-stack.md
  2. Run the Phase 2.1/2.2 derivation, gated by TIER → build EXPECTED skills list
     (a skill is EXPECTED only when the project has a real need for it at this tier)
  3. Scan .claude/skills/experts/ and .claude/skills/guides/ → build EXISTING list
  4. Compute:
       MISSING = EXPECTED − EXISTING
       EXTRA   = EXISTING − EXPECTED  (tech no longer detected)
  5. Show the state table (see references/examples.md#phase-0-state-table)
  6. IF --check flag → STOP (report only, no generation)
  7. IF MISSING is empty → inform user, suggest --regenerate if refresh needed → STOP
  8. IF MISSING is not empty → ask:
       A) Generate missing only
       B) Regenerate all
       C) Abort
     On A → Proceed to Phase 1 in MISSING-ONLY mode (target = MISSING list)
     On B → Proceed to Phase 1 in ALL mode
     On C → STOP
```

**MISSING-ONLY mode** is an internal flag carried through Phases 1–3: Phase 1.6
researches only the technologies needed for missing skills; Phase 2.4 shows only
missing skills in its plan table; Phase 3/3b generates only the missing skills.

**Externally-managed skills are never EXTRA.** `guides/conventions` and any expert
or guide created via `/ck-code:convention` are owned by that skill, not by `team`.
Exclude them from the EXTRA set and never overwrite them on `--regenerate` — they
hold hand-authored house rules that research-driven regeneration would destroy.

---

## PHASE 1: READ PROJECT CONTEXT

**Goal:** Build a complete understanding of the project to inject into each expert.

### 1.1 Validate Prerequisites

```
IF docs/architecture/ does NOT exist or is empty:
  → "No architecture docs found. Run /ck-code:design first to generate them."
  → STOP
```

### 1.2 Read the Global Architecture Docs

Expert/guide generation is driven by the project's tech stack and structure, which live
in the **global** docs — not in per-feature slices. Read these:

- `overview.md` — project vision, goals, users
- `folder-structure.md` — directory layout (the strongest signal for which experts apply)
- `tech-stack.md` — languages, frameworks, versions
- `_shared.md` — cross-cutting infra (auth, base entities, shared utils)
- `configuration.md` — config and env vars
- `dev-guide.md` — build, run, test instructions

Plus the `README.md` index to enumerate features. Do **not** read every
`features/<slug>/index.md` in full — skim a feature doc's `## Summary` only if `folder-structure.md`

- `tech-stack.md` leave a component type ambiguous. The retired layer docs
  (`components.md`, `api-contracts.md`, `database-schema.md`, `data-flow.md`) no longer
  exist; their content is in the feature docs and `_shared.md`.

Also read if available:

- `docs/specifications.md` or similar spec files

### 1.3 Scan Existing Codebase

Use Glob and Grep to understand:

- What source files exist and their languages
- Test file locations and testing frameworks used
- CI/CD configuration files
- Package manager files (package.json, Cargo.toml, CMakeLists.txt, etc.)
- Linting/formatting config files

### 1.4 Read Existing Plans (if any)

Check `tasks/` for existing epics and stories to give experts context on
what's planned vs. what's built.

### 1.5 Build Project Context Block

Compile everything into a structured context block injected into each
generated skill: project name, description, architecture type, components,
tech stack, key patterns, condensed folder tree, paths to architecture docs /
spec / task plans. For the exact shape, see
[references/examples.md#project-context-block-built-in-phase-15](references/examples.md#project-context-block-built-in-phase-15).

### 1.6 Research Current Best Practices (MANDATORY)

This step is **NOT optional**. Before generating ANY skill, research current
best practices for every detected technology. Full procedure lives in
[references/context7-research.md](references/context7-research.md).

Required steps:

1. Identify every language, framework, library, and tool from `tech-stack.md`
   and the codebase scan.
2. For each, resolve the library ID via context7 and fetch current docs
   (conventions, project structure, patterns, anti-patterns, performance,
   error handling, testing, version notes).
3. If context7 lacks coverage, supplement with WebSearch.
4. Compile results into a "Best Practices Knowledge" block — feeds both
   expert skills (for current advice) and guide skills (as their content).

---

## PHASE 2: DERIVE WHICH SKILLS TO GENERATE

**This is the intelligent core of the skill — not a lookup against a fixed list.**
Read the project context from Phase 1 and _derive_ the set of experts and guides
**this specific project** actually needs. Two categories are produced: **Expert
Roles** and **Language/Framework Guides**.

**Two non-negotiable principles:**

1. **Necessary only.** Generate a skill only when the project has a real,
   demonstrable area of work for it. A signal you can point to in the docs or
   codebase — not "most projects have one". If you cannot name the files,
   components, or requirements a skill would serve, do not generate it.
2. **Project-derived, not catalog-bound.** The lists below are **common anchors
   and examples**, never an exhaustive or mandatory set. Derive roles and guides
   from _this_ project's domain. A game engine may warrant `expert-graphics` /
   `expert-gameplay`; an embedded project `expert-firmware`; a fintech project
   `expert-compliance`; a blockchain project `expert-smart-contract`. Invent the
   role the project needs; never force a project into a predefined slot.

### 2.1 Derive the expert set

For each genuine **area of concern** in the project, generate one expert that owns
it. Identify areas of concern from: components in the feature docs and `_shared.md`,
top-level directories in `folder-structure.md`, the technologies in `tech-stack.md`,
and the requirements/targets in the spec. One expert per distinct area — split only
when two areas need genuinely different expertise; merge when one person would own both.

**`TIER` controls how finely you split, never whether to fabricate a need:**

- `--basic` — the minimal viable set: the few core roles the project's primary
  work demands, plus the always-on `expert-qa`, `expert-analyst`, `expert-qa-project`.
- `--standard` (default) — core **plus** every specialist the project clearly
  warrants (e.g. security when there is auth/secrets, database when there is a
  schema, devops when there is deployment).
- `--max` — the finest justified split: a dedicated expert for every distinct
  area, including domain-specific roles — but still **only where a real need exists**.

**Prefer a guide over an expert.** A single library or single cross-cutting concern
is almost always a **guide** (auto-loaded, cheap) folded under the expert that owns
the surrounding code — not its own expert. Litmus test:

- "How do I write idiomatic X?" → **guide-x**. Even at `--max`, do **not** mint
  `expert-analytics`, `expert-i18n`, `expert-styling`, or `expert-api` — these are
  guides under `expert-web`/`expert-backend`.
- "Who owns this whole subsystem end-to-end?" → **expert-x** — only a **distinct
  body of work** with its own files and lifecycle (a blockchain settlement pipeline,
  a separate mobile app, a data/ML pipeline). Cross-cutting _qualities_ like
  performance live in `expert-analyst` plus guides, not a standalone
  `expert-performance` — unless there is a dedicated perf workstream (benchmark
  suite, a latency budget with its own code).

**Common anchor roles** (start here, then add project-specific roles as needed).
Full templates: [`references/expert-templates.md`](references/expert-templates.md).

| Role               | Slug                 | Typical Tier | Generate when the project has…                                  |
| ------------------ | -------------------- | ------------ | --------------------------------------------------------------- |
| Frontend Developer | `expert-frontend`    | basic        | a UI/client component (web or mobile framework, UI directory)   |
| Backend Developer  | `expert-backend`     | basic        | a server/API/engine component                                   |
| QA Tester          | `expert-qa`          | basic        | always (testing)                                                |
| Code Analyst       | `expert-analyst`     | basic        | always (review)                                                 |
| Project Q&A        | `expert-qa-project`  | basic        | always (project knowledge)                                      |
| DevOps / Infra     | `expert-devops`      | standard     | deployment, CI/CD, Docker, cloud infra (lightweight if planned) |
| Security Engineer  | `expert-security`    | standard     | auth, secrets, crypto, payments, PII, or a public API surface   |
| Database Engineer  | `expert-database`    | standard     | a database, ORM, or migrations                                  |
| Performance Eng.   | `expert-performance` | max          | explicit latency/throughput targets, realtime, or heavy compute |
| API Designer       | `expert-api`         | max          | a public/external/versioned API contract surface                |
| Mobile Developer   | `expert-mobile`      | max          | a mobile app (React Native, Expo, Flutter, native iOS/Android)  |
| Data / ML Engineer | `expert-data`        | max          | a data pipeline, ETL, or ML/AI workflow                         |
| Technical Writer   | `expert-docs`        | max          | a docs site or user/developer documentation requirement         |

For an anchor role, use its template. For a **derived (project-specific) role**, use
the generic [`#derived-expert`](references/expert-templates.md#derived-expert) template
and fill it from the project context and Phase 1.6 research.

### 2.2 Derive the guide set

Generate one guide per **significant technology actually in the stack** — derived
from `tech-stack.md` and the codebase, not from a fixed language list. A technology
earns a guide when code is (or will be) written in it and getting it right is
non-trivial.

The bar is **"does this library have an idiom that is easy to get wrong?"** — not
"is it a language or a framework". Most of a project's best-practice surface lives
in libraries that are neither, so they MUST be able to earn a guide.

- **Generate for:**
  1. the project's **languages**;
  2. its major **frameworks** (Next.js, NestJS, React, React-Admin, Redux Toolkit…);
  3. major **protocols** it implements (gRPC, GraphQL…);
  4. **significant libraries with non-trivial idiom** — the category that was
     previously dropped. A library qualifies when using it well requires conventions
     a newcomer would not guess. Common kinds, with concrete examples:
     - **Styling systems** — Tailwind (utility ordering, design tokens, `@apply`
       misuse), CSS-in-JS.
     - **i18n** — i18next (namespace/key organization, interpolation, pluralization,
       lazy-loading).
     - **Analytics / feature flags** — PostHog (event-naming, capture conventions,
       flag patterns, PII).
     - **Client SDKs** — Firebase/FCM (SW setup, token lifecycle, fg/bg handling),
       auth SDKs (Web3Auth flows), blockchain libs (ethers/web3 signing, gas, nonce).
     - **State / data** — Redux Toolkit, React Query (cache keys, invalidation).
     - **Forms / validation** — react-hook-form + zod (resolver, schema patterns).
     - **Charts, maps, rich-text, file-upload** — any library with a real API idiom.
- **Skip only genuinely idiom-free utilities:** lodash, date-fns, uuid, dotenv,
  class-variance-authority, clsx, and plain build tools/bundlers/serializers. If a
  newcomer could use it correctly by reading its function signature, it needs no guide.

**Guide depth by tier:**

- `--basic` — one guide per detected **language** only.
- `--standard` — language guides **plus** one per detected **major framework** AND
  per **core daily-use library with strong idiom** (styling system, primary state
  library, i18n) — the libraries the team touches in almost every file.
- `--max` — the above **plus** major **protocols**, the primary **test framework**
  (`guide-testing`), a **tooling** guide when the build/tooling is non-trivial, AND
  **every remaining significant library with non-trivial idiom** (analytics/flags,
  push/SDK, auth SDK, blockchain lib, forms/validation, charts).

A library earns **one** guide, owned by the expert whose code uses it — it is never
a reason to mint a new expert (see the guide-over-expert rule in 2.1).

All guide content comes from Phase 1.6 research; the template is in
[`references/guide-templates.md`](references/guide-templates.md).
`guide-conventions` is **not** produced here — it is owned by `/ck-code:convention`
(see NEXT). `team` never creates or overwrites it.

### 2.3 Self-describing detection metadata (enables dynamic auto-load)

Because the expert/guide set is derived — not a fixed list `build`/`fix` can hardcode —
**every generated skill must describe its own auto-load triggers in frontmatter** so
the consumers in [`../../references/skill-detection.md`](../../references/skill-detection.md)
can load it without knowing its name in advance:

- `paths:` — glob(s) for the files this skill owns (e.g. `server/**`, `**/*.rs`,
  `mobile/**`). Derive from `folder-structure.md` and the technology's extensions.
- `keywords:` — Technical-Notes / story trigger words (e.g. `auth`, `migration`,
  `endpoint`, `shader`). Used when the touched-path globs do not fire.

`expert-qa`, `expert-analyst`, and `expert-qa-project` set no triggers — they are
always-relevant and loaded unconditionally by the consumers. Set `paths`/`keywords`
on every other expert and on every guide.

For the derivation worked through `TIER` and the EXPECTED-set rule (a skill enters
EXPECTED only when a real need exists for it at the resolved tier), this metadata is
what makes a dynamically-named expert discoverable later.

### 2.4 Present Plan

Show the user a plan listing every skill to be generated (in MISSING-ONLY mode:
only the missing skills), the trigger reason for each, and the output paths, then
ask **Proceed? YES / NO / ADJUST**. If ADJUST, let the user add/remove or
customize. For the exact layout, see
[references/examples.md#plan-presentation-phase-24](references/examples.md#plan-presentation-phase-24).

---

## PHASE 3: GENERATE ALL SKILLS

**Goal:** Create each expert skill AND language/framework guide with
project-specific context, role-specific instructions, and researched best
practices.

### Check for Existing Skills

Phase 0.5 handles the full detection and user prompt. By the time Phase 3 runs,
the generation mode is already set:

- **ALL mode** (no existing skills, or user chose "Regenerate all"): generate every planned skill, overwriting any that exist.
- **MISSING-ONLY mode** (user chose "Generate missing only"): skip any skill whose output file already exists.
- **REGENERATE mode** (`--regenerate` flag): overwrite all existing skills unconditionally.

### 3.1 Generate each EXPECTED expert

For every expert in the Phase 2 EXPECTED set (respecting the generation mode
above), write `.claude/skills/experts/<role>/SKILL.md`. Pick the template from
[references/expert-templates.md](references/expert-templates.md):

- **Anchor roles** map to a named template:
  - core: `#frontend-expert`, `#backend-expert`, `#qa-expert`, `#analyst-expert`, `#qa-project-expert`
  - standard: `#devops-expert`, `#security-expert`, `#database-expert`
  - max: `#performance-expert`, `#api-expert`, `#mobile-expert`, `#data-expert`, `#docs-expert`
- **Derived (project-specific) roles** use the generic `#derived-expert` template,
  filled from the project context and Phase 1.6 research.

When emitting any expert skill:

1. Resolve every `[bracketed placeholder]` from real project data and replace
   `[PROJECT CONTEXT BLOCK — injected from Phase 1.5]` with the actual block.
2. Inject relevant slices of the Phase 1.6 best-practices knowledge so advice is
   current and version-correct.
3. **Emit detection frontmatter** (Phase 2.3): set `paths:` and `keywords:` on
   every expert except the three always-on ones (`qa`, `analyst`, `qa-project`),
   which carry none.
4. Reference `/guide-conventions` in the Coding Standards section so the project's
   house rules (if present) override generic defaults.

### 3.1a Parallel generation (fan-out — when ≥4 skills remain)

Each expert/guide is one independent `SKILL.md` at its own path. When the generation mode is
settled and **≥4 skills remain**, dispatch one `general-purpose` Agent per skill per the artifact
variant in [../../references/subagent-fanout.md](../../references/subagent-fanout.md). Give each its
resolved PROJECT CONTEXT BLOCK (1.5), Phase 1.6 research slice, and template name; it writes exactly
one `experts/<role>/SKILL.md` (or `guides/<tech>/SKILL.md`) and nothing else. All prompts (Phase
0.5, 2.4) and `guide-conventions` stay with the orchestrator, before dispatch; Phase 4.1 still
verifies centrally. Below 4 skills, write inline.

---

## PHASE 3b: GENERATE LANGUAGE/FRAMEWORK GUIDE SKILLS

**Goal:** Create one guide skill per major technology, filled with current
best practices from the Phase 1.6 research.

For the guide skill template and the full guide-generation rules (research
first, code examples required, project-specific content, version-aware,
`user-invocable: false`, cross-reference experts), see
[references/guide-templates.md](references/guide-templates.md).

When emitting any guide skill: every section's content MUST come from Phase
1.6 research (context7 or WebSearch), not generic knowledge — if a section
has no research data, run WebSearch to fill it before writing the file.
Resolve every `[bracketed placeholder]`, replace the project context block
with the real one, and set `user-invocable: false` in the frontmatter.

---

## PHASE 4: POST-GENERATION

### 4.1 Verify All Files

After generating, verify each skill file was created:

```bash
ls -la .claude/skills/experts/*/SKILL.md .claude/skills/guides/*/SKILL.md
```

### 4.2 Present Summary

Show a summary of every generated expert and guide (tech focus / version,
research source, sample invocation prompts), note that guides auto-load while
experts are invoked directly, and close with regeneration guidance: re-run
`/ck-code:team --regenerate` after architecture changes, framework upgrades,
or new tech additions. For the exact layout, see
[references/examples.md#post-generation-summary-phase-42](references/examples.md#post-generation-summary-phase-42).

---

## NEXT

- Run `/ck-code:convention` to capture your project's own conventions (code
  structure, naming, style, architectural rules) into a `guide-conventions`
  skill that every expert reads — or to create/adjust custom experts and guides
  the research-driven generator does not produce.
- Run `/ck-code:plan <spec-file>` to break the architecture into epics, stories, and a roadmap.

---

## IMPORTANT GUIDELINES

- **Research is MANDATORY.** Phase 1.6 (context7/WebSearch research) MUST run
  before any skill generation. Never generate skills from stale or generic
  knowledge.
- **Project-specific content:** Each skill MUST contain real project details
  (tech stack, file paths, patterns), NOT generic placeholders. The
  `[PROJECT CONTEXT BLOCK]` must be fully resolved with actual project data.
- **No hardcoding in this skill:** This generator skill itself is
  project-agnostic. It reads the project context dynamically and injects it
  into the generated skills.
- **Tech stack adaptation:** Only generate skills relevant to the project. A
  pure backend CLI tool doesn't need a frontend expert or React guide.
- **Tier gates breadth, detection gates relevance:** a skill ships only when its
  detection signal fires AND its Tier ≤ the resolved `TIER`. Never generate a
  specialist whose signal is absent just because `--max` was passed.
- **Never touch convention-owned skills:** `guide-conventions` and any expert/guide
  created by `/ck-code:convention` are off-limits to `team` — never generate,
  overwrite, or flag them as EXTRA, even on `--regenerate`.
- **Consistency:** All generated experts reference the same architecture docs
  and follow the same format for easy maintenance.
- **Updatable:** When `--regenerate` is used, completely replace the expert
  skill files with fresh versions. Don't try to merge — full replacement is
  safer.
- **Language:** All output in English.
