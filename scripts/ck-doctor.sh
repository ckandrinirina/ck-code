#!/usr/bin/env bash
# ck-doctor.sh — read-only health report for a ck-code project.
#
# Answers "what is broken in THIS project?" — the counterpart to the marketplace's
# plugin-doctor.sh, which answers "what is broken in the plugin?". Writes nothing:
# every check is a read, and the index-drift check works on a throwaway copy.
#
# Usage:
#   ck-doctor.sh                # check every plan under tasks/
#   ck-doctor.sh tasks/<slug>   # check one plan (other checks still run)
#   ck-doctor.sh --quiet        # print only WARN/ERROR lines
#
# Exit status: 0 clean or warnings only, 1 if any ERROR was found.

set -uo pipefail

QUIET=0
ONLY_PLAN=""
for a in "$@"; do
  case "$a" in
    --quiet|-q) QUIET=1 ;;
    -*) echo "ck-doctor: unknown flag $a" >&2; exit 2 ;;
    *) ONLY_PLAN="${a%/}" ;;
  esac
done

# Run from the repo root so every relative path below resolves the same way.
if [ ! -d tasks ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$ROOT" ] && [ -d "$ROOT/tasks" ]; then cd "$ROOT"; fi
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ERRORS=0
WARNS=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

row() {
  local label="$1" detail="$2" status="$3" line n
  case "$status" in
    ERROR) ERRORS=$((ERRORS+1)) ;;
    WARN)  WARNS=$((WARNS+1)) ;;
    OK)    [ "$QUIET" -eq 1 ] && return 0 ;;
  esac
  line=$(printf '  %-14s %s ' "$label" "$detail")
  printf '%s' "$line"
  n=$(( 64 - ${#line} )); [ "$n" -lt 3 ] && n=3
  printf '%*s' "$n" '' | tr ' ' '.'
  printf ' %s\n' "$status"
}
note() { printf '                   → %s\n' "$1"; }

plans() {
  find tasks -maxdepth 2 \( -name PROJECT_OVERVIEW.md -o -name FEATURE_OVERVIEW.md \) 2>/dev/null \
    | sed 's|/[^/]*$||' | sort -u
}

# ---- 1. layout stamp ---------------------------------------------------------
check_layout() {
  local want="v6" got=""
  [ -f tasks/VERSION.md ] && got=$(awk -F: '/^layout:/{gsub(/[ \t]/,"",$2);print $2;exit}' tasks/VERSION.md)
  if [ -z "$got" ]; then
    row layout "tasks/VERSION.md missing" ERROR
    note "run /ck-code:migrate — every change-producing skill blocks until it is stamped"
  elif [ "$got" != "$want" ]; then
    row layout "stamped $got, expected $want" ERROR
    note "run /ck-code:migrate to upgrade this project to $want"
  else
    row layout "$got" OK
  fi

  if ls .claude/skills/experts/*/SKILL.md .claude/skills/guides/*/SKILL.md >/dev/null 2>&1; then
    row "team layout" "nested experts//guides/ folders" ERROR
    note "nested skills are never registered by Claude Code — /ck-code:migrate flattens them"
  fi
}

# ---- 2. story frontmatter ----------------------------------------------------
check_stories() {
  local out total
  cat > "$TMP/stories.py" <<'PY'
import glob, re, sys
STATUS = {'todo','in-progress','done','skip','bug'}
SIZE = {'S','M'}
bad, total = [], 0
for f in sorted(glob.glob('tasks/*/epics/*/stories/*.md')):
    total += 1
    t = open(f, encoding='utf-8', errors='replace').read()
    m = re.match(r'---\n(.*?)\n---\n', t, re.S)
    if not m:
        bad.append(f"{f}: no frontmatter fence — invisible in every index"); continue
    fm = {}
    for line in m.group(1).split('\n'):
        km = re.match(r'^([A-Za-z][\w-]*):\s*(.*)$', line)
        if km:
            fm[km.group(1)] = km.group(2).strip().strip('"\'')
    for k in ('id','title','epic','status','size'):
        if not fm.get(k):
            bad.append(f"{f}: missing `{k}` — story is skipped by the generator")
    st, sz = fm.get('status'), fm.get('size')
    if st and st not in STATUS:
        bad.append(f"{f}: status `{st}` is not one of {'|'.join(sorted(STATUS))}")
    if sz and sz not in SIZE:
        bad.append(f"{f}: size `{sz}` is not S or M")
    if fm.get('status') == 'bug' and '## Bug Report' not in t:
        bad.append(f"{f}: status `bug` with no `## Bug Report` — build will stop; re-run /ck-code:fix")
    # Duplicate ids are reported by check_ids, not here: the stories are well-formed,
    # it is the numbering that collided, and that has its own fix (/ck-code:migrate).
print(total)
print('\n'.join(bad))
PY
  out=$(python3 "$TMP/stories.py")
  total=$(printf '%s' "$out" | head -1)
  local rest; rest=$(printf '%s' "$out" | tail -n +2 | sed '/^$/d')
  if [ "${total:-0}" -eq 0 ]; then row stories "no story files found" WARN; return; fi
  if [ -n "$rest" ]; then
    row stories "$(printf '%s\n' "$rest" | awk 'END{print NR}') of $total malformed" ERROR
    printf '%s\n' "$rest" | sed 's/^/                   ✗ /'
  else
    row stories "$total parsed" OK
  fi
}

# ---- 3. index drift ----------------------------------------------------------
# Regenerate into a throwaway copy and diff. Exact, and it never touches the project.
check_indexes() {
  local missing="" drifted="" n=0
  cp -R tasks "$TMP/tasks" 2>/dev/null || { row indexes "no tasks/ to check" WARN; return; }
  mkdir -p "$TMP/docs"
  [ -d docs/architecture ] && cp -R docs/architecture "$TMP/docs/architecture" 2>/dev/null
  ( cd "$TMP" && "$SCRIPT_DIR/ck-index.sh" ) >/dev/null 2>&1

  while IFS= read -r p; do
    [ -n "$p" ] || continue
    n=$((n+1))
    if [ ! -f "$p/STORIES_INDEX.md" ]; then
      missing="$missing$p/STORIES_INDEX.md"$'\n'
    elif ! grep -q 'GENERATED by ck-code' "$p/STORIES_INDEX.md" 2>/dev/null; then
      drifted="$drifted$p/STORIES_INDEX.md (hand-written — no GENERATED header)"$'\n'
    elif ! diff -q "$p/STORIES_INDEX.md" "$TMP/$p/STORIES_INDEX.md" >/dev/null 2>&1; then
      drifted="$drifted$p/STORIES_INDEX.md"$'\n'
    fi
  done < <(plans)

  if [ ! -f tasks/FEATURE_INDEX.md ]; then
    missing="${missing}tasks/FEATURE_INDEX.md"$'\n'
  elif ! diff -q tasks/FEATURE_INDEX.md "$TMP/tasks/FEATURE_INDEX.md" >/dev/null 2>&1; then
    drifted="${drifted}tasks/FEATURE_INDEX.md"$'\n'
  fi

  if [ -n "$missing$drifted" ]; then
    row indexes "stale or missing" ERROR
    [ -n "$missing" ] && printf '%s' "$missing" | sed '/^$/d;s/^/                   ✗ missing /'
    [ -n "$drifted" ] && printf '%s' "$drifted" | sed '/^$/d;s/^/                   ✗ stale   /'
    note "run \"\${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh\" — never hand-edit a generated view"
  else
    row indexes "$n plan(s) in sync with frontmatter" OK
  fi
}

# ---- 3b. id uniqueness -------------------------------------------------------
# v6 requires epic numbers — and therefore story ids — to be unique across EVERY plan.
# This must run BEFORE check_deps: that check keys its graph on the bare `EE-SS` id, so a
# colliding project would otherwise surface as phantom missing-blocker or cycle errors
# instead of the real cause.
check_ids() {
  local dupes orphans sdupes
  dupes=$(find tasks -mindepth 3 -maxdepth 3 -type d -path 'tasks/*/epics/*' 2>/dev/null \
          | sed 's|.*/epics/||;s|_.*||' | grep -v '^$' | sort | uniq -d)

  if [ -n "$dupes" ]; then
    row "epic ids" "$(printf '%s\n' "$dupes" | awk 'END{print NR}') number(s) used by more than one plan" ERROR
    printf '%s\n' "$dupes" | while IFS= read -r n; do
      [ -n "$n" ] || continue
      printf '                   ✗ epic %s: %s\n' "$n" \
        "$(find tasks -mindepth 3 -maxdepth 3 -type d -path "tasks/*/epics/${n}_*" 2>/dev/null \
           | sed 's|^tasks/||;s|/epics/.*||' | sort -u | tr '\n' ' ')"
    done
    note "epic numbers must be unique project-wide — /ck-code:migrate renumbers (Phase R)"
  else
    row "epic ids" "unique across all plans" OK
  fi

  # Story ids inherit epic uniqueness, but check directly: a collision here is what
  # actually breaks build EE-SS, blocked_by, and the story/<EE>-<SS>-* branch name.
  cat > "$TMP/ids.py" <<'PY'
import glob, re
ids = {}
for f in sorted(glob.glob('tasks/*/epics/*/stories/*.md')):
    m = re.match(r'---\n(.*?)\n---\n', open(f, encoding='utf-8', errors='replace').read(), re.S)
    if not m: continue
    fm = dict(re.findall(r'^([A-Za-z][\w-]*):\s*(.*)$', m.group(1), re.M))
    sid = fm.get('id','').strip().strip('"\'')
    if sid: ids.setdefault(sid, []).append(f)
for i, fs in sorted(ids.items()):
    if len(fs) > 1:
        print(f"story id `{i}` used by {len(fs)} stories: {', '.join(fs)}")
PY
  sdupes=$(python3 "$TMP/ids.py")
  if [ -n "$sdupes" ]; then
    row "story ids" "$(printf '%s\n' "$sdupes" | awk 'END{print NR}') duplicated across plans" ERROR
    printf '%s\n' "$sdupes" | sed 's/^/                   ✗ /'
    note "an id must name one story anywhere — /ck-code:migrate renumbers (Phase R)"
  else
    row "story ids" "unique across all plans" OK
  fi

  # A directory holding epics but no overview file is invisible to ck-index's plans()
  # and to migrate Phase R, yet still feeds check_deps below. Never renumber around it.
  orphans=$(find tasks -mindepth 2 -maxdepth 2 -type d -name epics 2>/dev/null \
            | sed 's|/epics$||' | while IFS= read -r d; do
                [ -f "$d/PROJECT_OVERVIEW.md" ] || [ -f "$d/FEATURE_OVERVIEW.md" ] || printf '%s\n' "$d"
              done)
  if [ -n "$orphans" ]; then
    row "plan overview" "$(printf '%s\n' "$orphans" | awk 'END{print NR}') epics dir(s) with no overview" ERROR
    printf '%s\n' "$orphans" | sed 's/^/                   ✗ /'
    note "add PROJECT_OVERVIEW.md or FEATURE_OVERVIEW.md — this plan is invisible to ck-index and migrate"
  fi
}

# ---- 4. dependencies ---------------------------------------------------------
# Safe to key on the bare `EE-SS` id because check_ids above proves it is globally
# unique; on a colliding project that check has already reported the real fault.
check_deps() {
  local out
  cat > "$TMP/deps.py" <<'PY'
import glob, re
ids, deps, status = set(), {}, {}
for f in sorted(glob.glob('tasks/*/epics/*/stories/*.md')):
    m = re.match(r'---\n(.*?)\n---\n', open(f, encoding='utf-8', errors='replace').read(), re.S)
    if not m: continue
    fm = dict(re.findall(r'^([A-Za-z][\w-]*):\s*(.*)$', m.group(1), re.M))
    sid = fm.get('id','').strip().strip('"\'')
    if not sid: continue
    ids.add(sid); status[sid] = fm.get('status','').strip().strip('"\'')
    raw = fm.get('blocked_by','').strip()
    deps[sid] = [d.strip().strip('"\'') for d in raw.strip('[]').split(',') if d.strip()]
bad = []
for sid, ds in deps.items():
    for d in ds:
        if d not in ids:
            bad.append(f"{sid}: blocked_by `{d}` — no story has that id")
        elif d == sid:
            bad.append(f"{sid}: blocked_by itself")
# cycle detection
WHITE, GREY, BLACK = 0, 1, 2
mark = {i: WHITE for i in ids}
def walk(n, path):
    mark[n] = GREY
    for m2 in deps.get(n, []):
        if m2 not in mark: continue
        if mark[m2] == GREY:
            bad.append("dependency cycle: " + " -> ".join(path + [m2])); return
        if mark[m2] == WHITE: walk(m2, path + [m2])
    mark[n] = BLACK
for i in sorted(ids):
    if mark[i] == WHITE: walk(i, [i])
for sid, ds in deps.items():
    if status.get(sid) == 'done':
        open_ = [d for d in ds if d in status and status[d] not in ('done','skip')]
        if open_:
            bad.append(f"{sid}: done, but blocked_by {', '.join(open_)} is not")
print('\n'.join(dict.fromkeys(bad)))
PY
  out=$(python3 "$TMP/deps.py")
  if [ -n "$out" ]; then
    row dependencies "$(printf '%s\n' "$out" | awk 'END{print NR}') problem(s)" ERROR
    printf '%s\n' "$out" | sed 's/^/                   ✗ /'
  else
    row dependencies "all blocked_by ids resolve" OK
  fi
}

# ---- 5. feature docs ---------------------------------------------------------
check_docs() {
  local missing="" n=0
  [ -d docs/architecture ] || { row "feature docs" "no docs/architecture/" WARN
    note "run /ck-code:design to author the architecture docs"; return; }
  while IFS= read -r epicmd; do
    [ -n "$epicmd" ] || continue
    n=$((n+1))
    local slug; slug=$(awk 'NR==1&&$0!="---"{exit} NR==1{next} $0=="---"{exit} /^slug:/{sub(/^slug:[ \t]*/,"");gsub(/["'"'"']/,"");print;exit}' "$epicmd")
    [ -n "$slug" ] || slug=$(basename "$(dirname "$epicmd")" | sed 's/^[0-9]*_//')
    [ -f "docs/architecture/features/$slug/index.md" ] \
      || missing="$missing$slug (epic $(dirname "$epicmd"))"$'\n'
  done < <(find tasks -path '*/epics/*/EPIC.md' 2>/dev/null | sort)
  if [ -n "$missing" ]; then
    row "feature docs" "$(printf '%s' "$missing" | grep -c .) of $n epics unrouted" WARN
    printf '%s' "$missing" | sed '/^$/d;s/^/                   ✗ no feature doc for slug /'
    note "run /ck-code:design sync to scaffold them"
  else
    row "feature docs" "$n epics routed" OK
  fi
}

