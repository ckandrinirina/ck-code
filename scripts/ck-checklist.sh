#!/usr/bin/env bash
# ck-checklist.sh — a plan's manual-verification checklist: its items, their state, and the
# test session that walks them. `verify` writes it only through this script.
#
# Layout (skills/verify/references/checklist-format.md):
#   tasks/<plan>/CHECKLIST.md               index: frontmatter (plan, feature, format, session_*)
#                                           + Before you test + Not yet testable
#   tasks/<plan>/checklist/NN_<epic-slug>/C-NN_<slug>.md   an item of one epic: state + steps
#   tasks/<plan>/checklist/journeys/C-NN_<slug>.md        a journey, or an item spanning epics
#
# Usage:
#   ck-checklist.sh init    <plan> [--feature <slug>] [--title "<plan title>"]
#   ck-checklist.sh new     <plan> --title T --stories "NN-SS …" --source S
#                                  [--criterion C] [--checks X] [--expected E] [--after C-NN] [--recorded]
#   ck-checklist.sh list    <plan> [--open]
#   ck-checklist.sh summary <plan>
#   ck-checklist.sh count   <plan>
#   ck-checklist.sh start   <plan> [--epic NN] [--all]
#   ck-checklist.sh next    <plan> [-n N]
#   ck-checklist.sh record  <plan> C-NN pass|fail|blocked|skip ["tester's words"]
#   ck-checklist.sh set     <plan> C-NN key=value…
#   ck-checklist.sh path    <plan> C-NN
#   ck-checklist.sh close   <plan>
#   ck-checklist.sh import  <plan>
#
# new      Allocate the next free C-NN (never reused) and write the item as an outline.
#          --recorded: the human check is already ticked, so it enters as pass.
# list     Items grouped by epic, journeys last: id, status, stories, title · source. --open keeps todo|fail|blocked.
# summary  Counts overall and per epic, the Retest and Waiting-on-fix lists, the open session.
# count    The number of open items (0 when the plan has no checklist). `ship` reads it.
# start    Open a new session (number, scope, --all). Items answered in it are not
#          offered again by `next`, so a --all retest never loops.
# next     The next N items of the open session (default 2), epic by epic, resumable from any chat.
# record   Write a tester's answer: status, dated Result, the previous Result as `was`,
#          and on a pass the tick of the story's human-check line. Prints the files to stage.
# set      Mutable keys: detail (outline|full), after (C-NN), source, title, criterion, fix (NN-SS).
# close    End the session. `next` says when nothing is left.
# import   Convert a format-1 CHECKLIST.md (items as ### headings in one file) in place, or
#          move 7.4.0's flat checklist/C-NN_*.md items into their epic folders.
#
# CK_TODAY overrides today's date (tests).

set -uo pipefail

CK_HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck source=scripts/lib/ck-common.sh
. "$CK_HERE/lib/ck-common.sh"

ck_root || true
die() { echo "ck-checklist: ERROR — $*" >&2; exit 1; }
TODAY="${CK_TODAY:-$(date +%F)}"

CMD="${1:-}"
case "$CMD" in
  init|new|list|summary|count|start|next|record|set|path|close|import) ;;
  -h|--help|"") sed -n '3,39p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) die "unknown command: $CMD (init|new|list|summary|count|start|next|record|set|path|close|import)" ;;
esac
PLAN="${2:-}"; PLAN="${PLAN%/}"
[ -n "$PLAN" ] && [ -d "$PLAN" ] || die "no such plan directory: ${PLAN:-<empty>}"
shift 2
IDX="$PLAN/CHECKLIST.md"
DIR="$PLAN/checklist"

# ---- helpers -------------------------------------------------------------------

# q VALUE — a double-quoted YAML scalar, newlines folded to spaces.
q() { printf '"%s"' "$(printf '%s' "$1" | tr '\r\n' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g')"; }
# fm FILE KEY — one frontmatter value, with q's escapes undone.
fm() { ck_fm "$1" "$2" | sed 's/\\"/"/g; s/\\\\/\\/g'; }
# fset FILE KEY VALUE — ck_fm_set, with backslashes doubled because awk -v unescapes them.
fset() { ck_fm_set "$1" "$2" "$(printf '%s' "$3" | sed 's/\\/\\\\/g')"; }

