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
//   AbovePrompt band   active story, counts, recommended next command, merged-PR notes
//   panes              agents cockpit during a build; verify checklist with buttons
//   turn.*             per-skill time and token profile (/ck-profile)
//
// Pure rules live in logic.ts. `$` never leaves this file except into the state helpers.

import { atom, read, update } from "claude-code";
import type { EngineInterface, Register } from "claude-code";

import type { CkAgentRow, CkBand, CkVerify } from "../../types";
import {
  HANDOFF_TTL_MS,
  PROFILE_KEEP,
  addUsage,
  countsLine,
  fmtSeconds,
  generatedViewReason,
  gitCleanReason,
  handoffText,
  hideCommand,
  isLive,
  isRoutable,
  parseChecklistNext,
  parseMergedPrs,
  parseState,
  parseStoriesIndex,
  profileReport,
  shortAgentType,
  splitArgs,
  storySuggestions,
  stripAnsi,
  stripRouting,
  zeroTokens,
} from "./logic";
import type { ProjectKind, StoryRow, Tokens, TurnRecord } from "./logic";

const band = atom({ plugin: "ck-code", key: "band" } as const, null);
const bandHidden = atom(
  { plugin: "ck-code", key: "bandHidden" } as const,
  false,
);
const agents = atom({ plugin: "ck-code", key: "agents" } as const, []);
const verify = atom({ plugin: "ck-code", key: "verify" } as const, null);

const AGENTS_PANE = "ck-agents";
const VERIFY_PANE = "ck-verify";
const PR_POLL_MS = 5 * 60 * 1000;
const AGENT_POLL_MS = 3000;

// Module variables start over on a reload; what must outlive one is in $.state or $.store.
let guardsOn = true;
let bandOn = true;
let prWatchOn = true;
let routingCache: string | undefined;
let stories: StoryRow[] = [];
let isRefreshing = false;
let lastCommand: string | undefined;
let cwdCache = "";
let rootCache = "";
let agentPoll: { cancel: () => void } | undefined;
let autoOpenAgents = true;
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

// The shell router's adoption markers: a ck-code project has docs/architecture, docs/specs,
// tasks/VERSION.md or a tasks/<plan>/epics. A tasks/PLAN.md with no stamp is ck-code-lite's.
async function projectKind($: EngineInterface): Promise<ProjectKind> {
  const cwd = await $.session.cwd();
  if (
    (await $.fs.exists(`${cwd}/tasks/PLAN.md`)) &&
    !(await $.fs.exists(`${cwd}/tasks/VERSION.md`))
  ) {
    return "lite";
  }
  if (await $.fs.exists(`${cwd}/docs/architecture`)) return "code";
  if (await $.fs.exists(`${cwd}/docs/specs`)) return "code";
  if (await $.fs.exists(`${cwd}/tasks/VERSION.md`)) return "code";
  if (!(await $.fs.exists(`${cwd}/tasks`))) return "none";
  for (const entry of await $.fs.list(`${cwd}/tasks`)) {
    if (
      entry.kind === "dir" &&
      (await $.fs.exists(`${cwd}/tasks/${entry.name}/epics`))
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
    timeoutMs,
  });
}

