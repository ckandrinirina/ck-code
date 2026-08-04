# Parallel Mode — Orchestration Detail (P1–P9)

Detail for `SKILL.md` § PARALLEL MODE. Read when two or more stories are in scope, or when
`--epic NN` orchestrates a single remaining story. The orchestrator decides, verifies, and
merges; it never builds, tests, or reads source.

Companions: [agent-prompts.md](agent-prompts.md) (prompts + return schema) ·
[wave-mode.md](wave-mode.md) (wave planning) ·
[conflict-format.md](conflict-format.md) (every report shape).

## Two dispatch shapes

Every story here is implemented by a dispatched agent. What changes with wave width is
**isolation**, and everything downstream of it:

| Wave width | Shape | Isolation | P6 conflicts | P8 merge |
|---|---|---|---|---|
| ≥ 2 stories | **fan-out** | one worktree per story | runs | merge each branch into `$TARGET` |
| exactly 1 story | **solo** | none — the main checkout | skipped (no peer branch) | nothing to merge across branches |

Solo keeps the orchestrator/implementer split (this context still never builds or reads
source) while dropping the worktree, its cold dependency install, and the whole
conflict-and-merge stage that only exists because peers run concurrently.

**Where solo commits.** The agent works in the main checkout on `$TARGET` — *unless*
`$TARGET` is the default branch (`main`/`develop`, i.e. `integration: story`). Implementation
on a protected branch is forbidden project-wide (SKILL.md 3.5), so in that case the solo agent
cuts `story/<EE>-<SS>-<slug>` (or `fix/…`) **in the main checkout**, commits there, and P8
merges that one branch into `$TARGET`. Still no worktree. Call the branch it will use
`$WORKBRANCH` below; at `epic`/`feature` integration `$WORKBRANCH == $TARGET`.

## The P-step map

What this context does at each step, and the one thing that must never bend. Every row is
detailed in its section below.

| Step | What this context does | Non-negotiable |
|---|---|---|
| **P1** | Resolve `$TARGET` from the epic's `integration:` level (dirty tree or detached HEAD stops the run) and resolve the story set from `STORIES_INDEX.md` | Never `Read` a story body; never merge into a hardcoded `main`, and never into whatever branch happened to be checked out |
| **P2** | Order the scope into waves by `Blocked by`, then split each wave so no two stories share a declared `files:` path | Print every excluded story with its reason |
| **P3** | Team gate (`ls .claude/skills/{expert,guide}-*/SKILL.md`) + wave-plan confirmation + criteria ambiguity, folded into **one `AskUserQuestion`, ≤ 4 questions** | Never dispatch with zero project skills without asking — agents cannot prompt |
| **P4** | Dispatch the wave: **fan-out** (≥ 2) = one worktree `Agent` per story in a single message; **solo** (= 1) = one `Agent` on `$WORKBRANCH`, no worktree. Both `subagent_type: "ck-code:story-implementer"`, stable name `story-EE-SS`, `MODE: delegated` | Every story goes to an agent; a worktree only when a peer runs beside it. Tier the model by reasoning complexity, never `size` |
| **P5** | Integrity **the moment an agent returns** → ✓ complete / ◐ incomplete (resume the same agent, cap 2) / 🚫 blocked | "Done" comes from git, never the agent's self-report |
| **P6** | `ck-code:conflict-analyzer` dry-runs each ✓ branch onto `$TARGET` and returns a merge order | Cross-branch by construction — the fan-out wave's one barrier. **Skipped entirely on a solo wave.** Every dry-run is aborted; nothing lands here |
| **P7** | One `ck-code:qa-validator` per ✓ story, launched as it clears P5 | Acceptable = ✓ complete + `QA: PASS` (+ conflict-free, fan-out only) |
| **P8** | Fan-out: merge in P6's order. Solo: nothing to merge (or one local branch when `$WORKBRANCH ≠ $TARGET`). Then regenerate the indexes **once**, run `qa-validator` on `$TARGET`, then the SKILL.md 8.5 manual gate once for the wave | Never accept work that has not passed P7 |
| **P9** | Re-resolve the next wave from the regenerated index and loop from P3 | A held story keeps its branch (and worktree, if any) and holds its dependents |

**P5 and P7 are pipelined, P6 and P8 are barriers.** P5 and P7 judge one story against
itself, so each walks them as soon as its agent returns — the fastest story's QA runs
while the slowest is still coding. P6 derives an order from the overlaps *between* branches
and P8 merges into a moving `$TARGET`; neither can start on a partial set. Barriering P5 or
P7 on the whole wave is the single largest avoidable delay in this mode. On a solo wave the
pipeline collapses to one story and P6 does not run at all.