has_flat() { [ -n "$(find "$DIR" -maxdepth 1 -type f -name 'C-*.md' 2>/dev/null | head -1)" ]; }
is_v1() { [ -f "$IDX" ] && [ "$(ck_fm "$IDX" format)" != 2 ] && grep -qE '^### C-[0-9]+ ' "$IDX"; }
need_index() {
  is_v1 && die "$IDX is format 1 — run \`ck-checklist import $PLAN\` first"
  has_flat && die "$DIR holds ungrouped items — run \`ck-checklist import $PLAN\` first"
  [ -f "$IDX" ] || die "$PLAN has no CHECKLIST.md — run \`ck-checklist init $PLAN\` first"
}
norm_id() {
  local n="${1#C-}"; n="${n#c-}"
  case "$n" in ''|*[!0-9]*) die "not a checklist id: $1" ;; esac
  printf 'C-%02d' "$((10#$n))"
}
item_file() { # ID → its path (empty when absent)
  find "$DIR" -maxdepth 2 -type f -name "$1_*.md" 2>/dev/null | head -1
}
need_item() { local f; f="$(item_file "$1")"; [ -n "$f" ] || die "no item $1 in $DIR"; printf '%s' "$f"; }
slugify() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//' | cut -c1-40 | sed 's/-$//'; }
story_file() { # NN-SS → the story file of this plan
  local e="${1%%-*}" s="${1#*-}"
  find "$PLAN/epics" -type f -path "*/epics/${e}_*/stories/${s}_*.md" 2>/dev/null | head -1
}
# group_of EPICS SOURCE — the folder an item lives in: its epic's folder name, or `journeys`
# for a flow and for anything spanning several epics.
group_of() {
  case "$2" in journey*) printf 'journeys'; return ;; esac
  case "$1" in *" "*) printf 'journeys'; return ;; esac
  basename "$(find "$PLAN/epics" -mindepth 1 -maxdepth 1 -type d -name "$1_*" 2>/dev/null | head -1)"
}
# group_title GROUP — the heading a group is listed under.
group_title() {
  [ "$1" = journeys ] && { printf 'Journeys'; return; }
  local t; t="$(fm "$PLAN/epics/$1/EPIC.md" title)"
  printf 'Epic %s — %s' "${1%%_*}" "${t:-${1#*_}}"
}
story_status() { local f; f="$(story_file "$1")"; [ -n "$f" ] && ck_fm "$f" status || printf 'missing'; }

# rows — num, id, status, stories, epics, tested_in, file, group, gorder, title, source; one item
# per line, by C-NN. gorder sorts epics by number and journeys last.
# Fields are split by US (\037), never a tab: `read` collapses runs of whitespace IFS, so an
# empty tested_in would shift every later field.
US=$(printf '\037')
rows() {
  [ -d "$DIR" ] || return 0
  local f
  local f g go
  for f in "$DIR"/*/C-*.md "$DIR"/C-*.md; do
    [ -f "$f" ] || continue
    g="$(basename "$(dirname "$f")")"
    case "$g" in journeys|checklist) go=999 ;; *) go="$((10#${g%%_*}))" ;; esac
    printf '%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\n' "$(fm "$f" id | sed 's/^C-0*//;s/^$/0/')" "$(fm "$f" id)" \
      "$(fm "$f" status)" "$(fm "$f" stories)" "$(fm "$f" epics)" "$(fm "$f" tested_in)" "$f" "$g" "$go" "$(fm "$f" title)" "$(fm "$f" source)"
  done | sort -n -k1,1
}

# fail_kind STORIES → retest (every story back at done) or wait (the fix has not landed).
fail_kind() {
  local s
  for s in $1; do [ "$(story_status "$s")" = "done" ] || { printf 'wait'; return; }; done
  printf 'retest'
}

# ---- commands --------------------------------------------------------------------

