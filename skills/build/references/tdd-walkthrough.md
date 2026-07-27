# Worked TDD Walkthrough

End-to-end example of the red-green-refactor cycle plus SOLID review applied
to a single story. The rules in SKILL.md are authoritative.

---

## Phase 3.3 — SOLID Analysis Template

Two shapes, picked by the Phase 1.7 effort route. Either is filled before any test or code
is written (rule in SKILL.md 3.3).

### LEAN (size `S`, and Bug-Fix Mode)

Name only the principles this story actually puts at stake, and say how each is satisfied.
State the rest as not-in-play — never omit them silently:

```
## SOLID (lean) — [Story Title]

S: [NewThing] owns only [one responsibility]; no existing file gains a second reason to change.
D: [NewThing] takes [Dep] by interface, injected at [call site].
O/L/I: not in play — no new abstraction, subtype, or interface in this story.
```

### FULL (size `M`, or size absent)

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

**LEAN route (size `S`, Bug-Fix Mode)** — three tasks, each blocked by the previous;
refactor and completion fold into their phases rather than getting their own rows:

```
1. "Write tests for [story title]"      activeForm: "Writing tests for [story title]"
2. "Implement [story title]"            activeForm: "Implementing [story title]"
3. "QA validation for [story title]"    activeForm: "Running QA for [story title]"
```

**FULL route (size `M`)** — typical task breakdown for a story:

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

```
Acceptance Criterion: "WebSocket server accepts connections on port 8765"
→ Test: test_server_accepts_websocket_connection_on_configured_port()

Acceptance Criterion: "Messages are serialized in MessagePack format"
→ Test: test_message_serialization_uses_messagepack()
→ Test: test_message_deserialization_handles_invalid_msgpack()
```

Edge cases, error scenarios, and integration points: rules in SKILL.md Phase 4.3.

---

## Phase 6.1 — SOLID Compliance Check Template

**LEAN route** — spot-check only the principles named in the 3.3 lean note, plus any the
diff newly put at stake. One line per principle checked; escalate to the full template below
the moment a structural violation appears:

```
## SOLID spot-check — [Story Title]
S: [x] [NewThing] still single-purpose
D: [x] [Dep] still injected, no direct instantiation
(O/L/I unchanged — nothing new introduced)
```

**FULL route** — run this review against all new/modified code during the Refactor phase.

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

Issue handling and common refactorings: rules in SKILL.md Phase 6.2.

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

---

## JUCE Test Runner Rules

When writing JUCE unit tests:
- `juce::ScopedJuceInitialiser_GUI juceInit;` as the first line of `main()` — prevents CoreMidi/Singleton assertions
- ASCII-only strings in `beginTest()` / `expect()` / `juce::String(const char*)` (use `-` not `—`, `...` not `…`)
- One meaningful assertion instead of looping hundreds of `expect()` calls
