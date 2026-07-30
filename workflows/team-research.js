export const meta = {
  name: 'team-research',
  description: 'Per-technology best-practice research for /ck-code:team Phase 1.6a',
  phases: [{ title: 'Research', detail: 'one agent per technology, retried until dry' }],
}

const BRIEF = {
  type: 'object',
  additionalProperties: false,
  required: ['technology', 'version', 'conventions', 'structure', 'patterns', 'anti_patterns',
             'performance', 'error_handling', 'testing', 'version_notes', 'sources'],
  properties: {
    technology: { type: 'string' },
    version: { type: 'string' },
    conventions: { type: 'array', items: { type: 'string' } },
    structure: { type: 'string' },
    patterns: { type: 'array', items: { type: 'string' } },
    anti_patterns: { type: 'array', items: { type: 'string' } },
    performance: { type: 'array', items: { type: 'string' } },
    error_handling: { type: 'array', items: { type: 'string' } },
    testing: { type: 'array', items: { type: 'string' } },
    version_notes: { type: 'array', items: { type: 'string' } },
    sources: { type: 'array', items: { type: 'string' } },
  },
}

phase('Research')

let todo = args.technologies
const briefs = {}

for (let round = 0; round < 3 && todo.length; round++) {
  const batch = await parallel(todo.map(t => () => agent(
    `Research CURRENT, version-specific best practices for ${t.name} ${t.version}.

FIRST run ToolSearch with query "select:WebSearch,mcp__context7__resolve-library-id,mcp__context7__query-docs"
to load those schemas — they are deferred and not callable until you do. If the context7 MCP tools
do not resolve, fall back to the ctx7 CLI via Bash, then to WebSearch.

Resolve the context7 library id and fetch its docs; use WebSearch only where context7 lacks coverage.
Scope every field to what is current, version-specific, and project-relevant — never padded basics
a competent developer already knows.

Write NO files. Prompt no one. Return the schema; leave a field's array empty rather than inventing
content for it.`,
    { label: `research:${t.id}`, model: 'haiku', schema: BRIEF }
  )))

  const failed = []
  batch.forEach((r, i) => (r ? (briefs[todo[i].id] = r) : failed.push(todo[i])))
  if (failed.length) log(`round ${round + 1}: ${failed.length} technology(s) returned empty — retrying`)
  todo = failed
}

return { briefs, unresolved: todo.map(t => t.id) }
