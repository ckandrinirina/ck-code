#!/usr/bin/env bash
# tests/evals.sh — run ck-code's `claude plugin eval` routing suite (evals/) locally.
#
# Checks that a realistic free-text prompt, inside an adopted ck-code project where
# scripts/prompt-router.sh injects references/prompt-routing.md, reaches the right
# /ck-code:* skill. Local only: it runs on your logged-in Claude account (a Max plan
# works — no API key) and costs roughly $0.07 per run (22 cases × 3 runs by default).
#
#   bash tests/evals.sh                        # whole suite, 3 runs per case
#   bash tests/evals.sh --runs 1               # quick pass
#   bash tests/evals.sh --case 'route-fix-*'   # one skill while tuning its description
#   bash tests/evals.sh --model sonnet         # cheaper model
#
# Extra arguments pass straight to `claude plugin eval`. EVAL_THRESHOLD (default 0.67 —
# 2 of 3 runs) sets the per-case pass mark: routing is not deterministic, so the CLI's
# default of 1.0 would fail on noise.
#
# Fixed flags, each load-bearing:
#   --ablation none  the default no-plugin arm turns `tool_used: Skill` into an unscored
#                    indicator, so routing would never be graded;
#   --scaffold       each case copies evals/_fixture/adopted into the run's cwd — the only
#                    way to seed the cwd (context.add_dirs leaves it empty);
#   --trust-plugin   skips the first-run trust prompt for this repo's own plugin.

set -uo pipefail

PLUGIN_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
MIN_CC="2.1.269"

command -v claude >/dev/null 2>&1 || { echo "evals.sh: claude CLI not on PATH" >&2; exit 1; }
have=$(claude --version 2>/dev/null | awk '{print $1}')
oldest=$(printf '%s\n%s\n' "$MIN_CC" "$have" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)
if [ -z "$have" ] || [ "$oldest" != "$MIN_CC" ]; then
  echo "evals.sh: needs Claude Code >= $MIN_CC for 'claude plugin eval' (found: ${have:-none})" >&2
  exit 1
fi

cd "$PLUGIN_ROOT" || exit 1
exec claude plugin eval . \
  --ablation none --scaffold --trust-plugin --no-publish \
  --threshold "${EVAL_THRESHOLD:-0.67}" \
  "$@"
