# Reuse-First & Simplest-Viable Rule — Shared Constraint

Linked by the upstream authoring skills (`design`, `plan`, `team`, `spec`), which own
the decisions this rule governs, and by `build` — Phase 6.1 runs the redundancy scan
below, Phase 7 verifies it ran ([`qa-validation.md`](qa-validation.md) Step 3.5). `fix`
encodes the same ethos inline (the smallest possible change). One ethos: read what
already exists, reuse before you rebuild, and pick the simplest approach that satisfies
the requirement.

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

## Redundancy scan (implementation)

Run against the story's diff — the code added or changed in this run, never the whole
repo. Five checks, in order:

1. **Reimplementation** — the diff writes logic that already exists elsewhere. Before
   accepting a new function as new, grep the repo for its verb + noun and for a
   distinctive line of its body. A hit means call the existing one, or extend it.
2. **Copy-paste inside the diff** — the same block appears twice in the changed files.
   Two occurrences differing only by a value are a parameter; three are a helper.
3. **Dead code** — anything added this run with no caller: an export nothing imports, a
   parameter no body reads, an import no line uses, a branch no test reaches.
4. **Needless indirection** — a wrapper, adapter, or interface with exactly one caller
   and no behaviour of its own. Inline it unless the feature doc names it as a seam.
5. **Unasked-for surface** — an option, flag, config key, or generality no acceptance
   criterion requires. Delete it; the story is the scope.

**Not a finding:** duplication the architecture docs make deliberate (a boundary the feature
doc draws), test setup repeated for readability, or two similar-looking blocks that change
for different reasons. DRY without over-abstraction — collapsing those costs more than it
saves.

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
