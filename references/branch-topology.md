# Branch Topology — Where Work Lands (Shared Source of Truth)

Three integration levels, chosen **once per epic** and stored in that epic's `EPIC.md`
frontmatter as `integration:`. Everything else on this page is derived from it. `build`,
`ship` and `track` link here; none of them restates the rule.

| Level | Reviewed as | Story branch is cut from & merged into |
|---|---|---|
| `story` (or empty) | one PR per story | the default branch |
| `epic` | one PR per epic | `epic/<NN>-<epic-slug>` |
| `feature` | one PR per plan | `epic/<NN>-<epic-slug>`, itself based on `feat/<plan-slug>` |

**Empty is `story`.** Every project that predates this field keeps its exact previous
behaviour, so there is no migration and no layout bump.

## Branch names are derived, never stored

A stored branch name is a second source of truth that can drift from git — the failure
class the v5 generated-views design exists to eliminate.

```
story branch    story/<EE>-<SS>-<kebab-case(title)>    fix/<EE>-<SS>-<slug> for a bug story
epic branch     epic/<NN>-<epic-slug>                  slug = EPIC.md `slug:` else folder slug
feature branch  feat/<plan-slug>                       = the tasks/<plan-slug>/ folder name
```

Epic branches are **looked up by the immutable number**, so renaming an epic slug never
orphans its branch. The number is unique project-wide
([`data-model.md`](data-model.md#epic-and-story-numbers-are-globally-unique)), so exactly
one epic can ever claim a given `epic/<NN>-*`:

```bash
git branch --list "epic/<NN>-*"
```

- exactly one match → use it
- no match → create it (see Creation)
- more than one → **a stale branch**, not two epics. The epic was renamed and an old
  branch survived, or a branch was hand-created. `AskUserQuestion` which one to use and
  say the others look stale; never guess, and never delete one unasked.

## Resolution

```
<trunk>   = tasks/SETTINGS.md `trunk_branch:` when set — the project's own answer
            else gh repo view --json defaultBranchRef -q .defaultBranchRef.name
            fallback "main" when gh is missing or unauthenticated
<default> = <trunk>                                  (one name, used everywhere below)

resolve_parent(epic NN, plan <slug>)   the branch a story branch is cut from
                                       and merged back into
  story | empty  ->  <default>
  epic           ->  epic/<NN>-*                       based on <default>
  feature        ->  epic/<NN>-*                       based on feat/<plan-slug>
                     feat/<plan-slug>                  based on <default>

resolve_pr_base()  ->  <default>                       at every level
```

The PR base is still **never asked for** — it is derived, now from `integration:` rather
than from `defaultBranchRef` alone.

**`trunk_branch` settles the `main`/`develop` question once.** A team whose integration
branch is not the repo default sets it in `tasks/SETTINGS.md`
([`data-model.md`](data-model.md#project-settings-taskssettingsmd)) and `ship` stops asking
per PR. It is also the branch a PR must merge into for a story to reach
`delivery: merged` ([`github-projects.md`](github-projects.md#reconciliation--how-delivery-merged-happens)):
one trunk, one definition, no way for the PR base and the delivered test to disagree.

## Start point — the base a new story branch is cut from

`resolve_parent` says which branch a story *belongs* on. This section says how a skill
**arrives** there. The checked-out branch is never the answer by default: a build is launched
from wherever the previous run left the tree, and cutting a story from a stale peer branch
puts two unrelated stories in one PR — silently, and only visible at review time.

```
resolve_base(story <EE>-<SS>, epic NN, plan <slug>)
  1. git branch --list "story/<EE>-<SS>-*" "fix/<EE>-<SS>-*"
       exactly one  ->  that branch            RESUME  (work already started here)
       more than one ->  ask which; never guess
  2. resolve_parent(NN, <slug>)                NEW     (created lazily, see Creation)
  3. the checked-out branch is a legal base ONLY when it equals 1 or 2
```

Every consumer **shows the resolved base with its reason** and lets the user override it. A
base chosen silently is the same defect class as a stored branch name — correct until it is
not, and invisible when it is not.

| Resolved base | Reason shown |
|---|---|
| existing `story/<EE>-<SS>-*` | work already started here — `<N>` commits |
| `<trunk>` | level `story` — this story gets its own PR into `<trunk>` |
| `epic/<NN>-*` | level `epic` — the story lands inside epic `<NN>`'s single PR |
| `epic/<NN>-*` (on `feat/<plan-slug>`) | level `feature` — the epic itself lands in the feature PR, never in `<trunk>` |

### Four signals that change the suggestion

- **The epic already has an open PR** (`EPIC.md` `pr:` set with `delivery: pr`) — say it
  outright: *this story joins open PR #`<n>`; it is not reviewed on its own.* Correct at level
  `epic`/`feature`, and the single outcome a user most often did not intend.
- **The base is behind its remote** — `git rev-list --count <base>..origin/<base>`; when
  greater than 0, offer **Sync base first** *inside the same question* (`git merge
  origin/<base>`, with the identical abort-and-report path as [Story merge](#story-merge)).
  Never a second prompt, never a silent merge.
- **The checked-out branch is another story's** (`story/*` or `fix/*` whose `<EE>-<SS>` is not
  this story's) — never offer it as a base without naming whose it is.
- **The user does not want this work to reach `<trunk>` directly** — that is an `integration:`
  level, not a base override. Offer to write `epic` or `feature` to the epic's `EPIC.md` in the
  same gate, then re-resolve the base from it. Hand-picking a base to simulate a level leaves
  `ship` deriving the PR from the *stored* level and targeting `<trunk>` anyway.

## Creation

Lazy and idempotent: a branch is created from its own parent the first time something must
sit on it, and never recreated. Under `feature`, the chain is built top-down.

```bash
git fetch origin --quiet
git branch feat/<plan-slug> origin/<default>        # only if absent
git branch epic/<NN>-<slug> feat/<plan-slug>        # only if absent; <default> when level is epic
```

## Story merge

Used by `ship` Phase 5 when the level is `epic` or `feature`.

**Clean-tree guard first.** The commit has landed, but deliberately unstaged files can
remain. If `git status --porcelain` is non-empty, do **not** check out — report the dirty
paths and offer **Stash and merge** / **Leave on story branch**.

```bash
git status --porcelain                     # must be empty
git checkout epic/<NN>-<slug>
git merge --no-ff story/<EE>-<SS>-<slug> -m "Merge story <EE>-<SS> <title>"
git branch -d story/<EE>-<SS>-<slug>
```

`--no-ff` is required: it keeps each story a readable unit, so the epic PR reads
story-by-story and `git log --first-parent` is a story list.

**Conflict path — never sloppy.** If the merge exits non-zero:

1. `git merge --abort`
2. `git checkout story/<EE>-<SS>-<slug>` — put the user back exactly where they were
3. report the conflicting paths from the merge output
4. tell them to resolve on the story branch and re-run `/ck-code:ship`

Never leave a half-merged tree. Never auto-resolve a conflict. On success the user stays on
the epic branch — the next story of that epic is cut from it anyway.

## Promotion

An epic is **promotable** when its level is `epic` or `feature`, every non-`skip` story is
`status: done`, and either `git rev-list --count <parent>..epic/<NN>-*` is greater than 0 or
it has no open PR.

**Staleness is folded into the gate, never asked separately.** Before offering any promotion
PR, run `git rev-list --count <branch>..origin/<default>`; if greater than 0, add
**Sync from `<default>` first** as an option *inside* the same question. Syncing is
`git merge origin/<default>`, with the identical abort-and-report path as Story merge.

**Epic gate** — fires once, when the epic rolls up to DONE:

```
Q: "Epic <NN> is complete (<done>/<total>). Promote it?"
   > Open PR epic/<NN>-<slug> -> <default>
     Merge into feat/<plan-slug>     creates the branch if absent;
                                     writes integration: feature to EPIC.md
     Push epic branch only
     Not yet                          -> /ck-code:ship --promote --epic <NN>
```

**Merge into feat/…** is what makes `integration:` a default rather than a prison: at epic
completion the user knows more than they did at epic start and can escalate a level on the
spot. The escalation is written back to `EPIC.md`.

**Every promotion PR records its number.** Opening a PR for `epic/<NN>-*` writes that
number to the epic's `EPIC.md` as `pr:` with `delivery: pr`; opening the feature PR writes
it to the `EPIC.md` of **every** `feature`-level epic in the plan. Those are the pointers a
story with no PR of its own inherits, and without them a story that ships only through an
epic PR could never leave *Ready to Ship*
([`data-model.md`](data-model.md#two-axes-status-is-work-delivery-is-integration)).

**Feature gate** — the feature branch only ever collects epics whose level is `feature`;
epics left at `story` or `epic` land independently and neither block it nor appear in it.
It fires when every `feature`-level epic of the plan is DONE and merged into
`feat/<plan-slug>`, and at least one such epic exists.

```
Q: "All <N> feature-level epics of <plan-slug> are merged into feat/<plan-slug>. Open the PR?"
   > Open PR feat/<plan-slug> -> <default>
     Push only
     Not yet
```

## Cleanup

- A merged story branch is deleted **at merge time** — the tool does the chore rather than
  reminding the user to.
- A story branch with an **open PR** is kept; the PR needs it. Its deletion becomes a
  summary reminder, because ship cannot observe the PR merging.
- The epic branch is deleted after its PR merges — also a reminder, same reason.

## Rules

- **Never store a branch name** in frontmatter — derive it from the epic number and plan slug.
- **Never resolve an epic branch by slug** — glob the immutable number, `epic/<NN>-*`.
- **Never ask for the PR base** — derive it: `trunk_branch`, else the repo default.
- **Never cut a story branch from the checked-out branch by default** — resolve the base
  (`resolve_base`), show it with its one-line reason, and let the user override it. The branch
  a skill happened to be launched on is a legal base only when it is the one that resolved.
- **Never change the base to keep work off `<trunk>`** — change the epic's `integration:` and
  re-resolve, or `ship` will target `<trunk>` from the stored level regardless.
- **Never open a PR without recording its number** — a story PR writes the story's `pr:`, a promotion PR writes the epic's; an unrecorded PR is a story that can never reach Done.
- **Never merge without the clean-tree guard**, and never leave a merge half-applied —
  `git merge --abort` and restore the prior branch.
- **Never auto-open a PR** — promotion is always confirmed.
- **Never treat a level change as retroactive** — it applies from the next story onward.
