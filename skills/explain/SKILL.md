---
name: explain
description: Use to explain what was just implemented, the technologies involved, or how to manually verify it works. Triggers on "explain", "what was implemented", "how do I check", "how does this work".
argument-hint: "[file-or-concept]"
effort: low
context: fork
background: false
disallowed-tools: Write, Edit, NotebookEdit
---

# Explain — Implementation Details & Manual Verification

Produces two sections for the most recently implemented story or feature:

1. **Manual verification** — exact commands to confirm it works
2. **What was built** — learner-friendly explanation of every technology and pattern used

Read `tasks/VERSION.md`. If `layout: v5` → proceed silently. Otherwise emit one line —
`ℹ pre-v5 layout — run /ck-code:migrate` — and **continue read-only**. Never block. See
[`../../references/version-gate.md`](../../references/version-gate.md).

---

## How to Use

Invoke with `/ck-code:explain` after a story completes, or any time the user asks to understand what was built.

Optional argument: a specific file, class, or concept to focus on.

- `/ck-code:explain` → explains the last implemented story
- `/ck-code:explain CMakeLists.txt` → explains just that file
- `/ck-code:explain FetchContent` → explains just that CMake concept

---

## Output Format

### Section 1 — Manual Verification

List the exact shell commands the user can run right now to confirm everything works. Rules:

- One numbered check per command, each as a bold one-line label + a `bash` fence with a
  comment stating the expected output (`# Should show: …`, `# Should exit 0`)
- Cover: file existence, build/compile, binary run, key integration points
- Keep it short — 3 to 6 checks maximum
- If no terminal check is possible (e.g. pure UI), describe what to look at instead

### Section 2 — What Was Built (Learning Explanation)

Explain every file, technology, and pattern that was introduced, grouped by logical theme
(`### <Theme>` per group — build system, framework, class design, …), ending with a
`### What comes next` of 1–3 bullets on what future stories will add. Rules:

- Assume the user is **new to this technology** — never assume prior knowledge; prefer
  analogies to things they already know ("like package.json"); define unavoidable jargon
  immediately
- For each concept: what is it, why does it exist here, what problem does it solve
- For each file: what is its role, what key lines mean
- Use short annotated code snippets to illustrate

---

## Reading Context

Before generating output, read:

1. **The most recently completed story file** — the newest story whose frontmatter
   `status: done` (or a `bug` story just restored to `done`) — for acceptance criteria
   and its frontmatter `files:` list.
2. **The files themselves** (use Read on each created/modified file).
3. **The diff for that story's work** — prefer the story branch's diff against its merge
   base (`git diff $(git merge-base HEAD main)...HEAD` when on a story branch); fall back
   to `git diff HEAD~1` only when the change is known to be the last commit. `HEAD~1` is a
   fragile "last change" heuristic — do not rely on it if `sync`/index or other commits
   may sit between now and the story work.

If the user specifies a path or concept, focus on that instead.

---

## Tone

Supportive and encouraging (the user is learning); concrete and specific — never vague
("this handles the logic"); short paragraphs, one idea each.
