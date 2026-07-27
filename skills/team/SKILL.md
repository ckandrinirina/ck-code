---
name: team
description: Use when a project has architecture docs and needs project-tailored expert skills and technology guides generated, refreshed, or audited; when capturing the project's house coding conventions into a guide every expert reads; or when creating or adjusting a custom expert or guide skill.
argument-hint: "[--basic|--standard|--max] [--check|--regenerate] [--conventions] [--new expert|guide <slug>] [--adjust <slug>] [--workflow]"
disable-model-invocation: true
effort: high
---

# Team — Project-Tailored Expert & Guide Skill Factory

Reads the project's architecture docs and generates specialized skills, each deeply
aware of the project's tech stack, patterns, folder structure, and conventions.

**What it produces (all project-level, in the user's `.claude/skills/`):**

- `experts/<role>/SKILL.md` — expert-persona skills, invoked as `/expert-<role>`
- `guides/<tech>/SKILL.md` — language/framework/library guides, auto-loaded by Claude
- `guides/conventions/SKILL.md` — the project's house-rules guide (`--conventions` mode)

**Auto-loaded by:** `/ck-code:build` and `/ck-code:fix`. Re-run with `--regenerate`
after architecture or framework changes to refresh context and research — regeneration
is **merge-safe** (see [THE MERGE RULE](#the-merge-rule)); it never clobbers your edits.

## HARD GATES

- **PHASE 0 version gate** — inline below; BLOCK halts the skill.

## PHASE 0: VERSION GATE

Read `tasks/VERSION.md`. If it exists and `layout: v4` → **PASS**, proceed.
Otherwise run the shared [version gate](../../references/version-gate.md) (HARD GATE) —
it detects a pre-v4 layout, offers `/ck-code:migrate`, and stamps.

## ROUTING CHECK (do first)

This skill turns **architecture docs** into expert + guide skills. If the request is
actually something else, STOP and recommend the better skill:

- No `docs/architecture/` exists yet → `/ck-code:design` (first)
- Breaking the architecture into epics/stories → `/ck-code:plan`

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).

**Reuse-first:** generate only skills a real project signal demands, and research only
what is current, version-specific, or project-specific — never well-known fundamentals.
See [`reuse-first.md`](../../references/reuse-first.md).

## INPUT

`$ARGUMENTS` may include a path to the architecture docs folder (default
`docs/architecture/`), one **depth flag**, and one **mode flag/argument**.

### Depth flags — how much to generate (stated once; TIER carries through Phases 1–4)

Both axes below are gated by **real detection**: TIER gates *breadth*, detection gates
*relevance*. Never fabricate a need to fill a tier. Default is `--standard`.

| Flag | Expert breadth | Guide depth |
|---|---|---|
| `--basic` | the few core roles the primary work demands + always-on `qa`, `analyst`, `qa-project` | one guide per detected **language** |
| `--standard` | core **+** every specialist the project clearly warrants (security when auth/secrets, database when a schema, devops when deployment) | languages **+** major frameworks **+** core daily-use libraries with strong idiom (styling, primary state lib, i18n) |
| `--max` | the finest justified split — a dedicated expert per distinct area incl. domain-specific roles | the above **+** protocols, the primary test framework (`guide-testing`), a tooling guide when non-trivial, **every** remaining significant library with non-trivial idiom |

### Mode flags

- (none) → **GENERATE** the derived skill set (merge-safe: existing skills are handled per [THE MERGE RULE](#the-merge-rule)).
- `--check` → audit which skills are missing/present **for the resolved tier**, then STOP (no generation).
- `--regenerate` → refresh all team-owned skills with fresh context + research, **merge-safe** (see below).
- `--conventions` → **CAPTURE** the project's house rules into `guides/conventions` → [PHASE C](#phase-c-conventions-capture).
- `--new expert <slug>` / `--new guide <slug>` → scaffold a custom skill → [PHASE N](#phase-n-new-custom-skill).
- `--adjust <slug>` → edit one existing generated skill → [PHASE A](#phase-a-adjust).

A depth flag combines with `--check`/`--regenerate` (e.g. `--max --check`). `--conventions`,
`--new`, and `--adjust` route to their own phase and ignore the depth flag.

`--workflow` is orthogonal (opt-in): it runs the Phase 1.6a and 3.1a fan-outs as `Workflow` scripts —
enforced schemas, scripted retry, resume — when their ≥8 thresholds and the gate in
[`dynamic-workflows.md`](../../references/dynamic-workflows.md) are met; otherwise ignored.

## MODE ROUTING

- `--conventions` → [PHASE C](#phase-c-conventions-capture), then STOP.
- `--new …` → [PHASE N](#phase-n-new-custom-skill), then STOP.
- `--adjust …` → [PHASE A](#phase-a-adjust), then STOP.
- otherwise → the generation pipeline (Phase 0.5 → Phase 4).

## THE MERGE RULE

**Regeneration MERGES; it never clobbers.** This is what lets `--conventions`,
`--new`, and hand edits coexist with a research-driven regenerator. Ownership is by a
marker `team` writes as the first body line of every skill it generates:

```
<!-- ck-code:team GENERATED — /ck-code:team may overwrite this file on --regenerate. Delete this line to protect manual edits. -->
```

Per target path, in **every** generation and `--regenerate` run:

1. **Absent** → write it (emit the GENERATED marker).
2. **Present, marker missing** → **PROTECTED** — never overwrite. Skip and report as
   preserved. This covers `guides/conventions`, every `--new` skill, and any file whose
   marker the user deleted.
3. **Present, marker found** → team-owned. On plain generation it already exists → skip.
   On `--regenerate` → refresh the body, re-emit the marker, and **re-insert verbatim**
   any block fenced by `<!-- ck-code:team MANUAL START -->` … `<!-- ck-code:team MANUAL END -->`.

So a user protects a whole file by removing its marker line, or protects an addition
inside a team-owned file by wrapping it in a MANUAL fence. `--conventions` and `--new`
never write the GENERATED marker, so their output is protected forever.

---

## PHASE 0.5: DETECT EXISTING STATE

**Skip entirely if** no `experts/` or `guides/` skills exist yet → go straight to Phase 1
in ALL mode. Otherwise:

1. Quick-read `docs/architecture/tech-stack.md`.
2. Run the Phase 2.1/2.2 derivation, gated by TIER → build the **EXPECTED** list (a skill
   is EXPECTED only when the project has a real need for it at this tier).
3. Scan `experts/` and `guides/` → build the **EXISTING** list, tagging each file
   `owned` (GENERATED marker present) or `protected` (marker absent).
4. Compute `MISSING = EXPECTED − EXISTING`; `EXTRA = owned EXISTING − EXPECTED` (tech no
   longer detected). **Protected files are never EXTRA** — they are hand-authored.
5. Show the state table ([examples.md#phase-0-state-table](references/examples.md#phase-0-state-table)).
6. `--check` → STOP (report only).
7. `MISSING` empty → inform the user; suggest `--regenerate` if a refresh is wanted → STOP.
8. `MISSING` non-empty → ask via **AskUserQuestion** (single question, options):
   - **A) Generate missing only** → Phase 1 in MISSING-ONLY mode (target = MISSING).
   - **B) Regenerate all** → Phase 1 in REGENERATE mode (merge-safe per THE MERGE RULE).
   - **C) Abort** → STOP.

**MISSING-ONLY mode** carries through Phases 1–3: Phase 1.6 researches only the tech the
missing skills need; Phase 2.4 plans only missing skills; Phase 3/3b generates only those.

---

## PHASE 1: READ PROJECT CONTEXT

**Goal:** a complete understanding of the project to inject into each skill.

### 1.1 Validate prerequisites

If `docs/architecture/` is missing or empty → "No architecture docs found. Run
`/ck-code:design` first." → STOP.

### 1.2 Read the global architecture docs

Generation is driven by stack and structure, which live in the **global** docs:
`overview.md` (vision/users), `folder-structure.md` (the strongest signal for which
experts apply), `tech-stack.md` (languages/frameworks/versions), `_shared.md`
(cross-cutting infra), `configuration.md` (config/env), `dev-guide.md` (build/run/test),
and the `README.md` feature index. Do **not** read every `features/<slug>/index.md` in
full — skim a feature doc's `## Summary` only when structure + stack leave a component
type ambiguous. Read `docs/specifications.md` too if present.

### 1.3 Scan the codebase

Glob/Grep for: source files and languages; test locations and frameworks; CI/CD config;
package-manager files (`package.json`, `Cargo.toml`, …); lint/format config.

### 1.4 Read existing plans

Check `tasks/` for epics and stories to give experts planned-vs-built context.

### 1.5 Build the project context block

Compile everything into one structured block injected into each generated skill (name,
description, architecture type, components, tech stack, key patterns, condensed folder
tree, doc/spec/plan paths). Shape:
[examples.md#project-context-block-built-in-phase-15](references/examples.md#project-context-block-built-in-phase-15).

### 1.6 Research current best practices (MANDATORY)

**Not optional.** Before generating ANY skill, research current best practices for every
detected technology — scoped to what is **current, version-specific, and project-relevant**,
never padded basics. Full procedure: [references/context7-research.md](references/context7-research.md).

1. List every language, framework, library, and tool (`tech-stack.md` + codebase scan).
2. For each: resolve the context7 library ID and fetch current docs (conventions,
   structure, patterns, anti-patterns, performance, error handling, testing, version notes).
3. Where context7 lacks coverage, supplement with WebSearch.
4. Compile into a "Best Practices Knowledge" block feeding both experts (current advice)
   and guides (their content).

### 1.6a Parallel research (fan-out — when ≥4 technologies)

Each technology's research is independent, read-only, non-interactive. When step 1 lists
**≥4 technologies** (MISSING-ONLY: count only those the missing skills need), dispatch one
Agent per technology per the **investigation** variant in
[../../references/subagent-fanout.md](../../references/subagent-fanout.md) — `model: haiku`
(escalate one unit to `sonnet` only when its guidance needs a trade-off the docs fetch
cannot settle). Each agent runs steps 2–3 for its technology and **returns a structured
research brief** (typed, not prose) with these keys — it writes nothing:

```
technology, version, conventions[], structure, patterns[], anti_patterns[],
performance[], error_handling[], testing[], version_notes[], sources[]
```

The orchestrator merges the briefs into the single "Best Practices Knowledge" block (step
4), keeps verbose doc output out of its own context, and re-runs any failed/empty unit
inline before Phase 2. Below 4 technologies, research inline.

**Workflow path (≥8 technologies + `--workflow`).** When the gate in
[`dynamic-workflows.md`](../../references/dynamic-workflows.md) passes, run this fan-out with the
`Workflow` tool instead, passing [`references/research.workflow.md`](references/research.workflow.md)
verbatim as `script` with `args = {technologies}`. It retries empty units itself (3 rounds); merge
`briefs`, research the returned `unresolved` ids inline. At 8+ without the flag, print the hint once.

---

## PHASE 2: DERIVE WHICH SKILLS TO GENERATE

**The intelligent core — not a lookup against a fixed list.** Read the Phase 1 context and
*derive* the experts and guides **this specific project** needs.

**Two non-negotiable principles:**

1. **Necessary only.** Generate a skill only where the project has a real, demonstrable
   area of work — a signal you can point to in the docs or code. If you cannot name the
   files, components, or requirements it serves, do not generate it.
2. **Project-derived, not catalog-bound.** The anchors below are common examples, never a
   mandatory set. A game engine may warrant `expert-graphics`; embedded, `expert-firmware`;
   fintech, `expert-compliance`. Invent the role the project needs; never force a fit.

### 2.1 Derive the expert set

For each genuine **area of concern** (components in feature docs and `_shared.md`,
top-level dirs in `folder-structure.md`, tech in `tech-stack.md`, spec requirements),
generate one expert that owns it. Split only when two areas need genuinely different
expertise; merge when one person would own both. TIER (see [INPUT](#input)) sets how
finely to split — never whether to fabricate a need.

**Prefer a guide over an expert.** A single library or one cross-cutting concern is almost
always a **guide** folded under the expert that owns the surrounding code — not its own
expert. Litmus:

- "How do I write idiomatic X?" → **guide-x**. Even at `--max`, do **not** mint
  `expert-analytics`, `expert-i18n`, `expert-styling`, or `expert-api` — these are guides
  under `expert-web`/`expert-backend`.
- "Who owns this whole subsystem end-to-end?" → **expert-x** — only a distinct body of
  work with its own files and lifecycle. Cross-cutting *qualities* like performance live in
  `expert-analyst` + guides, not a standalone `expert-performance` — unless there is a
  dedicated perf workstream (benchmark suite, a latency budget with its own code).

**Common anchor roles** (start here, add project-specific roles as needed). Templates and
per-role deltas: [`references/expert-templates.md`](references/expert-templates.md).

| Role | Slug | Typical tier | Generate when the project has… |
|---|---|---|---|
| Frontend | `expert-frontend` | basic | a UI/client component (web or mobile framework, UI dir) |
| Backend | `expert-backend` | basic | a server/API/engine component |
| QA Tester | `expert-qa` | basic | always (testing) |
| Code Analyst | `expert-analyst` | basic | always (review) |
| Project Q&A | `expert-qa-project` | basic | always (project knowledge) |
| DevOps / Infra | `expert-devops` | standard | deployment, CI/CD, Docker, cloud infra |
| Security | `expert-security` | standard | auth, secrets, crypto, payments, PII, or a public API |
| Database | `expert-database` | standard | a database, ORM, or migrations |
| Performance | `expert-performance` | max | explicit latency/throughput targets, realtime, heavy compute |
| API Designer | `expert-api` | max | a public/external/versioned API contract surface |
| Mobile | `expert-mobile` | max | a mobile app (React Native, Expo, Flutter, native) |
| Data / ML | `expert-data` | max | a data pipeline, ETL, or ML/AI workflow |
| Technical Writer | `expert-docs` | max | a docs site or user/developer documentation requirement |

Anchor roles use their per-role delta; a **derived (project-specific) role** uses the
generic [base template](references/expert-templates.md#the-base-expert-template) filled from
project context + Phase 1.6 research.

### 2.2 Derive the guide set

Generate one guide per **significant technology actually in the stack** — derived from
`tech-stack.md` and the code, not a fixed language list. The bar is **"does this library
have an idiom that is easy to get wrong?"** — most best-practice surface lives in libraries
that are neither a language nor a framework, so they MUST be able to earn a guide.

- **Generate for:** the project's **languages**; its major **frameworks** (Next.js, NestJS,
  React, Redux Toolkit…); major **protocols** (gRPC, GraphQL…); and **significant libraries
  with non-trivial idiom** — styling systems (Tailwind, CSS-in-JS), i18n (i18next),
  analytics/flags (PostHog), client SDKs (Firebase/FCM, auth, blockchain), state/data
  (Redux Toolkit, React Query), forms/validation (react-hook-form + zod), charts/maps/
  rich-text/file-upload.
- **Skip only genuinely idiom-free utilities:** lodash, date-fns, uuid, dotenv, clsx, plain
  build tools. If a newcomer could use it correctly from its signature, it needs no guide.

Guide **depth by tier** is defined once in [INPUT](#input). A library earns **one** guide,
owned by the expert whose code uses it — never a reason to mint a new expert (2.1). All
guide content comes from Phase 1.6 research; template:
[`references/guide-templates.md`](references/guide-templates.md).

`guides/conventions` is **not** produced here — it is captured by
[`--conventions`](#phase-c-conventions-capture) and is a PROTECTED file (THE MERGE RULE).

### 2.3 Self-describing detection metadata (enables dynamic auto-load)

Because the set is derived — not a fixed list `build`/`fix` can hardcode — **every generated
skill describes its own auto-load triggers in frontmatter** so the consumers in
[`../../references/skill-detection.md`](../../references/skill-detection.md) can load it
without knowing its name:

- `paths:` — glob(s) for the files this skill owns (`server/**`, `**/*.rs`, `mobile/**`),
  derived from `folder-structure.md` and the tech's extensions.
- `keywords:` — Technical-Notes / story trigger words (`auth`, `migration`, `endpoint`).

`expert-qa`, `expert-analyst`, `expert-qa-project` set **no** triggers (always loaded).
Set `paths`/`keywords` on every other expert and every guide.

### 2.4 Present the plan

Show every skill to be generated (MISSING-ONLY: only missing ones), the trigger reason and
output path for each, plus which existing files are PROTECTED and will be preserved. Ask via
**AskUserQuestion**: **Proceed** / **Adjust** / **Cancel**. On Adjust, let the user
add/remove/customize, then re-ask. Layout:
[examples.md#plan-presentation-phase-24](references/examples.md#plan-presentation-phase-24).

---

## PHASE 3: GENERATE ALL SKILLS

Apply [THE MERGE RULE](#the-merge-rule) to **every** target path — absent files are written,
PROTECTED files are preserved, team-owned files are refreshed only under `--regenerate`
(preserving MANUAL fences). MISSING-ONLY writes only the planned missing skills.

### 3.1 Generate each expert

For every expert in the Phase 2 set, write `experts/<role>/SKILL.md` from the
[base template](references/expert-templates.md#the-base-expert-template) filled with the
role's [per-role delta](references/expert-templates.md#per-role-deltas) (anchor) or from
project context (derived). For each file:

1. Resolve every `[bracketed placeholder]` from real project data; replace
   `[PROJECT CONTEXT BLOCK]` with the actual Phase 1.5 block.
2. Inject the relevant Phase 1.6 best-practices slice so advice is current and version-correct.
3. Emit detection frontmatter (2.3): `paths:`/`keywords:` on every expert except the three
   always-on ones.
4. Reference `/guide-conventions` in the standards section so house rules override defaults.
5. Emit the GENERATED marker as the first body line (THE MERGE RULE).

### 3.1a Parallel generation (fan-out — when ≥4 skills remain)

Each skill is one independent `SKILL.md`. When ≥4 skills remain to write, dispatch one
`general-purpose` Agent per skill per the **artifact** variant in
[../../references/subagent-fanout.md](../../references/subagent-fanout.md) — `model: sonnet`
(each fills a frozen template from a resolved research slice). Give each: its resolved
PROJECT CONTEXT BLOCK, its Phase 1.6 research slice, its template + per-role delta, and the
GENERATED-marker instruction; it writes exactly one file and nothing else. All prompts
(0.5, 2.4) and the merge-rule decision stay with the orchestrator, before dispatch; Phase 4.1
verifies centrally. Below 4, write inline.

**Workflow path (≥8 skills + `--workflow`).** Same gate as 1.6a, using
[`references/generate.workflow.md`](references/generate.workflow.md) with `args = {projectContext,
skills}` — `skills` carries only paths the merge rule already cleared. Necessarily a **second,
separate** `Workflow` call: the 2.4 gate sits between the two and a script can never prompt.
Regenerate every slug in the returned `missing` inline.

## PHASE 3b: GENERATE GUIDE SKILLS

For each guide, write `guides/<tech>/SKILL.md` from
[references/guide-templates.md](references/guide-templates.md). Every section's content MUST
come from Phase 1.6 research (context7 or WebSearch) — if a section has no research data, run
WebSearch to fill it before writing. Resolve every placeholder, inject the real project
context block, set `user-invocable: false`, and emit the GENERATED marker as the first body
line.

---

## PHASE 4: POST-GENERATION

### 4.1 Verify

```bash
ls -la .claude/skills/experts/*/SKILL.md .claude/skills/guides/*/SKILL.md
```

This `ls` is the proof, never a subagent's or workflow manifest's self-report — a resumed workflow
replays cached results without re-writing, so a manifest entry can outlive its file. Write inline any
planned path it does not show.

### 4.2 Summary

Show every generated/refreshed expert and guide (tech focus/version, research source, sample
prompts), list any PROTECTED files that were preserved, note that guides auto-load while
experts are invoked directly, and close with: re-run `/ck-code:team --regenerate` after
architecture changes, framework upgrades, or new tech — regeneration is merge-safe. Layout:
[examples.md#post-generation-summary-phase-42](references/examples.md#post-generation-summary-phase-42).

---

## PHASE C: CONVENTIONS CAPTURE

**Goal:** produce or refresh `guides/conventions/SKILL.md` from the project's real house
rules — the conventions research cannot supply. This file is PROTECTED: it never carries the
GENERATED marker, so `--regenerate` never touches it.

1. **Infer from the code first** (so questions are concrete): sample 3–6 representative
   files per primary language (naming case, file/folder layout, import ordering, error
   style, comment density); read lint/format configs (`.eslintrc`, `rustfmt.toml`,
   `.prettierrc`, `ruff.toml`, `.editorconfig`) and any `CONVENTIONS.md`/`STYLE.md`/`CLAUDE.md`;
   note the architectural shape (layering, module boundaries).
2. **Confirm and fill gaps with the user.** Present what you inferred as a draft, then have
   the user confirm/correct and add rules the code cannot reveal. Cover: naming; file &
   folder structure; code style/formatting; architectural rules (layering, allowed/forbidden
   deps); preferred & banned libraries/patterns; project-specific must/never rules. **Capture
   only rules the user actually has** — never invent house rules to fill the template.
3. **Write** `guides/conventions/SKILL.md` from the
   [conventions template](references/guide-templates.md#guide-conventions-template):
   `user-invocable: false`, `paths: ["**/*"]`, **no GENERATED marker**. If it already exists,
   MERGE — keep sections the user did not change, update the rest. Every rule concrete, paired
   with a short correct/incorrect example where useful.
4. Report the rule areas covered; remind the user it auto-loads in `build`/`fix`, is read by
   every expert, and is safe from `--regenerate`.

## PHASE N: NEW CUSTOM SKILL

**Goal:** scaffold a custom skill `team` would not derive, in the namespaces `build`/`fix`
already scan. Its output is PROTECTED (no GENERATED marker).

1. Confirm slug, namespace (`experts/` or `guides/`), and a one-sentence purpose.
2. **Expert** → write `experts/<slug>/SKILL.md` from the
   [base template](references/expert-templates.md#the-base-expert-template): frontmatter
   (`name: expert-<slug>`, `description`, **plus `paths:`/`keywords:`** for auto-load), the
   resolved project context block, and the standard sections; the standards section must
   reference `/guide-conventions`.
3. **Guide** → write `guides/<slug>/SKILL.md` with `user-invocable: false`, a `paths` glob,
   and the conventions/patterns/anti-patterns the user dictates.
4. Set `paths`/`keywords` so `build`/`fix` auto-load it (see `skill-detection.md`); omit them
   only if the user wants it invoke-only (`/expert-<slug>`). Do **not** write the GENERATED
   marker — this file is hand-authored and permanent.

## PHASE A: ADJUST

**Goal:** refine one existing generated skill without a full regenerate.

1. Read the target (`experts/<slug>/SKILL.md` or `guides/<slug>/SKILL.md`) fully. If absent →
   report and STOP.
2. Confirm the exact change with the user (add a rule, revise a section, add an example). Make
   the **minimal targeted edit** — never rewrite the whole file. Preserve the project context
   block and frontmatter.
3. If the file is team-owned (GENERATED marker present) and the user wants the edit to survive
   `--regenerate`, wrap it in a `<!-- ck-code:team MANUAL START/END -->` fence — or move a
   durable house rule into `guides/conventions` (`--conventions`) instead.

---

## NEXT

- `/ck-code:team --conventions` — capture your project's own code structure, naming, style,
  and architectural rules into `guide-conventions` (read by every expert).
- `/ck-code:plan <spec-file>` — break the architecture into epics, stories, and a roadmap.

---

## RULES

- **Never generate a skill without Phase 1.6 research** — no stale or generic knowledge.
- **Never overwrite a PROTECTED file** — one lacking the team GENERATED marker (`guide-conventions`, every `--new` skill, any file the user un-marked) is off-limits, even on `--regenerate`.
- **Regeneration is merge-safe** — refresh only team-owned files, and re-insert every `MANUAL` fence verbatim. Never clobber user edits.
- **Never mark a `--conventions` or `--new` file GENERATED** — those outputs are permanent.
- **Never invent conventions** — CAPTURE records only rules the user states or the code demonstrably follows; an empty area stays empty.
- **Never ship a skill whose detection signal is absent**, whatever the tier: tier gates breadth, detection gates relevance.
- **Never leave a `[bracketed placeholder]`** or an unresolved `[PROJECT CONTEXT BLOCK]` in a generated skill.
- **Never run a `Workflow` without the full opt-in gate** — tool present, explicit `--workflow` signal, and the phase's threshold met. Missing any one → the `Agent` path. The workflow path is never the only way a phase can execute.
- **Always keep this generator project-agnostic** — it reads project context dynamically and injects it.
- **Always output in English.**
