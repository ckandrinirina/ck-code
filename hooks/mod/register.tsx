// ck-code mod: the plugin's in-process hooks (Claude Code ≥ 2.1.287).
//
// Everything here makes the workflow faster or easier to see; nothing here is load-bearing.
// Under --bare, --safe-mode or disableAllHooks no mod runs, and the skills and scripts still
// do the whole job: the scripts stay the source of truth, this module only calls them.
//
//   prompt.submit      routes free-text prompts (was scripts/prompt-router.sh)
//   attribution.text   no AI attribution in commits and PRs (references/no-ai-references.md)
//   tool.call          guards: generated views, `git clean -x/-X`; counts for the profiler
//   command.*          zero-model commands, last-command hand-off, de-duplicated command list
//   AbovePrompt band   progress bar, active story, recommended next command, merged-PR notes
//   toasts             a cheer when a story is done, a bigger one when every story is
//   panes              agents cockpit during a build; verify checklist with buttons
//   turn.*             per-skill time and token profile (/ck-profile)
//   cost guard         caps effort at high, gates Fable on the user, cheap default subagent model
//   session.compact    compacts the session once a wave run of builders has finished
//   look               flat-glyph tool rows and groups, workflow words (look.tsx, theme.ts)
//   task board         the builders' own task lists, mirrored into the band
//
// Pure rules live in logic.ts. `$` never leaves this file except into the state helpers.

import { atom, read, update } from "claude-code";
import type { EngineInterface, Register } from "claude-code";

import type { CkAgentRow, CkBand, CkBoard, CkVerify } from "../../types";
import { registerUpdateCheck, startUpdateCheck } from "./update";
import { registerLook } from "./look";
import { boardLine, taskCreated, taskUpdated, todosWritten } from "./theme";
import {
  COMPACT_INSTRUCTIONS,
  HANDOFF_TTL_MS,
  PROFILE_KEEP,
  addUsage,
  bandStory,
  celebration,
  checklistLine,
  countsLine,
  fillText,
  fmtSeconds,
  generatedViewReason,
  gitCleanReason,
  handoffText,
  hideCommand,
  isLive,
  isLiteLayout,
  isWaveRunOver,
  isRoutable,
  openStoryIds,
  parseChecklistNext,
  parseMergedPrs,
  parseState,
  parseStoriesIndex,
  percent,
  profileReport,
  progressBar,
  shortAgentType,
  splitArgs,
  storySuggestions,
  storyTotal,
  stripAnsi,
  stripRouting,
  zeroTokens,
  cappedEffort,
  guardDispatch,
} from "./logic";
import type {
  Progress,
  ProjectKind,
  StoryRow,
  Tokens,
  TurnRecord,
} from "./logic";

const band = atom({ plugin: "ck-code", key: "band" } as const, null);
const bandHidden = atom(
  { plugin: "ck-code", key: "bandHidden" } as const,
  false,
);
const agents = atom({ plugin: "ck-code", key: "agents" } as const, []);
const verify = atom({ plugin: "ck-code", key: "verify" } as const, null);
const board = atom({ plugin: "ck-code", key: "board" } as const, []);
// True once the band's action row has been up for BAND_ACTIONS_MS: the band folds to its
// progress line until the next turn ends.
const bandQuiet = atom({ plugin: "ck-code", key: "bandQuiet" } as const, false);

const AGENTS_PANE = "ck-agents";
const VERIFY_PANE = "ck-verify";
const PR_POLL_MS = 5 * 60 * 1000;
const AGENT_POLL_MS = 3000;
const BAND_ACTIONS_MS = 8000;

// Module variables start over on a reload; what must outlive one is in $.state or $.store.
let updateOn = true;
let guardsOn = true;
let bandOn = true;
let prWatchOn = true;
let compactOn = true;
let costGuardOn = true;
let themeOn = true;
let lookRoot = "";
let quietTimer: { cancel: () => void } | undefined;
// A builder's label on the task board, by agent id: its Agent call's description.
const boardLabels = new Map<string, string>();
// Story builders dispatched from the main loop since the last compaction. Not reset per turn:
// background builders end in later notification turns, which dispatch none themselves.
let builders = 0;
let routingCache: string | undefined;
let stories: StoryRow[] = [];
let progress: Progress | undefined;
let isRefreshing = false;
let lastCommand: string | undefined;
let lastKind: ProjectKind | undefined;
let rootCache = "";
let agentPoll: { cancel: () => void } | undefined;
// When the running agent poll started: its end-of-run toast counts only agents seen since.
let pollStart = 0;
let autoOpenAgents = true;
// Whether the terminal last drew the fullscreen layout, the one that docks a pane beside the
// transcript. The main screen would place it inline above the prompt, so it never opens unasked there.
let isFullscreen = false;
const firstSeen = new Map<string, number>();
const endedAt = new Map<string, number>();

type Turn = {
  at: number;
  skill: string;
  tools: number;
  agents: number;
  sub: Tokens;
};
let turn: Turn | undefined;

// ---- project probes ------------------------------------------------------------------

