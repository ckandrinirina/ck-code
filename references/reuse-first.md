# Reuse-First & Simplest-Viable Rule — Shared Constraint

Linked by the upstream authoring skills (`design`, `plan`, `team`, `spec`), which
own the decisions this rule governs. `build` and `fix` encode the same ethos inline
at the point of use (build 5.2 "reuse existing code"), so they do not link here.
One ethos: read what already exists, reuse before you rebuild, and pick the
simplest approach that satisfies the requirement.

## The rule

- **Read context before acting.** Before designing or generating anything, read the
  existing architecture docs (`docs/architecture/`), the spec, and any directly-related
  source — never re-derive what a doc or the code already states.
- **Reuse before you build.** Prefer an existing component, pattern, utility, doc
  section, or reference file over authoring a new one. Point to the source instead of
  duplicating it.
- **Simplest viable approach.** Choose the smallest design or implementation that meets
  the requirement. Do not add layers, options, or abstractions the requirement does not
  ask for.
- **Don't re-analyze what's already clear.** Skip questions the docs/spec already answer;
  skip research on well-known basics. Spend effort only on genuine gaps.
- **Effort scales depth, not busywork.** A higher effort level means more depth on real
  ambiguities — never more ceremony, more questions, or more re-derivation of settled facts.

## Why

Overthinking is the most common failure mode of the upstream authoring skills:
re-scoring settled dimensions, re-researching well-known tech, asking questions the
docs already answer, designing more than the requirement needs. Each costs tokens and
user time and bloats output. `build` and `fix` already encode this discipline ("write
the simplest code that passes", "the smallest possible change"); this rule extends it
upstream so the whole workflow stays lean.

Reuse-first **tightens, never loosens** a skill's own guarantees: where a skill mandates a
step for safety or correctness (`fix`'s scope analysis, the version gate, a confirmation
before a destructive write), that step still runs. This rule removes redundant analysis,
not required checks.
