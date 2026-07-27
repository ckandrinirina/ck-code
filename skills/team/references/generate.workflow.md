# Phase 3.1a/3b generation workflow script

Passed verbatim as the `Workflow` tool's inline `script`, with
`args = { projectContext: "<resolved Phase 1.5 block>", skills: [{ slug, path, kind, template, research, triggers }, …] }`.
Gate, contract, and script rules: [`../../../references/dynamic-workflows.md`](../../../references/dynamic-workflows.md).

Every merge-rule decision is already made by the orchestrator — `skills` contains only paths cleared
to write. Returns `{ written: [manifest], missing: [slug] }`.

**The manifest is a claim, not proof.** Phase 4.1 must `ls` the real paths: a resumed run replays
cached results without re-writing, so a manifest entry can outlive its file.

```js
export const meta = {
  name: 'team-generate',
  description: 'Per-skill SKILL.md generation for /ck-code:team Phase 3.1a and 3b',
  phases: [{ title: 'Generate', detail: 'one agent per SKILL.md' }],
}

const RESULT = {
  type: 'object',
  additionalProperties: false,
  required: ['path', 'kind', 'written', 'lines'],
  properties: {
    path: { type: 'string' },
    kind: { type: 'string', enum: ['expert', 'guide'] },
    written: { type: 'boolean' },
    lines: { type: 'integer' },
  },
}

phase('Generate')

const results = await parallel(args.skills.map(s => () => agent(
  `Write EXACTLY ONE file, at this absolute path: ${s.path}

TEMPLATE + PER-ROLE DELTA (fill this, do not restructure it):
${s.template}

PROJECT CONTEXT BLOCK (already resolved — inject verbatim where the template calls for it):
${args.projectContext}

RESEARCH SLICE for this skill (the only source for best-practice content):
${s.research}

Requirements:
- Resolve EVERY [bracketed placeholder] from the data above. Leave none.
- Emit detection frontmatter: ${s.triggers}
- Reference /guide-conventions in the standards section so house rules override defaults.
- Emit this as the FIRST body line:
  <!-- ck-code:team GENERATED — /ck-code:team may overwrite this file on --regenerate. Delete this line to protect manual edits. -->

Then run: wc -l < ${s.path} and return the schema with the real line count.

Write ONLY your own path. Do not touch any shared or index file, do not run any generator script,
do not prompt. Note that $CLAUDE_PLUGIN_ROOT is EMPTY in your environment — use absolute paths only.`,
  { label: `generate:${s.slug}`, model: 'sonnet', schema: RESULT }
)))

return {
  written: results.filter(Boolean),
  missing: args.skills.filter((s, i) => !results[i]).map(s => s.slug),
}
```