cmd_init() {
  local feature="" title=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --feature) feature="${2:-}"; shift 2 ;;
      --title)   title="${2:-}"; shift 2 ;;
      *) die "init: unknown option $1" ;;
    esac
  done
  is_v1 && die "$IDX is format 1 — run \`ck-checklist import $PLAN\` instead"
  [ -f "$IDX" ] && { echo "ck-checklist: $IDX already exists"; return 0; }
  [ -n "$title" ] || title="$(basename "$PLAN" | sed 's/^[0-9-]*_//')"
  mkdir -p "$DIR"
  {
    printf -- '---\nplan: %s\nfeature: %s\nformat: 2\nupdated: %s\nsession:\nsession_scope:\nsession_all:\nsession_last:\nsession_at:\n---\n\n' \
      "$(basename "$PLAN" | sed 's/^[0-9-]*_//')" "$feature" "$TODAY"
    printf '# Manual verification — %s\n\n## Before you test\n\n1. <prerequisite>\n\n## Not yet testable\n\n' "$title"
  } | sed 's/^\([a-z_]*\): $/\1:/' | ck_write_atomic "$IDX"
  echo "ck-checklist: created $IDX"
}

cmd_new() {
  local title="" stories="" source="" criterion="" checks="" expected="" after="" rec=0 st=todo res="" s epics="" last n id f g
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --title) title="${2:-}"; shift 2 ;;
      --stories) stories="${2:-}"; shift 2 ;;
      --source) source="${2:-}"; shift 2 ;;
      --criterion) criterion="${2:-}"; shift 2 ;;
      --checks) checks="${2:-}"; shift 2 ;;
      --expected) expected="${2:-}"; shift 2 ;;
      --after) after="$(norm_id "${2:-}")"; shift 2 ;;
      --recorded) rec=1; shift ;;
      *) die "new: unknown option $1" ;;
    esac
  done
  need_index
  [ -n "$title" ] && [ -n "$stories" ] && [ -n "$source" ] || die "new needs --title, --stories and --source"
  stories="$(printf '%s' "$stories" | tr ',' ' ' | tr -s ' ' | sed 's/^ //;s/ $//')"
  for s in $stories; do
    printf '%s' "$s" | grep -qE '^[0-9]{2}-[0-9]{2}$' || die "story id must be NN-SS (got: $s)"
    [ -n "$(story_file "$s")" ] || die "no story $s in $PLAN"
    case " $epics " in *" ${s%%-*} "*) ;; *) epics="${epics:+$epics }${s%%-*}" ;; esac
  done
  [ "$rec" = 1 ] && { st=pass; res="$(q "pass (recorded in story)")"; }
  last="$(rows | awk -F'\037' 'END { print ($1 == "" ? 0 : $1) }')"
  n=$((last + 1)); id="$(printf 'C-%02d' "$n")"
  g="$(group_of "$epics" "$source")"
  [ -n "$g" ] || die "no epic folder for $epics in $PLAN/epics"
  mkdir -p "$DIR/$g"
  f="$DIR/$g/${id}_$(slugify "$title").md"
  {
    printf -- '---\nid: %s\ntitle: %s\nstatus: %s\nstories: %s\nepics: %s\nsource: %s\n' "$id" "$(q "$title")" "$st" "$stories" "$epics" "$(q "$source")"
    printf 'criterion: %s\ndetail: outline\nafter: %s\nresult: %s\nwas:\nfix:\ntested_in:\nupdated: %s\n---\n\n' \
      "$([ -n "$criterion" ] && q "$criterion")" "$after" "$res" "$TODAY"
    printf -- '- **Checks:** %s\n- **Steps:** outline\n- **Expected:** %s\n' "${checks:-<the behavior under test>}" "${expected:-<one line>}"
  } | sed 's/^\([a-z_]*\): $/\1:/' | ck_write_atomic "$f"
  ck_fm_set "$IDX" updated "$TODAY"
  echo "$id $f"
}

