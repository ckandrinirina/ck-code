---
name: pre-spec
description: >
  Use BEFORE /ck-code:design when a feature idea needs stakeholder review
  before any architecture work starts. Generates a descriptive,
  non-developer-friendly specification (locally and/or as a GitHub issue
  with labels and project assignment). Re-invoke on an existing slug or
  issue URL to apply adjustments — the skill edits the local file in place
  and re-syncs the linked GitHub issue. Once validated, the pre-spec feeds
  /ck-code:design.
argument-hint: "[feature-description | notes-file | existing-slug | issue-url]"
---

# Feature Pre-Spec

Stakeholder-ready feature specification: descriptive, no code, no file
paths, no tooling jargon. PMs, designers, and leadership can read,
comment, and validate before any architecture work begins.

The OUTPUT must avoid: code blocks, type definitions, schemas, file paths,
internal tool names, "validated by X" lines.
The OUTPUT must include: numbered objectives, tables of rules and
decisions, narrative behaviors with concrete defaults inline, an open
"Next step" inviting comments from anyone.

---

## STORAGE

Per-feature folder, shared with later design output:

```
docs/specs/YYYY-MM-DD_<slug>/
├── pre-spec.md       # this skill writes here
├── .metadata.json    # see references/templates.md for the schema
└── feature-spec.md   # (later) /ck-code:design output, adjacent
```

`.metadata.json#status` evolves: `draft` → `ready-for-design` →
`design-in-progress` → `implemented` → `shipped`.

Full schema, status meanings, and language localization table are in
[`references/templates.md`](references/templates.md).

---

## ROUTING — CREATE or ADJUST

Resolve `$ARGUMENTS` against on-disk state:

- **slug** → glob `docs/specs/*_<slug>/.metadata.json` → ADJUST
- **path** to `pre-spec.md` or its folder → ADJUST
- **issue URL or `#NNN`** → glob `.metadata.json` files for matching
  `github.issueUrl` → ADJUST if found; otherwise ask
- **empty** → if any `docs/specs/*/pre-spec.md` exist, list them and ask
  CREATE-vs-ADJUST; else CREATE
- **free-text description / unknown path** → CREATE

---

## PHASE 1 — Locate or capture intent

### CREATE branch

1. Get a 1-3 sentence feature description (from `$ARGUMENTS` or ask).
2. Ask **language** (default English). Use end-to-end.
3. Ask **audience**: A) mixed B) product-focused C) technical reviewers.
   Drop jargon for A/B; keep precision for C.
4. **Read project context** (don't invent — ask if missing):
   - `CLAUDE.md` at repo root
   - Project memory at
     `~/.claude/projects/<encoded-path>/memory/MEMORY.md` and referenced
     files (memory may dictate where issues should be filed, label
     conventions, default branches — these take priority over inference)
   - `README.md`, `docs/SPEC.md`, `docs/specifications.md`,
     `docs/product/*`, `docs/functional-spec.md` if present
   - Glob `docs/architecture/*.md` and `docs/specs/*/pre-spec.md`
5. Slugify the feature name to kebab-case ASCII; confirm if non-obvious.

### ADJUST branch

1. Read `.metadata.json` at the resolved folder; if missing/malformed,
   ask the user how to recover.
2. Read `pre-spec.md` and present a brief summary: title, language,
   status, dates, linked issue, list of section headings.
3. Ask "What would you like to change?"

---

## PHASE 2 (CREATE only) — Refine

### Conflict + forgotten-details pass

If the project context surfaced contradictions, present them BEFORE Q&A:

```
| What you described | What the project says today | Decision needed |
```

Cite sources concretely. Then list 5-12 things the user may have
forgotten, tailored to the feature category. Bank in
[`references/templates.md`](references/templates.md).

### Q&A refinement

Cap at **3-4 rounds, 2-3 questions per round**. Stop early when clear.
After each round summarize and ask if another round or proceed.

Question bank in [`references/templates.md`](references/templates.md).

---

## PHASE 3 — Generate (CREATE) or apply edits (ADJUST)

### CREATE: pre-generation confirmation

Show the planned title, slug, language, sections to include, and chosen
output destinations (local, GitHub issue, or both). Wait for explicit
YES.

Then generate the document section-by-section following
[`references/templates.md`](references/templates.md). Section titles and
prose render in the chosen language; section anchors stay ASCII.

### ADJUST: iterative edits

Loop until the user is satisfied:

1. User describes a change in plain language.
2. Read current `pre-spec.md`.
3. Apply via `Edit`, anchored on stable text (headings, table rows).
4. Show a 1-3 line diff summary (paths and section titles only — do NOT
   echo full content).
5. Ask "Anything else, or should I sync the issue?"

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

### GitHub issue sync (if applicable)

Step-by-step procedure (target repo selection, label discovery, project
lookup, preview confirmation, create-or-edit, project assignment) is in
[`references/templates.md`](references/templates.md) under "GitHub
publishing".

Two key rules:
- **Always re-fetch** the issue body before editing
  (`gh issue view --json body --jq .body`) — UI edits may have happened.
- **Never recreate** an existing issue; always edit in place
  (`gh issue edit --body-file …`) to preserve comment history.

### Update metadata

- `updatedAt` = today
- ADJUST: if user marks ready (e.g. "spec is locked"), set
  `status: "ready-for-design"`
- If labels/project changed, sync `tags` and `github.projectUrl`

---

## PHASE 5 — Summary

Brief block reporting:
- Slug, language, status
- Local file path
- Issue URL (if any), project URL (if any)
- 1-line tally of objectives / decisions / rules covered
- ADJUST: bulleted list of changes applied
- Hint about re-invocation: `/ck-code:pre-spec <slug>` to adjust again

---

## CROSS-SKILL CONVENTION — feeding /ck-code:design

When the user says the spec is locked, set `status: "ready-for-design"`.
`/ck-code:design` looks for `.metadata.json` files with that status,
treats the pre-spec as input, writes its output to `feature-spec.md` in
the same folder, sets `linkedDesign` accordingly, and bumps status to
`design-in-progress`. If the design skill isn't yet aware, manual
linking still works.

---

## IMPORTANT

- **No tooling self-promotion in the OUTPUT.** Never mention `/ck-code:*`,
  this skill, or any other internal tooling in the generated spec body.
- **Respect user-saved memory.** Memory entries about issue location,
  label conventions, default branches override inference from the
  current repo.
- **Never invent.** If `CLAUDE.md`, `README.md`, or memory isn't found,
  ask instead of guessing.
- **Don't break sync or rename slugs** without confirmation — both can
  silently break external links.
- **Tone is descriptive, not prescriptive.** Avoid "MUST"/"SHALL" unless
  the rule is a non-negotiable product invariant.
