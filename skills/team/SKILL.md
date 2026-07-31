---
name: team
description: Use when a project has architecture docs and needs project-tailored expert skills and technology guides generated, refreshed, or audited; when capturing the project's house coding conventions into a guide every expert reads; or when creating or adjusting a custom expert or guide skill.
argument-hint: "[--basic|--standard|--max] [--check|--regenerate] [--conventions] [--new expert|guide <slug>] [--adjust <slug>] [--workflow]"
disable-model-invocation: true
effort: high
allowed-tools: Bash(ls*) Bash(mkdir*) Bash(git status*)
---

# Team — Project-Tailored Expert & Guide Skill Factory

Reads the project's architecture docs and generates specialized skills, each deeply
aware of the project's tech stack, patterns, folder structure, and conventions.

**What it produces (all project-level, in the user's `.claude/skills/`):**

- `expert-<role>/SKILL.md` — expert-persona skills, invoked as `/expert-<role>`
- `guide-<tech>/SKILL.md` — language/framework/library guides, auto-loaded by Claude
- `guide-conventions/SKILL.md` — the project's house-rules guide (offered inline at [2.4](#24-present-the-plan-and-settle-house-conventions); also `--conventions` alone)
- `guide-design-system/SKILL.md` — the project's Claude Design system contract. Generated **only** when `docs/architecture/design-system/index.md` exists; absent otherwise, and dropped by `--regenerate` once the user deletes that directory

**One skill, one top-level folder — never nest.** Claude Code discovers project skills at
`.claude/skills/<skill-name>/SKILL.md` and takes the command name from that directory, so a
file one level deeper (`skills/experts/frontend/`) is registered as nothing at all. The
folder name *is* the skill name, and it must match the frontmatter `name:`.

**Auto-loaded by:** `/ck-code:build` and `/ck-code:fix`. Re-run with `--regenerate`
after architecture or framework changes to refresh context and research — regeneration
is **merge-safe** (see [THE MERGE RULE](#the-merge-rule)); it never clobbers your edits.

## HARD GATES

- **PHASE 0 version gate** — inline below; BLOCK halts the skill.
- **Fan-out decision announced before producing units** (1.6a, 3.1) — count, compare to the
  threshold of 3, print the branch taken. Deciding after the units exist is a gate failure.

## PROGRESS TRACKING

Open a `TodoWrite` list as the **first action of Phase 0** — one todo per phase this run will
actually execute — then flip each to `in_progress` when it starts and `completed` when its
gate passes. Drop a phase that mode routing skips; never leave it pending. A long run's only
view into where it is comes from this list, so update it as you go and never batch the
updates to the end.

## PHASE 0: VERSION GATE

The stamp is injected at skill-load time — **do not spend a `Read` on it**:

Layout stamp: !`cat "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tasks/VERSION.md" 2>/dev/null || echo "ABSENT — no tasks/VERSION.md"`

Reads `layout: v5` → **PASS**, proceed. Anything else (including `ABSENT`) → run the
shared [version gate](../../references/version-gate.md) (HARD GATE) — it detects a pre-v5
layout, offers `/ck-code:migrate`, and stamps. Never read or write project state before
this PASSes.

## ROUTING CHECK (do first)

This skill turns **architecture docs** into expert + guide skills. If the request is
actually something else, STOP and recommend the better skill:

- No `docs/architecture/` exists yet → `/ck-code:design` (first)
- Breaking the architecture into epics/stories → `/ck-code:plan`

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:plan`.

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
- `--check` → audit which skills are missing/present **for the resolved tier**, then STOP (report only — never prompts).
- `--regenerate` → refresh all team-owned skills with fresh context + research, **merge-safe** (see below).
- `--conventions` → run **only** the house-rules capture → [PHASE C](#phase-c-conventions-capture). Not needed for a normal run: generation and `--regenerate` already offer it inline at [2.4](#24-present-the-plan-and-settle-house-conventions).
- `--new expert <slug>` / `--new guide <slug>` → scaffold a custom skill → [PHASE N](#phase-n-new-custom-skill).
- `--adjust <slug>` → edit one existing generated skill → [PHASE A](#phase-a-adjust).

A depth flag combines with `--check`/`--regenerate` (e.g. `--max --check`). `--conventions`,
`--new`, and `--adjust` route to their own phase and ignore the depth flag.

`--workflow` is orthogonal (opt-in): it runs the Phase 1.6a and 3.1 fan-outs as `Workflow` scripts —
enforced schemas, scripted retry, resume — when their ≥8 thresholds and the gate in
[`dynamic-workflows.md`](../../references/dynamic-workflows.md) are met; otherwise ignored.

## MODE ROUTING

- `--conventions` → [PHASE C](#phase-c-conventions-capture), then STOP.
- `--new …` → [PHASE N](#phase-n-new-custom-skill), then STOP.
- `--adjust …` → [PHASE A](#phase-a-adjust), then STOP.
- otherwise → the generation pipeline (Phase 0.5 → Phase 4), which settles house conventions
  inline at [2.4](#24-present-the-plan-and-settle-house-conventions)/[2.5](#25-capture-house-conventions-inline).

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
   preserved. This covers `guide-conventions`, every `--new` skill, and any file whose
   marker the user deleted.
3. **Present, marker found** → team-owned. On plain generation it already exists → skip.
   On `--regenerate` → refresh the body, re-emit the marker, and **re-insert verbatim**
   any block fenced by `<!-- ck-code:team MANUAL START -->` … `<!-- ck-code:team MANUAL END -->`.

So a user protects a whole file by removing its marker line, or protects an addition
inside a team-owned file by wrapping it in a MANUAL fence. `--conventions` and `--new`
never write the GENERATED marker, so their output is protected forever.

`guide-design-system` is the one exception to "regeneration only adds": when
`docs/architecture/design-system/` has been deleted, `--regenerate` **removes** it (rule 3
targets, marker present), because the directory's absence is the integration's off switch
and a stale guide would keep enforcing tokens that no longer have a source. A
`guide-design-system` whose marker the user removed is PROTECTED like any other file —
report it as preserved and let the user delete it.

---

## PHASE 0.5: DETECT EXISTING STATE

**Skip entirely if** no `expert-*` or `guide-*` skills exist yet → go straight to Phase 1
in ALL mode. Otherwise:

1. Quick-read `docs/architecture/tech-stack.md`.
2. Run the Phase 2.1/2.2 derivation, gated by TIER → build the **EXPECTED** list (a skill
   is EXPECTED only when the project has a real need for it at this tier).
3. Scan `.claude/skills/expert-*/` and `guide-*/` → build the **EXISTING** list, tagging each file
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
missing skills need; Phase 2.4 plans only missing skills; Phase 3 generates only those.

---

## PHASE 1: READ PROJECT CONTEXT

**Goal:** a complete understanding of the project to inject into each skill.

The reads in 1.2, 1.3, and 1.4 are independent — after 1.1 passes, issue them as **one
parallel tool-call message** (batched Reads + Globs/Greps), never three sequential rounds.

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

### 1.6a Parallel research (fan-out decision — make it before researching anything)

Each technology's research is independent, read-only, non-interactive. Count the step-1
technologies (MISSING-ONLY: only those the missing skills need) and announce the branch
before fetching a single doc. Below 3, research inline and say so. At **≥3**, dispatch one
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
inline before Phase 2.

**Workflow path (≥8 technologies + `--workflow`).** When the gate in
[`dynamic-workflows.md`](../../references/dynamic-workflows.md) passes, run this fan-out with the
`Workflow` tool instead, passing [`references/research.workflow.md`](references/research.workflow.md)
verbatim as `script` with `args = {technologies}`. It retries empty units itself (3 rounds); merge
`briefs`, research the returned `unresolved` ids inline. At 8+ without the flag, print the hint once.

---

## PHASE 2: DERIVE WHICH SKILLS TO GENERATE

**The intelligent core — not a lookup against a fixed list.** Read the Phase 1 context and
*derive* the experts and guides **this specific project** needs.

**Reuse Phase 0.5's derivation when it ran** — its EXPECTED list *is* this phase's output
for the same tier; carry it (and the MISSING-ONLY target set) into 2.3–2.4 instead of
re-deriving from scratch.

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

**Common anchor roles:** the catalog (role → slug → tier → generation signal) lives in
[`expert-templates.md` § Anchor-role catalog](references/expert-templates.md#anchor-role-catalog)
— start there, add project-specific roles as needed. Anchor roles use their per-role
delta; a **derived (project-specific) role** uses the generic
[base template](references/expert-templates.md#the-base-expert-template) filled from
project context + Phase 1.6 research.

### 2.2 Derive the guide set

Generate one guide per **significant technology actually in the stack** — derived from
`tech-stack.md` and the code, not a fixed language list. The bar is **"does this library
have an idiom that is easy to get wrong?"** — most best-practice surface lives in libraries
that are neither a language nor a framework, so they MUST be able to earn a guide.

- **Generate for:** the project's languages, major frameworks and protocols, and any
  library with non-trivial idiom — one that can be misused while still compiling and
  running (styling systems, i18n, state/data layers, client SDKs, forms/validation).
- **Skip idiom-free utilities** — if a newcomer could use it correctly from its signature
  alone (lodash, date-fns, uuid, dotenv), it needs no guide.
- **One guide owns one surface.** Technologies that ship as a single working surface get a
  **single combined guide**, never siblings that restate each other (React Native + Expo →
  one `guide-react-native`; a state library's docs live in its own guide, not repeated in
  the framework guide). Overlapping guides multiply load cost for zero new signal.

Guide **depth by tier** is defined once in [INPUT](#input). A library earns **one** guide,
owned by the expert whose code uses it — never a reason to mint a new expert (2.1). All
guide content comes from Phase 1.6 research; template:
[`references/guide-templates.md`](references/guide-templates.md).

`guide-conventions` is **not** derived here — it is captured at
[2.5](#25-capture-house-conventions-inline) and is a PROTECTED file (THE MERGE RULE).

### 2.3 Self-describing detection metadata (enables dynamic auto-load)

Because the set is derived — not a fixed list `build`/`fix` can hardcode — **every generated
skill describes its own auto-load triggers in frontmatter** so the consumers in
[`../../references/skill-detection.md`](../../references/skill-detection.md) can load it
without knowing its name:

- `paths:` — glob(s) for the files this skill owns (`server/**`, `**/*.rs`, `mobile/**`),
  derived from `folder-structure.md` and the tech's extensions.
- `keywords:` — Technical-Notes / story trigger words (`auth`, `migration`, `endpoint`).

`expert-qa`, `expert-analyst`, `expert-qa-project` set **no** triggers (always loaded).
Set `paths`/`keywords` on every other expert and every guide — and **never write
"always loaded" (or any always-on claim) into any other generated skill's description**:
the always-on set is exactly those three experts plus `guide-conventions`. Every extra
always-on skill is a permanent per-session token tax on `build`/`fix`.

### 2.4 Present the plan (and settle house conventions)

Show every skill to be generated (MISSING-ONLY: only missing ones), the trigger reason and
output path for each, plus which existing files are PROTECTED and will be preserved.

Probe `guide-conventions/SKILL.md` — reuse the Phase 0.5 state-table row when 0.5 ran, probe
directly when it was skipped. Then ask **both** questions in ONE **AskUserQuestion** call:

1. **Plan** — **Proceed** / **Adjust** / **Cancel**.
2. **House conventions** — options depend on the probe:
   - absent → **Capture now** (recommended) / **Skip**
   - present → **Keep as-is** (default) / **Refresh & merge**

On **Adjust**, let the user add/remove/customize, then re-ask question 1 only — carry the
conventions answer forward. On **Cancel**, STOP; nothing is captured. Layout:
[examples.md#plan-presentation-phase-24](references/examples.md#plan-presentation-phase-24).

### 2.5 Capture house conventions (inline)

**Capture now** / **Refresh & merge** → run [PHASE C](#phase-c-conventions-capture) here, before
any file is written, so every prompt is front-loaded and Phase 3 runs unattended.
**Skip** / **Keep as-is** → straight to Phase 3; record the choice for the 4.2 summary.

---

## PHASE 3: GENERATE ALL SKILLS

Experts and guides are generated in **one** pass — both are independent `SKILL.md` files, so
they share the single dispatch decision at 3.1.

### 3.0 Resolve the merge rule (orchestrator, before any write)

Apply [THE MERGE RULE](#the-merge-rule) to **every** target path — absent files are written,
PROTECTED files are preserved, team-owned files are refreshed only under `--regenerate`
(preserving MANUAL fences). MISSING-ONLY writes only the planned missing skills. What
survives this filter is the **write set**: every expert from 2.1 plus every guide from 2.2
that the rule cleared.

### 3.1 Dispatch decision (count the write set BEFORE writing anything)

Count the write set from 3.0 and announce the branch in one line
(`Fan-out: 9 skills ≥ 3 → dispatching 9 agents.`):

- **≥3 skills** → dispatch one `general-purpose` Agent per skill per the **artifact** variant
  in [../../references/subagent-fanout.md](../../references/subagent-fanout.md) —
  `model: sonnet` (each fills a frozen template from an already-resolved research slice) —
  experts and guides together, all in a single message. Give each: its resolved PROJECT
  CONTEXT BLOCK, its Phase 1.6 research slice, its template (3.2 for an expert, 3.3 for a
  guide), and the GENERATED-marker instruction; it writes exactly one file and nothing else.
- **<3 skills** → write them inline, following the same 3.2/3.3 contracts.

All prompts (0.5, 2.4), the 2.5 capture, and the 3.0 merge-rule resolution stay with the
orchestrator and are complete before dispatch; Phase 4.1 verifies centrally.

**Workflow path (≥8 skills + `--workflow`).** Same gate as 1.6a, using
[`references/generate.workflow.md`](references/generate.workflow.md) with `args = {projectContext,
skills}` — `skills` carries only paths the merge rule already cleared. Necessarily a **second,
separate** `Workflow` call: the 2.4/2.5 block sits between the two and a script can never prompt.
Regenerate every slug in the returned `missing` inline.

### 3.2 Expert content contract

Write `expert-<role>/SKILL.md` from the
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

### 3.3 Guide content contract

Write `guide-<tech>/SKILL.md` from
[references/guide-templates.md](references/guide-templates.md). Every section's content MUST
come from Phase 1.6 research (context7 or WebSearch) — if a section has no research data, run
WebSearch to fill it before writing. Resolve every placeholder, inject the real project
context block, set `user-invocable: false`, and emit the GENERATED marker as the first body
line.

**Size budget — a guide is a project idiom sheet, not a tutorial: ≤ 150 lines** (experts
≤ 120). Spend the budget on what is project-specific, version-specific, or easy to get
wrong *in this codebase*; link official docs for everything a framework tutorial would
cover. A guide that cannot fit is covering more than one surface — split the scope
decision back to 2.2, never pad the file. These skills are loaded into every `build`/`fix`
session that touches their paths: every line is a recurring cost.

### 3.4 Design-system guide contract (conditional)

**Skip entirely** when `docs/architecture/design-system/index.md` does not exist. That
absence is the integration's off switch — do not create the guide, do not mention it, do
not ask. Most projects have no design system and must see nothing.

When it exists, read it plus [`design-system.md`](../../references/design-system.md) and
write `.claude/skills/guide-design-system/SKILL.md` (GENERATED marker as the first body
line, `user-invocable: false`, same merge rule as every other guide):

```markdown
---
name: guide-design-system
description: Use when writing or changing UI in this project — components, styles, themes, or layout. Carries the project's Claude Design system tokens, component inventory, and the rules that keep generated UI exact against it.
paths: [UI globs derived from folder-structure.md and tech-stack.md]
keywords: [ui, component, style, css, theme, layout, design]
user-invocable: false
---

# Design System — [project name]

Cached at `docs/architecture/design-system/`. Refresh with `/ck-code:design ds`.

## Tokens
[the full ## Foundations table from index.md, verbatim]

## Components
[the full ## Components table from index.md, verbatim]

## Before implementing a component
[the three numbered steps from design-system.md § Component lookup order, verbatim]

## Rules
[the four rules from design-system.md § Fidelity rules, verbatim]
```

The tables are copied **verbatim**, never summarized: this guide is what sits in context
during a build, and a paraphrased token value produces wrong UI. It is therefore exempt
from the 150-line guide budget — an inventory is data, not prose, and truncating it
silently drops components. Derive `paths:` from the project's real UI locations (e.g.
`src/components/**`, `src/app/**/*.tsx`, `**/*.css`, `**/*.vue`); a `paths` match is the
authoritative load signal in
[`skill-detection.md`](../../references/skill-detection.md) Step 2.

---

## PHASE 4: POST-GENERATION

### 4.1 Verify

```bash
ls -la .claude/skills/expert-*/SKILL.md .claude/skills/guide-*/SKILL.md
```

This `ls` is the proof, never a subagent's or workflow manifest's self-report — a resumed workflow
replays cached results without re-writing, so a manifest entry can outlive its file. Write inline any
planned path it does not show.

### 4.2 Summary

Show every generated/refreshed expert and guide (tech focus/version, research source, sample
prompts), list any PROTECTED files that were preserved, note that guides auto-load while
experts are invoked directly, and state the 2.5 house-conventions outcome on its own line —
*captured* / *refreshed* / *preserved unchanged* / *skipped* (only when skipped, point at
`/ck-code:team --conventions`). Close with: re-run `/ck-code:team --regenerate` after
architecture changes, framework upgrades, or new tech — regeneration is merge-safe. Layout:
[examples.md#post-generation-summary-phase-42](references/examples.md#post-generation-summary-phase-42).

---

## PHASE C: CONVENTIONS CAPTURE

**Goal:** produce or refresh `guide-conventions/SKILL.md` from the project's real house
rules — the conventions research cannot supply. This file is PROTECTED: it never carries the
GENERATED marker, so `--regenerate` never touches it.

**Two entry points, never both in one run.** *Standalone* (`--conventions`) runs steps 1–4 in
full, then STOPs. *Inline* (from [2.5](#25-capture-house-conventions-inline)) applies the two
deltas marked below and continues to Phase 3.

1. **Infer from the code first** (so questions are concrete): sample 3–6 representative
   files per primary language (naming case, file/folder layout, import ordering, error
   style, comment density); read lint/format configs (`.eslintrc`, `rustfmt.toml`,
   `.prettierrc`, `ruff.toml`, `.editorconfig`) and any `CONVENTIONS.md`/`STYLE.md`/`CLAUDE.md`;
   note the architectural shape (layering, module boundaries).
   **Inline delta:** Phase 1.3 already located the source files, test layout, and lint/format
   configs — open only the sampled files and convention docs not yet read. Never re-scan.
2. **Confirm and fill gaps with the user.** Present what you inferred as a draft, then have
   the user confirm/correct and add rules the code cannot reveal. Cover: naming; file &
   folder structure; code style/formatting; architectural rules (layering, allowed/forbidden
   deps); preferred & banned libraries/patterns; project-specific must/never rules. **Capture
   only rules the user actually has** — never invent house rules to fill the template.
3. **Write** `guide-conventions/SKILL.md` from the
   [conventions template](references/guide-templates.md#guide-conventions-template):
   `user-invocable: false`, `paths: ["**/*"]`, **no GENERATED marker**. If it already exists,
   MERGE — keep sections the user did not change, update the rest. Every rule concrete, paired
   with a short correct/incorrect example where useful.
4. Report the rule areas covered; remind the user it auto-loads in `build`/`fix`, is read by
   every expert, and is safe from `--regenerate`.
   **Inline delta:** skip this report — Phase 4.2 states the outcome once.

## PHASE N: NEW CUSTOM SKILL

**Goal:** scaffold a custom skill `team` would not derive, in the namespaces `build`/`fix`
already scan. Its output is PROTECTED (no GENERATED marker).

1. Confirm slug, prefix (`expert-` or `guide-`), and a one-sentence purpose.
2. **Expert** → write `expert-<slug>/SKILL.md` from the
   [base template](references/expert-templates.md#the-base-expert-template): frontmatter
   (`name: expert-<slug>`, `description`, **plus `paths:`/`keywords:`** for auto-load), the
   resolved project context block, and the standard sections; the standards section must
   reference `/guide-conventions`.
3. **Guide** → write `guide-<slug>/SKILL.md` with `user-invocable: false`, a `paths` glob,
   and the conventions/patterns/anti-patterns the user dictates.
4. Set `paths`/`keywords` so `build`/`fix` auto-load it (see `skill-detection.md`); omit them
   only if the user wants it invoke-only (`/expert-<slug>`). Do **not** write the GENERATED
   marker — this file is hand-authored and permanent.

## PHASE A: ADJUST

**Goal:** refine one existing generated skill without a full regenerate.

1. Read the target (`expert-<slug>/SKILL.md` or `guide-<slug>/SKILL.md`) fully. If absent →
   report and STOP.
2. Confirm the exact change with the user (add a rule, revise a section, add an example). Make
   the **minimal targeted edit** — never rewrite the whole file. Preserve the project context
   block and frontmatter.
3. If the file is team-owned (GENERATED marker present) and the user wants the edit to survive
   `--regenerate`, wrap it in a `<!-- ck-code:team MANUAL START/END -->` fence — or move a
   durable house rule into `guide-conventions` (`--conventions`) instead.

---

## NEXT

- `/ck-code:plan <spec-file>` — break the architecture into epics, stories, and a roadmap.
- `/ck-code:team --conventions` — **only if 2.4 skipped it** — capture your project's own code
  structure, naming, style, and architectural rules into `guide-conventions`.

---

## RULES

- **Never generate a skill without Phase 1.6 research** — no stale or generic knowledge.
- **Never write the skill set inline when the 3.0 write set holds ≥3 files** — experts and guides share one dispatch decision (3.1), taken before the first file is written, never after the experts are already done.
- **Never overwrite a PROTECTED file** — one lacking the team GENERATED marker (`guide-conventions`, every `--new` skill, any file the user un-marked) is off-limits, even on `--regenerate`.
- **Regeneration is merge-safe** — refresh only team-owned files, and re-insert every `MANUAL` fence verbatim. Never clobber user edits.
- **Never mark a `--conventions` or `--new` file GENERATED** — those outputs are permanent.
- **Never invent conventions** — CAPTURE records only rules the user states or the code demonstrably follows; an empty area stays empty.
- **Never enter PHASE C twice in one run** — inline (2.5) and standalone (`--conventions`) are mutually exclusive entry points; inline never re-scans what Phase 1.3 already read, and no skill file is written until the 2.4 gate and 2.5 have both resolved.
- **Never ship a skill whose detection signal is absent**, whatever the tier: tier gates breadth, detection gates relevance.
- **Never exceed the size budget** — guides ≤ 150 lines, experts ≤ 120 (3.3); `guide-design-system` is exempt because its tables are verbatim data (3.4). Never generate overlapping guides for one surface (2.2), and never declare a generated skill always-on beyond `expert-qa`/`expert-qa-project`/`expert-analyst`/`guide-conventions` (2.3).
- **Never leave a `[bracketed placeholder]`** or an unresolved `[PROJECT CONTEXT BLOCK]` in a generated skill.
- **Never run a `Workflow` without the full opt-in gate** — tool present, explicit `--workflow` signal, and the phase's threshold met. Missing any one → the `Agent` path. The workflow path is never the only way a phase can execute.
- **Always keep this generator project-agnostic** — it reads project context dynamically and injects it.
- **Always output in English.**
