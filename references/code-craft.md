# Code Craft — Clean Code & Comment Standard

The implementation-quality bar every line written by `build` must meet — in the GREEN
phase (5.2), the REFACTOR phase (6.1 scan), and QA (Step 3.5 verifies the scan ran).
`team`'s conventions guide **refines** this standard for one project (its case style, its
doc-comment format, its idioms); it never lowers it. Sits beside
[`reuse-first.md`](reuse-first.md): that rule decides *whether* code should exist, this
one decides *how* the code that exists reads.

## Clean code

Readable first, clever never. A reader who knows the stack but not the story must follow
the code without a comment.

- **Names carry the meaning.** Intention-revealing, domain vocabulary from the feature doc,
  no abbreviations the codebase doesn't already use. A name that needs a comment to explain
  it is the wrong name — rename instead of commenting.
- **One function, one job.** Small enough to read in one screen; nesting shallow enough to
  follow without counting braces. Guard clauses and early returns over nested `if`/`else`.
- **No magic values.** A literal with meaning (a limit, a key, a status code) becomes a named
  constant at the narrowest scope that needs it.
- **Errors are handled the stack's way.** `Result`/`?`, exceptions, error returns — whatever
  the loaded guide and surrounding code use. Never swallow an error; never catch broader
  than the failure you handle.
- **Match the room.** New code reads like the file it lives in — same structure, style,
  and idioms as its neighbours and the loaded guide. Consistency beats personal preference;
  a mixed style is a defect even when each half is fine on its own.
- **Only what the story needs.** No speculative parameters, feature flags, or generality.
  [`reuse-first.md`](reuse-first.md#redundancy-scan-implementation) owns that check.

## Comments

A comment costs every future reader a pause. It earns that pause only when it tells them
something the code cannot.

**A comment earns its place when it states:**

- **Why** — the intent or the trade-off behind a non-obvious choice.
- **An invariant** the code assumes but cannot enforce (ordering, units, a caller contract).
- **A workaround** — the bug or limitation it dodges, with the issue link or version.
- **A pointer** — the algorithm, spec, or RFC a dense block implements.
- **Public API** — a doc comment in the stack's format (JSDoc, rustdoc, docstring, Doxygen)
  on every exported symbol: one line on what it does, params/returns only when the
  signature alone leaves a question.

**A comment never:**

- restates the code (`// increment i`, `// return the user`)
- narrates history or the change (`// added for story 02-03`, `// refactored`)
- banners a section (`// ===== Helpers =====`)
- keeps dead code alive (commented-out blocks — delete them; git remembers)
- leaves a bare `TODO`/`FIXME` — either do it now or write `TODO(<story-id>): <what>`
- mentions AI, Claude, or the assistant ([`no-ai-references.md`](no-ai-references.md))

**Form.** One line where one line suffices; a short paragraph only for an invariant or
algorithm that needs it. Precise and present tense — *what is true*, not what you did.
Placed on the line above the code it explains, never trailing a long line. A comment is
part of the code: change the code, update or delete the comment. A stale comment is a bug.

## Comment & readability scan (implementation)

Run against the story's diff in `build` Phase 6.1, right after the redundancy scan — the
added or changed lines only, never the whole repo. Four checks, in order:

1. **Restating comments** — every comment the code already says. Delete it.
2. **Missing why** — every place a reviewer would ask "why this?": a non-obvious branch,
   a magic-looking value, a workaround, an ordering dependency. Add one precise line, or
   rename/restructure so the question disappears.
3. **Doc comments** — every new or changed exported symbol has one in the stack's format,
   and it matches the current signature.
4. **Readability** — a name that needs explaining, a function past one screen, nesting past
   three levels, a literal with meaning. Each is an ISSUE for 6.2 like any SOLID violation.

**Not a finding:** a test's descriptive comment, a license or file header the project
mandates, or a comment the loaded conventions guide explicitly requires.

## Why

Code is read far more often than it is written, and the next reader is usually an agent
with no memory of this run. Names and structure that explain themselves keep that reader
fast; comments that restate the code or narrate its history slow them down and drift out
of date. The scan keeps the bar mechanical: `build` writes to it, QA checks it ran, and
`team`'s guide localises it per stack instead of every run rediscovering house style.
