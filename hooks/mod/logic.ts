// Pure helpers of the ck-code mod: parsing, guard rules, profile arithmetic.
//
// Nothing here touches `$`. The hooks module (register.tsx) does every engine call and
// hands plain values to these functions, so each rule is unit-tested without a session
// (tests/mod/logic.test.ts).

export type ProjectKind = "code" | "lite" | "none";

// ---- the lite-project rule -------------------------------------------------------------

// Kept word for word in both plugins' mods, and agreeing with the skills' plugin guards
// (version-gate.md, plugin-redirect.md): a stamped project is ck-code's; a lite plan stays
// lite's even beside an unstamped docs/architecture/ (half-migrated); a bare
// docs/ARCHITECTURE.md is lite's only when no docs/architecture/ sits beside it.
export function isLiteLayout(has: {
  stamp: boolean;
  plan: boolean;
  architectureDir: boolean;
  architectureDoc: boolean;
}): boolean {
  if (has.stamp) return false;
  if (has.plan) return true;
  return has.architectureDoc && !has.architectureDir;
}

// ---- prompt routing (was scripts/prompt-router.sh) --------------------------------

// A reply to a running skill ("yes", "2", "go") is shorter than this; routing it would
// derail the skill.
export const ROUTE_MIN_CHARS = 12;

// Only a person's own prompt is routed: never a task notification, a peer's message
// or a prompt another plugin submitted.
const ROUTED_ORIGINS = new Set(["composer", "bridge", "sdk"]);

export function isRoutable(text: string, originKind: string): boolean {
  if (!ROUTED_ORIGINS.has(originKind)) return false;
  const t = text.trimStart();
  if (t.startsWith("/")) return false;
  return t.length >= ROUTE_MIN_CHARS;
}

// prompt-routing.md carries maintainer notes as `<!--` lines; the model never needs them.
export function stripRouting(md: string): string {
  return md
    .split("\n")
    .filter((line) => !line.startsWith("<!--"))
    .join("\n")
    .trim();
}

// ---- ck-view state -> band ---------------------------------------------------------

export type ViewState = {
  counts: Record<string, number>;
  recommend: string;
  why: string;
};

// Reads the machine lines of `ck-view.sh state`:
//   COUNTS: ready=4 bug=0 blocked=13 in_progress=0 done=42 ...
//   RECOMMEND: /ck-code:track next
//   WHY: 4 ready stories to implement
export function parseState(stdout: string): ViewState | null {
  const counts: Record<string, number> = {};
  let recommend = "";
  let why = "";
  let seen = false;
  for (const line of stdout.split("\n")) {
    if (line.startsWith("COUNTS:")) {
      seen = true;
      for (const pair of line.slice(7).trim().split(/\s+/)) {
        const [key, value] = pair.split("=");
        const n = Number(value);
        if (key && Number.isFinite(n)) counts[key] = n;
      }
    } else if (line.startsWith("RECOMMEND:")) {
      recommend = line.slice(10).trim();
    } else if (line.startsWith("WHY:")) {
      why = line.slice(4).trim();
    }
  }
  return seen ? { counts, recommend, why } : null;
}

export function countsLine(counts: Record<string, number>): string {
  const parts: string[] = [];
  const add = (key: string, word: string, always = false) => {
    const n = counts[key] ?? 0;
    if (n > 0 || always) parts.push(`${n} ${word}`);
  };
  add("ready", "ready", true);
  add("bug", "bug");
  add("in_progress", "in progress");
  add("blocked", "blocked");
  add("done", "done");
  return parts.join(" · ");
}

// Every story ck-view counts, skipped ones aside: the progress bar's whole.
export function storyTotal(counts: Record<string, number>): number {
  return ["ready", "bug", "blocked", "in_progress", "done"].reduce(
    (sum, key) => sum + (counts[key] ?? 0),
    0,
  );
}

// The IDs a story-done cheer compares between two refreshes.
export function openStoryIds(rows: readonly StoryRow[]): string[] {
  return rows
    .filter((r) => r.status !== "DONE" && r.status !== "SKIP")
    .map((r) => r.id);
}

// statusline.sh prints its whole line, `ck-code demo 0/1 33% 1⚡ · epic 01 core 1/3 33% ·
// ⚡ 01-02 Story 2`; the band wants only the story, the last segment when it starts with ⚡.
export function bandStory(line: string): string {
  const last = stripAnsi(line).split(" · ").pop() ?? "";
  return last.startsWith("⚡") ? last.slice(last.lastIndexOf("⚡ ") + "⚡ ".length).trim() : "";
}

// What the band's Use button fills: the recommended command, or only its slash command when
// the rest is a placeholder (`/ck-code:ship <story-path>`) the person has to write.
export function fillText(command: string): string {
  return command.includes("<") ? `${command.split(/\s+/)[0]} ` : `${command} `;
}

