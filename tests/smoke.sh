#!/usr/bin/env bash
# tests/smoke.sh — end-to-end smoke test for ck-code's scripts/bin against a
# synthetic, throwaway v6 project fixture.
#
# Builds a temp git repo with a v6 tasks/ layout (see references/data-model.md),
# puts this plugin's bin/ on PATH, and drives the real scripts against it: ck-index,
# ck-view, ck-doctor, ck-story, ck-bootstrap, and the four hook scripts. Assertions
# encode the CORRECT behaviour per references/data-model.md, references/stories-index.md,
# references/feature-index.md and skills/build/references/wave-mode.md — a FAIL here is
# not necessarily this harness being wrong; see tests/README.md.
#
# bash 3.2 compatible: no mapfile, no associative arrays, no ${var,,}. No external
# deps beyond git, awk, sed, python3; jq-dependent assertions are skipped (with a
# note) when jq is not on PATH.

set -uo pipefail

PLUGIN_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
FIXTURE=""
PASS=0
FAIL=0

cleanup() {
  [ -n "$FIXTURE" ] && [ -d "$FIXTURE" ] && rm -rf "$FIXTURE"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# ---- tiny assertion harness ---------------------------------------------------

log_ok() {
  printf 'ok      %s\n' "$1"
  PASS=$((PASS + 1))
}
log_fail() {
  printf 'FAIL    %s\n' "$1"
  [ -n "${2:-}" ] && printf '        %s\n' "$2" | sed 's/^/        /' | sed '1s/^        //'
  FAIL=$((FAIL + 1))
}
log_skip() {
  printf 'skip    %s\n' "$1"
}

assert_contains() { # label haystack needle
  case "$2" in
    *"$3"*) log_ok "$1" ;;
    *) log_fail "$1" "expected to contain: $3" ;;
  esac
}
assert_not_contains() { # label haystack needle
  case "$2" in
    *"$3"*) log_fail "$1" "expected NOT to contain: $3" ;;
    *) log_ok "$1" ;;
  esac
}
assert_eq() { # label want got
  [ "$2" = "$3" ] && log_ok "$1" || log_fail "$1" "expected [$2] got [$3]"
}
assert_exit() { # label want_code got_code
  [ "$2" = "$3" ] && log_ok "$1" || log_fail "$1" "expected exit $2, got $3"
}
assert_true() { # label condition-as-string(0/1)
  [ "$2" -eq 0 ] && log_ok "$1" || log_fail "$1" "condition failed"
}

# ---- fixture construction ------------------------------------------------------
# tasks/<slug>/epics/NN_<epic-slug>/stories/SS_<story-slug>.md — v6 layout
# (references/data-model.md). One plan (2026-01-01_demo) with two epics; a second,
# deliberately-broken plan is added later to exercise ck-doctor scoping / ck-story
# WARN passthrough.

write_epic() { # write_epic PATH EPIC SLUG TITLE DESCRIPTION
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<EOF
---
epic: $2
slug: $3
title: $4
description: $5
issue:
pr:
delivery:
integration:
---

# Epic $2: $4

## Description

$5.

## Goals

- Ship $4.

## Scope

### In Scope

- Everything under this epic's stories.

### Out of Scope

- Nothing noted.

## Dependencies

- **Depends on:** None
- **Blocks:** None

## Acceptance Criteria

- [ ] All stories in this epic are done.
EOF
}

# write_story PATH ID TITLE EPIC STATUS SIZE BLOCKED FILES ISSUE PR DELIVERY PRIOR [BODY_EXTRA]
write_story() {
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<EOF
---
id: $2
title: $3
epic: $4
status: $5
size: $6
blocked_by: $7
files: $8
issue: $9
pr: ${10}
delivery: ${11}
prior_status: ${12}
---

# Story $2: $3

## Description

Fixture story for ck-code's smoke test.

## Acceptance Criteria

- [ ] Fixture criterion one.
- [ ] Fixture criterion two.

## Implementation Tasks

- [ ] Fixture task.

## Technical Notes

None.
EOF
  if [ -n "${13:-}" ]; then
    printf '\n%s\n' "${13}" >> "$1"
  fi
}

