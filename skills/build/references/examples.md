# Example Dialogues — Worked Walkthroughs

Heavier, conditional dialogues: the interactive selection menu and the manual-test
bug-fix sub-loop. The compact per-phase status/prompt templates live in
`output-blocks.md`. Wording is adaptable; the **data shown** must match the checks in `SKILL.md`.

---

## Phase 1.2 — Interactive Story Selection

The menu leads with the **parallel** option whenever ≥ 2 ready stories are conflict-free,
then whole-epic wave builds, then single stories. Picking parallel or an epic enters
SKILL.md § PARALLEL MODE at P1 with the scope already resolved, and P3 does not re-ask which
stories to build. Every story is then implemented by a dispatched agent — one worktree agent
per story in a wave of ≥ 2, one solo agent in the main checkout for a wave of exactly one.

```
## Stories Ready for Implementation

| # | Story | Epic | Size | Dependencies |
|---|-------|------|------|-------------|
| 1 | [01-04] Abort on SOKA reject | 01 | M | None |
| 2 | [01-02] Paid abandon grace   | 01 | S | None |
| 3 | [02-01] Free-private → 0 pts | 02 | M | None |

## ⚡ Recommended — build in parallel (isolated worktrees, one agent each)

| #  | Set                      | Scope                    |
|----|--------------------------|--------------------------|
| P  | 01-04, 01-02, 02-01 (3)  | one wave, 3 worktrees    |

## Or build a whole epic in dependency-ordered waves (drives every story to DONE)

| #  | Epic    | Remaining | Scope             |
|----|---------|-----------|-------------------|
| E1 | Epic 01 | 2 stories | epic 01, in waves |
| E2 | Epic 02 | 2 stories | epic 02, in waves |

Pick P to build the parallel set, an epic (E1/E2) for waves, or a single story (number/path).
```

**Routing (the selection is the single confirm — PARALLEL MODE does not re-prompt for scope):**

- **Parallel set (P)** → statuses stay `todo` (skip SKILL.md 1.3–1.6); enter PARALLEL MODE at P1 with those IDs as the scope, one wave.
- **Epic (E1/E2)** → statuses stay `todo`; enter PARALLEL MODE at P1 with scope `--epic NN` — [wave-mode.md](wave-mode.md) owns the loop.
- **Single story** → proceed to SKILL.md 1.3; Phase 1.4 does NOT re-offer parallel/epic.

Do NOT glob `tasks/*/epics/*/stories/*.md` and do NOT full-`Read` any story body — for
conflict detection read only each ready story's frontmatter `files:` line (SKILL.md 1.2 step
5), located via the index `File` column.

### Touched-files map (SKILL.md 1.2 step 5) — one batched Bash call

`READY` is each ready story's `File` column from `STORIES_INDEX.md`, prefixed with its plan
root. The `awk` stops at the closing frontmatter fence, so no body is ever read:

```bash
for f in $READY; do
  echo "== $f"
  awk 'FNR==1&&$0!="---"{exit} FNR==1{next} $0=="---"{exit} /^files:/{sub(/^files:[ \t]*/,"");print}' "$f"
done
```

Group the printed paths so no two stories share a file. The largest conflict-free group of
≥ 2 is the recommended parallel set.

If none ready:

```
No unblocked `todo` stories found. Check `tasks/` or run `/ck-code:plan` to generate stories.
```

---

## Phase 8.5.3 — Bug-Fix Sub-Loop (worked example)

When the user replies `ISSUES`, each cycle MUST run all 8 sub-steps before re-prompting (capture → log → red test → fix → refactor → QA → mark FIXED → re-prompt). The audit trail is the `## Manual-Test Bugs` section in the story file.

```
You: ISSUES — when I click "Save" with an empty title, the form silently
     resets instead of showing a validation error.

Claude: Captured. Recording bug #1.

  [TDD red]    tests/editor.test.ts → "shows validation error on empty title" → FAIL
  [TDD green]  src/editor/save.ts:42-48 — added required-title check → 47/47 pass
  [Refactor]   SOLID review on src/editor/save.ts → PASS
  [QA]         full suite + lint + arch → PASS, 0 regressions

  Bug #1 marked FIXED. Re-running manual test.

Please manually test:
- Save with empty title → should show validation error
- Save with valid title → should persist normally

Result? PASS / ISSUES
```

---

## Phase 8.5.3 — Escalation (after 3 cycles)

```
The manual-test bug-fix loop has run 3 times and issues remain:

  #1  Empty-title save resets the form          → FIXED (cycle 1)
  #2  Date-picker timezone offset               → FIXED (cycle 2)
  #3  Form race condition on rapid double-click → still ISSUES

A) FIX MANUALLY — you apply the fix; I run Refactor + QA against it
B) ACCEPT AS-IS — set `status: done`; #3 documented as known issue
C) ABORT        — set `status: todo`; do not commit
```

(Delivered via `AskUserQuestion` — A / B / C are the options, not a typed reply.)