// Kept word for word in both plugins' mods. The project is the nearest folder, from the
// session's cwd up, holding tasks/ or docs/ — never past the repository's top (.git) — so a
// shell cd into a subfolder keeps the band, the routing and the guards.
async function projectRoot($: EngineInterface): Promise<string> {
  const cwd = await $.session.cwd();
  for (let dir = cwd; ;) {
    if (
      (await $.fs.exists(`${dir}/tasks`)) ||
      (await $.fs.exists(`${dir}/docs`))
    )
      return dir;
    const up = dir.replace(/\/[^/]+$/, "");
    if ((await $.fs.exists(`${dir}/.git`)) || up === dir || up === "")
      return cwd;
    dir = up;
  }
}

// A lite layout (isLiteLayout, shared with ck-code-lite's mod and the skills' plugin guards)
// is ck-code-lite's, and that plugin owns it. Otherwise a ck-code project has a stamp,
// docs/architecture, docs/specs or a tasks/<plan>/epics.
async function projectKind($: EngineInterface): Promise<ProjectKind> {
  const root = await projectRoot($);
  const stamp = await $.fs.exists(`${root}/tasks/VERSION.md`);
  const architectureDir = await $.fs.exists(`${root}/docs/architecture`);
  const lite = isLiteLayout({
    stamp,
    plan: await $.fs.exists(`${root}/tasks/PLAN.md`),
    architectureDir,
    architectureDoc: await $.fs.exists(`${root}/docs/ARCHITECTURE.md`),
  });
  if (lite) return "lite";
  if (stamp || architectureDir) return "code";
  if (await $.fs.exists(`${root}/docs/specs`)) return "code";
  if (!(await $.fs.exists(`${root}/tasks`))) return "none";
  for (const entry of await $.fs.list(`${root}/tasks`)) {
    if (
      entry.kind === "dir" &&
      (await $.fs.exists(`${root}/tasks/${entry.name}/epics`))
    )
      return "code";
  }
  return "none";
}

async function script(
  $: EngineInterface,
  name: string,
  args: readonly string[],
  timeoutMs = 60_000,
) {
  return $.process.run([`${$.plugin.root}/scripts/${name}`, ...args], {
    cwd: await projectRoot($),
    timeoutMs,
  });
}

// Every plan's STORIES_INDEX.md, read after ck-view has regenerated the views.
async function loadStories($: EngineInterface): Promise<StoryRow[]> {
  const cwd = await projectRoot($);
  const rows: StoryRow[] = [];
  if (!(await $.fs.exists(`${cwd}/tasks`))) return rows;
  for (const entry of await $.fs.list(`${cwd}/tasks`)) {
    const path = `${cwd}/tasks/${entry.name}/STORIES_INDEX.md`;
    if (entry.kind === "dir" && (await $.fs.exists(path))) {
      rows.push(...parseStoriesIndex(String(await $.fs.read(path))));
    }
  }
  return rows;
}

// ---- band ----------------------------------------------------------------------------

async function refreshBand($: EngineInterface): Promise<void> {
  if (isRefreshing) return;
  isRefreshing = true;
  try {
    const kind = await projectKind($);
    // command.describe answers are cached for the session: a migrate or a design that
    // changed the kind would leave the other plugin's commands hidden.
    if (lastKind !== undefined && kind !== lastKind)
      $.ui.invalidate("command.describe");
    lastKind = kind;
    lookRoot = await projectRoot($);
    if (kind !== "code") {
      stories = [];
      if (bandOn) await update($, band, () => null);
      return;
    }
    // Story-id completion reads these, band or no band.
    if (!bandOn) {
      stories = await loadStories($);
      return;
    }
    const state = parseState((await script($, "ck-view.sh", ["state"])).stdout);
    if (state === null) return;
    const cwd = await projectRoot($);
    const line = await $.process.run(
      [`${$.plugin.root}/scripts/statusline.sh`],
      {
        cwd,
        stdin: JSON.stringify({ cwd, workspace: { current_dir: cwd } }),
        timeoutMs: 15_000,
      },
    );
    stories = await loadStories($);
    const done = state.counts.done ?? 0;
    const total = storyTotal(state.counts);
    const now: Progress = { done, total, open: openStoryIds(stories) };
    const cheer = celebration(progress, now, "stories");
    progress = now;
    if (cheer) $.ui.toast(`ck-code: ${cheer}`);
    await update($, band, (old) => ({
      story: bandStory(line.stdout.split("\n")[0] ?? ""),
      counts: countsLine(state.counts),
      done,
      total,
      recommend: state.recommend,
      why: state.why,
      notes: old?.notes ?? [],
    }));
  } catch {
    // A failed probe leaves the band as it was; the next turn tries again.
  } finally {
    isRefreshing = false;
  }
}

async function addNote($: EngineInterface, note: string): Promise<void> {
  await update($, band, (old) =>
    old === null ? old : { ...old, notes: [...old.notes, note].slice(-3) },
  );
}

async function clearNotes($: EngineInterface): Promise<void> {
  await update($, band, (old) =>
    old === null || old.notes.length === 0 ? old : { ...old, notes: [] },
  );
}

// ---- merged-PR watch -----------------------------------------------------------------

