# Worked TDD Walkthrough

End-to-end example of the red-green loop (one behaviour per cycle), the refactor and
test-prune pass, and the SOLID review, applied to a single story. The rules in SKILL.md are authoritative.

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

**LEAN route (size `S`, Bug-Fix Mode)** — two tasks, the second blocked by the first;
refactor, prune and completion fold into their phases rather than getting their own rows:

```
1. "Test-drive [story title]"           activeForm: "Test-driving [story title]"
2. "QA validation for [story title]"    activeForm: "Running QA for [story title]"
```

**FULL route (size `M`)** — typical task breakdown for a story:

```
1. "Test-drive [component/module A]"
   - activeForm: "Test-driving [component A]"

2. "Test-drive [component/module B]" (if applicable)
   - activeForm: "Test-driving [component B]"

3. "Refactor and prune tests for [story title]"
   - activeForm: "Refactoring [story title]"

4. "QA validation for [story title]"
   - activeForm: "Running QA for [story title]"

5. "Complete [story title] — summary, status and files:"
   - activeForm: "Completing [story title]"
```

Each test-drive task runs Phases 4–5 as a loop, one behaviour per cycle; never split
"write tests" and "implement" into separate tasks. Set dependencies: each test-drive task
blocked by the previous, refactor blocked by the last one, QA blocked by refactor,
completion blocked by QA.

---

## Phase 4.3 — Worked Example: Acceptance Criterion → Tests

One cycle per behaviour. A second test for a criterion needs its own branch in the code:

```
Cycle 1  AC "WebSocket server accepts connections on port 8765"
  RED    test_server_accepts_websocket_connection_on_configured_port() → FAIL
  GREEN  bind + accept loop → PASS

Cycle 2  AC "Messages are serialized in MessagePack format"
  RED    test_message_round_trips_through_messagepack() → FAIL
  GREEN  encode/decode → PASS

Cycle 3  the decoder now branches on malformed bytes (it returns a protocol error)
  RED    test_invalid_msgpack_returns_protocol_error() → FAIL
  GREEN  error branch → PASS
```

What 6.1 prunes from a loop like this one:

```
scaffolding   test_encoder_writes_map_header()   → covered by the round-trip test → delete
duplicate     test_accepts_second_connection()   → same path as cycle 1          → delete
coupled       test_handler_calls_encode_once()   → asserts mock calls, not output → delete
not written   test_port_is_8765()                → tests a constant (never write)
not written   test_empty_frame()                 → the decoder has no empty-frame branch
```

Rules: SKILL.md Phase 4.3 and [`test-craft.md`](../../../references/test-craft.md).

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

## Phase 7 — Code Quality Checks by Stack

The per-stack build/test/lint commands are the manifest table in
[parallel-mode.md](parallel-mode.md#p7--qa-one-validator-per-story) — the single source for
both inline Phase 7 and PARALLEL MODE P7. Detect the manifest, run that row's commands, and
let a project's `guide-conventions` skill override them when it names canonical ones.

---

## JUCE Test Runner Rules

**Build check.** Run the build unpiped and read the tail of its output for `warning:` and
`error:` lines (ignore anything under `_deps`) — piping a build into `grep` hides the exit
code and drops the context around the first error:

```bash
cmake --build build -- -v
clang-format --dry-run --Werror Source/*.cpp Source/*.h   # only if .clang-format exists
```

Zero compiler warnings in project-owned files is the quality bar.

When writing JUCE unit tests:
- `juce::ScopedJuceInitialiser_GUI juceInit;` as the first line of `main()` — prevents CoreMidi/Singleton assertions
- ASCII-only strings in `beginTest()` / `expect()` / `juce::String(const char*)` (use `-` not `—`, `...` not `…`)
- One meaningful assertion instead of looping hundreds of `expect()` calls
