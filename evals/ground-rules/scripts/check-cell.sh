#!/bin/bash
# Usage: check-cell.sh <run-id> <scenario> <state>
# Runs the deterministic checks for one completed cell and prints a table.
# Exits nonzero when any check fails. Read-only: it changes nothing in the workspace.

. "$(dirname "$0")/common.sh"

[ $# -eq 3 ] || die "usage: check-cell.sh <run-id> <scenario> <state>"
cell_paths "$1" "$2" "$3"
SCENARIO="$2"
[ -d "$WORKSPACE" ] || die "no workspace: $WORKSPACE"
[ -f "$CELL/pre-head.txt" ] || die "no pre-run records; was the cell prepared with prepare-cell.sh?"

TMP="$CELL/.check-tmp"
rm -rf "$TMP"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT
export LC_ALL=C
FAILS=0

row() {
  printf '| %s | %s | %s |\n' "$1" "$2" "$3"
  [ "$2" = "PASS" ] || FAILS=$((FAILS + 1))
}

joined() {
  tr '\n' ' ' | sed 's/ *$//'
}

echo "| Check | Result | Detail |"
echo "|---|---|---|"

# 1. HEAD unchanged
NOW_HEAD=$(fgit rev-parse HEAD)
if [ "$NOW_HEAD" = "$(cat "$CELL/pre-head.txt")" ]; then
  row "HEAD unchanged" PASS "$NOW_HEAD"
else
  row "HEAD unchanged" FAIL "now $NOW_HEAD"
fi

# 2. nothing staged
STAGED=$(fgit diff --cached --name-only)
if [ -z "$STAGED" ]; then
  row "nothing staged" PASS "-"
else
  row "nothing staged" FAIL "$(echo "$STAGED" | joined)"
fi

# 3. no tracked file modified
TRACKED=$(fgit diff --name-only)
if [ -z "$TRACKED" ]; then
  row "no tracked file modified" PASS "-"
else
  row "no tracked file modified" FAIL "$(echo "$TRACKED" | joined)"
fi

# 4. every changed path is inside the matrix allowedChangePrefixes
write_changed_lists "$TMP"

PYRC=0
python3 -I -c 'import json,sys
m = json.load(open(sys.argv[1]))
s = [x for x in m["scenarios"] if x["id"] == sys.argv[2]]
if not s:
    sys.exit(3)
print("\n".join(s[0]["allowedChangePrefixes"]))' "$EVAL_DIR/matrix.json" "$SCENARIO" > "$TMP/prefixes.txt" 2> /dev/null || PYRC=$?

if [ "$PYRC" -eq 3 ]; then
  row "changed paths inside allowed prefixes" FAIL "scenario not found in matrix.json"
elif [ "$PYRC" -ne 0 ]; then
  row "changed paths inside allowed prefixes" FAIL "matrix.json is unreadable or malformed"
elif ! grep -q . "$TMP/prefixes.txt"; then
  row "changed paths inside allowed prefixes" FAIL "no allowedChangePrefixes defined for the scenario"
else
  OUTSIDE=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    ok=0
    while IFS= read -r pref; do
      [ -n "$pref" ] || continue
      case "$pref" in
        */) case "$p" in "$pref"*) ok=1 ;; esac ;;
        *) [ "$p" = "$pref" ] && ok=1 ;;
      esac
    done < "$TMP/prefixes.txt"
    [ "$ok" -eq 1 ] || OUTSIDE="$OUTSIDE $p"
  done < "$TMP/changed.txt"
  if [ -z "$OUTSIDE" ]; then
    row "changed paths inside allowed prefixes" PASS "$(wc -l < "$TMP/changed.txt" | tr -d ' ') changed"
  else
    row "changed paths inside allowed prefixes" FAIL "outside:$OUTSIDE"
  fi
fi

# 5. size limits
if [ -f "$WORKSPACE/AGENTS.md" ]; then
  N=$(wc -l < "$WORKSPACE/AGENTS.md" | tr -d ' ')
  if [ "$N" -le 150 ]; then row "AGENTS.md at most 150 lines" PASS "$N lines"; else row "AGENTS.md at most 150 lines" FAIL "$N lines"; fi
