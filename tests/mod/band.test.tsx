import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

let counts = 'ready=4 bug=0 blocked=13 in_progress=1 done=42'
// statusline.sh's real line, in a story branch, then with no story.
let statusLine = '\u001b[2mck-code\u001b[0m demo 0/1 33% \u001b[33m1⚡\u001b[0m\u001b[2m · \u001b[0mepic 01 core 1/3 33%\u001b[2m · \u001b[0m\u001b[33m⚡\u001b[0m 01-02 Story 2'
const state = () => [
  `COUNTS: ${counts}`,
  'RECOMMEND: /ck-code:track next',
  'WHY: 4 ready stories to implement',
].join('\n')

function project(on: On, filled: string[]) {
  mock.store(on)
  on('session.cwd', () => ({ value: '/p' }))
  on('fs.exists', (_$, e) => ({ value: e.path === '/p/docs/architecture' || e.path === '/p/tasks' }))
  on('fs.list', () => ({ value: [] }))
  on('process.run', (_$, e) => {
    const out = (e.argv[0] ?? '').endsWith('ck-view.sh') ? state() : statusLine
    return { value: { exitCode: 0, stdout: out, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('prompt.fill', (_$, e) => {
    filled.push(e.text)
    return { isFilled: true }
  })
}

const RUN = {
  command: 'ck-band',
  args: '',
  origin: { kind: 'composer' },
  presentation: { isFullscreen: true, columns: 160 },
} as const

const PROPS = {
  hasSurvey: false,
  isWorking: false,
  maxRows: 6,
  bodyColumns: 100,
  scroll: { offset: 0, bodyRows: 6 },
}

test('the band shows the story, the counts and fills the next command', async ($, on) => {
  const filled: string[] = []
  project(on, filled)
  // /ck-band hides, then shows again and refreshes.
  await $.command.run(RUN)
  await $.command.run(RUN)
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ plugin: 'ck-code', surface, component: 'AbovePrompt', props: PROPS as never })
    expect(await ui.find({ text: /4 ready · 1 in progress · 13 blocked · 42 done/ })).toBeDefined()
    expect(await ui.find({ text: /⚡ 01-02 Story 2/ })).toBeDefined()
    expect(await ui.find({ text: /epic 01 core/ })).toBe(undefined)
    expect(await ui.find({ text: /42\/60 70%/ })).toBeDefined()
    await ui.press({ key: 'fill' })
    await ui.unmount()
  }
  expect(filled).toEqual(['/ck-code:track next ', '/ck-code:track next '])
})

test('a story finished between two refreshes raises a toast', async ($, on) => {
  const toasts: string[] = []
  project(on, [])
  on('ui.toast', (_$, e) => {
    toasts.push(e.text)
    return { value: undefined }
  })
  counts = 'ready=4 bug=0 blocked=13 in_progress=1 done=42'
  await $.command.run(RUN)
  await $.command.run(RUN)
  counts = 'ready=4 bug=0 blocked=13 in_progress=0 done=43'
  await $.command.run(RUN)
  await $.command.run(RUN)
  expect(toasts).toEqual(['ck-code: ✨ 1 more done — 43/60 (71%)'])
})

test('with no story the band shows none', async ($, on) => {
  project(on, [])
  statusLine = 'ck-code 1/3 33% 1⚡'
  await $.command.run(RUN)
  await $.command.run(RUN)
  const ui = await $.ui.mount({ plugin: 'ck-code', surface: 'terminal', component: 'AbovePrompt', props: PROPS as never })
  expect(await ui.find({ text: /⚡/ })).toBe(undefined)
  await ui.unmount()
})
