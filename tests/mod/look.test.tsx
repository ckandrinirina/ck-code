import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const PROPS = { hasSurvey: false, isWorking: false, maxRows: 8, bodyColumns: 120, scroll: { offset: 0, bodyRows: 8 } }

function project(on: On, isOurs = true) {
  mock.store(on)
  on('ui.render', () => ({ type: 'Text', props: {}, children: ['engine'] }))
  on('session.cwd', () => ({ value: '/p' }))
  on('session.root', () => ({ value: '/p' }))
  on('fs.exists', (_$, e) => ({ value: isOurs && (e.path === '/p/docs/architecture' || e.path === '/p/tasks') }))
  on('fs.list', () => ({ value: [] }))
  on('agent.list', () => ({ value: [{ id: 'a1', description: 'Build 03-02', type: 'ck-code:story-implementer', status: 'running' }] }))
  on('process.run', (_$, e) => {
    const out = (e.argv[0] ?? '').endsWith('ck-view.sh')
      ? 'COUNTS: ready=1 in_progress=1 done=2\nRECOMMEND: /ck-code:build 03-03\nWHY: next ready story'
      : 'ck-code 2/4 50%'
    return { value: { exitCode: 0, stdout: out, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('ui.toast', () => ({ value: undefined }))
  on('turn.start', (_$, e) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
}

const TURN = { turnId: 't1', reason: 'answer', answer: '', durationMs: 1, isAborted: false } as const

test('a search row draws the flat search glyph, its pattern and its state', async ($, on) => {
  const clock = mock.clock(on)
  project(on)
  await $.turn.start({ text: 'x', turnId: 't1' })
  await $.turn.complete(TURN)
  await clock.advance(100)
  const props = { tool_use_id: 'u1', tool: 'Grep', input: { pattern: 'isLite', path: '/p/hooks' }, isRunning: false, isErrored: false, isInterrupted: false, output: { numFiles: 4 } }
  const ui = await $.ui.mount({ plugin: 'ck-code', surface: 'terminal', component: 'ToolUse', props: props as never })
  expect(await ui.find({ text: '⌕' })).toBeDefined()
  expect(await ui.find({ text: /"isLite" · hooks/ })).toBeDefined()
  expect(await ui.find({ text: '✓' })).toBeDefined()
  expect(await ui.find({ text: '4 files' })).toBeDefined()
  await ui.unmount()
  const group = await $.ui.mount({ plugin: 'ck-code', surface: 'terminal', component: 'ToolGroup', props: {
    calls: [{ tool: 'Read', input: {}, isRunning: false, isErrored: false }, { tool: 'Grep', input: {}, isRunning: false, isErrored: false }],
    isActive: false, isExpanded: false,
  } as never })
  expect(await group.find({ text: '≡ 1 · ⌕ 1' })).toBeDefined()
  await group.unmount()
})

test('outside a ck-code project the engine draws its own rows', async ($, on) => {
  const clock = mock.clock(on)
  project(on, false)
  await $.turn.start({ text: 'x', turnId: 't1' })
  await $.turn.complete(TURN)
  await clock.advance(100)
  const props = { tool_use_id: 'u1', tool: 'Grep', input: { pattern: 'x' }, isRunning: true, isErrored: false, isInterrupted: false }
  const ui = await $.ui.mount({ plugin: 'ck-code', surface: 'terminal', component: 'ToolUse', props: props as never })
  expect(await ui.find({ text: 'engine' })).toBeDefined()
  expect(await ui.find({ text: '⌕' })).toBe(undefined)
  await ui.unmount()
})

test("the band's action row folds after a few seconds; the progress line stays", async ($, on) => {
  const clock = mock.clock(on)
  project(on)
  await $.turn.start({ text: 'x', turnId: 't1' })
  await $.turn.complete(TURN)
  await clock.advance(100)
  const ui = await $.ui.mount({ plugin: 'ck-code', surface: 'terminal', component: 'AbovePrompt', props: PROPS as never })
  expect(await ui.find({ text: /→ \/ck-code:build 03-03/ })).toBeDefined()
  await clock.advance(8000)
  await ui.advance(0)
  expect(await ui.find({ text: /→ \/ck-code:build 03-03/ })).toBe(undefined)
  expect(await ui.find({ text: /2\/4 50%/ })).toBeDefined()
  expect(await ui.find({ text: 'engine' })).toBeDefined()
  await ui.unmount()
})

test("a builder's own task list shows on the band", async ($, on) => {
  const clock = mock.clock(on)
  project(on)
  let next = 0
  on('tool.call', (_$, e) => (e.tool === 'TaskCreate' ? { result: { task: { id: String(++next), subject: e.subject } } } : { result: { success: true } }))
  await $.turn.start({ text: 'x', turnId: 't1' })
  await $.turn.complete(TURN)
  await clock.advance(100)
  await $.tool.call({ tool: 'TaskCreate', subject: 'Write the failing test', description: 'x', activeForm: 'Writing the failing test', agentId: 'a1' } as never)
  await $.tool.call({ tool: 'TaskCreate', subject: 'Make it pass', description: 'x', agentId: 'a1' } as never)
  await $.tool.call({ tool: 'TaskUpdate', taskId: '1', status: 'in_progress', agentId: 'a1' } as never)
  const ui = await $.ui.mount({ plugin: 'ck-code', surface: 'terminal', component: 'AbovePrompt', props: { ...PROPS, isWorking: true } as never })
  expect(await ui.find({ text: /◈ Build 03-02 ▱▱ 0\/2 ▸ Writing the failing test/ })).toBeDefined()
  await ui.unmount()
})