cmd_list() {
  local open=0
  [ "${1:-}" = --open ] && open=1
  need_index
  local g="" num id st stories ep ti file grp go title src
  while IFS="$US" read -r num id st stories ep ti file grp go title src; do
    [ -n "$id" ] || continue
    [ "$open" = 1 ] && case "$st" in todo|fail|blocked) ;; *) continue ;; esac
    [ "$grp" = "$g" ] || { g="$grp"; echo "## $(group_title "$grp")"; }
    printf '%-6s %-8s %-12s %s · %s\n' "$id" "$st" "$stories" "$title" "$src"
  done <<EOF
$(rows | sort -t"$US" -k9,9n -k1,1n)
EOF
}

cmd_count() {
  [ -f "$IDX" ] || { echo 0; return 0; }
  if is_v1; then grep -cE '^### C-[0-9]+ · (todo|fail|blocked) ·' "$IDX"; return 0; fi
  rows | awk -F'\037' '$3=="todo" || $3=="fail" || $3=="blocked" { c++ } END { print c+0 }'
}

cmd_summary() {
  need_index
  local all p f b t k retest="" wait="" num id st stories ep ti file title sess
  all=0 p=0 f=0 b=0 t=0 k=0
  while IFS="$US" read -r num id st stories ep ti file _; do
    all=$((all + 1))
    case "$st" in
      pass) p=$((p + 1)) ;; todo) t=$((t + 1)) ;; blocked) b=$((b + 1)) ;; skip) k=$((k + 1)) ;;
      fail) f=$((f + 1))
            if [ "$(fail_kind "$stories")" = retest ]; then retest="$retest $id"; else wait="$wait $id"; fi ;;
    esac
  done <<EOF
$(rows)
EOF
  echo "$all items · $p pass · $f fail · $b blocked · $t todo · $k skip"
  rows | sort -t"$US" -k9,9n -k1,1n | awk -F'\037' '
    $8 != g { if (g != "") out(); g = $8; n = p = o = 0 }
    { n++; if ($3 == "pass") p++; if ($3 == "todo" || $3 == "fail" || $3 == "blocked") o++ }
    function out() { printf "%s\037%d items · %d pass · %d open\n", g, n, p, o }
    END { if (g != "") out() }' | while IFS="$US" read -r grp line; do
    printf '  %s: %s\n' "$(group_title "$grp")" "$line"
  done
  echo "Retest:${retest:- none}"
  echo "Waiting on fix:${wait:- none}"
  sess="$(ck_fm "$IDX" session)"
  if [ -n "$(ck_fm "$IDX" session_scope)" ]; then
    echo "Session $sess open · scope $(ck_fm "$IDX" session_scope)$([ "$(ck_fm "$IDX" session_all)" = true ] && printf ' --all') · last $(ck_fm "$IDX" session_last | sed "s/^$/—/") · $(ck_fm "$IDX" session_at) · $(queue | grep -c . | tr -d ' ') left"
  else
    echo "Session: none open"
  fi
}

cmd_start() {
  local scope=all retest_all=false n
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --epic) printf '%s' "${2:-}" | grep -qE '^[0-9]{2}$' || die "--epic needs a two-digit number"; scope="epic $2"; shift 2 ;;
      --all) retest_all=true; shift ;;
      *) die "start: unknown option $1" ;;
    esac
  done
  need_index
  n="$(ck_fm "$IDX" session)"; n=$(( ${n:-0} + 1 ))
  ck_fm_set "$IDX" session "$n" && ck_fm_set "$IDX" session_scope "$scope" && ck_fm_set "$IDX" session_all "$retest_all" \
    && ck_fm_set "$IDX" session_last "" && ck_fm_set "$IDX" session_at "$TODAY" || exit 1
  echo "ck-checklist: session $n started · scope $scope$([ "$retest_all" = true ] && printf ' --all')"
}

