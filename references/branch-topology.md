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
class the v4 generated-views design exists to eliminate.

```
story branch    story/<EE>-<SS>-<kebab-case(title)>    fix/<EE>-<SS>-<slug> for a bug story
epic branch     epic/<NN>-<epic-slug>                  slug = EPIC.md `slug:` else folder slug
feature branch  feat/<plan-slug>                       = the tasks/<plan-slug>/ folder name
```

Epic branches are **looked up by the immutable number**, so renaming an epic slug never
orphans its branch:

```bash
git branch --list "epic/<NN>-*"
```

- exactly one match → use it
- no match → create it (see Creation)
- more than one → `AskUserQuestion` which one; never guess

## Resolution

```
<default> = gh repo view --json defaultBranchRef -q .defaultBranchRef.name
            fallback "main" when gh is missing or unauthenticated

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
- **Never ask for the PR base** — derive it.
- **Never merge without the clean-tree guard**, and never leave a merge half-applied —
  `git merge --abort` and restore the prior branch.
- **Never auto-open a PR** — promotion is always confirmed.
- **Never treat a level change as retroactive** — it applies from the next story onward.