build_fixture() {
  mkdir -p tasks
  cat > tasks/VERSION.md <<'EOF'
# ck-code project version

layout: v6
EOF

  mkdir -p "tasks/2026-01-01_demo"
  cat > "tasks/2026-01-01_demo/PROJECT_OVERVIEW.md" <<'EOF'
# Demo Project

## Vision

Fixture project used only by ck-code's tests/smoke.sh.

## Architecture

N/A — fixture only.

## Tech Stack

| Layer | Technology | Version |
| ----- | ---------- | ------- |
| n/a   | n/a        | n/a     |

## Components

### Fixture

- **Purpose:** exercise ck-index/ck-view/ck-doctor/ck-story against a real v6 layout.

## Key Design Decisions

- None — this is a fixture.

## Non-Functional Requirements

- **Performance:** n/a
- **Security:** n/a
- **Compatibility:** n/a

## References

- Generated: by tests/smoke.sh
EOF
  cat > "tasks/2026-01-01_demo/ROADMAP.md" <<'EOF'
# Roadmap

## Milestones

| Milestone | Epics | Target |
|-----------|-------|--------|
| MVP       | 01, 02 | n/a |
EOF

  write_epic "tasks/2026-01-01_demo/epics/01_foundation/EPIC.md" 01 foundation Foundation \
    "Core foundation work"
  write_epic "tasks/2026-01-01_demo/epics/02_payments/EPIC.md" 02 payments Payments \
    "Payment processing"

  # ---- epic 01: foundation ----
  write_story "tasks/2026-01-01_demo/epics/01_foundation/stories/01_bootstrap.md" \
    01-01 "Bootstrap project scaffold" 01 done S "[]" "[src/app.ts]" "" 10 merged ""
  write_story "tasks/2026-01-01_demo/epics/01_foundation/stories/02_ci-pipeline.md" \
    01-02 "Set up CI pipeline" 01 done S "[01-01]" "[.github/workflows/ci.yml]" "" "" direct ""
  write_story "tasks/2026-01-01_demo/epics/01_foundation/stories/03_login-fix.md" \
    01-03 'Fix "login" bug | urgent case' 01 in-progress M "[01-02]" "[src/auth/login.ts]" "" "" "" ""

  # ---- epic 02: payments ----
  write_story "tasks/2026-01-01_demo/epics/02_payments/stories/01_charge.md" \
    02-01 "Charge processing" 02 done S "[]" "[src/payments/charge.ts]" "" "" "" ""
  # blocked_by quoted ON PURPOSE — references/data-model.md's inline-flow-list contract
  # allows a quoted scalar; ck-index must unquote it in the STORIES_INDEX cell.
  write_story "tasks/2026-01-01_demo/epics/02_payments/stories/02_refund.md" \
    02-02 "Refund handling" 02 todo S '["02-01"]' "[src/payments/refund.ts]" "" "" "" ""
  write_story "tasks/2026-01-01_demo/epics/02_payments/stories/03_invoice.md" \
    02-03 "Invoice generation" 02 todo S "[02-02]" "[src/payments/invoice.ts]" "" "" "" ""
  # out-of-epic blocker (01-03, epic 01), not done — must render UNSCHEDULABLE in
  # `ck-view waves --epic 02` (skills/build/references/wave-mode.md).
  write_story "tasks/2026-01-01_demo/epics/02_payments/stories/04_receipt.md" \
    02-04 "Receipt email" 02 todo S "[01-03]" "[src/payments/receipt.ts]" "" "" "" ""
  write_story "tasks/2026-01-01_demo/epics/02_payments/stories/05_webhook.md" \
    02-05 "Webhook retries" 02 skip S "[]" "[src/payments/webhook.ts]" "" "" "" ""
  # bug with a prior_status, and the required "## Bug Report" body section so
  # ck-doctor's check_stories does not flag it on the clean fixture.
  write_story "tasks/2026-01-01_demo/epics/02_payments/stories/06_double-charge.md" \
    02-06 "Fix double-charge bug" 02 bug S "[]" "[src/payments/charge.ts]" "" "" "" done \
    $'## Bug Report\n\nCustomers were double-charged under a race condition.'
  # files overlap with 02-02 (src/payments/refund.ts) — the wave splitter must not
  # put both in the same wave even though both are otherwise wave-1 ready.
  write_story "tasks/2026-01-01_demo/epics/02_payments/stories/07_export.md" \
    02-07 "Export refunds report" 02 todo S "[]" "[src/payments/refund.ts, src/payments/export.ts]" "" "" "" ""

  git init -q .
  git config user.email "smoke@ck-code.test"
  git config user.name "ck-code smoke"
  git add -A
  git commit -q -m "fixture: v6 demo project"
  git checkout -q -b story/01-03-login-fix
}

