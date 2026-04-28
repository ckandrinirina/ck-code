# Worked TDD Walkthrough

End-to-end example showing how the red-green-refactor cycle plus SOLID review
are applied to a single story. Use this as a reference when the inline rules in
SKILL.md are unclear.

---

## Phase 3.3 — SOLID Analysis Template

Plan the implementation applying each SOLID principle. Fill this out before any
test or code is written.

```
## SOLID Analysis for This Story

**S — Single Responsibility:**
- [Each new file/class and its ONE responsibility]

**O — Open/Closed:**
- [Existing code to extend via abstractions, NOT modify]
- [Extension points to create for future flexibility]

**L — Liskov Substitution:**
- [Any new types must be substitutable for their parent types]

**I — Interface Segregation:**
- [Keep interfaces focused — no methods the caller doesn't need]

**D — Dependency Inversion:**
- [High-level modules depend on abstractions, not concrete implementations]
- [Where to inject dependencies]
```

---

## Phase 3.4 — Subtasks Breakdown (TaskCreate)

Typical task breakdown for a story:

```
1. "Write tests for [story title]"
   - activeForm: "Writing tests for [story title]"

2. "Implement [component/module A]"
   - activeForm: "Implementing [component A]"

3. "Implement [component/module B]" (if applicable)
   - activeForm: "Implementing [component B]"

4. "Refactor [story title] implementation"
   - activeForm: "Refactoring [story title]"

5. "QA validation for [story title]"
   - activeForm: "Running QA for [story title]"

6. "Complete [story title] — update docs and commit"
   - activeForm: "Completing [story title]"
```

Set dependencies: implementation blocked by tests, refactor blocked by
implementation, QA blocked by refactor, completion blocked by QA.

---

## Phase 4.3 — Worked Example: Acceptance Criterion → Tests

For EACH acceptance criterion in the story, write at minimum one test.

```
Acceptance Criterion: "WebSocket server accepts connections on port 8765"
→ Test: test_server_accepts_websocket_connection_on_configured_port()

Acceptance Criterion: "Messages are serialized in MessagePack format"
→ Test: test_message_serialization_uses_messagepack()
→ Test: test_message_deserialization_handles_invalid_msgpack()
```

Also add tests for:
- **Edge cases** — empty input, boundary values, max limits
- **Error scenarios** — invalid input, connection failures, timeouts
- **Integration points** — if the story connects two components

---

## Phase 6.1 — SOLID Compliance Check Template

Run this review against all new/modified code during the Refactor phase.

```
## SOLID Compliance Check

S — Single Responsibility:
  [x] Each function does one thing
  [x] Each file/class has one reason to change
  [ ] ISSUE: [function X] handles both [A] and [B] → split

O — Open/Closed:
  [x] Extended via abstractions, not modification

L — Liskov Substitution:
  [x] Subtypes are substitutable

I — Interface Segregation:
  [x] No fat interfaces

D — Dependency Inversion:
  [x] Depends on abstractions
  [ ] ISSUE: [module X] directly instantiates [concrete Y] → inject
```

For each issue found:
1. Apply the refactoring
2. Run tests → must still pass
3. If tests break → revert and reconsider

Common refactorings:
- Extract function/method for duplicated code
- Rename for clarity
- Introduce interface/trait for dependency inversion
- Split large functions by responsibility
- Move code to appropriate module per folder structure

---

## Phase 7.4 — Code Quality Checks by Stack

Detect which tools are available in the project and run them:

```bash
# TypeScript projects
npx tsc --noEmit        # Type checking
npx eslint .            # Linting
npx prettier --check .  # Formatting

# Rust projects
cargo clippy            # Linting
cargo fmt -- --check    # Formatting

# Python projects
mypy .                  # Type checking
ruff check .            # Linting
black --check .         # Formatting

# C++ / JUCE projects
cmake --build build -- -v 2>&1 | grep -iE "warning:|error:" | grep -v "_deps"
# clang-format --dry-run --Werror Source/*.cpp Source/*.h   (if .clang-format exists)
# Zero compiler warnings in project-owned files is the quality bar
```
