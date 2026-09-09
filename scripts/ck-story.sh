#!/usr/bin/env bash
# ck-story.sh — the one way to mutate story state, and regenerate in the same breath.
#
# Story frontmatter is the single writable source of truth; every index and every board
# card is a generated view of it (references/data-model.md). That makes ONE invariant
# load-bearing across `build`, `fix`, `ship`, `sync` and `config`:
#
#   change frontmatter  →  run ck-index  →  run ck-project sync,  in the same phase.
#
# Left to prose, that invariant is three steps a skill has to remember every time, and
# `ck-doctor`'s index-drift and board checks exist because it was sometimes forgotten.
# Here it is one call that cannot be half-done.
#
# Usage:
#   ck-story.sh set <story.md> [<story.md>…] key=value [key=value…] [--no-sync|--no-board]
#   ck-story.sh get <story.md> [key…]
#   ck-story.sh path <EE-SS>
#
# Paths and key=value pairs may be interleaved in any order, so a whole wave flips in one
# call: `ck-story set status=in-progress a.md b.md c.md`.
#
# Mutable keys are ONLY the state fields skills flip — status, prior_status, delivery,
# pr, issue, size. Structural fields (id, epic, title, blocked_by, files) belong to
# `plan`/`migrate` and are refused here on purpose: a typo in `id` or `blocked_by` is
# not a state change, it is a corrupted plan.
#
# --no-sync   edit frontmatter only (build PARALLEL MODE: a worktree agent touches its
#             own story and never regenerates — the orchestrator does that after merge)
# --no-board  regenerate the indexes but skip `ck-project sync`

set -uo pipefail

if [ ! -d tasks ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$ROOT" ] && [ -d "$ROOT/tasks" ] && cd "$ROOT"
fi

usage() { sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'; }

MUTABLE="status prior_status delivery pr issue size"

die() { echo "ck-story: ERROR — $*" >&2; exit 1; }

here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
run_tool() { # run_tool ck-index ARGS…
  local name="$1"; shift
  if [ -x "$here/$name.sh" ]; then "$here/$name.sh" "$@"
  elif command -v "$name" >/dev/null 2>&1; then "$name" "$@"
  else return 127; fi
}

# validate KEY VALUE — enums come straight from references/data-model.md.
validate() {
  local k="$1" v="$2"
  case " $MUTABLE " in *" $k "*) ;; *) die "\`$k\` is not a mutable field. Allowed: $MUTABLE" ;; esac
  case "$k" in
    status)
      case "$v" in todo|in-progress|done|skip|bug) ;; *) die "status must be todo|in-progress|done|skip|bug (got: $v)" ;; esac ;;
    prior_status)
      case "$v" in ""|todo|in-progress|done|skip|bug) ;; *) die "prior_status must be empty or todo|in-progress|done|skip|bug (got: $v)" ;; esac ;;
    delivery)
      case "$v" in ""|pr|merged|direct) ;; *) die "delivery must be empty|pr|merged|direct (got: $v)" ;; esac ;;
    size)
      case "$v" in S|M) ;; *) die "size must be S or M (got: $v)" ;; esac ;;
    pr|issue)
      case "$v" in ""|*[!0-9]*) [ -z "$v" ] || die "$k must be a number or empty (got: $v)" ;; esac ;;
  esac
}

# plan_root STORYFILE — tasks/<slug> for a story at tasks/<slug>/epics/NN_*/stories/*.md
plan_root() {
  local d; d="$(dirname "$1")"          # …/stories
  d="$(dirname "$d")"                    # …/epics/NN_slug
  d="$(dirname "$d")"                    # …/epics
  d="$(dirname "$d")"                    # tasks/<slug>
  printf '%s' "$d"
}

# fm_get FILE KEY — one frontmatter scalar, quotes stripped.
fm_get() {
  awk -v key="$2" '
    function unquote(s) { if (s ~ /^".*"$/ || s ~ /^\047.*\047$/) s=substr(s,2,length(s)-2); return s }
    { sub(/\r$/,"") }
    FNR==1 && $0!="---" { exit } FNR==1 { next }
    $0=="---" { exit }
    { i=index($0,":"); if(i>0){ k=substr($0,1,i-1); v=substr($0,i+1)
        gsub(/^[ \t]+|[ \t]+$/,"",k); gsub(/^[ \t]+|[ \t]+$/,"",v)
        if(k==key){ print unquote(v); exit } } }
  ' "$1"
}