// A story's PR merged on GitHub leaves its delivery behind until `doctor --fix` or `ship`
// records it. The first poll only learns what is already merged; later ones announce.
async function pollMergedPrs($: EngineInterface): Promise<boolean> {
  if ((await projectKind($)) !== "code") return true;
  let ran;
  try {
    ran = await $.process.run(
      [
        "gh",
        "pr",
        "list",
        "--author",
        "@me",
        "--state",
        "merged",
        "--limit",
        "15",
        "--json",
        "number,title,headRefName",
      ],
      { timeoutMs: 20_000 },
    );
  } catch (err) {
    // A slow network times out: try again next round. Anything else is gh missing.
    return /time/i.test(String(err));
  }
  // Not authenticated, no GitHub remote, offline: skip this round, keep watching.
  if (ran.exitCode !== 0) return true;
  const prs = parseMergedPrs(ran.stdout);
  const key = `prs:${rootCache}`;
  const seen = (await $.store.get(key)) as number[] | undefined;
  const known = new Set(seen ?? []);
  const fresh =
    seen === undefined ? [] : prs.filter((p) => !known.has(p.number));
  await $.store.set(
    key,
    [...known, ...prs.map((p) => p.number)]
      .filter((n, i, all) => all.indexOf(n) === i)
      .slice(-100),
  );
  for (const pr of fresh) {
    $.ui.toast(
      `ck-code: PR #${pr.number} merged — /ck-code:doctor --fix records it in the plan`,
    );
    await addNote(
      $,
      `🔔 PR #${pr.number} merged (${pr.headRefName}) → /ck-code:doctor --fix`,
    );
  }
  return true;
}

// ---- agents cockpit ------------------------------------------------------------------

async function pollAgents($: EngineInterface): Promise<void> {
  const now = await $.clock.now();
  const mine = (await $.agent.list()).filter((a) =>
    a.type.startsWith("ck-code:"),
  );
  const rows: CkAgentRow[] = mine.map((a) => {
    const start = firstSeen.get(a.id) ?? now;
    firstSeen.set(a.id, start);
    if (!isLive(a.status) && !endedAt.has(a.id)) endedAt.set(a.id, now);
    const end = isLive(a.status) ? now : (endedAt.get(a.id) ?? now);
    return {
      id: a.id,
      label: a.name ?? a.description,
      kind: shortAgentType(a.type),
      status: a.status,
      secs: Math.round((end - start) / 1000),
    };
  });
  await update($, agents, () => rows);
  const running = rows.filter((r) => isLive(r.status));
  const builders = running.filter((r) => r.kind === "build").length;
  if (builders >= 2 && autoOpenAgents && isFullscreen) {
    autoOpenAgents = false;
    void $.ui.open({ id: AGENTS_PANE, title: "ck-code agents" });
  }
  if (running.length > 0) {
    $.ui.status(
      `ck-code: ${running.length} running · ${rows.length - running.length} done`,
    );
    return;
  }
  $.ui.status(undefined);
  // Only a poll that was running ends with a toast, and it counts only its own agents,
  // not an earlier wave's.
  const wasPolling = agentPoll !== undefined;
  agentPoll?.cancel();
  agentPoll = undefined;
  const ran = rows.filter((r) => (firstSeen.get(r.id) ?? 0) >= pollStart);
  const failed = ran.filter(
    (r) => r.status === "failed" || r.status === "killed",
  ).length;
  if (wasPolling && ran.length > 0) {
    $.ui.toast(
      failed
        ? `ck-code: agents finished — ${ran.length - failed} completed, ${failed} failed`
        : `ck-code: ✦ agents finished — all ${ran.length} completed`,
    );
  }
}

// ---- band timing and the builders' task board ------------------------------------------

// The action row (next command, Use, Hide) comes up when a turn ends and folds away after
// BAND_ACTIONS_MS, leaving the progress line; the next turn's end brings it back.
async function wakeBand($: EngineInterface): Promise<void> {
  try {
    quietTimer?.cancel();
    await update($, bandQuiet, () => false);
    quietTimer = $.clock.after(BAND_ACTIONS_MS, () => void update($, bandQuiet, () => true));
  } catch {
    // No clock: the action row simply stays up.
  }
}

async function boardLabel($: EngineInterface, agent: string): Promise<string> {
  const known = boardLabels.get(agent);
  if (known !== undefined) return known;
  const info = (await $.agent.list()).find((a) => a.id === agent);
  const label = info?.name ?? info?.description ?? "agent";
  boardLabels.set(agent, label);
  return label;
}

// Builders that ended leave the board once the main loop's turn ends.
async function pruneBoard($: EngineInterface): Promise<void> {
  const rows = await read($, board);
  if (rows.length === 0) return;
  const live = new Set(
    (await $.agent.list()).filter((a) => isLive(a.status)).map((a) => a.id),
  );
  if (rows.every((b) => live.has(b.agent))) return;
  await update($, board, (old) => (old ?? []).filter((b) => live.has(b.agent)));
}

// ---- verify checklist ----------------------------------------------------------------

async function loadChecklist(
  $: EngineInterface,
  plan: string,
  message: string,
): Promise<void> {
  const ran = await script($, "ck-checklist.sh", ["next", plan, "-n", "3"]);
  const { header, items: found } = parseChecklistNext(ran.stdout);
  const root = await projectRoot($);
  const items: CkVerify["items"] = [];
  for (const item of found) {
    const file = item.path.startsWith("/") ? item.path : `${root}/${item.path}`;
    const md =
      item.path && (await $.fs.exists(file)) ? String(await $.fs.read(file)) : "";
    items.push({ id: item.id, line: checklistLine(item, md) });
  }
  const next: CkVerify = {
    plan,
    header:
      ran.exitCode === 0
        ? header
        : stripAnsi(ran.stderr || ran.stdout).slice(0, 300),
    items,
    steps: null,
    message,
  };
  await update($, verify, () => next);
}

