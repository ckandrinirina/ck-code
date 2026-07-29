---
name: spec
description: Use when the user wants a stakeholder-ready feature specification (descriptive, no code, no file paths, no tooling jargon) before any design or architecture work, or wants to revise an existing spec identified by a slug or a GitHub issue URL. Produces a reviewable feature-spec document, optionally published as a GitHub issue, that `/ck-code:design` later consumes. Runs before `/ck-code:design`.
argument-hint: "[feature-description | notes-file | existing-slug | issue-url]"
effort: high
---

# Feature Spec

Stakeholder-ready feature specification: descriptive, no code, no file
paths, no tooling jargon. PMs, designers, and leadership can read,
comment, and validate before any architecture work begins.

The OUTPUT must avoid: code blocks, type definitions, schemas, file paths, internal tool
names, architectural primitives (Redis keys, locks, polling), "validated by X" lines, and
walls of `MUST`/`SHALL` directives.
The OUTPUT must include: numbered objectives, tables of rules and decisions, narrative
behaviors with concrete defaults inline, illustrative timelines at human granularity,
plain-language operational knobs, and an open "Next step" inviting comments from anyone.

## ROUTING CHECK (do first)

This skill drafts a **stakeholder-friendly spec** before any technical work.
If the request is actually something else, STOP and recommend the better skill:

- A spec already exists / ready for architecture → `/ck-code:design`
- One tiny tweak to an existing `tasks/` plan → `/ck-code:plan` (single-story `--quick` mode)

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:design`.

**Reuse-first:** read the existing project context first and surface only genuinely relevant
gaps — don't pad breadth or re-ask what's already clear. See
[`reuse-first.md`](../../references/reuse-first.md).

---

## STORAGE

Per-feature folder, shared with later design output:

```
docs/specs/YYYY-MM-DD_<slug>/
├── pre-spec.md       # this skill writes here
├── .metadata.json    # see references/templates.md for the schema
└── feature-spec.md   # (later) /ck-code:design output, adjacent
```

`.metadata.json#status` evolves through exactly three states:
`draft` → `ready-for-design` → `design-in-progress`.

Full schema, status meanings, and language localization table are in
[`references/templates.md`](references/templates.md).

---

## ROUTING — CREATE or ADJUST

Resolve `$ARGUMENTS` against on-disk state:

- **slug** → glob `docs/specs/*_<slug>/.metadata.json` → ADJUST
- **path** to `pre-spec.md` or its folder → ADJUST
- **issue URL or `#NNN`** → glob `.metadata.json` files for matching
  `github.issueUrl` → ADJUST if found; otherwise ask
- **empty** → if any `docs/specs/*/pre-spec.md` exist, list them and gate
  CREATE-vs-ADJUST with `AskUserQuestion`; else CREATE
- **free-text description / unknown path** → CREATE

---

## PHASE 0 — Version gate (HARD GATE)

Before reading or writing any project state: read `tasks/VERSION.md`. If it exists and
`layout: v4` → PASS, proceed. Otherwise run the shared [version gate](../../references/version-gate.md)
(HARD GATE) — it detects a pre-v4 layout, offers `/ck-code:migrate` via `AskUserQuestion`,
and stamps a clean/greenfield project. Do not read or write any spec state until it PASSes.

---

## PHASE 1 — Locate or capture intent

### CREATE branch