## P1 — Freeze the target and resolve scope

```bash
git status --porcelain && git branch --show-current
```

A dirty tree or a detached HEAD stops the run — say which and stop.

`$TARGET` is `resolve_parent(epic NN)`
([`branch-topology.md`](../../../references/branch-topology.md#resolution)), created if
absent — **not** whatever branch is currently checked out. At level `story` that resolves to
the default branch; at `epic`/`feature` to `epic/<NN>-*`. This mode is already scoped to a
single epic, so exactly one `$TARGET` resolves. Every later phase merges into it, never a
hardcoded `main`.

Resolving the scope set, by argument shape:

| `$ARGUMENTS` | Scope |
|---|---|
| Story IDs (`02-05 03-01`) | exactly those stories; skip the feature gate — explicit scope is always respected |
| `--epic NN` | every non-`DONE` story of epic `NN`; skip the feature gate |
| Empty (menu route) | the set the SKILL.md 1.2 menu already resolved — do not re-derive it |

Read the feature's `tasks/<Plan>/STORIES_INDEX.md` (the generated view) to map IDs to file
paths and `Blocked by` sets; regenerate it with
`ck-index tasks/<Plan>` first if it is missing or lacks
the `GENERATED by ck-code` header. **Never `Read` an individual story body in this phase** —
the index is the only discovery source.

A story is **ready** when its `Status` is `TODO` and every `Blocked by` ID resolves to `DONE`
in the same table (empty `Blocked by` is always ready), **or** its `Status` is `BUG` (a
triaged bug from `/ck-code:fix`; the dispatched run enters Bug-Fix Mode). If nothing in scope
is ready, list the still-blocked `TODO` rows with their unmet blockers and stop.

**One story in scope from anything other than `--epic NN`** — an explicit story path, a lone
story ID, a single-story pick from the 1.2 menu — **is never orchestrated**: hand it to
SKILL.md Phase 1.3 and run Phases 1–8 inline.
**`--epic NN` always orchestrates**, even when one story remains: it dispatches that story
solo at P4 (no worktree), because an epic run keeps the orchestrator's context clean and lands
every story the same way on `$TARGET`.

## P2 — Plan the waves

Each story's declared file scope is its frontmatter `files:` line. Read only that one line
per story — bounded, never the body — reusing the SKILL.md 1.2 map when it already ran:

```bash
for f in <story paths from the index File column>; do
  echo "== $f"
  awk -F'[][]' '/^files:/{n=split($2,a,","); for(i=1;i<=n;i++){gsub(/^ +| +$/,"",a[i]); if(a[i]!="")print a[i]}}' "$f"
done
```

Order the scope into waves by `Blocked by`, then split each wave so no two stories in it
share a declared path — the algorithm and the un-startable / `UNSCHEDULABLE` cases are in
[wave-mode.md](wave-mode.md). Print the wave plan table
([conflict-format.md](conflict-format.md)) plus every excluded story and the reason.

This is a heuristic from *declared* scope; P6 still runs the authoritative dry-run merge on
*actual* diffs.

## P3 — Team gate and confirmation

```bash
ls .claude/skills/expert-*/SKILL.md .claude/skills/guide-*/SKILL.md 2>/dev/null
```

Empty output means `/ck-code:team` has never run and every dispatched agent would write
generic code with no project experts, guides, or QA rules. Warn per
[`skill-detection.md`](../../../references/skill-detection.md) § 4a.1: **RUN TEAM FIRST**
(recommended) → `Skill({ skill: "ck-code:team" })`, then dispatch with the generated skills
in place; **CONTINUE WITHOUT SKILLS** → dispatch as-is. Never dispatch without asking.

Fold that question, the wave-plan confirmation (`PROCEED` / `DROP A STORY` / `ABORT`), and
any genuine acceptance-criteria ambiguity into **one `AskUserQuestion`, at most 4 questions**
— the dispatched agents have no user, so ambiguity is resolved here or not at all. Skip the
wave-plan question when the SKILL.md 1.2 menu already resolved this exact scope; that
selection was the confirmation, and re-asking it is a wasted round-trip.

## P4 — Dispatch

Count the wave's stories first — that count, and nothing else, picks the shape.

### Fan-out (wave holds ≥ 2 stories)

Announce the decision first, in one line: `Fan-out: N stories → dispatching N agents.`
(an unannounced dispatch is indistinguishable from a forgotten one). Then dispatch every
story of the wave in a **single message** — one `Agent` call each, all in one turn, so
they run concurrently. Per story (full prompt: [agent-prompts.md](agent-prompts.md)):

- `isolation: "worktree"` — the harness cuts each agent its own git worktree from `$TARGET`;
  no manual `git worktree add`, no base-SHA pinning, no branch-collision guard. Changed
  worktrees persist for merge; unchanged ones auto-clean.
- `subagent_type: "ck-code:story-implementer"` (falls back to `general-purpose`).
- A stable **name** per agent (`story-EE-SS`) so P5 can resume it with `SendMessage`.
- A prompt beginning `MODE: delegated`, so the dispatched `build` run applies its
  DELEGATED MODE deltas (no branch question, no `ck-index`, no manual gate, no ship).

### Solo (wave holds exactly 1 story)

One story has no peer to collide with, so it gets no worktree — the agent works in the main
checkout and its commits are already where they need to be.

1. **Resolve `$WORKBRANCH`.** `$TARGET` when the epic's `integration:` is `epic` or
   `feature`. When `$TARGET` is the default branch (`integration: story`), instead create and
   check out `story/<EE>-<SS>-<slug>` (`fix/…` for a `BUG` story) from `$TARGET` **here in the
   orchestrator, before dispatch** — never let the agent choose a branch — and record that
   P8 must merge it back.
2. **Record the base SHA** — `git rev-parse HEAD` on `$WORKBRANCH`. P5 has no second branch to
   diff against, so this SHA *is* the baseline. Capture it before the agent starts.
3. **Announce**: `Solo: 1 story → dispatching 1 agent on <$WORKBRANCH> (no worktree).`
4. **Dispatch one `Agent`** — same `subagent_type`, same stable `story-EE-SS` name, same
   model tiering, same `MODE: delegated` prompt, but **no `isolation` field** and the extra
   branch guard from [agent-prompts.md](agent-prompts.md) § solo: the agent verifies
   `git rev-parse --abbrev-ref HEAD` is `$WORKBRANCH` before its first edit and never runs
   `checkout -b`, `switch -c`, `rebase`, `reset`, or `worktree`.

The tree must be clean at dispatch (P1 already enforced that) and stays the agent's alone
until it returns — never dispatch a solo agent while a fan-out wave is still in flight, and
never edit files in this context while one is running.

### Worktree dependency bootstrap (fan-out only)

A solo wave skips this section entirely — the main checkout already has its dependencies
installed, which is a large part of why solo is cheaper.

Every worktree is a bare checkout — no `node_modules`, no `target/`, no `.venv`. N agents
pay N cold installs and N cold compiles, routinely the largest slice of a parallel run's wall
clock. The rule: **share immutable caches, never a mutable install tree** — a peer that
changes a dependency must not be able to mutate another worktree mid-run.

| Stack | Share this | Never |
|---|---|---|
| npm / yarn | pnpm's global store — `pnpm install` links a per-worktree `node_modules` over one immutable content store | One `node_modules` symlinked into every worktree |
| Rust | `CARGO_TARGET_DIR=<absolute shared path>` — cargo file-locks it, so it is correct; concurrent builds then serialize on that lock, so measure before adopting | — |
| Python | `UV_CACHE_DIR` / `PIP_CACHE_DIR` pointed at one shared path | One `.venv` shared across worktrees |

Name the scheme in the dispatch prompt when the project has one, so every agent installs the
same way. With no scheme, say so in the launch announce — the cold installs are then the
expected cost, not a stall.

### Model tier — by reasoning complexity, never `size`

Default every story to **balanced → `model: sonnet`**. Escalate to **advanced → `model: opus`**
only on a clear high-reasoning signal (novel algorithm, concurrency/distributed correctness,
intricate state machine, security- or perf-critical path, non-obvious architecture); use
**fast → `model: haiku`** (or `fable` when `haiku` drops instructions) only for trivial
mechanical changes. `size` reflects scope, not difficulty, so it never escalates on its own.

**Dispatch the alias, never the tier name** — `model:` accepts only `haiku`, `fable`,
`sonnet`, `opus`; `balanced`/`advanced`/`fast` are rejected. Full map:
[agent-prompts.md](agent-prompts.md#tier-map--write-the-alias-never-the-tier-name).

The operator can repoint any tier in `/plugin` → ck-code (`userConfig`); the resolved values
are substituted into [agent-prompts.md](agent-prompts.md#tier-map--write-the-alias-never-the-tier-name)
at load time. Print the resolved Story → Complexity → Tier → Model line in the launch announce
so a mis-resolution is catchable before work starts.

Create one Claude Task per story (`TaskCreate`, `Implement EE-SS: <title>`, wave-prefixed in
wave mode) as a live board when the Task tools are available; mark each `in_progress` at
dispatch and `completed` when it merges and passes its gate. `TaskList` at P5, P7, and P8.

## P5 — Integrity and resume

Verify each story **the moment its agent returns** — never hold a returned branch waiting on
the wave. The failure to catch is an agent that did nothing yet reported success. Same three
checks either way; only the baseline of the diff changes.

**Fan-out** — using the returned `branch` and the story path:

```bash
git diff --shortstat "$TARGET".."<branch>"                     # empty → 🚫 no implementation
git show "<branch>:<story path>" | grep -cE '^\s*-\s*\[ \]'    # >0 → criteria unmet
git diff --name-only --diff-filter=D "$TARGET".."<branch>"     # any → ⚠ unexpected deletion
```

**Solo** — there is no second branch, so diff against the base SHA recorded at P4, and also
confirm the agent left the tree clean and stayed on `$WORKBRANCH`:

```bash
git rev-parse --abbrev-ref HEAD                                # ≠ $WORKBRANCH → 🚫 branch drift
git status --porcelain                                         # non-empty → ◐ uncommitted work
git diff --shortstat <base-sha>..HEAD                          # empty → 🚫 no implementation
grep -cE '^\s*-\s*\[ \]' "<story path>"                        # >0 → criteria unmet
git diff --name-only --diff-filter=D <base-sha>..HEAD          # any → ⚠ unexpected deletion
```

Branch drift on a solo run is a hard stop, not a resume: the agent committed somewhere this
context did not sanction. Report the branch it landed on and stop the wave.

Classify (report format: [conflict-format.md](conflict-format.md)):

- **✓ complete** — non-empty diff, zero unchecked criteria, no unexpected deletion.
  Merge-eligible pending QA. (`criteria_met` from the return is a hint; the grep is the proof.)
- **◐ incomplete** — real diff but criteria still unchecked, or (solo) work left uncommitted
  (the agent ran out of budget). Not failed. **Resume the same agent** with `SendMessage`
  ([agent-prompts.md](agent-prompts.md)) — its context is intact, and so is its worktree
  (fan-out) or the main checkout it left behind (solo). Re-run this gate; cap **2 resume
  rounds**. Still
  incomplete after the cap, or a resume that makes zero new commits → flag `too large /
  stuck`, keep the branch, recommend splitting.
- **🚫 blocked** — empty diff (nothing to resume — re-dispatch fresh via a new `Agent` call)
  or an unexpected deletion. Excluded from merge; branch kept; reported for review.

Never trust the agent's word; a story is done only when this gate and P7 QA agree.

## P6 — Conflict analysis (dry-run stage, before any merge)

**Skipped on a solo wave** — conflict analysis compares peer branches, and a solo wave has
none. Say so in one line (`Conflicts: skipped (solo wave).`) and go to P7.

**The fan-out wave's one barrier** — starts only once every branch has cleared P5, and runs
while the P7 QA already dispatched is still in flight. It never waits for QA.

Delegate the ✓-complete branches to `ck-code:conflict-analyzer` (falls back inline): it
dry-run `git merge --no-commit`s each branch onto `$TARGET`, classifies risk, and returns a
merge order (fewest overlaps first) — aborting every dry-run so nothing lands. Print the
conflict report ([conflict-format.md](conflict-format.md)); no overlaps → "all branches merge
cleanly." One branch → nothing to compare; skip.

## P7 — QA, one validator per story

Dispatch one `ck-code:qa-validator` agent (Haiku tier) per ✓-complete story **as soon as it
clears P5** — batch whatever cleared in the same turn into one message, but never hold a
cleared branch waiting on a slower peer (the P4 single-message rule governs the implementer
fan-out, not this one). QA judges one story's branch against itself, so it needs no other
branch. Each runs its stack's build/test/lint in its own cheap context and returns
a compact `QA: PASS` / `QA: FAIL — <cmd> — <excerpt>` verdict, keeping the heavy output off
this context (prompt: [agent-prompts.md](agent-prompts.md)).

**Solo wave:** dispatch the same validator **without `isolation`**, against `$WORKBRANCH` in
the main checkout — there is no worktree to check out and re-install. It stays read-only, so
it cannot disturb the checkout.

Resolve each story's commands from the component its `files:` touch — detect the stack from
that directory's manifest:

| Manifest | QA commands |
| --- | --- |
| `Cargo.toml` | `cargo test && cargo clippy -- -D warnings && cargo fmt --check` |
| `package.json` | the declared `test`, `lint`, and typecheck scripts |
| `pyproject.toml` | `pytest` + the declared lint/format checks |
| `go.mod` | `go test ./... && go vet ./...` |
| `CMakeLists.txt` | `cmake --build build --config Release`, then verify the artifact |

A project's `guide-conventions` skill overrides this table when it names canonical commands.
No manifest match → ask once and reuse. Mark any QA-failing story **BLOCKED** — from merge in
a fan-out wave — and keep its branch. Acceptable = ✓ complete + `QA: PASS`, plus conflict-free
in a fan-out wave.

A solo wave that QA-fails has its work sitting on `$WORKBRANCH` with nothing to withhold, so
"blocked" means *do not proceed to the manual gate or the next wave*: report the failure, keep
the commits, and offer the same P8 choices (fix agent on `$WORKBRANCH`, or stop for review).
Never advance P9 past a red solo story — its dependents would build on broken code.

## P8 — Merge, regenerate, verify

Print the final summary with options ([conflict-format.md](conflict-format.md)) and use
**AskUserQuestion**:

1. **Merge ready branches now** (conflict-free order) — *fan-out, or a solo run whose
   `$WORKBRANCH ≠ $TARGET`*
2. **Review branches first, merge manually** — print branch names and stop
3. **Re-dispatch blocked/failed stories** — fresh `Agent` call for empty or errored stories
   only (◐ incomplete is resumed at P5, not here). A new worktree in fan-out; a fresh solo
   dispatch on `$WORKBRANCH` in a solo wave.

**Solo wave, `$WORKBRANCH == $TARGET`** — the work is already on the target; there is no merge
question. Skip straight to the regenerate below, saying so in one line
(`Merge: none needed (solo on <$TARGET>).`).

**Option 1** — merge each eligible branch into `$TARGET` in P6's order (a solo wave has one
branch and no order to derive):

```bash
git checkout "$TARGET"
git merge --no-ff "<branch>" -m "feat: implement story <id>"
```

Then **regenerate the indexes once** on the target branch — every dispatched agent, worktree
or solo, carries only its own story frontmatter at `done` (sub-agents never touch the shared
views); the generator rebuilds them from that frontmatter with no cell-editing and no
sole-writer hazard:

```bash
ck-index tasks/<Plan>
```

Commit the regenerated views. Then dispatch **one** post-merge `ck-code:qa-validator` on
`$TARGET` in the main checkout (the union of the wave's stories' commands, de-duplicated) — a
merge does not make integration failures cheap to find. `QA: FAIL` here is a cross-branch
integration failure by construction; keep the branches and offer `git revert -m 1 <merge-sha>`
or a fix agent on `$TARGET`.

**Solo wave:** run this post-wave QA too, even though P7 just passed on the same branch — P7
judged the story before the index regenerate committed on top of it. Its failure is not a
cross-branch integration failure (there was no merge); recover with a fix agent on
`$WORKBRANCH`, or `git revert <sha>` of this wave's commits when the story must come back out.

**Manual gate (SKILL.md 8.5, once per wave — solo waves included).** Ask the operator to
exercise the wave's work on `$TARGET` in the main checkout (`AskUserQuestion` `PASS / ISSUES`)
— the only place every story of the wave sits together with real dependencies. A solo wave is
not exempt: one story still lands on the shared target, and the gate is what keeps it from
becoming the next wave's foundation unverified. On `ISSUES`, dispatch one `Agent` into the
main checkout on `$TARGET` (`git rev-parse --abbrev-ref HEAD` guard) invoking
`/ck-code:build`, which enters its bug-fix loop and commits the fix on `$TARGET`; then
re-ask. The story stays merged — this is a fix, not a re-open.

**Cleanup.** After the merge and its check settle, `git worktree prune` and confirm only the
main worktree remains (changed native worktrees linger until pruned; unchanged ones already
auto-cleaned). Then delete each **merged** story branch — `git branch -d "<branch>"` per
branch that landed in `$TARGET` this wave (`-d`, never `-D`: an unmerged branch must refuse
to die). Merged branches left standing accumulate forever and bury the real ones. A worktree
or branch still standing must map to a story the report names as held, blocked, or
conflicted — that is the only state a resume can read from.

A solo wave has nothing to prune when `$WORKBRANCH == $TARGET`; say `Cleanup: none (solo on
<$TARGET>).` rather than skipping the step silently. When it cut its own `story/…` branch,
delete it with the same `-d` after it merges.

## P9 — Next wave

Re-resolve the following wave from the freshly regenerated index and loop from P3. A story
held back from merge stays non-`done` and holds every story that depends on it — those cannot
dispatch. When no scheduled story remains, print the batch report naming every held,
`UNSCHEDULABLE`, and blocked story with its reason, then point at `/ck-code:ship <story-path>`
per merged branch and `/ck-code:track next` for the following batch.