async function recordItem(
  $: EngineInterface,
  plan: string,
  id: string,
  status: "pass" | "skip",
): Promise<void> {
  const ran = await script($, "ck-checklist.sh", ["record", plan, id, status]);
  const said = stripAnsi(
    ran.exitCode === 0
      ? (ran.stdout.split("\n")[0] ?? "")
      : ran.stderr || ran.stdout,
  );
  await loadChecklist(
    $,
    plan,
    `${said} — commit with /ck-code:verify or /ck-code:ship`,
  );
}

async function showSteps(
  $: EngineInterface,
  plan: string,
  id: string,
): Promise<void> {
  const ran = await script($, "ck-checklist.sh", ["path", plan, id]);
  const found = ran.stdout.trim();
  const path = found.startsWith("/") ? found : `${await projectRoot($)}/${found}`;
  const text =
    ran.exitCode === 0 && found
      ? String(await $.fs.read(path))
      : `No file for ${id}.`;
  await update($, verify, (old) =>
    old === null ? old : { ...old, steps: { id, text } },
  );
}

// The plan to verify: the one named, else the only plan with a CHECKLIST.md.
async function pickPlan(
  $: EngineInterface,
  arg: string,
): Promise<string | undefined> {
  if (arg) return arg.replace(/\/$/, "");
  const cwd = await projectRoot($);
  const found: string[] = [];
  if (!(await $.fs.exists(`${cwd}/tasks`))) return undefined;
  for (const entry of await $.fs.list(`${cwd}/tasks`)) {
    if (
      entry.kind === "dir" &&
      (await $.fs.exists(`${cwd}/tasks/${entry.name}/CHECKLIST.md`))
    ) {
      found.push(`tasks/${entry.name}`);
    }
  }
  return found.length === 1 ? found[0] : undefined;
}

// ---- profiler ------------------------------------------------------------------------

async function saveTurn($: EngineInterface, record: TurnRecord): Promise<void> {
  const key = `profile:${rootCache}`;
  const old = ((await $.store.get(key)) as TurnRecord[] | undefined) ?? [];
  await $.store.set(key, [...old, record].slice(-PROFILE_KEEP));
}

// A background agent's turn often ends after the main turn that dispatched it: its tokens
// go to the most recent saved turn, the one that dispatched it or a notification turn
// after it, rather than nowhere.
async function addLateUsage(
  $: EngineInterface,
  usage: Parameters<typeof addUsage>[1],
): Promise<void> {
  const key = `profile:${rootCache}`;
  const old = ((await $.store.get(key)) as TurnRecord[] | undefined) ?? [];
  const last = old[old.length - 1];
  if (!last) return;
  await $.store.set(key, [
    ...old.slice(0, -1),
    { ...last, sub: addUsage(last.sub, usage) },
  ]);
}

// ---- compaction after a wave run --------------------------------------------------------

// Runs between turns: $.session.compact rejects while one runs, and a person who has already
// typed the next prompt keeps the session as it is. The next command (ship --promote, verify)
// starts from the story files, not from the transcript. Background builders end in later
// turns, so the count runs since the last compaction and every clean turn end checks it,
// once no builder is still live. An interrupt or an error keeps the count for a later turn.
async function compactAfterWaves(
  $: EngineInterface,
  reason: string,
): Promise<void> {
  try {
    if ((await projectKind($)) !== "code") return;
    const live = (await $.agent.list()).some(
      (a) => a.type === "ck-code:story-implementer" && isLive(a.status),
    );
    if (live) return;
    const state = parseState((await script($, "ck-view.sh", ["state"])).stdout);
    const inProgress = state?.counts.in_progress;
    if (inProgress === undefined) return;
    if (!isWaveRunOver({ reason, builders, inProgress })) return;
    const out = await $.session.compact({ instructions: COMPACT_INSTRUCTIONS });
    // Compacted, or skipped (the next prompt is typed): either way this run is spent.
    builders = 0;
    $.ui.toast(
      out.skip
        ? `ck-code: not compacted, ${out.skip}`
        : "ck-code: wave run finished, session compacted",
    );
  } catch {
    // A turn already running, or a failed probe: the session stays as it is.
  }
}

// ---- agents pane look ------------------------------------------------------------------

// A live agent's glyph turns a quarter each poll, so a long build visibly moves.
const SPIN = ["◐", "◓", "◑", "◒"];

function agentGlyph(row: CkAgentRow): string {
  if (isLive(row.status))
    return SPIN[Math.floor(row.secs / (AGENT_POLL_MS / 1000)) % SPIN.length]!;
  return row.status === "completed" ? "✓" : "✗";
}

function agentColor(status: string): string | undefined {
  if (isLive(status)) return "claude";
  if (status === "completed") return "success";
  return "error";
}

// ---- commands ------------------------------------------------------------------------

async function viewCommand($: EngineInterface, mode: string, args: string): Promise<{ text: string }> {
  const ran = await script($, 'ck-view.sh', [mode, ...splitArgs(args)])
  return { text: (ran.stdout || ran.stderr).trim() || 'ck-view printed nothing.' }
}



