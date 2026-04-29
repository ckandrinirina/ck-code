---
name: pre-spec
description: >
  Use BEFORE /ck-code:design when a feature idea needs stakeholder review
  before any architecture work starts. CREATES a descriptive, non-developer-
  friendly specification (locally and/or as a GitHub issue with labels and
  project assignment). RE-INVOKE on an existing pre-spec to adjust it — the
  skill detects existing specs, lets you pick one, applies your changes
  locally, and re-syncs the linked GitHub issue. Once validated, the pre-spec
  feeds /ck-code:design.
argument-hint: "[feature-description | notes-file | existing-slug | issue-url]"
---

# Feature Pre-Spec — Stakeholder-Ready Specification Generator & Editor

Turn a rough feature idea into a polished, descriptive specification that
stakeholders (product, design, engineering leadership, legal) can read,
comment on, and validate — **before** any architecture or implementation
work begins. Then iterate on it as feedback lands.

The output deliberately avoids:
- Code blocks, type definitions, schemas
- Internal tool names (slash commands, build scripts)
- File paths inside the repository
- Mentions of specific reviewers ("must be validated by X")

The output deliberately includes:
- Numbered objectives in plain language
- Tables of product rules and validated decisions
- Narrative descriptions of user-facing and behind-the-scenes behavior
- Plain-language summaries of configurable knobs (no env-var dumps)
- An open "Next step" closing inviting comments from anyone

---

## STORAGE LAYOUT

All feature specs (pre-spec stage AND later design output) live under a
**single per-feature folder**:

```
docs/specs/YYYY-MM-DD_<slug>/
├── pre-spec.md            # Descriptive stakeholder version (this skill)
├── .metadata.json         # Slug, GitHub issue, language, status, links
└── feature-spec.md        # (Later, optional) Design output from /ck-code:design
```

This keeps the pre-spec and any downstream artifacts adjacent. Other tools
(notably `/ck-code:design`) can detect a pre-spec by looking up
`.metadata.json` in this folder and use it as input.

`.metadata.json` schema:

```json
{
  "slug": "intelligent-bot-system",
  "title": "<full title used in the file and issue>",
  "language": "French",
  "createdAt": "2026-04-29",
  "updatedAt": "2026-04-29",
  "status": "draft",
  "github": {
    "repo": "owner/repo-name",
    "issueNumber": 809,
    "issueUrl": "https://github.com/owner/repo-name/issues/809",
    "projectUrl": "https://github.com/orgs/owner/projects/1"
  },
  "tags": ["..."],
  "stage": "pre-spec",
  "linkedDesign": null
}
```

`status` evolves: `"draft"` → `"ready-for-design"` → `"design-in-progress"`
→ `"implemented"` → `"shipped"`.
`linkedDesign` is set later (by `/ck-code:design` or manually) to point at
`feature-spec.md` once the design pass runs.

---

## ROUTING — CREATE vs. ADJUST

The skill has two modes. Detect which one to run from `$ARGUMENTS` and from
the on-disk state.

### Detection logic