# queue — "phase<TAB>gorder<TAB>num<TAB>id<TAB>kind<TAB>file": Retest first, then todo/blocked
# (and pass/skip with --all); each epic by epic, journeys last, C-NN within a group. Never an
# item answered this session or waiting on a fix.
queue() {
  local scope all sess num id st stories ep ti file title kind
  scope="$(ck_fm "$IDX" session_scope)"; all="$(ck_fm "$IDX" session_all)"; sess="$(ck_fm "$IDX" session)"
  while IFS="$US" read -r num id st stories ep ti file _ go _; do
    [ -n "$id" ] || continue
    [ -n "$sess" ] && [ "$ti" = "$sess" ] && continue
    case "$scope" in "epic "*) case " $ep " in *" ${scope#epic } "*) ;; *) continue ;; esac ;; esac
    case "$st" in
      fail) kind="$(fail_kind "$stories")"; [ "$kind" = retest ] || continue; printf '0\t%s\t%s\t%s\t%s\n' "$go" "$num" "$id	retest" "$file" ;;
      todo|blocked) printf '1\t%s\t%s\t%s\t%s\n' "$go" "$num" "$id	$st" "$file" ;;
      pass|skip) [ "$all" = true ] && printf '1\t%s\t%s\t%s\t%s\n' "$go" "$num" "$id	$st" "$file" ;;
    esac
  done <<EOF
$(rows)
EOF
}

cmd_next() {
  local n=2 out
  [ "${1:-}" = -n ] && { n="${2:-2}"; case "$n" in ''|*[!0-9]*) die "-n needs a number" ;; esac; }
  need_index
  [ -n "$(ck_fm "$IDX" session_scope)" ] || cmd_start >/dev/null
  echo "# session $(ck_fm "$IDX" session) · scope $(ck_fm "$IDX" session_scope)$([ "$(ck_fm "$IDX" session_all)" = true ] && printf ' --all') · last $(ck_fm "$IDX" session_last | sed 's/^$/—/')"
  out="$(queue | sort -t"$(printf '\t')" -k1,1n -k2,2n -k3,3n | cut -f4- | head -n "$n")"
  if [ -z "$out" ]; then echo "# nothing left in this session"; else printf '%s\n' "$out"; fi
}

cmd_record() {
  local id="${1:-}" st="${2:-}" words="${3:-}" f old_st old_res old_fix result was sfile crit changed
  [ -n "$id" ] && [ -n "$st" ] || die "record needs C-NN and a status"
  id="$(norm_id "$id")"
  case "$st" in pass|fail|blocked|skip) ;; *) die "status must be pass|fail|blocked|skip (got: $st)" ;; esac
  case "$st" in fail|blocked) [ -n "$words" ] || die "$st needs the tester's own words" ;; esac
  need_index; f="$(need_item "$id")"
  old_st="$(fm "$f" status)"; old_res="$(fm "$f" result)"; old_fix="$(fm "$f" fix)"
  result="$st $TODAY${words:+ — $words}"
  was="$(fm "$f" was)"
  if [ "$old_st" != todo ] && [ -n "$old_res" ]; then was="$old_res${old_fix:+ → fix $old_fix}"; fi
  ck_fm_set "$f" status "$st" && fset "$f" result "$(q "$result")" && fset "$f" was "$([ -n "$was" ] && q "$was")" \
    && ck_fm_set "$f" fix "" && ck_fm_set "$f" tested_in "$(ck_fm "$IDX" session)" && ck_fm_set "$f" updated "$TODAY" \
    && ck_fm_set "$IDX" session_last "$id" && ck_fm_set "$IDX" updated "$TODAY" || exit 1
  echo "ck-checklist: $id $old_st → $st"
  changed="$IDX $f"
  crit="$(fm "$f" criterion)"
  if [ "$st" = pass ] && [ -n "$crit" ] && printf '%s' "$(fm "$f" source)" | grep -qE '^[0-9]{2}-[0-9]{2} human check'; then
    sfile="$(story_file "$(fm "$f" source | cut -c1-5)")"
    if [ -z "$sfile" ]; then
      echo "ck-checklist: WARN — story $(fm "$f" source | cut -c1-5) not found; nothing ticked" >&2
    elif grep -F -- "$crit" "$sfile" | grep -q -- '- \[x\]'; then
      echo "ck-checklist: human check already ticked in $sfile"
    elif grep -F -- "$crit" "$sfile" | grep -q -- '- \[ \]'; then
      awk -v c="$crit" '!done && index($0, c) && sub(/- \[ \]/, "- [x]") { done=1 } { print }' "$sfile" | ck_write_atomic "$sfile"
      echo "ck-checklist: ticked the human check in $sfile"
      changed="$changed $sfile"
    else
      echo "ck-checklist: WARN — criterion not found in $sfile; nothing ticked" >&2
    fi
  fi
  echo "stage: $changed"
}