// The status-line script may color its segment.
export function stripAnsi(text: string): string {
  return text.replace(/\u001b\[[0-9;]*[A-Za-z]/g, "").trim();
}

// ---- guards ------------------------------------------------------------------------

const GENERATED_VIEW =
  /(^|\/)tasks\/(?:[^/]+\/)?(STORIES_INDEX|EPICS_INDEX)\.md$/;

// STORIES_INDEX.md and EPICS_INDEX.md are projections of story frontmatter
// (references/stories-index.md): a hand edit is overwritten at the next regeneration.
export function generatedViewReason(path: string): string | undefined {
  const m = GENERATED_VIEW.exec(path);
  if (!m) return undefined;
  return (
    `ck-code: ${m[2]}.md is a generated view and is never hand-edited. ` +
    "Change the story frontmatter (`ck-story set <story> key=value`), then run `ck-index`."
  );
}

// `git clean` with -x or -X deletes gitignored files: .env files, local config, every
// build cache. Freeing a kept worktree's build output is ck-reclaim's job, which deletes
// only directories it proves rebuildable.
export function gitCleanReason(command: string): string | undefined {
  // Quoted text is an argument, never a command: `git commit -m "a; git clean -x"` passes.
  const bare = command.replace(/'[^']*'|"(?:\\.|[^"\\])*"/g, "''");
  for (const segment of bare.split(/&&|\|\||[;|\n]/)) {
    const words = segment.replace(/[()]/g, " ").trim().split(/\s+/);
    // The command word, after any `sudo`, `command`, `env` and `VAR=value` before it.
    const git = words.findIndex(
      (w) =>
        !/^[A-Za-z_][A-Za-z0-9_]*=/.test(w) && !/^(sudo|command|env)$/.test(w),
    );
    if (git < 0 || words[git] !== "git") continue;
    // Skip git's own options (`-C <dir>`, `-c k=v`) to reach the subcommand.
    let i = git + 1;
    while (i < words.length && words[i]!.startsWith("-")) {
      i += words[i] === "-C" || words[i] === "-c" ? 2 : 1;
    }
    if (words[i] !== "clean") continue;
    const flags = words.slice(i + 1).filter((w) => /^-[A-Za-z]+$/.test(w));
    if (flags.some((f) => /[xX]/.test(f))) {
      return (
        "ck-code: `git clean -x/-X` deletes gitignored files (.env, local config, build caches). " +
        "To free the build output of a kept worktree, run `ck-reclaim <worktree-path>`; " +
        "to remove untracked files only, drop the x flag. The person can still run it as `! git clean …`."
      );
    }
  }
  return undefined;
}

// ---- stories index -> autocomplete --------------------------------------------------

export type StoryRow = { id: string; title: string; status: string };

// Rows of `| Epic | ID | Title | Status | Delivery | Size | Blocked by | File |`.
export function parseStoriesIndex(md: string): StoryRow[] {
  const rows: StoryRow[] = [];
  for (const line of md.split("\n")) {
    if (!line.startsWith("|")) continue;
    const cells = line.split("|").map((c) => c.trim());
    const id = cells[2] ?? "";
    if (!/^\d{2}-\d{2}$/.test(id)) continue;
    rows.push({
      id,
      title: cells[3] ?? "",
      status: (cells[4] ?? "").toUpperCase(),
    });
  }
  return rows;
}

export type Suggestion = { text: string; label: string; description: string };

// A token such as `10-` or `10-0` offers the matching stories that still have work.
export function storySuggestions(
  token: string,
  stories: readonly StoryRow[],
  max = 8,
): Suggestion[] {
  if (!/^\d{2}-\d{0,2}$/.test(token)) return [];
  return stories
    .filter(
      (s) =>
        s.id.startsWith(token) && s.status !== "DONE" && s.status !== "SKIP",
    )
    .slice(0, max)
    .map((s) => ({
      text: s.id,
      label: `${s.id}  ${s.title}`,
      description: s.status.toLowerCase(),
    }));
}

// ---- merged PR watch ----------------------------------------------------------------

export type MergedPr = { number: number; title: string; headRefName: string };

export function parseMergedPrs(json: string): MergedPr[] {
  try {
    const data: unknown = JSON.parse(json);
    if (!Array.isArray(data)) return [];
    return data
      .filter(
        (p): p is MergedPr =>
          typeof p === "object" && p !== null && typeof p.number === "number",
      )
      .map((p) => ({
        number: p.number,
        title: String(p.title ?? ""),
        headRefName: String(p.headRefName ?? ""),
      }));
  } catch {
    return [];
  }
}

// ---- command list -------------------------------------------------------------------

// With both plugins installed every workflow skill is listed twice. A ck-code project
// hides ck-code-lite's; a lite project hides ck-code's but the ones that lead from lite
// to ck-code. A hidden command still runs when typed in full.
const LITE_KEEPS = new Set([
  "ck-code:migrate",
  "ck-code:guide",
  "ck-code:init",
]);

export function hideCommand(kind: ProjectKind, command: string): boolean {
  if (kind === "code") return command.startsWith("ck-code-lite:");
  if (kind === "lite")
    return command.startsWith("ck-code:") && !LITE_KEEPS.has(command);
  return false;
}

// ---- agents cockpit -----------------------------------------------------------------

const LIVE = new Set(["pending", "running", "waiting"]);

export function isLive(status: string): boolean {
  return LIVE.has(status);
}

export function shortAgentType(type: string): string {
  switch (type) {
    case "ck-code:story-implementer":
      return "build";
    case "ck-code:qa-validator":
      return "qa";
    case "ck-code:conflict-analyzer":
      return "merge";
    default:
      return type.replace(/^ck-code:/, "");
  }
}

export function fmtSeconds(secs: number): string {
  if (secs < 60) return `${secs}s`;
  const m = Math.floor(secs / 60);
  if (m < 60) return `${m}m${String(secs % 60).padStart(2, "0")}s`;
  return `${Math.floor(m / 60)}h${String(m % 60).padStart(2, "0")}m`;
}

// ---- profiler -----------------------------------------------------------------------

export type Tokens = {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
};

export type TurnRecord = {
  at: number;
  skill: string;
  ms: number;
  tools: number;
  agents: number;
  main: Tokens;
  sub: Tokens;
};

export const PROFILE_KEEP = 200;

export function zeroTokens(): Tokens {
  return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
}

type UsageLike = {
  input_tokens?: number | null;
  output_tokens?: number | null;
  cache_read_input_tokens?: number | null;
  cache_creation_input_tokens?: number | null;
};

export function addUsage(into: Tokens, usage: UsageLike | undefined): Tokens {
  if (!usage) return into;
  return {
    input: into.input + (usage.input_tokens ?? 0),
    output: into.output + (usage.output_tokens ?? 0),
    cacheRead: into.cacheRead + (usage.cache_read_input_tokens ?? 0),
    cacheWrite: into.cacheWrite + (usage.cache_creation_input_tokens ?? 0),
  };
}

function kTokens(n: number): string {
  return n >= 1_000_000
    ? `${(n / 1_000_000).toFixed(1)}M`
    : n >= 1000
      ? `${Math.round(n / 1000)}k`
      : String(n);
}

function sumTokens(t: Tokens): number {
  return t.input + t.output + t.cacheRead + t.cacheWrite;
}

// One row per skill: where the time and the tokens of this project's turns went.
export function profileReport(records: readonly TurnRecord[]): string {
  if (records.length === 0) return "No turns recorded yet in this project.";
  const by = new Map<string, TurnRecord[]>();
  for (const r of records) by.set(r.skill, [...(by.get(r.skill) ?? []), r]);
  const rows = [...by.entries()]
    .map(([skill, rs]) => {
      const ms = rs.reduce((a, r) => a + r.ms, 0);
      const main = rs.reduce((a, r) => addTokens(a, r.main), zeroTokens());
      const sub = rs.reduce((a, r) => addTokens(a, r.sub), zeroTokens());
      return {
        skill,
        turns: rs.length,
        ms,
        tools: rs.reduce((a, r) => a + r.tools, 0),
        agents: rs.reduce((a, r) => a + r.agents, 0),
        main,
        sub,
      };
    })
    .sort((a, b) => b.ms - a.ms);
  const lines = [
    `ck-code profile — last ${records.length} turns in this project`,
    "",
    "| Skill | Turns | Time | Avg | Tools | Agents | Main tokens (out / cache read) | Agent tokens |",
    "|---|---|---|---|---|---|---|---|",
    ...rows.map(
      (r) =>
        `| ${r.skill} | ${r.turns} | ${fmtSeconds(Math.round(r.ms / 1000))} | ${fmtSeconds(
          Math.round(r.ms / r.turns / 1000),
        )} | ${r.tools} | ${r.agents} | ${kTokens(sumTokens(r.main))} (${kTokens(r.main.output)} / ${kTokens(
          r.main.cacheRead,
        )}) | ${kTokens(sumTokens(r.sub))} |`,
    ),
  ];
  return lines.join("\n");
}

function addTokens(a: Tokens, b: Tokens): Tokens {
  return {
    input: a.input + b.input,
    output: a.output + b.output,
    cacheRead: a.cacheRead + b.cacheRead,
    cacheWrite: a.cacheWrite + b.cacheWrite,
  };
}

// ---- verify checklist ----------------------------------------------------------------

export type ChecklistItem = { id: string; status: string; path: string };

// `ck-checklist.sh next <plan> -n N`: a `# session …` header, then `C-01<TAB>todo<TAB>
// tasks/…/C-01_login-works.md` per item, or `# nothing left in this session`.
export function parseChecklistNext(stdout: string): {
  header: string;
  items: ChecklistItem[];
} {
  let header = "";
  const items: ChecklistItem[] = [];
  for (const line of stdout.split("\n")) {
    if (line.startsWith("#")) {
      if (!header) header = line.replace(/^#\s*/, "");
      continue;
    }
    const [id = "", status = "", path = ""] = line.trim().split("\t");
    if (/^C-\d+$/.test(id)) items.push({ id, status, path });
  }
  return { header, items };
}

// An item's pane line: its frontmatter `title:`, else its file's slug (`C-01_login-works.md`
// reads `login works`), and its status when it is not a plain todo.
export function checklistLine(item: ChecklistItem, md: string): string {
  const fm = /^---\n([\s\S]*?)\n---/.exec(md)?.[1] ?? "";
  const quoted = /^title:\s*"((?:\\.|[^"\\])*)"\s*$/m.exec(fm)?.[1];
  const title =
    quoted?.replace(/\\(.)/g, "$1") ??
    /^title:\s*(.+)$/m.exec(fm)?.[1]?.trim() ??
    (item.path.split("/").pop() ?? "")
      .replace(/\.md$/, "")
      .replace(/^C-\d+_?/, "")
      .replace(/[-_]+/g, " ");
  const status = item.status && item.status !== "todo" ? ` · ${item.status}` : "";
  return `${item.id}  ${title || item.id}${status}`;
}