# ---- 6. team skills ----------------------------------------------------------
check_team() {
  local n bad=""
  n=$(ls -d .claude/skills/expert-*/ .claude/skills/guide-*/ 2>/dev/null | wc -l | tr -d ' ')
  if [ "${n:-0}" -eq 0 ]; then
    row "team skills" "none generated" WARN
    note "run /ck-code:team — build and fix rely on the expert and guide skills"
    return
  fi
  for f in .claude/skills/expert-*/SKILL.md .claude/skills/guide-*/SKILL.md; do
    [ -f "$f" ] || continue
    local dir fmname
    dir=$(basename "$(dirname "$f")")
    fmname=$(awk 'NR==1&&$0!="---"{exit} NR==1{next} $0=="---"{exit} /^name:/{sub(/^name:[ \t]*/,"");gsub(/["'"'"']/,"");print;exit}' "$f")
    [ "$dir" = "$fmname" ] || bad="$bad$f: folder '$dir' != name '$fmname'"$'\n'
    grep -q '^description:.*:[[:space:]]' "$f" 2>/dev/null \
      && bad="$bad$f: description contains \": \" — frontmatter will not parse"$'\n'
  done
  if [ -n "$bad" ]; then
    row "team skills" "$n present, some invalid" ERROR
    printf '%s' "$bad" | sed '/^$/d;s/^/                   ✗ /'
    note "run /ck-code:team --regenerate, or fix the frontmatter by hand"
  else
    row "team skills" "$n present and valid" OK
  fi
}

