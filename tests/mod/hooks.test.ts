import { expect, mock, test } from 'claude-code/testing'
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

test('a lite project is left to ck-code-lite: no routing, no ck-code-lite commands hidden', async ($, on) => {
  on('session.cwd', () => ({ value: '/p' }))
  on('fs.exists', (_$, e) => ({ value: e.path === '/p/tasks/PLAN.md' || e.path === '/p/docs/specs' }))
  on('fs.list', () => ({ value: [] }))
  on('fs.read', () => ({ value: '# Routing' }))
  on('prompt.submit', (_$, e) => ({ text: e.text, context: e.context }))
  const r = await $.prompt.submit({ text: 'add a dark mode toggle please', wait: false, origin: { kind: 'composer' } })
  expect(r.context ?? []).toEqual([])
})

test('tasks/PLAN.md beside an unstamped docs/architecture stays lite (half-migrated)', async ($, on) => {
  on('session.cwd', () => ({ value: '/p' }))
  on('fs.exists', (_$, e) => ({ value: e.path === '/p/tasks/PLAN.md' || e.path === '/p/docs/architecture' }))
  on('fs.list', () => ({ value: [] }))
  on('attribution.text', (_$, e) => ({ text: e.text }))
  expect((await $.attribution.text({ kind: 'commit', text: 'x' })).text).toBe('x')
})

test('a stamped project is ck-code’s even with a tasks/PLAN.md', async ($, on) => {
  on('session.cwd', () => ({ value: '/p' }))
  on('fs.exists', (_$, e) => ({ value: ['/p/tasks/PLAN.md', '/p/tasks/VERSION.md'].includes(e.path) }))
  on('fs.list', () => ({ value: [] }))
  on('attribution.text', (_$, e) => ({ text: e.text }))
  expect((await $.attribution.text({ kind: 'commit', text: 'x' })).text).toBe('')
})

test('a shell cd into a subfolder is still the ck-code project', async ($, on) => {
  on('session.cwd', () => ({ value: '/p/src/app' }))
  on('fs.exists', (_$, e) => ({ value: ['/p/docs', '/p/docs/architecture', '/p/.git'].includes(e.path) }))
  on('fs.list', () => ({ value: [] }))
  on('attribution.text', (_$, e) => ({ text: e.text }))
  expect((await $.attribution.text({ kind: 'commit', text: 'x' })).text).toBe('')
})

test('compaction waits for background builders, then runs once', async ($, on) => {
  const clock = mock.clock(on)
  mock.store(on)
  let inProgress = 1
  let compacted = 0
  on('session.cwd', () => ({ value: '/p' }))
  on('fs.exists', (_$, e) => ({ value: e.path === '/p/docs/architecture' || e.path === '/p/tasks' }))
  on('fs.list', () => ({ value: [] }))
  on('agent.list', () => ({ value: [] }))
  on('process.run', (_$, e) => {
    const out = (e.argv[0] ?? '').endsWith('ck-view.sh')
      ? `COUNTS: ready=0 in_progress=${inProgress} done=2\nRECOMMEND: /ck-code:track next\nWHY: x`
      : 'ck-code 2/3 66%'
    return { value: { exitCode: 0, stdout: out, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('ui.toast', () => ({ value: undefined }))
  on('session.compact', () => {
    compacted += 1
    return { skip: 'the test keeps its messages' }
  })
  on('tool.call', () => ({ result: 'dispatched' }))
  on('turn.start', (_$, e) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
  const end = (turnId: string) =>
    $.turn.complete({ turnId, reason: 'answer', answer: '', durationMs: 1, isAborted: false })

  // Turn 1 dispatches two background builders and ends with both stories in progress.
  await $.turn.start({ text: 'build --epic 01', turnId: 't1' })
  for (const n of [1, 2])
    await $.tool.call({ tool: 'Agent', description: `story ${n}`, prompt: 'x', subagent_type: 'ck-code:story-implementer' })
  await end('t1')
  await clock.advance(600)
  expect(compacted).toBe(0)

  // Turn 2, a notification turn, dispatches none and ends with nothing in progress.
  inProgress = 0
  await $.turn.start({ text: '', turnId: 't2' })
  await end('t2')
  await clock.advance(600)
  expect(compacted).toBe(1)

  // Turn 3 has nothing left to compact.
  await $.turn.start({ text: 'thanks', turnId: 't3' })
  await end('t3')
  await clock.advance(600)
  expect(compacted).toBe(1)
})