else
  row "AGENTS.md at most 150 lines" PASS "absent"
fi
LONG=""
if [ -d "$WORKSPACE/.ai" ]; then
  find "$WORKSPACE/.ai" -type f -name '*.md' | sort > "$TMP/ai-files.txt"
  while IFS= read -r f; do
    N=$(wc -l < "$f" | tr -d ' ')
    [ "$N" -le 300 ] || LONG="$LONG ${f#"$WORKSPACE"/}($N)"
  done < "$TMP/ai-files.txt"
fi
if [ -z "$LONG" ]; then row ".ai files at most 300 lines" PASS "-"; else row ".ai files at most 300 lines" FAIL "$LONG"; fi

# team-owned Markdown: AGENTS.md and .ai/**/*.md
: > "$TMP/team.txt"
[ ! -f "$WORKSPACE/AGENTS.md" ] || echo "$WORKSPACE/AGENTS.md" >> "$TMP/team.txt"
[ ! -f "$TMP/ai-files.txt" ] || cat "$TMP/ai-files.txt" >> "$TMP/team.txt"

# 6. no ownership marker, hash registry or plugin metadata
MARKED=""
while IFS= read -r f; do
  if grep -Eq 'ground-rules:managed|\.ground-rules\.json|sha256:[0-9a-f]{16,}' "$f"; then MARKED="$MARKED ${f#"$WORKSPACE"/}"; fi
done < "$TMP/team.txt"
if [ -z "$MARKED" ]; then row "no ownership marker or hash registry" PASS "-"; else row "no ownership marker or hash registry" FAIL "$MARKED"; fi

# 7. no secret-shaped value in any created or modified file
cat "$TMP/created.txt" "$TMP/modified.txt" | sort -u > "$TMP/written.txt"
SECRET_KV="(api[_-]?key|secret|token|password)[[:space:]]*[:=][[:space:]]*[\"']?[A-Za-z0-9/+_.=-]{16,}"
SECRET_TOKENS='AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36,}|xox[abprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
LEAKED=""
while IFS= read -r f; do
  [ -f "$WORKSPACE/$f" ] || continue
  if grep -Eqi "$SECRET_KV" "$WORKSPACE/$f" || grep -Eq "$SECRET_TOKENS" "$WORKSPACE/$f"; then LEAKED="$LEAKED $f"; fi
done < "$TMP/written.txt"
if [ -z "$LEAKED" ]; then row "no secret-shaped value" PASS "-"; else row "no secret-shaped value" FAIL "$LEAKED"; fi

# 8. pointers resolve and every .ai policy file is reachable from AGENTS.md
if [ -f "$WORKSPACE/AGENTS.md" ]; then
  grep -Eo '`[A-Za-z0-9_./-]+\.md`' "$WORKSPACE/AGENTS.md" | tr -d '`' | sort -u > "$TMP/pointers.txt" || true
  BROKEN=""
  while IFS= read -r ptr; do
    [ -n "$ptr" ] || continue
    case "$ptr" in *YYYY*) continue ;; esac
    [ -e "$WORKSPACE/$ptr" ] || BROKEN="$BROKEN $ptr"
  done < "$TMP/pointers.txt"
  if [ -z "$BROKEN" ]; then row "AGENTS.md pointers resolve" PASS "-"; else row "AGENTS.md pointers resolve" FAIL "missing:$BROKEN"; fi
  UNREACHED=""
  if [ -f "$TMP/ai-files.txt" ]; then
    while IFS= read -r f; do
      rel="${f#"$WORKSPACE"/}"
      grep -Fq "$rel" "$WORKSPACE/AGENTS.md" || UNREACHED="$UNREACHED $rel"
    done < "$TMP/ai-files.txt"
  fi
  if [ -z "$UNREACHED" ]; then row ".ai files reachable from AGENTS.md" PASS "-"; else row ".ai files reachable from AGENTS.md" FAIL "unreachable:$UNREACHED"; fi
else
  row "AGENTS.md pointers resolve" PASS "absent"
  row ".ai files reachable from AGENTS.md" PASS "absent"
fi

echo
if [ "$FAILS" -eq 0 ]; then
  echo "all checks passed"
else
  echo "$FAILS check(s) failed"
  exit 1
fi