add_broken_plan() {
  mkdir -p "tasks/2026-02-02_other/epics/03_other/stories"
  cat > "tasks/2026-02-02_other/PROJECT_OVERVIEW.md" <<'EOF'
# Other Project

## Vision

Second, deliberately-broken plan — exercises ck-doctor plan scoping and
ck-story's WARN passthrough.
EOF
  write_epic "tasks/2026-02-02_other/epics/03_other/EPIC.md" 03 other Other "Other work"
  # Missing `id:` on purpose — ck-index must skip it with a WARN, and ck-doctor's
  # check_stories must flag it as an ERROR.
  cat > "tasks/2026-02-02_other/epics/03_other/stories/01_broken.md" <<'EOF'
---
id:
title: Broken story
epic: 03
status: todo
size: S
blocked_by: []
files: []
issue:
pr:
delivery:
prior_status:
---

# Story: Broken story

## Description

Missing `id:` on purpose.
EOF
  git add -A
  git commit -q -m "fixture: add broken plan (missing id)"
}

# ---- go -------------------------------------------------------------------

FIXTURE="$(mktemp -d 2>/dev/null || mktemp -d -t ckcode-smoke)"
( cd "$FIXTURE" && build_fixture )

export PATH="$PLUGIN_ROOT/bin:$PATH"

HAVE_JQ=1
command -v jq >/dev/null 2>&1 || HAVE_JQ=0

cd "$FIXTURE" || { echo "smoke: could not cd into fixture $FIXTURE" >&2; exit 1; }

echo "=== ck-index (first run) ==="
IDX_OUT=$(ck-index 2>&1); IDX_RC=$?
assert_exit "ck-index: exits 0 on the clean fixture" 0 "$IDX_RC"
assert_not_contains "ck-index: no WARN on the clean fixture" "$IDX_OUT" "ck-index: WARN"

SI_DEMO="tasks/2026-01-01_demo/STORIES_INDEX.md"
FI="tasks/FEATURE_INDEX.md"
assert_true "ck-index: wrote $SI_DEMO" "$([ -f "$SI_DEMO" ]; echo $?)"
assert_true "ck-index: wrote $FI" "$([ -f "$FI" ]; echo $?)"

echo
echo "=== ck-index idempotency ==="
cp "$SI_DEMO" "$FIXTURE/.snap_si"
cp "$FI" "$FIXTURE/.snap_fi"
ck-index >/dev/null 2>&1
if diff -q "$SI_DEMO" "$FIXTURE/.snap_si" >/dev/null 2>&1; then
  log_ok "ck-index: STORIES_INDEX.md byte-identical across two runs"
else
  log_fail "ck-index: STORIES_INDEX.md byte-identical across two runs" "$(diff "$SI_DEMO" "$FIXTURE/.snap_si" | head -10)"
fi
if diff -q "$FI" "$FIXTURE/.snap_fi" >/dev/null 2>&1; then
  log_ok "ck-index: FEATURE_INDEX.md byte-identical across two runs"
