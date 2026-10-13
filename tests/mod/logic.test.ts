import { describe, expect, test } from 'claude-code/testing'

import {
  bandStory,
  celebration,
  checklistLine,
  fillText,
  isLiteLayout,
  isWaveRunOver,
  openStoryIds,
  storyTotal,
  countsLine,
  generatedViewReason,
  gitCleanReason,
  hideCommand,
  isRoutable,
  parseChecklistNext,
  parseMergedPrs,
  parseState,
  parseStoriesIndex,
  profileReport,
  storySuggestions,
  stripAnsi,
  stripRouting,
} from '../../hooks/mod/logic'

describe('routing', () => {
  test('a person’s free-text prompt is routed', async () => {
    expect(isRoutable('the login page crashes on submit', 'composer')).toBe(true)
  })
  test('slash commands, short replies and non-person origins are not', async () => {
    expect(isRoutable('/ck-code:build 02-05', 'composer')).toBe(false)
    expect(isRoutable('  yes go', 'composer')).toBe(false)
    expect(isRoutable('a background task finished its work', 'task-notification')).toBe(false)
  })
  test('maintainer comment lines are stripped', async () => {
    expect(stripRouting('<!-- note -->\n# Routing\nrow')).toBe('# Routing\nrow')
  })
})

describe('ck-view state', () => {
  const out = [
    '| Stories | 4 ready |',
    'FLAGS: specs=1',
    'COUNTS: ready=4 bug=0 blocked=13 in_progress=1 done=42 unshipped=0',
    'RECOMMEND: /ck-code:track next',
    'WHY: 4 ready stories to implement',
  ].join('\n')
  test('parses counts, recommendation and reason', async () => {
    const s = parseState(out)
    expect(s?.counts.ready).toBe(4)
    expect(s?.recommend).toBe('/ck-code:track next')
    expect(s?.why).toBe('4 ready stories to implement')
    expect(countsLine(s!.counts)).toBe('4 ready · 1 in progress · 13 blocked · 42 done')
  })
  test('no COUNTS line is no state', async () => {
    expect(parseState('nothing here')).toBe(null)
  })
  test('ANSI colors are stripped', async () => {
    expect(stripAnsi('\u001b[36m02-05\u001b[0m · 3/9 ')).toBe('02-05 · 3/9')
  })
})

describe('guards', () => {
  test('generated views are refused, story files are not', async () => {
    expect(generatedViewReason('/p/tasks/2026-08-05_v1/STORIES_INDEX.md')).toContain('generated view')
    expect(generatedViewReason('tasks/EPICS_INDEX.md')).toContain('EPICS_INDEX')
    expect(generatedViewReason('/p/tasks/v1/epics/01_a/stories/01_b.md')).toBe(undefined)
    expect(generatedViewReason('/p/docs/STORIES_INDEX.md')).toBe(undefined)
  })
  test('git clean with x or X is refused', async () => {
    expect(gitCleanReason('git clean -fdX')).toContain('ck-reclaim')
    expect(gitCleanReason('cd a && git -C wt clean -x -f')).toContain('ck-reclaim')
  })
  test('git clean without x, and other commands, pass', async () => {
    expect(gitCleanReason('git clean -fd')).toBe(undefined)
    expect(gitCleanReason('git status -x')).toBe(undefined)
    expect(gitCleanReason('echo git clean -X')).toBe(undefined)
    expect(gitCleanReason('GIT_DIR=x git clean -X')).toContain('ck-reclaim')
  })
  test('quoted text is not a command; subshells and sudo do not hide one', async () => {
    expect(gitCleanReason('git commit -m "a; git clean -x b"')).toBe(undefined)
    expect(gitCleanReason("git commit -m 'a && git clean -X'")).toBe(undefined)
    expect(gitCleanReason('(git clean -X)')).toContain('ck-reclaim')
    expect(gitCleanReason('sudo git clean -X')).toContain('ck-reclaim')
    expect(gitCleanReason('command git clean -fx')).toContain('ck-reclaim')
    expect(gitCleanReason('env A=1 git clean -X')).toContain('ck-reclaim')
  })
})

describe('stories', () => {
  const md = [
    '| Epic | ID | Title | Status | Delivery | Size | Blocked by | File |',
    '|---|---|---|---|---|---|---|---|',
    '| Session | 10-01 | Session assembler | TODO | - | M | - | x.md |',
    '| Session | 10-02 | Session schema | DONE | MERGED | M | - | y.md |',
    '| Skill | 11-01 | Skill strength | IN-PROGRESS | - | M | - | z.md |',
  ].join('\n')
  test('rows parse and suggestions skip finished stories', async () => {
    const rows = parseStoriesIndex(md)
    expect(rows.length).toBe(3)
    const s = storySuggestions('10-', rows)
    expect(s.map(x => x.text)).toEqual(['10-01'])
    expect(storySuggestions('1', rows)).toEqual([])
  })
})

