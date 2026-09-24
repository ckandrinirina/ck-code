# Phase 3.1 generation workflow

The script is a **registered plugin workflow**, not an inline blob: it ships at
`workflows/team-generate.js` and Claude Code loads it with the plugin. Invoke it by name —
never paste the source into the `script` parameter.

```
Workflow({
  name: "team-generate",
  args: {
    digest: "<output of ck-team digest>",
    skills: [{ slug, path, kind, template, research, triggers }, …]
  }
})
```

Gate, contract, and script rules: [`../../../references/dynamic-workflows.md`](../../../references/dynamic-workflows.md).

Every merge-rule decision is already made by the orchestrator — `skills` contains only paths
cleared to write. Returns `{ written: [manifest], missing: [slug] }`.

**`skills` carries net-new paths only.** The script hands each agent a template, not the file
it is replacing, so it cannot honour the MANUAL re-insert rule. A target that already exists on
disk — a team-owned GENERATED file being refreshed under `--refresh` or `--regenerate` — is therefore excluded
from `args.skills` and regenerated **inline** by the orchestrator, which reads the current file
and re-inserts every `<!-- ck-code:team MANUAL START/END -->` fence verbatim. A `--regenerate`
run over an existing team can legitimately pass an empty or short `skills` array; that is not a
gate failure. `--refresh` never calls this workflow: every path it rewrites already exists.

Each `template` already carries the resolved **Project context** links (Phase 1.5); the script
adds no context block of its own. `digest` is stamped into the SOURCES marker line of every
file, so run `ck-team digest` once before the call and never let an agent compute it.

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