# ---- 7. orphan branches ------------------------------------------------------
check_branches() {
  git rev-parse --git-dir >/dev/null 2>&1 || { row branches "not a git repo" WARN; return; }
  local orphans="" n=0
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    n=$((n+1))
    local num; num=$(printf '%s' "$b" | sed -n 's|^epic/\([0-9][0-9]*\)-.*|\1|p')
    [ -n "$num" ] || continue
    find tasks -path "*/epics/${num}_*/EPIC.md" 2>/dev/null | grep -q . \
      || orphans="$orphans$b"$'\n'
  done < <(git branch --list 'epic/*' --format='%(refname:short)' 2>/dev/null)
  if [ -n "$orphans" ]; then
    row branches "$(printf '%s' "$orphans" | grep -c .) orphan of $n" WARN
    printf '%s' "$orphans" | sed '/^$/d;s/^/                   ✗ no epic folder for /'
  else
    row branches "$n epic branch(es)" OK
  fi
}

# ---- 8. design-system cache --------------------------------------------------
# Local integrity only — never a network call. The design system is optional, so an
# absent directory prints no row at all: most projects have none and must see nothing.
check_design_system() {
  local ds=docs/architecture/design-system
  [ -d "$ds" ] || return 0
  if [ ! -f "$ds/manifest.json" ]; then
    row "design system" "cards/ present, manifest.json missing" WARN
    note "run /ck-code:design ds to rebuild the cache manifest"
    return 0
  fi
  if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$ds/manifest.json" 2>/dev/null; then
    row "design system" "manifest.json is not valid JSON" WARN
    note "run /ck-code:design ds to rebuild the cache manifest"
    return 0
  fi
  local bad="" n=0
  while IFS=$'\t' read -r path want; do
    [ -n "$path" ] || continue
    n=$((n+1))
    local f="$ds/cards/$path" got
    if [ ! -f "$f" ]; then
      bad="$bad$path: recorded as cached but the file is missing"$'\n'
      continue
    fi
    got=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
    [ "$got" = "$want" ] || bad="$bad$path: digest differs from manifest"$'\n'
  done < <(python3 -c '
import json,sys
for c in json.load(open(sys.argv[1])).get("cards", []):
    if c.get("cached") and c.get("sha256"):
        print("%s\t%s" % (c["path"], c["sha256"]))
' "$ds/manifest.json" 2>/dev/null)
  if [ -n "$bad" ]; then
    row "design system" "$(printf '%s' "$bad" | grep -c .) of $n cached card(s) drifted" WARN
    printf '%s' "$bad" | sed '/^$/d;s/^/                   ✗ /'
    note "run /ck-code:design ds to refresh the cache"
  else
    row "design system" "$n cached card(s) verified" OK
  fi
}

# ---- run ---------------------------------------------------------------------
echo
if [ -n "$ONLY_PLAN" ] && [ ! -d "$ONLY_PLAN" ]; then
  echo "ck-doctor: no such plan directory: $ONLY_PLAN" >&2; exit 2
fi
printf '%s\n' "ck-code project health — $(basename "$PWD")"
check_layout
check_stories
check_indexes
check_ids
check_deps
check_docs
check_team
check_branches
check_design_system
echo
if [ "$ERRORS" -gt 0 ]; then
  echo "$WARNS warning(s), $ERRORS error(s)."
  exit 1
fi
echo "$WARNS warning(s), 0 errors."
exit 0
