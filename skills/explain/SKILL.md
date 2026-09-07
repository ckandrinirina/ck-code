---
name: explain
description: Use to explain what was just implemented, the technologies involved, or how to manually verify it works, or — with `--epic NN` — what a whole epic and each of its stories are for. Triggers on "explain", "what was implemented", "how do I check", "how does this work", "what is epic NN about".
argument-hint: "[file-or-concept] | --epic NN"
effort: low
model: haiku
context: fork
agent: Explore
background: false
allowed-tools: Bash(git diff*) Bash(git log*) Bash(git show*) Bash(git status*) Bash(git branch*)
disallowed-tools: Write, Edit, NotebookEdit
---

# Explain — Implementation Details, Manual Verification & Epic Intent

Two modes, chosen by `$ARGUMENTS`:

| `$ARGUMENTS` | Mode | Produces |
|---|---|---|
| empty, or a file/concept | **STORY MODE** (default) | manual-verification commands + a learner-friendly walkthrough of what was built |
| `--epic NN` | **EPIC MODE** | the goal of epic `NN` and the goal of every story in it |

STORY MODE is everything below down to *Reading Context (STORY MODE)*; EPIC MODE is its own
section further down. The two share only the Tone and RULES blocks.

Read `tasks/VERSION.md`. If `layout: v6` → proceed silently. Otherwise emit one line —
`ℹ pre-v6 layout — run /ck-code:migrate` — and **continue read-only**. Never block. See
[`../../references/version-gate.md`](../../references/version-gate.md).

---

## How to Use

Invoke with `/ck-code:explain` after a story completes, or any time the user asks to understand what was built.

Optional argument: a specific file, class, or concept to focus on — or `--epic NN` to
explain an epic and its stories instead.

- `/ck-code:explain` → explains the last implemented story
- `/ck-code:explain CMakeLists.txt` → explains just that file
- `/ck-code:explain FetchContent` → explains just that CMake concept
- `/ck-code:explain --epic 03` → EPIC MODE — the goal of epic 03 and of each of its stories

`--epic` with no number, or a number that is not `NN`, is an error — say so and stop; never
guess an epic.

---

## Output Format (STORY MODE)

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

## Reading Context (STORY MODE)

Before generating output, read:

1. **The most recently completed story file** — the newest story whose frontmatter
   `status: done` (or a `bug` story just restored to `done`) — for acceptance criteria
   and its frontmatter `files:` list. Read its `delivery:` too: when it is neither `merged`
   nor `direct`, say so in one line, because the work explained here is not on the trunk
   branch yet and the reader may be looking for it there.
2. **The files themselves** (use Read on each created/modified file).
3. **The diff for that story's work** — prefer the story branch's diff against its merge
   base (`git diff $(git merge-base HEAD main)...HEAD` when on a story branch); fall back
   to `git diff HEAD~1` only when the change is known to be the last commit. `HEAD~1` is a
   fragile "last change" heuristic — do not rely on it if `sync`/index or other commits
   may sit between now and the story work.

If the user specifies a path or concept, focus on that instead.

---

## EPIC MODE — `--epic NN`

Explains **intent, not implementation**: why the epic exists and what each of its stories is
for. No diffs, no code walkthrough, no verification commands — none of the STORY MODE
sections apply here.

### E.1 Resolve the epic

Zero-pad `NN` to two digits (`3` → `03`), then locate its folder with Glob:

```
tasks/*/epics/NN_*/EPIC.md
```

Epic numbers are unique across every plan
([`../../references/data-model.md`](../../references/data-model.md#epic-and-story-numbers-are-globally-unique)),
so exactly one match is expected:

- **one match** → its `tasks/<Plan>/epics/NN_<slug>/` is the epic; proceed
- **no match** → list the epic numbers that do exist (Glob `tasks/*/epics/*/EPIC.md`) and stop
- **more than one match** → colliding epic numbers. Stop, tell the user to run
  `/ck-code:migrate`, and never pick one

### E.2 Read

1. `EPIC.md` — frontmatter `title`, `description`, `slug`, `integration`, plus the body.
2. Every `stories/*.md` in that folder, in filename order — frontmatter `id`, `title`,
   `status`, `size`, `blocked_by`, and the body's **Description** and **Acceptance Criteria**.
3. `docs/architecture/features/<slug>/index.md` (from the epic's `slug`) **only if it
   exists** — one read, for the product context behind the epic. Skip silently if absent.

Never read the story indexes (they carry no goal text) and never run git — EPIC MODE
explains the plan, which is true whether or not any code exists yet.

### E.3 Output Format

**`## Epic NN — <title>`**, then:

1. **Goal** — 2–4 sentences on the outcome this epic delivers and who it is for. Ground it
   in `EPIC.md` plus the feature doc; never restate the title back as a goal.
2. **Stories** — one `### NN-SS — <title>` block per story, in ID order, each with:
   - a `Status` line (`todo` / `in-progress` / `done` / `skip` / `bug`, and `blocked by X`
     when `blocked_by` is non-empty)
   - **2–4 sentences on that story's goal** — what it makes possible and why the epic needs
     it, derived from its Description and Acceptance Criteria. Never a bullet dump of the
     criteria, and never a list of files or tasks
3. **How they fit together** — 2–5 bullets on the order the stories unlock each other
   (from `blocked_by`) and what the epic looks like once all are `done`.
4. **Where it stands** — one line — `X of Y done, Z in progress, W blocked` — plus the
   next story that is actionable, if any.

A story whose body has no Description yet is explained from its title and acceptance
criteria alone, marked `(not yet detailed)`. Never invent a goal for an empty story.

---

## Tone

Supportive and encouraging (the user is learning); concrete and specific — never vague
("this handles the logic"); short paragraphs, one idea each.

---

## RULES

- **Never** call the `Skill` tool — this skill runs forked and read-only, and an Explore
  fork has no write tools.
- **Never** emit a `NEXT:` directive — explaining finished work implies no next step. This
  is the one read-only skill with no hand-off
  ([`../../references/skill-invocation.md`](../../references/skill-invocation.md)).
- **Never** mix the modes — `--epic NN` produces no verification commands and no code
  walkthrough; a story/file/concept argument produces no epic rollup.
- **Never** guess which plan an `--epic NN` belongs to when the Glob matches more than one
  folder — that is colliding epic numbers, and the fix is `/ck-code:migrate`.
- **Always** output in English.