else
  log_fail "ck-index: FEATURE_INDEX.md byte-identical across two runs" "$(diff "$FI" "$FIXTURE/.snap_fi" | head -10)"
fi
rm -f "$FIXTURE/.snap_si" "$FIXTURE/.snap_fi"

echo
echo "=== STORIES_INDEX content ==="
# Match on the ID column specifically (field 3 of the pipe-split row) — a naive
# substring grep for "02-02" also hits it as the Blocked-by CELL of story 02-03's
# row, which reads back as a multi-line "match" instead of one row.
row_for_id() { # row_for_id ID <FILE   — the one row whose ID column equals ID
  awk -F'|' -v want="$2" '
    { id=$3; gsub(/^[ \t]+|[ \t]+$/,"",id); if (id==want) { print; exit } }
  ' "$1"
}
ROW_0202=$(row_for_id "$SI_DEMO" "02-02")
BL_0202=$(printf '%s' "$ROW_0202" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$8); print $8}')
assert_eq "STORIES_INDEX: 02-02 Blocked-by is unquoted 02-01" "02-01" "$BL_0202"

ROW_0103=$(row_for_id "$SI_DEMO" "01-03")
assert_contains "STORIES_INDEX: title with | and \" — pipe escaped" "$ROW_0103" 'Fix "login" bug \| urgent case'

echo
echo "=== FEATURE_INDEX rollup ==="
# Feature column reads "NN · Name" — match the epic NUMBER token, not a raw
# substring grep (which could also hit "01" inside some other cell).
FEAT_01=$(awk -F'|' '{f=$2; gsub(/^[ \t]+|[ \t]+$/,"",f); sub(/ .*/,"",f); if (f=="01") { print; exit }}' "$FI")
# NOTE: with 01-03 (epic 01) left in-progress, references/data-model.md's rollup rule
# ("MERGED when every non-skip story is done AND delivery: merged") correctly computes
# IN PROGRESS for epic 01, not MERGED — a story still in flight cannot roll up to a
# finished state. This checks the documented-correct value; see tests/README.md and the
# smoke-test report for the fixture/assertion-brief discrepancy this surfaces.
assert_contains "FEATURE_INDEX: epic 01 rollup is IN PROGRESS (01-03 still in-progress)" "$FEAT_01" "IN PROGRESS"

echo
echo "=== ck-view next ==="
NEXT_OUT=$(ck-view next tasks/2026-01-01_demo 2>&1); NEXT_RC=$?
assert_exit "ck-view next: exits 0" 0 "$NEXT_RC"
assert_contains "ck-view next: recommends 02-02 (blocker 02-01 is done)" "$NEXT_OUT" "02-02"
NEXT_RECOMMENDED=$(printf '%s\n' "$NEXT_OUT" | grep -m1 '^\*\*Recommended:\*\*' || true)
assert_not_contains "ck-view next: does not recommend 02-03 (blocker 02-02 not done)" "$NEXT_RECOMMENDED" "02-03"

echo
echo "=== ck-view status / progress / state ==="
STATUS_OUT=$(ck-view status tasks/2026-01-01_demo 2>&1); STATUS_RC=$?
assert_exit "ck-view status: exits 0" 0 "$STATUS_RC"
assert_contains "ck-view status: shows Epic 01 and Epic 02" "$STATUS_OUT" "Epic 01"

PROGRESS_OUT=$(ck-view progress tasks/2026-01-01_demo 2>&1); PROGRESS_RC=$?
assert_exit "ck-view progress: exits 0" 0 "$PROGRESS_RC"
assert_contains "ck-view progress: renders By Epic table" "$PROGRESS_OUT" "By Epic"

STATE_OUT=$(ck-view state 2>&1); STATE_RC=$?
assert_exit "ck-view state: exits 0" 0 "$STATE_RC"
assert_contains "ck-view state: prints project-state probe" "$STATE_OUT" "ck-code: project state"

