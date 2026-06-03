---
name: convention
description: Use to capture a project's own conventions (code structure, naming, coding style, architectural rules) into a `guide-conventions` skill every expert reads, or to create custom expert/guide skills and adjust existing generated ones. Run after `/ck-code:team`. Args `[new expert|guide <slug>] [adjust <slug>]`; default captures conventions.
argument-hint: "[new expert <slug>|new guide <slug>|adjust <slug>]"
disable-model-invocation: true
effort: high
---

# Convention — House-Rules & Custom-Skill Factory

Captures the conventions `/ck-code:team` cannot research — your project's own
code structure, naming, coding style, and architectural rules — and lets you
create or adjust the experts and guides that enforce them. Its output is owned
by this skill: `team --regenerate` never overwrites it.

**What it produces / edits:**

- `.claude/skills/guides/conventions/SKILL.md` — the project house-rules guide,
  auto-loaded by every expert and by `/ck-code:build` and `/ck-code:fix`.
- `.claude/skills/experts/<slug>/SKILL.md` or `.claude/skills/guides/<slug>/SKILL.md`
  — brand-new custom skills not in `team`'s catalog.
- Edits to any existing generated expert/guide (append or revise a section).

## INPUT

`$ARGUMENTS` selects the mode:

- empty → **CAPTURE** mode: build/update `guide-conventions` from your rules.
- `new expert <slug>` or `new guide <slug>` → **NEW** mode: scaffold a custom skill.
- `adjust <slug>` → **ADJUST** mode: edit an existing expert/guide (e.g. `adjust expert-backend`).

---

## PHASE 0: PREREQUISITES

```
IF .claude/skills/ has no experts/ or guides/ subfolder:
  → "No generated skills found. Run /ck-code:team first so conventions have
     experts to attach to." → ask CONTINUE ANYWAY? YES / NO. On NO → STOP.
```

Read `docs/architecture/folder-structure.md` and `tech-stack.md` (if present) and
any root `CLAUDE.md` for lightweight project context. Do NOT run the full
team research pass — conventions come from you and the existing code, not context7.

---

## PHASE 1: CAPTURE MODE (default)

**Goal:** Produce or refresh `.claude/skills/guides/conventions/SKILL.md` from the
project's real conventions.

### 1.1 Infer from the codebase first

Before asking the user anything, gather evidence so questions are concrete:

- Sample 3–6 representative source files per primary language; note naming case,
  file/folder layout, import ordering, error-handling style, comment density.
- Read existing lint/format configs (`.eslintrc`, `rustfmt.toml`, `.prettierrc`,
  `ruff.toml`, `.editorconfig`) and any `CONVENTIONS.md` / `STYLE.md` / `CLAUDE.md`.
- Note the architectural shape (layering, module boundaries, naming patterns).

### 1.2 Confirm and fill gaps with the user

Present what you inferred as a draft, then ask the user to confirm or correct
each area and add rules the code does not reveal. Cover: **naming**, **file &
folder structure**, **code style/formatting**, **architectural rules** (layering,
allowed/forbidden dependencies), **preferred & banned libraries/patterns**, and
**any project-specific must/never rules**. Capture only rules the user actually
has — never invent house rules to fill the template.

### 1.3 Write the conventions guide

Write `.claude/skills/guides/conventions/SKILL.md` from the template in
[references/conventions-guide-template.md](references/conventions-guide-template.md).
Set `user-invocable: false` and `paths: ["**/*"]` so it loads on any file. If the
guide already exists, merge: keep sections the user did not change, update the
rest. Every rule must be concrete and, where useful, paired with a short
correct/incorrect code example.

---

## PHASE 2: NEW MODE (`new expert <slug>` / `new guide <slug>`)

**Goal:** Scaffold a custom skill `team` would not generate, in the same
namespaces `build`/`fix` already scan.

1. Confirm the slug and target namespace (`experts/` or `guides/`) and a
   one-sentence purpose with the user.
2. For an **expert**: write `.claude/skills/experts/<slug>/SKILL.md` following the
   shape of `team`'s `#derived-expert` template — frontmatter (`name: expert-<slug>`,
   `description`, **plus `paths:` and `keywords:`** so `build`/`fix` auto-load it),
   a `[PROJECT CONTEXT BLOCK]` resolved from Phase 0 context, and the sections
   **Your Expertise**, **Your Responsibilities**, **Before Writing Code**,
   **Standards** (must reference `/guide-conventions`), **When Asked to …**.
3. For a **guide**: write `.claude/skills/guides/<slug>/SKILL.md` with
   `user-invocable: false`, a `paths` glob (so it auto-loads on matching files),
   and the conventions/patterns/anti-patterns the user dictates.
4. Confirm auto-load: `build`/`fix` match by each skill's `paths`/`keywords`
   frontmatter (see `references/skill-detection.md`), so a skill with accurate
   triggers loads automatically. Without `paths`/`keywords` it is invoke-only
   (`/expert-<slug>`). Set them unless the user wants it invoke-only.

---

## PHASE 3: ADJUST MODE (`adjust <slug>`)

**Goal:** Refine an existing generated skill without a full `team --regenerate`.

1. Read the target file fully (`.claude/skills/experts/<slug>/SKILL.md` or
   `.claude/skills/guides/<slug>/SKILL.md`). If absent → report and STOP.
2. Confirm the exact change with the user (add a rule, revise a section, add an
   example). Make the **minimal targeted edit** — never rewrite the whole file.
3. Preserve the `[PROJECT CONTEXT BLOCK]` and frontmatter; edit only the section
   in question.
4. Note that a later `team --regenerate` will overwrite research-driven experts
   and guides — durable house rules belong in `guide-conventions` (Phase 1), not
   in an adjusted expert.

---

## PHASE 4: REPORT

Show what changed: the file path(s) written/edited, and for the conventions guide,
the rule areas it now covers. Remind the user that `guide-conventions` auto-loads
in `build`/`fix` and is referenced by every expert, and is safe from
`team --regenerate`.

---

## RULES

- **Never invent conventions.** Capture only rules the user states or the code
  demonstrably follows. An empty area stays empty, not filled with generic advice.
- **Never overwrite `guide-conventions` blindly.** In CAPTURE mode, merge with the
  existing guide; preserve rules the user did not change.
- **Conventions guide is `user-invocable: false`** with `paths: ["**/*"]` — it is
  background knowledge, not a command.
- **Adjust is minimal.** ADJUST mode edits one section; it never rewrites a file
  or regenerates from research.
- **Durable rules live in conventions, not experts.** Tell the user any rule they
  want to survive `team --regenerate` must go in `guide-conventions`.
- **This skill owns its outputs.** `guide-conventions` and skills created here are
  excluded from `team`'s EXTRA/regenerate logic — never depend on `team` to manage them.
- **Language:** All output in English.