export const register: Register = (on, options) => {
  guardsOn = options.guards !== false;
  bandOn = options.band !== false;
  prWatchOn = options.pr_watch !== false;
  compactOn = options.compact_after_waves !== false;
  costGuardOn = options.cost_guard !== false;
  themeOn = options.theme !== false;
  updateOn = options.update_check !== false;
  registerUpdateCheck(on);

  registerLook(on, {
    isOurs: () => themeOn && lastKind === "code",
    root: () => lookRoot,
  });

  on("session.start", async ($, e, next) => {
    await startUpdateCheck($, updateOn);
    rootCache = (await $.session.root()) || (await $.session.cwd());
    await $.command.register({ name: 'ck-status', description: 'ck-code dashboard, printed at once with no model turn', argumentHint: '[tasks/<plan>]', immediate: true })
    await $.command.register({ name: 'ck-next', description: 'Next ready ck-code story, printed at once with no model turn', argumentHint: '[tasks/<plan>]', immediate: true })
    await $.command.register({ name: 'ck-progress', description: 'ck-code epic rollup and milestones, with no model turn', argumentHint: '[tasks/<plan>]', immediate: true })
    await $.command.register({
      name: "ck-waves",
      description: "Wave plan of one ck-code epic, with no model turn",
      argumentHint: "<NN>",
      immediate: true,
    });
    await $.command.register({
      name: "ck-check",
      description: "ck-doctor warnings and errors only, with no model turn",
    });
    await $.command.register({
      name: "ck-agents",
      description: "Open the ck-code agents pane (the build cockpit)",
      immediate: true,
    });
    await $.command.register({
      name: "ck-verify-pane",
      description:
        "Walk the ck-code manual-test checklist in a pane with buttons",
      argumentHint: "[tasks/<plan>]",
    });
    await $.command.register({
      name: "ck-band",
      description: "Show or hide the ck-code band above the prompt",
      immediate: true,
    });
    await $.command.register({
      name: "ck-profile",
      description: "Where time and tokens went, per ck-code skill",
      argumentHint: "[reset]",
      immediate: true,
    });
    const hidden = await $.store.get("bandHidden");
    if (hidden === true) await update($, bandHidden, () => true);
    $.clock.after(50, () => void refreshBand($));
    await wakeBand($);
    if (prWatchOn) {
      $.clock.after(20_000, async () => {
        if (!(await pollMergedPrs($))) return;
        const timer = $.clock.every(PR_POLL_MS, async () => {
          if (!(await pollMergedPrs($))) timer.cancel();
        });
      });
    }
    return next(e);
  });

  // ---- the cost guard: effort cap, the Fable gate, a cheap default subagent model ----
  // Kept word for word in both plugins' mods. Runs in every project, not only adopted ones:
  // it is a spending rule, not a workflow rule. Off with the cost_guard option.

  on("tool.call", { tool: "Agent" }, async ($, e, next) => {
    const g = costGuardOn ? guardDispatch(e) : undefined;
    if (g && "deny" in g) return { deny: g.deny };
    return next(g ? ({ ...e, ...g } as typeof e) : e);
  }).catch(($, e, next) => next(e));

  on("turn.step", async function* ($, e, next) {
    const effort = costGuardOn ? cappedEffort(e.effort) : e.effort;
    return yield* next(effort === e.effort ? e : { ...e, effort });
  });

  // ---- routing, attribution, hand-off ----

  on("prompt.submit", async ($, e, next) => {
    if (!isRoutable(e.text, e.origin?.kind ?? "composer") || (await projectKind($)) !== "code")
      return next(e);
    if (routingCache === undefined) {
      routingCache = stripRouting(
        String(
          await $.fs.read(`${$.plugin.root}/references/prompt-routing.md`),
        ),
      );
    }
    if (!routingCache) return next(e);
    return next({ ...e, context: [...(e.context ?? []), routingCache] });
  }).catch(($, e, next) => next(e));

  // references/no-ai-references.md, at the source: the engine's attribution guidance for
  // commits and PRs is dropped in a ck-code project, so there is nothing for the guard to catch.
  on("attribution.text", async ($, e, next) => {
    if (
      (e.kind === "commit" || e.kind === "pr") &&
      (await projectKind($)) === "code"
    )
      return { text: "" };
    return next(e);
  });

  on("command.run", async ($, e, next) => {
    if (e.command.startsWith("ck-code:")) {
      lastCommand = `/${e.command}${e.args ? ` ${e.args}` : ""}`;
      if (/^ck-code:(doctor|ship)$/.test(e.command)) await clearNotes($);
    }
    return next(e);
  }).catch(($, e, next) => next(e));

  on("session.end", async ($, e, next) => {
    if (e.reason === "clear") builders = 0;
    if (e.reason === "clear" && lastCommand) {
      await $.store.set(`handoff:${await projectRoot($)}`, {
        command: lastCommand,
        at: await $.clock.now(),
      });
    }
    return next(e);
  });

  on("prompt.context", async ($, e, next) => {
    const out = await next(e);
    const key = `handoff:${await projectRoot($)}`;
    const saved = (await $.store.get(key)) as
      { command: string; at: number } | undefined;
    if (!saved) return out;
    await $.store.delete(key);
    if ((await $.clock.now()) - saved.at > HANDOFF_TTL_MS) return out;
    return {
      ...out,
      blocks: [
        ...out.blocks,
        { name: "ckCodeHandoff", text: handoffText(saved.command) },
      ],
    };
  });

  on("command.describe", async ($, e, next) => {
    const out = await next(e);
    return hideCommand(await projectKind($), e.command)
      ? { ...out, isHidden: true }
      : out;
  });

  on(
    "prompt.autocomplete",
    { token: /^\d{2}-\d{0,2}$/ },
    async ($, e, next) => {
      const out = await next(e);
      return {
        suggestions: [
          ...out.suggestions,
          ...storySuggestions(e.token, stories),
        ],
      };
    },
  );

  // ---- guards (fail open: a guard that errors never wedges a session) ----

  on("tool.call", { tool: "Write" }, async ($, e, next) => {
    const why = guardsOn ? generatedViewReason(e.file_path) : undefined;
    return why && (await projectKind($)) === "code" ? { deny: why } : next(e);
  }).catch(($, e, next) => next(e));

  on("tool.call", { tool: "Edit" }, async ($, e, next) => {
    const why = guardsOn ? generatedViewReason(e.file_path) : undefined;
    return why && (await projectKind($)) === "code" ? { deny: why } : next(e);
  }).catch(($, e, next) => next(e));

  on("tool.call", { tool: "Bash" }, async ($, e, next) => {
    const why = guardsOn ? gitCleanReason(e.command) : undefined;
    return why && (await projectKind($)) === "code" ? { deny: why } : next(e);
  }).catch(($, e, next) => next(e));

  // ---- agents cockpit: a ck-code agent dispatched from the main loop starts the poll ----

  on("tool.call", { tool: "Agent" }, async ($, e, next) => {
    if (
      e.agentId === undefined &&
      e.subagent_type?.startsWith("ck-code:") &&
      agentPoll === undefined
    ) {
      pollStart = await $.clock.now();
      agentPoll = $.clock.every(AGENT_POLL_MS, () => void pollAgents($));
    }
    return next(e);
  }).catch(($, e, next) => next(e));

  on("ui.close", { id: AGENTS_PANE }, async ($, e, next) => {
    if (e.origin.kind === "person") autoOpenAgents = false;
    return next(e);
  });

  // ---- task board: a subagent's task list, mirrored (its own never reaches the session's) ----

  on("tool.call", { tool: "TaskCreate" }, async ($, e, next) => {
    const out = await next(e);
    if (e.agentId === undefined || lastKind !== "code" || !("result" in out) || out.isError)
      return out;
    const id = out.result?.task?.id;
    if (!id) return out;
    const label = await boardLabel($, e.agentId);
    await update($, board, (old) =>
      taskCreated(old ?? [], e.agentId!, label, { id, subject: e.subject, activeForm: e.activeForm }),
    );
    return out;
  }).catch(($, e, next) => next(e));

  on("tool.call", { tool: "TaskUpdate" }, async ($, e, next) => {
    const out = await next(e);
    if (e.agentId === undefined || lastKind !== "code") return out;
    await update($, board, (old) => taskUpdated(old ?? [], e.agentId!, e));
    return out;
  }).catch(($, e, next) => next(e));

  on("tool.call", { tool: "TodoWrite" }, async ($, e, next) => {
    const out = await next(e);
    if (e.agentId === undefined || lastKind !== "code") return out;
    const label = await boardLabel($, e.agentId);
    await update($, board, (old) => todosWritten(old ?? [], e.agentId!, label, e.todos));
    return out;
  }).catch(($, e, next) => next(e));

  // ---- profiler ----

  on("turn.start", async ($, e, next) => {
    turn = {
      at: await $.clock.now(),
      skill: "-",
      tools: 0,
      agents: 0,
      sub: zeroTokens(),
    };
    return next(e);
  });

  on("tool.call", async ($, e, next) => {
    if (turn) {
      turn.tools += 1;
      if (e.tool === "Agent") turn.agents += 1;
    }
    if (
      e.tool === "Agent" &&
      e.agentId === undefined &&
      e.subagent_type === "ck-code:story-implementer"
    )
      builders += 1;
    return next(e);
  }).catch(($, e, next) => next(e));

  on("skill.prompt", async ($, e, next) => {
    if (turn && turn.skill === "-" && e.skill.startsWith("ck-code:"))
      turn.skill = e.skill;
    return next(e);
  });

  on("turn.complete", async ($, e, next) => {
    const out = await next(e);
    if (e.agentId !== undefined) {
      if (turn) turn.sub = addUsage(turn.sub, e.usage);
      else if (rootCache) await addLateUsage($, e.usage);
      return out;
    }
    const done = turn;
    turn = undefined;
    if (done && rootCache) {
      await saveTurn($, {
        at: done.at,
        skill: done.skill,
        ms: e.durationMs,
        tools: done.tools,
        agents: done.agents,
        main: addUsage(zeroTokens(), e.usage),
        sub: done.sub,
      });
    }
    $.clock.after(50, () => void refreshBand($));
    await wakeBand($);
    void pruneBoard($);
    if (compactOn && builders >= 2 && e.reason === "answer")
      $.clock.after(500, () => void compactAfterWaves($, e.reason));
    return out;
  });

  // ---- commands with no model turn ----

  on('command.run', { command: 'ck-status' }, async ($, e) => viewCommand($, 'status', e.args))
  on('command.run', { command: 'ck-next' }, async ($, e) => viewCommand($, 'next', e.args))
  on('command.run', { command: 'ck-progress' }, async ($, e) => viewCommand($, 'progress', e.args))

  on("command.run", { command: "ck-waves" }, async ($, e) => {
    const epic = splitArgs(e.args)[0];
    if (!epic) return { text: "Usage: /ck-waves <NN> — the epic number." };
    const ran = await script($, "ck-view.sh", ["waves", "--epic", epic]);
    return { text: (ran.stdout || ran.stderr).trim() };
  });

  on("command.run", { command: "ck-check" }, async ($) => {
    const ran = await script($, "ck-doctor.sh", ["--quiet"], 120_000);
    const text = (ran.stdout + ran.stderr).trim();
    return { text: text || "ck-doctor: no warnings, no errors." };
  });

  on("command.run", { command: "ck-agents" }, async ($) => {
    await pollAgents($);
    const opened = await $.ui.open({
      id: AGENTS_PANE,
      title: "ck-code agents",
    });
    if (opened.isPlaced) return {};
    const rows = await read($, agents);
    return {
      text: rows.length
        ? rows
            .map(
              (r) =>
                `${r.status.padEnd(9)} ${r.kind.padEnd(5)} ${r.label} · ${fmtSeconds(r.secs)}`,
            )
            .join("\n")
        : "No ck-code agent has run in this session.",
    };
  });

  on("command.run", { command: "ck-verify-pane" }, async ($, e) => {
    const plan = await pickPlan($, e.args.trim());
    if (!plan)
      return {
        text: "Name the plan: /ck-verify-pane tasks/<plan> (no single plan has a CHECKLIST.md).",
      };
    await loadChecklist($, plan, "");
    const opened = await $.ui.open({
      id: VERIFY_PANE,
      title: `Verify ${plan.replace(/^tasks\//, "")}`,
      rows: 18,
      // The keys, not only a click: Tab walks the buttons and the first item's hotkeys press.
      focus: true,
    });
    return opened.isPlaced
      ? {}
      : {
          text: "The verify pane needs the terminal or the Desktop app; run /ck-code:verify here.",
        };
  });

  on("command.run", { command: "ck-band" }, async ($) => {
    const hidden = !(await read($, bandHidden));
    await update($, bandHidden, () => hidden);
    await $.store.set("bandHidden", hidden);
    if (!hidden) await refreshBand($);
    if (!hidden) await wakeBand($);
    return {
      text: hidden
        ? "ck-code band hidden (/ck-band shows it again)."
        : "ck-code band shown.",
    };
  });

  on("command.run", { command: "ck-profile" }, async ($, e) => {
    const key = `profile:${rootCache}`;
    if (e.args.trim() === "reset") {
      await $.store.delete(key);
      return { text: "ck-code profile cleared for this project." };
    }
    return {
      text: profileReport(
        ((await $.store.get(key)) as TurnRecord[] | undefined) ?? [],
      ),
    };
  });

  // ---- drawing ----

  on("ui.render", { component: "AbovePrompt" }, async ($, e, next) => {
    if (e.surface === "terminal") isFullscreen = e.viewport?.isFullscreen === true;
    const data: CkBand | null = await read($, band);
    if (data === null || e.props.hasSurvey || (await read($, bandHidden)))
      return next(e);
    const { Box, Button, Text } = $.ui.resolve(e);
    const score = `${data.done}/${data.total}`;
    // The mods after this one (ck-tools' plan-limit rows) draw under ours, in the rows we
    // leave; a tree that ignored next(e) would hide them. Kept word for word in both mods.
    const below = async (rows: number) =>
      e.props.maxRows > rows
        ? await next({
            ...e,
            props: { ...e.props, maxRows: e.props.maxRows - rows },
          })
        : null;
    // The builders' task lists, one line each, in the rows the band can spare.
    const tasks: CkBoard[] = (await read($, board)).filter((b) => b.tasks.length > 0);
    const boardRows = (room: number) =>
      tasks.slice(0, Math.max(0, room)).map((b) => (
        <Text key={`board-${b.agent}`} color="claude" wrap="truncate-end">
          ◈ {boardLine(b)}
        </Text>
      ));
    if (e.props.isWorking) {
      if (!data.story && tasks.length === 0) return next(e);
      const lines = [
        ...(data.story
          ? [
              <Text key="story" dimColor wrap="truncate-end">
                ▸ ck-code · {data.story} · {score}
              </Text>,
            ]
          : []),
        ...boardRows(e.props.maxRows - (data.story ? 1 : 0)),
      ];
      const rest = await below(lines.length);
      return (
        <Box flexDirection="column">
          {lines}
          {rest}
        </Box>
      );
    }
    const command = data.recommend.split(" — ")[0]?.trim() ?? "";
    const isComplete = data.total > 0 && data.done >= data.total;
    // Off the fullscreen layout no click reaches a Button: name its hotkey and the chord that
    // focuses the band (ctrl+x tab). Kept word for word in both mods.
    const keys = e.surface === "terminal" && e.viewport?.isFullscreen !== true ? true : undefined;
    const header = (
      <Box key="head" gap={1}>
        <Text bold color="claude">
          ◆ ck-code
        </Text>
        <Text color="success">{progressBar(data.done, data.total)}</Text>
        <Text bold>
          {score} {percent(data.done, data.total)}%
        </Text>
        {data.story !== "" && (
          <Text color="warning" wrap="truncate-end">
            ▸ {data.story}
          </Text>
        )}
        {isComplete && <Text color="success">★ every story done</Text>}
      </Box>
    );
    // Folded: the action row has had its seconds; the progress line and the board stay.
    if (await read($, bandQuiet)) {
      const boardEls = boardRows(e.props.maxRows - 1 - data.notes.length);
      const rest = await below(1 + boardEls.length + data.notes.length);
      return (
        <Box flexDirection="column">
          {header}
          {boardEls}
          {data.notes.map((note) => (
            <Text color="warning" wrap="truncate-end">
              {note}
            </Text>
          ))}
          {rest}
        </Box>
      );
    }
    const actions = (
      <Box key="next" gap={1}>
        {command.startsWith("/") && (
          <Text color="suggestion" wrap="truncate-end">
            → {command}
            {data.why ? ` — ${data.why}` : ""}
          </Text>
        )}
        {command.startsWith("/") && (
          <Button
            key="fill"
            label="Use"
            hotkey="u"
            plain={keys}
            onPress={() => $.prompt.fill({ text: fillText(command) })}
          />
        )}
        <Button
          key="hide"
          label="Hide"
          hotkey="h"
          plain={keys}
          onPress={async () => {
            await update($, bandHidden, () => true);
            await $.store.set("bandHidden", true);
          }}
        />
        {keys && (
          <Text key="keys" dimColor>
            (ctrl+x tab)
          </Text>
        )}
      </Box>
    );
    // Short on rows: the next step matters more than the bar.
    if (e.props.maxRows < 2) return actions;
    const counts = isComplete ? 0 : 1;
    const boardEls = boardRows(e.props.maxRows - 2 - counts - data.notes.length);
    const rest = await below(2 + counts + boardEls.length + data.notes.length);
    return (
      <Box flexDirection="column">
        {header}
        {counts === 1 && (
          <Text key="counts" dimColor wrap="truncate-end">
            {data.counts}
          </Text>
        )}
        {boardEls}
        {actions}
        {data.notes.map((note) => (
          <Text color="warning" wrap="truncate-end">
            {note}
          </Text>
        ))}
        {rest}
      </Box>
    );
  });

  on(
    "ui.render",
    { component: "Pane", requestId: AGENTS_PANE },
    async ($, e) => {
      const { Box, Text } = $.ui.resolve(e);
      const rows = await read($, agents);
      if (rows.length === 0)
        return <Text dimColor>No ck-code agent has run in this session.</Text>;
      const room = Math.max(1, (e.props.scroll?.bodyRows ?? 20) - 2);
      const running = rows.filter((r) => isLive(r.status)).length;
      const finished = rows.length - running;
      return (
        <Box flexDirection="column">
          <Box key="head" gap={1}>
            <Text bold color="claude">
              {running} running · {finished} done
            </Text>
            <Text color="success">{progressBar(finished, rows.length)}</Text>
          </Box>
          {rows.slice(-room).map((r) => (
            <Text
              key={r.id}
              color={agentColor(r.status)}
              dimColor={r.status === "completed"}
              wrap="truncate-end"
            >
              {agentGlyph(r)} {r.kind.padEnd(5)}{" "}
              {fmtSeconds(r.secs).padStart(6)} {r.label}
            </Text>
          ))}
        </Box>
      );
    },
  );

  on(
    "ui.render",
    { component: "Pane", requestId: VERIFY_PANE },
    async ($, e) => {
      const { Box, Button, Markdown, Text } = $.ui.resolve(e);
      const data = await read($, verify);
      if (data === null)
        return <Text dimColor>Run /ck-verify-pane to load a checklist.</Text>;
      const plan = data.plan;
      return (
        <Box flexDirection="column" gap={1}>
          <Text dimColor wrap="truncate-end">
            {data.header}
          </Text>
          {data.message !== "" && <Text color="green">{data.message}</Text>}
          {e.surface === "terminal" && e.viewport?.isFullscreen !== true && data.items.length > 0 && (
            <Text dimColor wrap="truncate-end">
              p pass · s skip · f fail · t steps (first item) · Tab walks · ctrl+x tab refocuses
            </Text>
          )}
          {data.items.length === 0 && (
            <Text>
              Nothing left to test in this session. Close it with
              /ck-code:verify.
            </Text>
          )}
          {data.items.map((item, i) => {
            const first = i === 0;
            return (
            <Box key={item.id} flexDirection="column">
              <Text wrap="wrap">{item.line}</Text>
              <Box gap={1}>
                <Button
                  key={`pass-${item.id}`}
                  hotkey={first ? "p" : undefined}
                  label="Pass"
                  variant="primary"
                  onPress={() => recordItem($, plan, item.id, "pass")}
                />
                <Button
                  key={`skip-${item.id}`}
                  hotkey={first ? "s" : undefined}
                  label="Skip"
                  onPress={() => recordItem($, plan, item.id, "skip")}
                />
                <Button
                  key={`fail-${item.id}`}
                  hotkey={first ? "f" : undefined}
                  label="Fail…"
                  onPress={() =>
                    $.prompt.fill({
                      text: `/ck-code:verify ${plan} — ${item.id} failed: `,
                    })
                  }
                />
                <Button
                  key={`steps-${item.id}`}
                  hotkey={first ? "t" : undefined}
                  label="Steps"
                  onPress={() => showSteps($, plan, item.id)}
                />
              </Box>
            </Box>
            );
          })}
          {data.steps !== null && <Markdown text={data.steps.text} />}
        </Box>
      );
    },
  );
};