describe('misc', () => {
  test('merged PRs parse, junk is empty', async () => {
    expect(parseMergedPrs('[{"number":12,"title":"t","headRefName":"story/02-05"}]')[0]?.number).toBe(12)
    expect(parseMergedPrs('not json')).toEqual([])
  })
  test('command list de-duplication', async () => {
    expect(hideCommand('code', 'ck-code-lite:build')).toBe(true)
    expect(hideCommand('code', 'ck-code:build')).toBe(false)
    expect(hideCommand('lite', 'ck-code:build')).toBe(true)
    expect(hideCommand('lite', 'ck-code:migrate')).toBe(false)
    expect(hideCommand('none', 'ck-code-lite:build')).toBe(false)
  })
  test('checklist next', async () => {
    const r = parseChecklistNext(
      '# session 2 · scope all · last C-03\n' +
      'C-04\ttodo\ttasks/v1/checklist/C-04_login-works.md\n' +
      'C-05\tretest\ttasks/v1/checklist/C-05_logout-works.md\n',
    )
    expect(r.header).toBe('session 2 · scope all · last C-03')
    expect(r.items.map(i => i.id)).toEqual(['C-04', 'C-05'])
    expect(r.items[0]?.path).toBe('tasks/v1/checklist/C-04_login-works.md')
  })
  test('a checklist item reads its title, else its slug', async () => {
    const item = { id: 'C-04', status: 'todo', path: 'tasks/v1/checklist/C-04_login-works.md' }
    expect(checklistLine(item, '---\nid: C-04\ntitle: "Login \\"works\\""\nstatus: todo\n---\nbody')).toBe('C-04  Login "works"')
    expect(checklistLine(item, '')).toBe('C-04  login works')
    expect(checklistLine({ ...item, status: 'retest' }, '')).toBe('C-04  login works · retest')
  })
  test('the band keeps only the story segment of the status line', async () => {
    expect(bandStory('ck-code demo 0/1 33% 1⚡ · epic 01 core 1/3 33% · ⚡ 01-02 Story 2')).toBe('01-02 Story 2')
    expect(bandStory('\u001b[2mck-code 1/3 33% \u001b[33m1⚡\u001b[0m')).toBe('')
    expect(bandStory('')).toBe('')
  })
  test('Use fills a placeholder command up to its slash command only', async () => {
    expect(fillText('/ck-code:track next')).toBe('/ck-code:track next ')
    expect(fillText('/ck-code:ship <story-path>')).toBe('/ck-code:ship ')
    expect(fillText('/ck-code:spec "<feature description>"')).toBe('/ck-code:spec ')
  })
  test('profile report groups by skill', async () => {
    const t = { input: 10, output: 5, cacheRead: 1000, cacheWrite: 0 }
    const text = profileReport([
      { at: 1, skill: 'ck-code:build', ms: 60_000, tools: 10, agents: 2, main: t, sub: t },
      { at: 2, skill: '-', ms: 1000, tools: 1, agents: 0, main: t, sub: t },
    ])
    expect(text).toContain('| ck-code:build | 1 | 1m00s')
    expect(profileReport([])).toContain('No turns')
  })
})

describe('compaction after a wave run', () => {
  test('a clean wave run of two or more builders is over', async () => {
    expect(isWaveRunOver({ reason: 'answer', builders: 3, inProgress: 0 })).toBe(true)
  })
  test('one builder, an interrupt, an error or a held task keeps the session', async () => {
    expect(isWaveRunOver({ reason: 'answer', builders: 1, inProgress: 0 })).toBe(false)
    expect(isWaveRunOver({ reason: 'aborted', builders: 3, inProgress: 0 })).toBe(false)
    expect(isWaveRunOver({ reason: 'error', builders: 3, inProgress: 0 })).toBe(false)
    expect(isWaveRunOver({ reason: 'answer', builders: 3, inProgress: 1 })).toBe(false)
  })
})

describe('progress and celebrations', () => {
  test('the total counts every story but skipped ones', async () => {
    expect(storyTotal({ ready: 4, bug: 0, blocked: 13, in_progress: 1, done: 42, unshipped: 3, merged: 30 })).toBe(60)
    expect(openStoryIds([
      { id: '01-01', title: 'a', status: 'DONE' },
      { id: '01-02', title: 'b', status: 'SKIP' },
      { id: '01-03', title: 'c', status: 'TODO' },
    ])).toEqual(['01-03'])
  })
  test('a done story is named; an unnamed jump is counted', async () => {
    const before = { done: 42, total: 60, open: ['02-05', '02-06'] }
    expect(celebration(before, { done: 43, total: 60, open: ['02-06'] }, 'stories')).toBe('✨ 02-05 done — 43/60 (71%)')
    expect(celebration({ ...before, open: [] }, { done: 44, total: 60, open: [] }, 'stories')).toBe('✨ 2 more done — 44/60 (73%)')
    expect(celebration(before, { done: 60, total: 60, open: [] }, 'stories')).toBe('🎉 Plan complete — 60/60 stories done!')
  })
})

describe('the lite-project rule', () => {
  // stamp, plan, architectureDir, architectureDoc -> lite
  const table: [boolean, boolean, boolean, boolean, boolean][] = [
    [false, false, false, false, false],
    [false, false, false, true, true],
    [false, false, true, false, false],
    [false, false, true, true, false],
    [false, true, false, false, true],
    [false, true, false, true, true],
    [false, true, true, false, true],
    [false, true, true, true, true],
    [true, false, false, false, false],
    [true, false, false, true, false],
    [true, false, true, false, false],
    [true, false, true, true, false],
    [true, true, false, false, false],
    [true, true, false, true, false],
    [true, true, true, false, false],
    [true, true, true, true, false],
  ]
  test('every combination of the four markers', async () => {
    for (const [stamp, plan, architectureDir, architectureDoc, lite] of table) {
      expect(isLiteLayout({ stamp, plan, architectureDir, architectureDoc })).toBe(lite)
    }
  })
})
