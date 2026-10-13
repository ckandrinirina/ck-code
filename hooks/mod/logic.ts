// Pure helpers of the ck-code mod: parsing, guard rules, profile arithmetic.
//
// Nothing here touches `$`. The hooks module (register.tsx) does every engine call and
// hands plain values to these functions, so each rule is unit-tested without a session
// (tests/mod/logic.test.ts).

export type ProjectKind = "code" | "lite" | "none";

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
  for (const segment of command.split(/&&|\|\||[;|\n]/)) {
    const words = segment.trim().split(/\s+/);
    // The command word, after any `VAR=value` assignments.
    const git = words.findIndex((w) => !/^[A-Za-z_][A-Za-z0-9_]*=/.test(w));
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

export type ChecklistItem = { id: string; line: string };

// `ck-checklist.sh next <plan> -n N`: a `# session …` header, then one line per item,
// or `# nothing left in this session`.
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
    const id = /\bC-\d+\b/.exec(line)?.[0];
    if (id) items.push({ id, line: line.replace(/\t/g, "  ").trim() });
  }
  return { header, items };
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