// Every plan's STORIES_INDEX.md, read after ck-view has regenerated the views.
async function loadStories($: EngineInterface): Promise<StoryRow[]> {
  const cwd = await $.session.cwd();
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
  if (!bandOn || isRefreshing) return;
  isRefreshing = true;
  try {
    if ((await projectKind($)) !== "code") {
      await update($, band, () => null);
      return;
    }
    const state = parseState((await script($, "ck-view.sh", ["state"])).stdout);
    if (state === null) return;
    const cwd = await $.session.cwd();
    const line = await $.process.run(
      [`${$.plugin.root}/scripts/statusline.sh`],
      {
        stdin: JSON.stringify({ cwd, workspace: { current_dir: cwd } }),
        timeoutMs: 15_000,
      },
    );
    stories = await loadStories($);
    await update($, band, (old) => ({
      story: stripAnsi(line.stdout.split("\n")[0] ?? ""),
      counts: countsLine(state.counts),
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
  } catch {
    return false; // no gh on this machine
  }
  if (ran.exitCode !== 0) return false; // not authenticated, or no GitHub remote
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
      `PR #${pr.number} merged (${pr.headRefName}) → /ck-code:doctor --fix`,
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
  if (builders >= 2 && autoOpenAgents) {
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
  agentPoll?.cancel();
  agentPoll = undefined;
  const failed = rows.filter(
    (r) => r.status === "failed" || r.status === "killed",
  ).length;
  if (rows.length > 0) {
    $.ui.toast(
      `ck-code: agents finished — ${rows.length - failed} completed${failed ? `, ${failed} failed` : ""}`,
    );
  }
}

// ---- verify checklist ----------------------------------------------------------------

async function loadChecklist(
  $: EngineInterface,
  plan: string,
  message: string,
): Promise<void> {
  const ran = await script($, "ck-checklist.sh", ["next", plan, "-n", "3"]);
  const { header, items } = parseChecklistNext(ran.stdout);
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
  const path = ran.stdout.trim();
  const text =
    ran.exitCode === 0 && path
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
  const cwd = await $.session.cwd();
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

// ---- commands ------------------------------------------------------------------------

async function viewCommand($: EngineInterface, mode: string, args: string): Promise<{ text: string }> {
  const ran = await script($, 'ck-view.sh', [mode, ...splitArgs(args)])
  return { text: (ran.stdout || ran.stderr).trim() || 'ck-view printed nothing.' }
}



export const register: Register = (on, options) => {
  guardsOn = options.guards !== false;
  bandOn = options.band !== false;
  prWatchOn = options.pr_watch !== false;

  on("session.start", async ($, e, next) => {
    cwdCache = await $.session.cwd();
    rootCache = (await $.session.root()) || cwdCache;
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
    if (e.reason === "clear" && lastCommand && cwdCache) {
      await $.store.set(`handoff:${cwdCache}`, {
        command: lastCommand,
        at: await $.clock.now(),
      });
    }
    return next(e);
  });

  on("prompt.context", async ($, e, next) => {
    const out = await next(e);
    const key = `handoff:${await $.session.cwd()}`;
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
      agentPoll = $.clock.every(AGENT_POLL_MS, () => void pollAgents($));
    }
    return next(e);
  }).catch(($, e, next) => next(e));

  on("ui.close", { id: AGENTS_PANE }, async ($, e, next) => {
    if (e.origin.kind === "person") autoOpenAgents = false;
    return next(e);
  });

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
    const data: CkBand | null = await read($, band);
    if (data === null || e.props.hasSurvey || (await read($, bandHidden)))
      return next(e);
    const { Box, Button, Text } = $.ui.resolve(e);
    if (e.props.isWorking) {
      return data.story ? (
        <Box>
          <Text dimColor wrap="truncate-end">
            ck-code · {data.story}
          </Text>
        </Box>
      ) : (
        next(e)
      );
    }
    const command = data.recommend.split(" — ")[0]?.trim() ?? "";
    return (
      <Box flexDirection="column">
        <Box gap={1}>
          <Text wrap="truncate-end">
            <Text bold>ck-code</Text>
            {data.story ? ` · ${data.story}` : ""} · {data.counts}
          </Text>
        </Box>
        {command.startsWith("/") && (
          <Box gap={1}>
            <Text dimColor wrap="truncate-end">
              next: {command}
              {data.why ? ` — ${data.why}` : ""}
            </Text>
            <Button
              key="fill"
              label="Use"
              onPress={() => $.prompt.fill({ text: `${command} ` })}
            />
            <Button
              key="hide"
              label="Hide"
              onPress={() => update($, bandHidden, () => true)}
            />
          </Box>
        )}
        {data.notes.map((note) => (
          <Text color="yellow" wrap="truncate-end">
            {note}
          </Text>
        ))}
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
      const room = Math.max(1, (e.props.scroll?.bodyRows ?? 20) - 1);
      return (
        <Box flexDirection="column">
          {rows.slice(-room).map((r) => (
            <Text
              key={r.id}
              dimColor={!isLive(r.status)}
              color={r.status === "failed" ? "red" : undefined}
              wrap="truncate-end"
            >
              {isLive(r.status) ? "●" : r.status === "completed" ? "✓" : "✗"}{" "}
              {r.kind.padEnd(5)} {fmtSeconds(r.secs).padStart(6)} {r.label}
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
          {data.items.length === 0 && (
            <Text>
              Nothing left to test in this session. Close it with
              /ck-code:verify.
            </Text>
          )}
          {data.items.map((item) => (
            <Box key={item.id} flexDirection="column">
              <Text wrap="wrap">{item.line}</Text>
              <Box gap={1}>
                <Button
                  key={`pass-${item.id}`}
                  label="Pass"
                  variant="primary"
                  onPress={() => recordItem($, plan, item.id, "pass")}
                />
                <Button
                  key={`skip-${item.id}`}
                  label="Skip"
                  onPress={() => recordItem($, plan, item.id, "skip")}
                />
                <Button
                  key={`fail-${item.id}`}
                  label="Fail…"
                  onPress={() =>
                    $.prompt.fill({
                      text: `/ck-code:verify ${plan} — ${item.id} failed: `,
                    })
                  }
                />
                <Button
                  key={`steps-${item.id}`}
                  label="Steps"
                  onPress={() => showSteps($, plan, item.id)}
                />
              </Box>
            </Box>
          ))}
          {data.steps !== null && <Markdown text={data.steps.text} />}
        </Box>
      );
    },
  );
};