cmd_set() {
  local id="${1:-}" f kv k v
  [ -n "$id" ] || die "set needs C-NN"
  id="$(norm_id "$id")"; shift
  [ "$#" -gt 0 ] || die "no key=value given"
  need_index; f="$(need_item "$id")"
  for kv in "$@"; do
    case "$kv" in *=*) ;; *) die "expected key=value, got: $kv" ;; esac
    k="${kv%%=*}"; v="${kv#*=}"
    case "$k" in
      detail) case "$v" in outline|full) ;; *) die "detail must be outline|full (got: $v)" ;; esac ;;
      after)  [ -z "$v" ] || v="$(norm_id "$v")" ;;
      fix)    [ -z "$v" ] || printf '%s' "$v" | grep -qE '^[0-9]{2}-[0-9]{2}$' || die "fix must be NN-SS (got: $v)" ;;
      source|title|criterion) [ -z "$v" ] || v="$(q "$v")" ;;
      *) die "\`$k\` is not settable (detail, after, source, title, criterion, fix); status and result go through \`record\`" ;;
    esac
    fset "$f" "$k" "$v" || exit 1
  done
  ck_fm_set "$f" updated "$TODAY"
  echo "ck-checklist: $id updated"
}

cmd_path() { need_index; need_item "$(norm_id "${1:-}")"; echo; }

cmd_close() {
  need_index
  ck_fm_set "$IDX" session_scope "" && ck_fm_set "$IDX" session_all "" || exit 1
  echo "ck-checklist: session $(ck_fm "$IDX" session) closed"
}

cmd_import() {
  local f g
  if ! is_v1; then
    has_flat || die "$IDX is neither format 1 nor ungrouped — nothing to import"
    for f in "$DIR"/C-*.md; do
      g="$(group_of "$(fm "$f" epics)" "$(fm "$f" source)")"
      [ -n "$g" ] || die "no epic folder for $(fm "$f" id) (epics: $(fm "$f" epics))"
      mkdir -p "$DIR/$g" && mv "$f" "$DIR/$g/" || exit 1
    done
    echo "ck-checklist: grouped the items of $DIR by epic"
    echo "stage: $DIR"
    return 0
  fi
  command -v python3 >/dev/null 2>&1 || die "import needs python3"
  python3 - "$PLAN" "$TODAY" <<'PY' || exit 1
import glob, os, re, sys
plan, today = sys.argv[1], sys.argv[2]
idx = os.path.join(plan, "CHECKLIST.md")
text = open(idx, encoding="utf-8").read().replace("\r\n", "\n")
fm, body = {}, text
m = re.match(r"---\n(.*?)\n---\n?(.*)", text, re.S)
if m:
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1); fm[k.strip()] = v.strip()
    body = m.group(2)

def q(v):
    v = " ".join(v.split())
    return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'

def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")[:40].rstrip("-")

def story(sid):
    e, s = sid.split("-")
    hits = glob.glob(os.path.join(plan, "epics", e + "_*", "stories", s + "_*.md"))
    return hits[0] if hits else None

head = re.compile(r"^### (C-\d+) · (\w+) · ([\d\- ]+?) — (.+)$")
kept, items, cur = [], [], None
for line in body.split("\n"):
    h = head.match(line)
    if h:
        cur = {"id": h.group(1), "status": h.group(2), "stories": h.group(3).split(), "title": h.group(4), "lines": []}
        items.append(cur); continue
    if cur is not None and re.match(r"^#{1,2} ", line):
        cur = None
    if cur is None:
        if not re.match(r"^## (Epic \d+|Journeys)\b", line):
            kept.append(line)
    else:
        cur["lines"].append(line)

