// The ck-code mod's $.state contract: the values its band and panes draw from.

export type CkBand = {
  // The status-line segment: the active story derived from the branch, or "".
  story: string;
  // "4 ready · 13 blocked · 42 done"
  counts: string;
  // ck-view's routing verdict: the command to run next, and why.
  recommend: string;
  why: string;
  // One line per event worth a look, such as a merged PR the plan has not caught up with.
  notes: string[];
};

export type CkAgentRow = {
  id: string;
  label: string;
  kind: string;
  status: string;
  secs: number;
};

export type CkVerify = {
  plan: string;
  header: string;
  items: { id: string; line: string }[];
  steps: { id: string; text: string } | null;
  message: string;
};

declare module "claude-code" {
  interface PluginState {
    "ck-code": {
      band: CkBand | null;
      bandHidden: boolean;
      agents: CkAgentRow[];
      verify: CkVerify | null;
    };
  }
}
