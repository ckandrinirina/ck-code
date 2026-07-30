# Phase 1.6a research workflow

The script is a **registered plugin workflow**, not an inline blob: it ships at
`workflows/team-research.js` and Claude Code loads it with the plugin. Invoke it by name —
never paste the source into the `script` parameter.

```
Workflow({
  name: "team-research",
  args: { technologies: [{ id, name, version }, …] }
})
```

Gate, contract, and script rules: [`../../../references/dynamic-workflows.md`](../../../references/dynamic-workflows.md).

Returns `{ briefs: { <id>: brief }, unresolved: [<id>] }`. The orchestrator merges `briefs`
into the single "Best Practices Knowledge" block and researches every `unresolved` id inline
before Phase 2.

**Why registered rather than inline.** A named workflow has a stable identity across runs, so
`resumeFromRunId` can replay the unchanged prefix from cache when a long research fan-out dies
halfway — the whole reason [`dynamic-workflows.md`](../../../references/dynamic-workflows.md)
sanctions the `Workflow` backend at all. An inline script re-pasted from a reference file is a
new script each time and resumes nothing.

Each technology is researched by one `haiku` agent returning a validated `BRIEF` schema, retried
for up to 3 rounds while any agent returns empty. Read
[`workflows/team-research.js`](../../../workflows/team-research.js) for the schema fields and
the retry loop; it is the single source of truth and is never restated here.