d = os.path.join(plan, "checklist"); os.makedirs(d, exist_ok=True)
warn = []
for it in items:
    src = res = ""; lines = []
    for l in it["lines"]:
        ms = re.match(r"^- \*\*Source:\*\*\s*(.*)$", l); mr = re.match(r"^- \*\*Result:\*\*\s*(.*)$", l)
        if ms: src = ms.group(1).strip()
        elif mr: res = mr.group(1).strip()
        else: lines.append(l)
    while lines and not lines[-1].strip(): lines.pop()
    while lines and not lines[0].strip(): lines.pop(0)
    res = "" if res in ("—", "-") else res
    was = fix = ""
    mw = re.search(r"\s*\(was (.*)\)\s*$", res)
    if mw: was, res = mw.group(1), res[:mw.start()]
    mf = re.search(r"\s*→ fix (\d{2}-\d{2})\s*$", res)
    if mf: fix, res = mf.group(1), res[:mf.start()]
    crit = ""
    mh = re.match(r"^(\d{2}-\d{2}) human check", src)
    if mh:
        sf = story(mh.group(1))
        checks = [l for l in open(sf, encoding="utf-8").read().splitlines() if re.match(r"^\s*- \[[ xX]\]", l) and "human check" in l.lower()] if sf else []
        if len(checks) == 1:
            crit = re.sub(r"^\s*- \[[ xX]\]\s*", "", checks[0]).strip()
        else:
            warn.append(f"{it['id']}: {len(checks)} human-check lines in {mh.group(1)} — set its criterion with `ck-checklist set`")
    epics = []
    for s in it["stories"]:
        if s[:2] not in epics: epics.append(s[:2])
    outline = any(re.match(r"^- \*\*Steps:\*\*\s*outline\s*$", l) for l in lines)
    out = ["---", f"id: {it['id']}", f"title: {q(it['title'])}", f"status: {it['status']}",
           f"stories: {' '.join(it['stories'])}", f"epics: {' '.join(epics)}", f"source: {q(src)}",
           f"criterion: {q(crit) if crit else ''}", f"detail: {'outline' if outline else 'full'}", "after:",
           f"result: {q(res) if res else ''}", f"was: {q(was) if was else ''}", f"fix: {fix}", "tested_in:",
           f"updated: {today}", "---", ""]
    out = [l.rstrip() for l in out] + lines + [""]
    if src.startswith("journey") or len(epics) != 1:
        g = "journeys"
    else:
        hits = glob.glob(os.path.join(plan, "epics", epics[0] + "_*"))
        g = os.path.basename(hits[0]) if hits else epics[0]
    os.makedirs(os.path.join(d, g), exist_ok=True)
    with open(os.path.join(d, g, f"{it['id']}_{slug(it['title'])}.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))

rest = re.sub(r"\n{3,}", "\n\n", "\n".join(kept)).strip("\n")
new = ["---", f"plan: {fm.get('plan', '')}", f"feature: {fm.get('feature', '')}", "format: 2", f"updated: {today}",
       "session:", "session_scope:", "session_all:", "session_last:", "session_at:", "---", "", rest, ""]
with open(idx + ".tmp", "w", encoding="utf-8") as fh:
    fh.write("\n".join(new))
os.replace(idx + ".tmp", idx)
print(f"ck-checklist: imported {len(items)} items into {d}")
for w in warn: print("ck-checklist: WARN — " + w, file=sys.stderr)
PY
  echo "stage: $IDX $DIR"
}

case "$CMD" in
  init) cmd_init "$@" ;; new) cmd_new "$@" ;; list) cmd_list "$@" ;; summary) cmd_summary ;;
  count) cmd_count ;; start) cmd_start "$@" ;; next) cmd_next "$@" ;; record) cmd_record "$@" ;;
  set) cmd_set "$@" ;; path) cmd_path "$@" ;; close) cmd_close ;; import) cmd_import ;;
esac