// ---- misc ---------------------------------------------------------------------------

export function splitArgs(args: string): string[] {
  return args.trim() === "" ? [] : args.trim().split(/\s+/);
}

// The last /ck-code:* command typed, kept across a /clear for a few hours.
export const HANDOFF_TTL_MS = 6 * 60 * 60 * 1000;

export function handoffText(command: string): string {
  return (
    `Before the /clear that started this conversation, the last ck-code command run in this ` +
    `project was \`${command}\`. If the person asks to continue, resume from it.`
  );
}

// ---- compaction after a wave run ------------------------------------------------------

// Kept word for word in both plugins' mods. A wave run is a main-loop turn that dispatched
// two or more builder agents; it is over, and its per-wave detail spent, when the turn
// answered (not interrupted, not an API error) and nothing is left in progress. A held,
// failed or unsigned task stays in progress, and the user still needs the detail to finish it.
export function isWaveRunOver(run: {
  reason: string;
  builders: number;
  inProgress: number;
}): boolean {
  return run.reason === "answer" && run.builders >= 2 && run.inProgress === 0;
}

export const COMPACT_INSTRUCTIONS =
  "A ck-code build run just finished. Keep the plan and epic, every story built and its " +
  "final status, every branch and PR named, the manual test checklist and any deferred " +
  "manual tests word for word, and the next command the run recommended. Drop per-wave " +
  "agent reports, QA output and diffs: the story files and git hold them.";

