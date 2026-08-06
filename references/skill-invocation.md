# Skill Invocation Contract — Cross-Skill Hand-Offs (Shared Procedure)

How one ck-code skill hands off to another. This file owns the **mechanics**;
[`workflow-map.md`](workflow-map.md) owns **which** hand-offs exist. A skill links to both
and restates neither.

## The rule

**Every cross-skill hand-off asks the user first — exactly one question, never a retype.**

The user always decides whether the hand-off happens. What this contract removes is not the
decision, it is the *labour* of the decision. Before it, saying yes meant reading a command
out of the output, typing `/ck-code:build tasks/2026-07-11_auth/stories/03-login.md` by
hand, and then approving a `Skill` permission prompt on top. After it, saying yes is
selecting **Run it** once.

## Two tiers

| Tier | Skills | Who calls `Skill` |
|---|---|---|
| **DIRECT** | `build` `config` `design` `fix` `migrate` `plan` `ship` `spec` `team` | The skill itself, via `Skill({ skill: "ck-code:<name>", args: "<resolved args>" })`. |
| **DIRECTIVE** | `doctor` `explain` `guide` `track` | Nobody, inside the skill. It prints a terminal `NEXT:` line; the main session runs the prompt below on its behalf. |

The DIRECTIVE tier is not a weaker form of consent — it asks the same single question. It
exists because these four skills run `context: fork` + `agent: Explore`, and an Explore
subagent has no `Write`/`Edit` tools, so a `build` invoked from inside one would fail at its
first file write.

`Skill` must appear in a DIRECT skill's `allowed-tools`. Without it the user answers **two**
prompts — the skill's own question, then a `Skill` permission prompt. That entry is what
makes the consent one click instead of two.

## The hand-off prompt

Print one announce block, then ask one question.

```
→ [fix → build] /ck-code:build tasks/2026-07-11_auth/stories/03-login.md
  reason: fix plan recorded, story at status: bug
```

Then `AskUserQuestion` with the command already resolved:

- **Run it** — one line naming the concrete effect ("takes the reproduction test RED → GREEN
  per the recorded Fix Plan").
- **Skip** — one line naming the resulting state ("the story stays at `status: bug`; run
  `/ck-code:build <path>` later").
- **Change arguments** — same skill, different story or flags.

On **Run it**, invoke immediately. On **Skip**, stop cleanly.

**Skip is always safe.** A hand-off is never load-bearing for the caller's own correctness —
the caller must already have reached a valid, resumable state before it asks.

## The `NEXT:` directive (DIRECTIVE tier only)

A read-only skill ends its output with one line, and nothing after it:

```
NEXT: /ck-code:build tasks/2026-07-11_auth/stories/03-login.md
```

Emit **at most one** `NEXT:` line per run, and only when a single next step is unambiguous.
Where the skill genuinely has several equal candidates, list them as prose recommendations
and emit no directive.

The main session treats a `NEXT:` line as a DIRECT hand-off from that skill and runs the
prompt above. A read-only skill never calls `Skill` itself.

## Chain guard

- **Max depth 3.** A fourth nested invocation stops and reports instead of invoking.
- **No repeats.** A skill may not invoke a skill already on the current chain. This kills
  `fix → build → fix` structurally rather than by judgement.
- The chain travels in the announce line (`[fix → build]`), so depth and loops are visible to
  the user at a glance and readable by each callee.

## Argument discipline

A caller passes a **concrete path or ID** — `tasks/2026-07-11_auth/stories/03-login.md`,
`--epic 07`, `03-01`. Never a referential phrase ("the current story", "that epic"). The
callee resolves nothing on the caller's behalf.

## Failure handling

If a callee fails, the caller **reports the failure and stops**. No silent retry, no fallback
to a different skill, no continuing as though the hand-off had succeeded. The user sees which
link in the chain broke.

## Rules

- **Never** hand off without asking — there is no silent-invocation tier.
- **Never** make the user retype a command the skill already resolved.
- **Never** call `Skill` from a read-only skill (`disallowed-tools: Write, Edit, NotebookEdit`) — emit `NEXT:`.
- **Never** invoke a skill already on the current chain, or at depth > 3.
- **Never** pass a referential argument; always a resolved path or ID.
- **Always** leave the project valid and resumable before asking, so **Skip** is safe.
- **Always** link here for the mechanics and to `workflow-map.md` for the graph; restate neither.