echo
echo "=== ck-view waves --epic 02 ==="
WAVES_OUT=$(ck-view waves --epic 02 2>&1); WAVES_RC=$?
assert_exit "ck-view waves: exits 0" 0 "$WAVES_RC"
assert_contains "ck-view waves: reports UNSCHEDULABLE" "$WAVES_OUT" "UNSCHEDULABLE"
assert_contains "ck-view waves: 02-04 waiting on 01-03" "$WAVES_OUT" "02-04"
UNSCHED_LINE=$(printf '%s\n' "$WAVES_OUT" | grep '02-04' | grep 'waiting on' || true)
assert_contains "ck-view waves: 02-04's waiting-on names 01-03" "$UNSCHED_LINE" "01-03"
assert_not_contains "ck-view waves: never schedules 02-05 (skip)" "$WAVES_OUT" "02-05"
assert_contains "ck-view waves: 02-06 (bug) is scheduled" "$WAVES_OUT" "02-06"

wave_of() { # wave_of ID <<< "$WAVES_OUT"  — prints the wave number a scheduled id
            # landed in, or nothing if it never appears before UNSCHEDULABLE.
  awk -v id="$1" '
    /^  Wave [0-9]+/ {
      line=$0; sub(/^  Wave /,"",line); split(line,parts," "); w=parts[1]
    }
    /UNSCHEDULABLE/ { exit }
    index($0, id) { print w; exit }
  '
}
W_0202=$(printf '%s\n' "$WAVES_OUT" | wave_of "02-02")
W_0207=$(printf '%s\n' "$WAVES_OUT" | wave_of "02-07")
W_0206=$(printf '%s\n' "$WAVES_OUT" | wave_of "02-06")
if [ -n "$W_0202" ] && [ -n "$W_0207" ]; then
  if [ "$W_0202" != "$W_0207" ]; then
    log_ok "ck-view waves: 02-02 and 02-07 (shared file) land in different waves"
  else
    log_fail "ck-view waves: 02-02 and 02-07 (shared file) land in different waves" "both scheduled in wave $W_0202"
  fi
else
  log_fail "ck-view waves: 02-02 and 02-07 (shared file) land in different waves" "one or both not found scheduled (02-02=$W_0202 02-07=$W_0207)"
fi
assert_true "ck-view waves: 02-06 (bug) scheduled in a real wave" "$([ -n "$W_0206" ]; echo $?)"

echo
echo "=== ck-doctor (clean fixture) ==="
DOCTOR_CLEAN_OUT=$(ck-doctor 2>&1); DOCTOR_CLEAN_RC=$?
assert_exit "ck-doctor: exits 0 on the clean fixture" 0 "$DOCTOR_CLEAN_RC"

DOCTOR_PLAN_CLEAN_OUT=$(ck-doctor tasks/2026-01-01_demo 2>&1); DOCTOR_PLAN_CLEAN_RC=$?
assert_exit "ck-doctor tasks/2026-01-01_demo: exits 0 on the clean fixture" 0 "$DOCTOR_PLAN_CLEAN_RC"

echo
echo "=== ck-doctor worktree include ==="
assert_contains "ck-doctor worktree: OK with no gitignored .env" "$DOCTOR_CLEAN_OUT" "no gitignored .env to copy"
printf '.env\n' > .gitignore; printf 'SECRET=1\n' > .env; printf 'SECRET=\n' > .env.example
WT_WARN_OUT=$(ck-doctor 2>&1); WT_WARN_RC=$?
assert_contains "ck-doctor worktree: WARNs on a gitignored .env with no .worktreeinclude" "$WT_WARN_OUT" "gitignored .env not in .worktreeinclude"
assert_exit "ck-doctor worktree: a WARN still exits 0" 0 "$WT_WARN_RC"
printf '.env\n' > .worktreeinclude
WT_OK_OUT=$(ck-doctor 2>&1)
assert_contains "ck-doctor worktree: OK once .worktreeinclude exists" "$WT_OK_OUT" ".worktreeinclude present"
rm -f .gitignore .env .env.example .worktreeinclude