```
1. If $ARGUMENTS looks like an existing slug:
   - Glob docs/specs/*_<slug>/.metadata.json
   - If exactly one match → ADJUST mode on that spec.
2. If $ARGUMENTS is a path to an existing pre-spec.md or its folder:
   - ADJUST mode.
3. If $ARGUMENTS is a GitHub issue URL or "#NNN":
   - Glob docs/specs/*/.metadata.json
   - Find the metadata.json whose github.issueUrl or github.issueNumber matches.
   - ADJUST mode if found; otherwise ask user (an issue not tracked locally).
4. If $ARGUMENTS is empty:
   - Glob docs/specs/*/pre-spec.md (and corresponding .metadata.json).
   - If any exist, ask:

     ```
     I found <N> existing pre-specs. What would you like to do?

     A) CREATE a new pre-spec
     B) ADJUST one of the existing pre-specs:
        1. <slug> — <title> (<status>)  [issue #NNN if linked]
        2. ...
     ```

   - If none exist, default to CREATE mode and ask for the feature description.
5. Otherwise (free-text feature description, file path to draft notes that
   doesn't yet have a slug) → CREATE mode.
```

---

## CREATE MODE

### Phase C1 — Capture intent & project context

#### Get the feature description

If `$ARGUMENTS` is empty (already covered in routing), ask:

```
What feature or capability do you want to scope?

Describe in 1-3 sentences:
- what it does
- who it's for
- (optional) the main reason you want it
```

If `$ARGUMENTS` is a file path, read the file and confirm intent in one
sentence.

#### Determine output language

```
What language should the spec be written in?
(default: English)

Examples: English, French, Spanish, ...
```

Use the answer for ALL output. Do not switch mid-document.

#### Determine target audience

```
Who will primarily read this spec?

A) Mixed (product + engineering + non-technical stakeholders)
B) Mostly product / business stakeholders (PM, designer, legal, exec)
C) Mostly technical reviewers (CTO, tech leads)
```

- A or B: drop technical jargon; favor plain narrative.
- C: keep precise terminology but still avoid implementation details
  (architecture is the next pass).

#### Read project context

Before content questions:

1. Read `CLAUDE.md` at repo root if present.
2. Read project memory at
   `~/.claude/projects/<encoded-project-path>/memory/MEMORY.md` and any
   files it references.
3. Read `README.md`, then any `docs/SPEC.md`, `docs/specifications.md`,
   `docs/product/*`, `docs/functional-spec.md` if present.
4. Glob `docs/architecture/*.md` if present.
5. Glob `docs/specs/*/pre-spec.md` for adjacent pre-specs that may inform
   this one.

Use this context to flag conflicts and reuse terminology in Phase C2.

### Phase C2 — Conflict flagging & forgotten-details pass

If reading project context surfaced contradictions or missing
considerations, present them BEFORE content Q&A.

```
## ⚠️ Tensions with existing project rules

| What you described | What the project says today | Decision needed |
|---|---|---|
```

Cite sources concretely (`CLAUDE.md`, `docs/SPEC.md §X.Y`, project memory).

After conflicts, list 5-12 things the user may have forgotten — tailored to
the feature category. See the bank in
[`references/templates.md`](references/templates.md).

### Phase C3 — Q&A refinement

Cap at 3-4 rounds, 2-3 questions per round. Stop early when clear. After
each round summarize and ask if another round or proceed.

Question bank in [`references/templates.md`](references/templates.md) under
"Question bank".

### Phase C4 — Pre-generation confirmation

Show:

```
## Pre-Spec to generate

**Feature:** <name>
**Slug:** <kebab-slug>
**Language:** <chosen>
**Audience:** <chosen>

**Sections to include:**
  Contexte, Objectif, [Hors-périmètre], [Décisions validées],
  Règles produit, Comportements détaillés, [Côté utilisateur],
  [Côté backend], [Impact technique minimal], Configurations clés,
  [Points à clarifier], Prochaine étape

**Output:**
  [ ] Local folder: docs/specs/YYYY-MM-DD_<slug>/
        - pre-spec.md
        - .metadata.json
  [ ] GitHub issue: <repo>
        Labels: <list>
        Project: <project-url-or-none>

Proceed? YES / ADJUST
```

Bracketed sections appear only when relevant. Wait for explicit YES.

### Phase C5 — Generate

#### Slugify

`<feature name>` → kebab-case ASCII slug (e.g. `intelligent bot system` →
`intelligent-bot-system`). Confirm with user if non-obvious.

#### Build the document

Follow [`references/templates.md`](references/templates.md) for the
section-by-section structure. Translate section titles to the chosen
language. Render in the chosen language end-to-end.

#### Write local files

```
mkdir -p docs/specs/YYYY-MM-DD_<slug>/
write docs/specs/YYYY-MM-DD_<slug>/pre-spec.md
write docs/specs/YYYY-MM-DD_<slug>/.metadata.json
```

`.metadata.json` initial content:

```json
{
  "slug": "<slug>",
  "title": "<full-title>",
  "language": "<chosen>",
  "createdAt": "<today YYYY-MM-DD>",
  "updatedAt": "<today YYYY-MM-DD>",
  "status": "draft",
  "github": null,
  "tags": [],
  "stage": "pre-spec",
  "linkedDesign": null
}
```

#### Optionally publish as GitHub issue

If the user opted in:

1. **Determine target repo.**
   - Memory or `CLAUDE.md` may indicate a different issue repo than the
     current repo (e.g. monorepo work files issues elsewhere). Respect it.
   - Else, default to `gh repo view --json nameWithOwner -q .nameWithOwner`.
   - Always confirm with the user before creating.

2. **Determine labels.**
   - Run `gh label list --repo <repo>` and propose product / type labels.
   - Confirm with user.

3. **Determine project assignment.**
   - If memory or user input mentions a project URL, propose it.
   - Else, run `gh project list --owner <owner>` to discover.

4. **Show preview** — title + first ~30 lines of the generated body —
   and wait for explicit YES.

5. **Create the issue:**

   ```bash
   gh issue create \
     --repo <owner>/<repo> \
     --title "<title>" \
     --body-file docs/specs/YYYY-MM-DD_<slug>/pre-spec.md \
     --label "<l1>" --label "<l2>"
   ```

6. **Add to project (if applicable):**

   ```bash
   gh project item-add <project-number> --owner <owner> --url <issue-url>
   ```

7. **Update `.metadata.json`** with the issue URL, repo, project URL,
   `updatedAt`. Set `tags` from the chosen labels.

8. **Report** the issue URL and the local path.

### Phase C6 — Final summary

```
## Pre-Spec Generated

**Slug:** <slug>
**Language:** <chosen>
**Status:** draft

### Output
- Local: docs/specs/YYYY-MM-DD_<slug>/pre-spec.md
- Metadata: docs/specs/YYYY-MM-DD_<slug>/.metadata.json
- Issue: <url-or-none>
- Project: <project-url-or-none>

### Coverage
- Objectives: <N>
- Validated decisions: <N>
- Product rules: <N>
- Open considerations: <N>     (none if all decisions are clear)

### Adjusting later
Run /ck-code:pre-spec <slug>  (or no argument and pick from the list)
to apply changes — the skill will edit the local file AND re-sync the
linked GitHub issue.
```

---

## ADJUST MODE

The user already has a pre-spec and wants to change it. The on-disk file
and the GitHub issue (if any) must stay in sync.

### Phase A1 — Locate the spec

From routing, you have a `<slug>` and the path
`docs/specs/YYYY-MM-DD_<slug>/`. Confirm by reading
`.metadata.json`.

If `.metadata.json` is missing or malformed, treat the spec as orphaned and
ask the user how to proceed (recreate metadata, or pick a different one).

### Phase A2 — Show current state

Read `pre-spec.md` and present a brief summary to the user:

```
## Current Pre-Spec — <slug>

**Title:** <title>
**Language:** <language>
**Status:** <status>
**Created:** <createdAt>   **Updated:** <updatedAt>
**Linked issue:** <github.issueUrl-or-none>

**Sections present:**
  - <section 1>
  - <section 2>
  - ...

What would you like to change?
You can:
  - Describe edits in plain language ("update §7.3 to mention …", "add a row to the rules table for …")
  - Add a new section
  - Remove a section
  - Replace specific paragraphs
  - Re-translate the whole document into another language
  - Sync labels / project assignment on the linked issue
```

### Phase A3 — Apply edits iteratively

Loop until the user is satisfied:

1. The user describes a change.
2. Read the current `pre-spec.md`.
3. Apply the edit using the `Edit` tool (anchored on stable text — section
   headings, table rows, etc.).
4. Show a short diff summary of what changed (1-3 lines max — file paths
   and section titles only, do NOT echo the full new content).
5. Ask "Anything else, or should I sync the issue?"

When applying edits:
- Keep section anchors (slugs) stable so external links don't break.
- Maintain the chosen language end-to-end. If the user asks to change
  language, re-translate the WHOLE file in one pass and update
  `.metadata.json#language`.
- Do not introduce technical jargon that wasn't there.
- If a structural change requires renumbering sections (e.g. a §12 was
  removed), renumber consistently and check that cross-references in the
  document still resolve.

### Phase A4 — Sync the linked GitHub issue

When the user says edits are complete:

```bash
# Always re-fetch then push, never assume the issue body matches the local
# file (someone might have edited the issue in the GitHub UI).

gh issue view <num> --repo <repo> --json body --jq .body > /tmp/<slug>-remote.md
diff /tmp/<slug>-remote.md docs/specs/.../pre-spec.md
# If non-empty diff: ask the user how to merge (local wins / remote wins /
# show me the diff and let me decide).

gh issue edit <num> --repo <repo> --body-file docs/specs/.../pre-spec.md
```

Also offer to update labels or project membership if the user mentioned
either:

```bash
gh issue edit <num> --repo <repo> --add-label "..." --remove-label "..."
gh project item-add <pid> --owner <owner> --url <issue-url>
```

### Phase A5 — Update metadata

Update `.metadata.json`:
- `updatedAt` = today
- If the user changed status (e.g. "ready for design"), update `status`
- If labels changed, update `tags`

### Phase A6 — Adjust summary

```
## Pre-Spec Updated

**Slug:** <slug>
**Local file:** docs/specs/YYYY-MM-DD_<slug>/pre-spec.md  (edited)
**Issue:** <url> (synced)
**Status:** <status>

### Changes applied
- <one-line per change>
- ...
```

---

## CROSS-SKILL CONVENTION — feeding /ck-code:design

Once the pre-spec is validated and ready for an architecture pass:

1. Update `.metadata.json#status` to `"ready-for-design"` (the user can
   ask, or the skill can offer, when they say "the spec is locked").
2. `/ck-code:design` should look for `docs/specs/*/.metadata.json` files
   with `status: "ready-for-design"` and offer them as input. When it
   completes, it sets `linkedDesign` to the path of its output and
   updates `status` to `"design-in-progress"`. (This is the convention;
   if the design skill isn't yet aware of it, no harm done — manual
   linking still works.)

---

## IMPORTANT GUIDELINES

- **Never invent project context.** If `CLAUDE.md`, `README.md`, or memory
  isn't found, ask the user instead of guessing.
- **Respect user-saved memory.** Memory entries about WHERE issues should
  be filed, default branches, label conventions, etc. take priority over
  guessing from the current repo.
- **Output language is the user's choice.** All section titles, tables,
  prose render in that language. Section anchors / slugs stay ASCII.
- **No tooling self-promotion in the OUTPUT.** Do not mention `/ck-code:*`,
  this skill, or any other internal tooling in the generated spec body.
  The spec exists for stakeholders, not the dev workflow.
- **Tone is descriptive, not prescriptive.** Tables describe rules;
  narrative describes behavior. Avoid imperative engineering directives
  ("MUST", "SHALL") unless they truly are non-negotiable product
  invariants.
- **Don't recreate the issue when adjusting.** Always edit in place via
  `gh issue edit`. Recreating loses comment history and breaks links.
- **Don't break sync.** Always re-fetch the issue body before pushing
  edits — someone may have made changes in the GitHub UI.
- **No destructive actions without confirmation.** Don't delete or close
  existing issues. Don't push labels the user hasn't authorized. Don't
  rename slugs (which would break folder references) without asking.