CMD="${1:-}"; [ -n "$CMD" ] && shift
case "$CMD" in
  -h|--help|"") usage; exit 0 ;;

  path)
    ID="${1:-}"
    case "$ID" in ''|*[!0-9-]*) die "path needs a story id (EE-SS), got: ${ID:-<empty>}" ;; esac
    EE="${ID%%-*}"
    match=""
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      [ "$(fm_get "$f" id)" = "$ID" ] && match="$match$f"$'\n'
    done < <(find tasks -type f -path "*/epics/${EE}_*/stories/*.md" 2>/dev/null | sort)
    n=$(printf '%s' "$match" | grep -c . || true)
    [ "$n" -eq 0 ] && die "no story with id $ID under tasks/"
    if [ "$n" -gt 1 ]; then
      printf '%s' "$match" >&2
      die "id $ID resolves to $n files (colliding epic numbers) — run /ck-code:migrate; never pick one"
    fi
    printf '%s' "$match"
    exit 0
    ;;

  get)
    F="${1:-}"; [ -f "$F" ] || die "no such story file: ${F:-<empty>}"
    shift
    if [ "$#" -eq 0 ]; then
      awk '{ sub(/\r$/,"") } FNR==1 && $0!="---" { exit } FNR==1 { next } $0=="---" { exit } { print }' "$F"
    else
      for k in "$@"; do printf '%s: %s\n' "$k" "$(fm_get "$F" "$k")"; done
    fi
    exit 0
    ;;

  set) ;;
  *) die "unknown command: $CMD (set|get|path)" ;;
esac

# ---- set ---------------------------------------------------------------------
FILES=""
KEYS=""
VALS=""
NO_SYNC=0
NO_BOARD=0
for arg in "$@"; do
  case "$arg" in
    --no-sync)  NO_SYNC=1 ;;
    --no-board) NO_BOARD=1 ;;
    *=*)
      k="${arg%%=*}"; v="${arg#*=}"
      validate "$k" "$v"
      KEYS="$KEYS$k"$'\n'; VALS="$VALS$v"$'\n' ;;
    *)
      [ -f "$arg" ] || die "no such story file: $arg"
      FILES="$FILES$arg"$'\n' ;;
  esac
done
[ -n "$FILES" ] || die "no story file given (usage: ck-story set <story.md> key=value)"
[ -n "$KEYS" ]  || die "no key=value given (allowed: $MUTABLE)"

PLANS=""
SUMMARY=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  sid="$(fm_get "$f" id)"; [ -n "$sid" ] || sid="$(basename "$f")"
  changes=""
  i=0
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    i=$((i+1))
    v="$(printf '%s' "$VALS" | sed -n "${i}p")"
    old="$(fm_get "$f" "$k")"
    [ "$old" = "$v" ] && continue
    tmp="$f.ckstory.$$"
    # Rewrite in place, inside the FIRST frontmatter fence only. A key that is absent is
    # appended just before the closing fence, so a plan scaffolded without `prior_status`
    # still accepts one without hand-editing.
    awk -v key="$k" -v val="$v" '
      BEGIN { seen=0; done=0 }
      NR==1 { print; if ($0!="---") { passthru=1 } ; next }
      passthru { print; next }
      !done && $0=="---" { if (!seen) print key ": " val ; done=1; print; next }
      !done { i=index($0,":")
              if (i>0) { kk=substr($0,1,i-1); gsub(/^[ \t]+|[ \t]+$/,"",kk)
                         if (kk==key) { print key ": " val; seen=1; next } }
              print; next }
      { print }
    ' "$f" > "$tmp" && cat "$tmp" > "$f"
    rm -f "$tmp"
    changes="$changes${changes:+, }$k ${old:-∅} → ${v:-∅}"
  done <<<"$KEYS"
  if [ -n "$changes" ]; then
    SUMMARY="$SUMMARY  $sid: $changes"$'\n'
  else
    SUMMARY="$SUMMARY  $sid: already current — no change"$'\n'
  fi
  p="$(plan_root "$f")"
  case "$PLANS" in *"$p"$'\n'*) ;; *) PLANS="$PLANS$p"$'\n' ;; esac
done <<<"$FILES"

printf 'ck-story: updated\n%s' "$SUMMARY"

if [ "$NO_SYNC" -eq 1 ]; then
  echo "ck-story: --no-sync — indexes and board NOT regenerated (orchestrator regenerates after merge)."
  exit 0
fi

while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ -d "$p" ] || continue
  if run_tool ck-index "$p" >/dev/null 2>&1; then
    echo "ck-story: regenerated $p/STORIES_INDEX.md + tasks/FEATURE_INDEX.md"
  else
    echo "ck-story: WARN — could not run ck-index for $p; the generated views are now stale." >&2
  fi
  [ "$NO_BOARD" -eq 1 ] && continue
  # The board is one more generated view: a no-op without tasks/SETTINGS.md or with
  # github_issues off, and NEVER fatal — a board that is down must not block a build.
  out=$(run_tool ck-project sync "$p" 2>&1)
  rc=$?
  if [ "$rc" -eq 127 ]; then
    echo "ck-story: WARN — ck-project not found; board not synced." >&2
  elif printf '%s' "$out" | grep -q 'no tasks/SETTINGS.md\|github_issues'; then
    # Not a failure: a project that never opted into issue tracking has no board to sync.
    echo "ck-story: no GitHub board configured — board sync skipped."
  elif [ "$rc" -ne 0 ]; then
    echo "ck-story: WARN — ck-project sync reported a failure (board may lag):" >&2
    printf '%s\n' "$out" | tail -3 >&2
  else
    printf '%s\n' "$out" | tail -1
  fi
done <<<"$PLANS"