1. Get a 1-3 sentence feature description (from `$ARGUMENTS` or ask).
2. **Read project context** (don't invent — ask if missing). Every bullet below is an
   independent read — issue them all in **one parallel tool-call message**:
   - `CLAUDE.md` at repo root
   - Project memory at
     `~/.claude/projects/<encoded-path>/memory/MEMORY.md` and referenced
     files (memory may dictate where issues should be filed, label
     conventions, default branches — these take priority over inference)
   - `README.md`, `docs/SPEC.md`, `docs/specifications.md`,
     `docs/product/*`, `docs/functional-spec.md` if present
   - Glob `docs/architecture/*.md` (the global docs + `README.md` index) and
     `docs/specs/*/pre-spec.md`. Do NOT read every `docs/architecture/features/*/index.md`;
     open a single feature doc only when this spec extends that existing feature.
3. Propose a kebab-case ASCII slug from the feature name.
4. **Setup gate — one `AskUserQuestion` call**, skipping any question already
   unambiguous from context or `$ARGUMENTS`:
   - **Language** — English / French / Spanish / Other (used end-to-end).
   - **Audience** — Mixed / Product-focused / Technical reviewers (drop jargon
     for the first two; keep precision for the third).
   - **Output** — Local file only / GitHub issue only / Both.
   - **Slug** — `Use <proposed-slug>` / a custom kebab-case slug via Other.

### ADJUST branch

1. Read `.metadata.json` at the resolved folder; if missing/malformed,
   ask the user how to recover.
2. Read `pre-spec.md` and present a brief summary: title, language,
   status, dates, linked issue, list of section headings.
3. Ask "What would you like to change?" (open-ended input).

---

## PHASE 2 (CREATE only) — Refine

### Conflict + forgotten-details pass

If the project context contradicts the description, present the conflicts as a
table BEFORE Q&A, citing sources concretely:

```
| What you described | What the project says today | Decision needed |
```

Then resolve each with **`AskUserQuestion` — one question per conflict** (max 4),
options being the competing values (plus Other for a custom resolution). Never
guess a resolution silently.

Then list only the genuinely relevant things the user may have forgotten, tailored
to the feature category (typically a handful — don't pad to a count). Bank in
[`references/templates.md`](references/templates.md).

### Q&A refinement

Ask **2-3 focused questions per round** from the bank in
[`references/templates.md`](references/templates.md); skip dimensions already clear.
Cap at **3-4 rounds**; stop early when clear. After each round, summarize what was
learned in 1-2 sentences, then gate with **`AskUserQuestion`: Another round /
Proceed to generate**.

---

## PHASE 3 — Generate (CREATE) or apply edits (ADJUST)

### CREATE: generate the document

Generate `pre-spec.md` section-by-section following
[`references/templates.md`](references/templates.md), then write it locally (Phase 4).
A local Markdown write is safe and revertable — the setup gate already locked title,
slug, language, audience, and destinations, so no separate free-text confirmation is
needed. Section titles and prose render in the chosen language; section anchors stay
ASCII. The single external-action confirmation (GitHub) is the publish gate in Phase 4.

### ADJUST: iterative edits

Loop until the user is satisfied:

1. User describes a change in plain language.
2. Read current `pre-spec.md`.
3. Apply via `Edit`, anchored on stable text (headings, table rows).
4. Show a 1-3 line diff summary (paths and section titles only — do NOT
   echo full content).
5. Gate with **`AskUserQuestion`: Edit more / Done — persist**.

Editing rules:

- Keep section anchors stable.
- Maintain the chosen language end-to-end (full re-translation if the
  user changes language).
- Don't introduce technical jargon that wasn't there.
- Renumber sections if any are added/removed; check internal references.

---

## PHASE 4 — Persist

### Write local files

```
mkdir -p docs/specs/YYYY-MM-DD_<slug>/
write docs/specs/YYYY-MM-DD_<slug>/pre-spec.md
write docs/specs/YYYY-MM-DD_<slug>/.metadata.json   # CREATE: full; ADJUST: bump updatedAt
```

### Publish + readiness gate (one `AskUserQuestion` call)

- **If GitHub is a destination:** first show the issue title and the first ~30 lines
  of the generated body as a text preview. Then ask two questions in a single
  `AskUserQuestion` call:
  - **Publish** — Publish to GitHub / Skip GitHub for now / Edit locally first.
  - **Status** — Keep as draft / Mark ready-for-design.
- **If Local file only:** ask just the **Status** question (Keep as draft /
  Mark ready-for-design).

On **Mark ready-for-design**, set `status: "ready-for-design"` — this is the explicit
handoff signal `/ck-code:design` consumes.

### GitHub issue sync (when Publish is chosen)

Step-by-step procedure (target repo selection, label discovery, project
lookup, create-or-edit, project assignment) is in
[`references/templates.md`](references/templates.md) under "GitHub
publishing". Two key rules:

- **Always re-fetch** the issue body before editing
  (`gh issue view --json body --jq .body`) — UI edits may have happened.
- **Never recreate** an existing issue; always edit in place
  (`gh issue edit --body-file …`) to preserve comment history.

### Update metadata

- `updatedAt` = today
- `status` per the readiness gate above
- If labels/project changed, sync `tags` and `github.projectUrl`

---

## PHASE 5 — Summary

Brief block reporting:

- Slug, language, status
- Local file path
- Issue URL (if any), project URL (if any)
- 1-line tally of objectives / decisions / rules covered
- ADJUST: bulleted list of changes applied
- Hint about re-invocation: `/ck-code:spec <slug>` to adjust again

## NEXT

Once stakeholders sign off and the spec status is `ready-for-design`, run
`/ck-code:design <path-to-pre-spec.md>` to produce the architecture docs.

---

## CROSS-SKILL CONVENTION — feeding /ck-code:design

When the user marks the spec ready (Phase 4 readiness gate), `status` becomes
`ready-for-design`. `/ck-code:design` looks for `.metadata.json` files with that
status, treats the `pre-spec.md` as input, writes its output to `feature-spec.md`
in the same folder, sets `linkedDesign` accordingly, and bumps status to
`design-in-progress`.

---

## RULES

- **Never mention `/ck-code:*`, this skill, or any internal tooling** in the spec body.
- **Never invent** — when `CLAUDE.md`, `README.md`, or memory is missing, ask.
- **Never rename a slug or break issue sync** without confirmation — both silently break external links.
- **Never guess a conflict resolution** — every contradiction goes through the `AskUserQuestion` gate.
- **Always let user-saved memory override repo inference** for issue location, labels, and default branch.
- **Always write descriptively, not prescriptively** — `MUST`/`SHALL` only for non-negotiable product invariants.