echo
echo "=== ck-story get/set round-trip ==="
STORY_0203="tasks/2026-01-01_demo/epics/02_payments/stories/03_invoice.md"
GET_BEFORE=$(ck-story get "$STORY_0203" size 2>&1)
assert_contains "ck-story get: 02-03 starts at size S" "$GET_BEFORE" "size: S"
SET_M_OUT=$(ck-story set "$STORY_0203" size=M 2>&1); SET_M_RC=$?
assert_exit "ck-story set: 02-03 size=M exits 0" 0 "$SET_M_RC"
GET_M=$(ck-story get "$STORY_0203" size 2>&1)
assert_contains "ck-story set: 02-03 size is now M" "$GET_M" "size: M"
SET_BACK_OUT=$(ck-story set "$STORY_0203" size=S 2>&1); SET_BACK_RC=$?
assert_exit "ck-story set: 02-03 size=S (revert) exits 0" 0 "$SET_BACK_RC"
GET_BACK=$(ck-story get "$STORY_0203" size 2>&1)
assert_contains "ck-story set: 02-03 size reverted to S" "$GET_BACK" "size: S"

echo
echo "=== ck-bootstrap check ==="
BOOTSTRAP_OUT=$(ck-bootstrap check 2>&1); BOOTSTRAP_RC=$?
assert_exit "ck-bootstrap check: exits 0 (read-only report)" 0 "$BOOTSTRAP_RC"

echo
echo "=== hook scripts (statusline / session-start / subagent-statusline / prompt-router) ==="
STATUSLINE_JSON=$(printf '{"workspace":{"current_dir":"%s"}}' "$FIXTURE")
STATUSLINE_OUT=$(printf '%s' "$STATUSLINE_JSON" | "$PLUGIN_ROOT/scripts/statusline.sh" 2>&1); STATUSLINE_RC=$?
assert_exit "statusline.sh: exits 0" 0 "$STATUSLINE_RC"
assert_contains "statusline.sh: renders the active story's title with \" and | intact" "$STATUSLINE_OUT" 'login" bug |'

SESSION_OUT=$(printf '%s' "$STATUSLINE_JSON" | "$PLUGIN_ROOT/scripts/session-start.sh" 2>&1); SESSION_RC=$?
assert_exit "session-start.sh: exits 0" 0 "$SESSION_RC"
assert_contains "session-start.sh: emits a SessionStart hook JSON line" "$SESSION_OUT" '"hookSpecificOutput"'

if [ "$HAVE_JQ" -eq 1 ]; then
  SUBAGENT_JSON=$(cat <<EOF
{"tasks":[{"id":"t1","name":"story-02-03","type":"agent","status":"running","description":"Implement invoice generation","label":"story-02-03","startTime":"","tokenCount":12345,"cwd":"$FIXTURE"}]}
EOF
)
  SUBAGENT_OUT=$(printf '%s' "$SUBAGENT_JSON" | "$PLUGIN_ROOT/scripts/subagent-statusline.sh" 2>&1); SUBAGENT_RC=$?
  assert_exit "subagent-statusline.sh: exits 0" 0 "$SUBAGENT_RC"
  assert_contains "subagent-statusline.sh: renders a row for the dispatched story" "$SUBAGENT_OUT" "02-03"
else
  log_skip "subagent-statusline.sh: jq not on PATH — script no-ops by design, skipping content assertion"
fi

# prompt-router.sh: routes a free-text prompt, stays silent on a slash command, a short
# reply, and outside an adopted project (references/prompt-routing.md is the payload).
ROUTER="$PLUGIN_ROOT/scripts/prompt-router.sh"
ROUTER_OUT=$(printf '{"cwd":"%s","prompt":"fix the \\"login\\" bug, it crashes on submit"}' "$FIXTURE" | "$ROUTER" 2>&1); ROUTER_RC=$?
assert_exit "prompt-router.sh: exits 0" 0 "$ROUTER_RC"
assert_contains "prompt-router.sh: emits a UserPromptSubmit hook JSON line" "$ROUTER_OUT" '"hookEventName":"UserPromptSubmit"'
assert_contains "prompt-router.sh: injects the routing table" "$ROUTER_OUT" 'ck-code router'
if [ "$HAVE_JQ" -eq 1 ]; then
  assert_true "prompt-router.sh: output is valid JSON" "$(printf '%s' "$ROUTER_OUT" | jq -e . >/dev/null 2>&1; echo $?)"
