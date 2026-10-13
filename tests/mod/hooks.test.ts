import { expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

// A ck-code project at /p: docs/architecture exists, nothing else does.
function codeProject(on: On) {
  on('session.cwd', () => ({ value: '/p' }))
  on('fs.exists', (_$, e) => ({ value: e.path === '/p/docs/architecture' }))
  on('fs.list', () => ({ value: [] }))
}

// A scratch repo: no marker at all.
function scratchProject(on: On) {
  on('session.cwd', () => ({ value: '/p' }))
  on('fs.exists', () => ({ value: false }))
  on('fs.list', () => ({ value: [] }))
}

test('a hand edit of a generated view is refused in a ck-code project', async ($, on) => {
  codeProject(on)
  on('tool.call', () => ({ result: 'written' }))
  const r = await $.tool.call({ tool: 'Write', file_path: '/p/tasks/v1/STORIES_INDEX.md', content: 'x' })
  expect(JSON.stringify(r)).toContain('generated view')
})

test('the same write runs in a project that has not adopted ck-code', async ($, on) => {
  scratchProject(on)
  on('tool.call', () => ({ result: 'written' }))
  const r = await $.tool.call({ tool: 'Write', file_path: '/p/tasks/v1/STORIES_INDEX.md', content: 'x' })
  expect(JSON.stringify(r)).toContain('written')
})

test('git clean -X is refused, git clean -fd runs', async ($, on) => {
  codeProject(on)
  on('tool.call', () => ({ result: 'ran' }))
  const refused = await $.tool.call({ tool: 'Bash', command: 'git clean -fdX' })
  expect(JSON.stringify(refused)).toContain('ck-reclaim')
  const ran = await $.tool.call({ tool: 'Bash', command: 'git clean -fd' })
  expect(JSON.stringify(ran)).toContain('ran')
})

test('commit and PR attribution is empty in a ck-code project', async ($, on) => {
  codeProject(on)
  on('attribution.text', (_$, e) => ({ text: e.text }))
  const commit = await $.attribution.text({ kind: 'commit', text: 'Co-Authored-By: Claude' })
  expect(commit.text).toBe('')
})

test('attribution is left alone outside a ck-code project', async ($, on) => {
  scratchProject(on)
  on('attribution.text', (_$, e) => ({ text: e.text }))
  const commit = await $.attribution.text({ kind: 'commit', text: 'Co-Authored-By: Claude' })
  expect(commit.text).toBe('Co-Authored-By: Claude')
})

test('ck-code-lite commands are hidden in a ck-code project', async ($, on) => {
  codeProject(on)
  on('command.describe', (_$, e) => ({ description: e.description, isHidden: e.isHidden }))
  const lite = await $.command.describe({
    command: 'ck-code-lite:build',
    description: 'x',
    isHidden: false,
    immediate: false,
    provider: { plugin: 'ck-code-lite', tier: 'user' },
  })
  expect(lite.isHidden).toBe(true)
})

test('a free-text prompt in a ck-code project gets the routing table as context', async ($, on) => {
  codeProject(on)
  on('fs.read', () => ({ value: '<!-- maintainer -->\n# Routing\nbug -> /ck-code:fix' }))
  on('prompt.submit', (_$, e) => ({ text: e.text, context: e.context }))
  const r = await $.prompt.submit({ text: 'the login page crashes on submit', wait: false, origin: { kind: 'composer' } })
  expect(JSON.stringify(r.context)).toContain('bug -> /ck-code:fix')
  expect(JSON.stringify(r.context)).not.toContain('maintainer')
})

test('a slash command is never routed', async ($, on) => {
  codeProject(on)
  on('fs.read', () => ({ value: '# Routing' }))
  on('prompt.submit', (_$, e) => ({ text: e.text, context: e.context }))
  const r = await $.prompt.submit({ text: '/ck-code:build 02-05 please', wait: false, origin: { kind: 'composer' } })
  expect(r.context ?? []).toEqual([])
})
