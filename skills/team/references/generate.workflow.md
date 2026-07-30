# Phase 3.1 generation workflow

The script is a **registered plugin workflow**, not an inline blob: it ships at
`workflows/team-generate.js` and Claude Code loads it with the plugin. Invoke it by name —
never paste the source into the `script` parameter.

```
Workflow({
  name: "team-generate",
  args: {
    projectContext: "<resolved Phase 1.5 block>",
    skills: [{ slug, path, kind, template, research, triggers }, …]
  }
})
```

Gate, contract, and script rules: [`../../../references/dynamic-workflows.md`](../../../references/dynamic-workflows.md).

Every merge-rule decision is already made by the orchestrator — `skills` contains only paths
cleared to write. Returns `{ written: [manifest], missing: [slug] }`.

**The manifest is a claim, not proof.** Phase 4.1 must `ls` the real paths: a resumed run
replays cached results without re-writing, so a manifest entry can outlive its file.

**Why registered rather than inline.** A named workflow keeps a stable identity across runs, so
a generation fan-out that dies halfway resumes from cache with `resumeFromRunId` instead of
re-paying every agent. See [`workflows/team-generate.js`](../../../workflows/team-generate.js)
for the per-skill prompt and the `RESULT` schema — it is the single source of truth and is
never restated here.

Note the constraint the script passes to every agent: `$CLAUDE_PLUGIN_ROOT` is **empty** inside
a workflow subagent, so paths must be absolute. ck-code's own generators are exempt — `ck-index`
and `ck-doctor` are on `PATH` via the plugin's `bin/` and work there unchanged (though a
generation agent must still never run them).
