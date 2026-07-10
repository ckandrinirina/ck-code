# Conventions Guide Template

Body template for `.claude/skills/guides/conventions/SKILL.md` produced by
CAPTURE mode. Every rule must come from the user or from demonstrable code
patterns — never from generic advice. Leave a section out entirely if the
project has no rule for it; do not pad it.

---

## conventions-guide-template

**File:** `.claude/skills/guides/conventions/SKILL.md`

````markdown
---
name: guide-conventions
description: >
  Project house rules for [project-name] — code structure, naming, style, and
  architectural conventions specific to this codebase. The authoritative source
  of "how we write code here". Use whenever writing or reviewing code in this project.
user-invocable: false
paths:
  - "**/*"
---

# [project-name] House Conventions

> Hand-authored project conventions. These override generic language/framework
> defaults. When a generated guide or expert conflicts with this file, this file wins.
> Last updated: [date]

## Naming

- [Variable / function / type / file naming rules, with the exact case style]
- [Domain-specific naming patterns, e.g. handlers end in `Handler`, hooks start with `use`]

## File & Folder Structure

- [Where each kind of file lives — derived from folder-structure.md + the user's rules]
- [Module boundaries: what may import what]
- [Co-location / barrel-file / index conventions]

## Code Style

- [Formatting rules not covered by the formatter, or formatter config to honor]
- [Comment and documentation conventions]
- [Preferred constructs and idioms]

```[primary-language]
// Correct — follows the house style
[short example]

// Incorrect — what to avoid and why
[short counter-example]
```

## Architectural Rules

- [Layering / dependency direction rules]
- [Patterns that are mandatory in this project]
- [Boundaries that must not be crossed]

## Preferred & Banned

- **Prefer:** [libraries, utilities, patterns the project standardizes on]
- **Avoid / banned:** [libraries or patterns not allowed, with the reason]

## Must / Never

- **Always:** [project-specific hard rules]
- **Never:** [absolute prohibitions]

## References

- [Links to CONVENTIONS.md / STYLE.md / CLAUDE.md or other in-repo sources]
````

---

## Generation Rules

1. **User/code-sourced only.** Every line traces to a stated rule or an observed
   pattern. No generic best practices — those already live in the language guides.
2. **Concrete over abstract.** Pair non-obvious rules with a short correct/incorrect
   example in the project's primary language.
3. **Omit empty sections.** If the project has no architectural rules, drop that
   heading rather than inventing one.
4. **`user-invocable: false` + `paths: ["**/*"]`** so it loads on every file as
   background knowledge.
5. **Merge, don't clobber.** On re-run, preserve unchanged sections; update only
   what the user revised.
6. **Authoritative.** State explicitly that this guide overrides generic guide/expert
   defaults on conflict.