// ---- progress bar and celebrations ----------------------------------------------------

// Kept word for word in both plugins' mods, so the two bands look like one family.

export function progressBar(done: number, total: number, width = 10): string {
  const filled =
    total > 0 ? Math.round((Math.min(done, total) / total) * width) : 0;
  return "▰".repeat(filled) + "▱".repeat(width - filled);
}

// Floored, so 100% means every item is done, never 199 of 200.
export function percent(done: number, total: number): number {
  return total > 0 ? Math.floor((Math.min(done, total) / total) * 100) : 0;
}

// `open` lists the IDs not done yet; a refresh compares it with the one before.
export type Progress = { done: number; total: number; open: readonly string[] };

// The toast for work finished between two refreshes. None on the first look (a session
// start or a mod reload), and none when nothing new is done.
export function celebration(
  before: Progress | undefined,
  after: Progress,
  nouns: string,
): string | undefined {
  if (!before || after.total === 0 || after.done <= before.done)
    return undefined;
  const score = `${after.done}/${after.total}`;
  if (after.done >= after.total)
    return `🎉 Plan complete — ${score} ${nouns} done!`;
  const finished = before.open.filter((id) => !after.open.includes(id));
  const what =
    finished.length > 0 && finished.length <= 3
      ? finished.join(", ")
      : `${after.done - before.done} more`;
  return `✨ ${what} done — ${score} (${percent(after.done, after.total)}%)`;
}
