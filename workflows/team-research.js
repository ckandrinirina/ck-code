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

// A brief whose every content field came back empty carries no research at all, so it counts
// as a failure and is retried exactly like a null result.
const CONTENT_FIELDS = ['conventions', 'patterns', 'anti_patterns', 'performance',
                        'error_handling', 'testing', 'version_notes', 'sources']
const isEmptyBrief = b => !b ||
  (!String(b.structure || '').trim() && CONTENT_FIELDS.every(k => !(b[k] || []).length))

phase('Research')

let todo = args.technologies
const briefs = {}

for (let round = 0; round < 3 && todo.length; round++) {
  const batch = await parallel(todo.map(t => () => agent(
    `Research CURRENT, version-specific best practices for ${t.name} ${t.version}.

FIRST run ToolSearch with query "select:WebSearch,mcp__context7__resolve-library-id,mcp__context7__query-docs,mcp__plugin_context7_context7__resolve-library-id,mcp__plugin_context7_context7__query-docs"
to load those schemas — they are deferred and not callable until you do. context7 ships under two
MCP names; use whichever of the two pairs the ToolSearch result actually returned. If neither
resolves, fall back via Bash to \`npx -y @upstash/context7 library "${t.name}" "<query>"\` (or
\`ctx7 library …\` if installed globally), then to WebSearch.

Resolve the context7 library id and fetch its docs; use WebSearch only where context7 lacks coverage.
Scope every field to what is current, version-specific, and project-relevant — never padded basics
a competent developer already knows.

Write NO files. Prompt no one. Return the schema; leave a field's array empty rather than inventing
content for it. Do not return a brief in which every content field is empty — that is read as a
failed unit and retried; use WebSearch before giving up.`,
    { label: `research:${t.id}`, model: 'haiku', schema: BRIEF }
  )))

  const failed = []
  batch.forEach((r, i) => (isEmptyBrief(r) ? failed.push(todo[i]) : (briefs[todo[i].id] = r)))
  if (failed.length) log(`round ${round + 1}: ${failed.length} technology(s) returned empty — retrying`)
  todo = failed
}

return { briefs, unresolved: todo.map(t => t.id) }