fi
ROUTER_SLASH=$(printf '{"prompt":"/ck-code:fix"}' | "$ROUTER" 2>&1)
assert_eq "prompt-router.sh: silent on a slash command" "" "$ROUTER_SLASH"
ROUTER_SHORT=$(printf '{"prompt":"yes"}' | "$ROUTER" 2>&1)
assert_eq "prompt-router.sh: silent on a short reply" "" "$ROUTER_SHORT"
ROUTER_ELSEWHERE=$(cd "$(mktemp -d)" && printf '{"prompt":"fix the login bug please"}' | "$ROUTER" 2>&1)
assert_eq "prompt-router.sh: silent outside an adopted project" "" "$ROUTER_ELSEWHERE"

echo
echo "=== breaking a second plan (tasks/2026-02-02_other, story missing id) ==="
add_broken_plan

DOCTOR_ALL_OUT=$(ck-doctor 2>&1); DOCTOR_ALL_RC=$?
assert_exit "ck-doctor (no arg): reports the broken plan (exit 1)" 1 "$DOCTOR_ALL_RC"
assert_contains "ck-doctor (no arg): mentions the broken plan" "$DOCTOR_ALL_OUT" "2026-02-02_other"

DOCTOR_SCOPED_OUT=$(ck-doctor tasks/2026-01-01_demo 2>&1); DOCTOR_SCOPED_RC=$?
# EXPECTED-FAILING pending fix: "ck-doctor plan scoping" — ONLY_PLAN is parsed
# (scripts/ck-doctor.sh line ~18-24) but never threaded into check_stories/
# check_indexes/check_ids/check_deps, so a scoped run still walks every plan.
assert_exit "ck-doctor tasks/2026-01-01_demo: still exits 0 (scoped to the clean plan)" 0 "$DOCTOR_SCOPED_RC"
assert_not_contains "ck-doctor tasks/2026-01-01_demo: does not mention the other plan" "$DOCTOR_SCOPED_OUT" "2026-02-02_other"

echo
echo "=== ck-story WARN passthrough on the broken plan ==="
BROKEN_STORY="tasks/2026-02-02_other/epics/03_other/stories/01_broken.md"
STORY_WARN_OUT=$(ck-story set "$BROKEN_STORY" size=M 2>&1); STORY_WARN_RC=$?
# EXPECTED-FAILING pending fix: "ck-story WARN passthrough" — scripts/ck-story.sh's
# `run_tool ck-index "$p" >/dev/null 2>&1` swallows ck-index's stderr WARN entirely,
# so a skipped story is reported as a clean "regenerated" with no WARN relayed
# (references/stories-index.md: "every skill that runs ck-index must relay any
# ck-index: WARN line it emits").
assert_contains "ck-story set: relays ck-index's WARN for the broken story" "$STORY_WARN_OUT" "ck-index: WARN"

echo
echo "=== shellcheck ==="
if command -v shellcheck >/dev/null 2>&1; then
  SC_OUT=$(cd "$PLUGIN_ROOT" && shellcheck -x -S warning scripts/*.sh bin/* 2>&1); SC_RC=$?
  if [ "$SC_RC" -eq 0 ]; then
    log_ok "shellcheck -S warning: scripts/*.sh bin/* clean"
  else
    log_fail "shellcheck -S warning: scripts/*.sh bin/* clean" "$SC_OUT"
  fi
else
  log_skip "shellcheck not on PATH — skipping lint pass"
fi

echo
echo "smoke: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
