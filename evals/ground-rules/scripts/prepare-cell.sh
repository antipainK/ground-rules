#!/bin/bash
# Usage: prepare-cell.sh <run-id> <scenario> <fresh|foreign|rerun>
# Builds one evaluation cell under results/<run-id>/<scenario>/<state>/:
#   workspace/   the working copy
#   git-data/    separate Git directory, so workspace/.git is a pointer file
#   pre-*.txt    pre-run records the deterministic checks compare against
# fresh    copy of the pristine base; legacy-node-service also gets an unstaged operator edit
#          to src/server.js and a staged release note in README.md
# foreign  the fresh state plus the foreign overlay, copied after the baseline commit
# rerun    the final files of the passed fresh cell in a new repository, plus one maintainer
#          rule from matrix.json appended to the single .ai file matching the scenario's topic
# A copy failure (for example a fixture file the sandbox blocks) removes the half-built cell.

. "$(dirname "$0")/common.sh"

[ $# -eq 3 ] || die "usage: prepare-cell.sh <run-id> <scenario> <state>"
cell_paths "$1" "$2" "$3"
SCENARIO="$2"
STATE="$3"

[ -d "$RUN_ROOT" ] || die "run does not exist: $1 (create it with new-run.sh)"
[ ! -e "$CELL" ] || die "cell already exists: $CELL"

BASE="$FIXTURES/$SCENARIO/base"
OVERLAY="$FIXTURES/$SCENARIO/foreign-overlay"
FRESH="$RUN_ROOT/$SCENARIO/fresh"
TMP="$RUN_ROOT/.prepare-tmp-$SCENARIO-$STATE"
trap 'rm -rf "$TMP"' EXIT

if [ "$STATE" = "foreign" ]; then
  [ -d "$OVERLAY" ] || die "no foreign overlay for $SCENARIO"
fi

# Appends one line to a file, adding a newline first when the file does not end with one.
append_line() {
  if [ -s "$1" ] && [ "$(tail -c1 "$1" | od -An -c | tr -d ' ')" != '\n' ]; then
    echo >> "$1"
  fi
  printf '%s\n' "$2" >> "$1"
}

# Copies the contents of directory $1 into directory $2. On failure the half-built cell is
# removed, because nothing but this script has touched it yet.
copy_tree() {
  local err="$CELL/.copy-error.txt"
  if ! cp -R "$1/." "$2/" 2> "$err"; then
    local detail
    detail=$(head -3 "$err" | tr '\n' ' ')
    rm -rf "$CELL"
    die "could not copy $1 (a file may be blocked by the sandbox, for example .env files): $detail"
  fi
  rm -f "$err"
}

# Removes the cell and stops. Used only for failures that happen before any agent touched it.
fail_clean() {
  rm -rf "$CELL"
  die "$@"
}

init_repo_with_baseline() {
  git init --quiet --template= --separate-git-dir="$GIT_DIR" "$WORKSPACE" || die "git init failed; cell left as is"

  [ -f "$WORKSPACE/.git" ] || die "workspace/.git is not a pointer file"
  [ -f "$GIT_DIR/HEAD" ] || die "git-data/HEAD is missing"
  local expected actual
  expected=$(cd "$WORKSPACE" && pwd -P)
  actual=$(fgit rev-parse --show-toplevel)
  [ "$actual" = "$expected" ] || die "fixture repository resolves to $actual"

  fgit add -A
  fgit commit --quiet -m "Fixture baseline" || die "baseline commit failed (is a Git identity configured?)"
}

plant_legacy_edits() {
  append_line "$WORKSPACE/src/server.js" "// operator edit: do not commit"
  append_line "$WORKSPACE/README.md" ""
  append_line "$WORKSPACE/README.md" "## Release notes"
  append_line "$WORKSPACE/README.md" ""
  append_line "$WORKSPACE/README.md" "- Unreleased: operator note."
  fgit add -- README.md
  mkdir -p "$CELL/pre-run-copies/src"
  cp "$WORKSPACE/README.md" "$CELL/pre-run-copies/README.md"
  cp "$WORKSPACE/src/server.js" "$CELL/pre-run-copies/src/server.js"
}

# Finds the one .ai file of the fresh workspace that matches the scenario's rerun topics, then
# builds the rerun cell. Every refusal below happens before the cell is created.
prepare_rerun() {
  [ -d "$FRESH/workspace" ] || die "no fresh cell for $SCENARIO in this run"
  [ -f "$FRESH/result.json" ] || die "the fresh cell has not passed: no result.json"
  python3 -I -c 'import json,sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(2)
sys.exit(0 if d.get("verdict") == "pass" else 1)' "$FRESH/result.json" || die "the fresh cell has not passed: result.json verdict is not pass"

  rm -rf "$TMP"
  mkdir -p "$TMP"
  python3 -I -c 'import json,sys
m = json.load(open(sys.argv[1]))
s = [x for x in m["scenarios"] if x["id"] == sys.argv[2]]
r = s[0].get("rerunMaintainerRule") if s else None
if not r or not r.get("topics") or not r.get("text"):
    sys.exit(3)
open(sys.argv[3], "w").write("\n".join(t.lower() for t in r["topics"]) + "\n")
open(sys.argv[4], "w").write(r["text"] + "\n")' "$EVAL_DIR/matrix.json" "$SCENARIO" "$TMP/topics.txt" "$TMP/rule.txt" \
    || die "no usable rerunMaintainerRule for $SCENARIO in matrix.json"
  local rule
  rule=$(cat "$TMP/rule.txt")

  : > "$TMP/ai.txt"
  if [ -d "$FRESH/workspace/.ai" ]; then
    find "$FRESH/workspace/.ai" -type f -name '*.md' | sort > "$TMP/ai.txt"
  fi
  : > "$TMP/matches.txt"
  while IFS= read -r f; do
    local stem heading
    stem=$(basename "$f" .md | tr 'A-Z' 'a-z')
    heading=$(grep -m1 '^# ' "$f" | sed 's/^# *//' | tr 'A-Z' 'a-z' | tr ' ' '-')
    if grep -Fxq -e "$stem" "$TMP/topics.txt" || { [ -n "$heading" ] && grep -Fxq -e "$heading" "$TMP/topics.txt"; }; then
      echo "${f#"$FRESH/workspace/"}" >> "$TMP/matches.txt"
    fi
  done < "$TMP/ai.txt"

  local count found
  count=$(wc -l < "$TMP/matches.txt" | tr -d ' ')
  found=$(sed "s|^$FRESH/workspace/||" "$TMP/ai.txt" | tr '\n' ' ')
  if [ "$count" -eq 0 ]; then
    die "no .ai file matches the topics for $SCENARIO (.ai files found: ${found:-none})"
  elif [ "$count" -gt 1 ]; then
    die "ambiguous: more than one .ai file matches the topics for $SCENARIO: $(tr '\n' ' ' < "$TMP/matches.txt")"
  fi
  local match
  match=$(cat "$TMP/matches.txt")
  if grep -Fxq -e "$rule" "$FRESH/workspace/$match"; then
    die "the maintainer rule is already present in $match"
  fi

  mkdir -p "$WORKSPACE"
  copy_tree "$FRESH/workspace" "$WORKSPACE"
  rm -f "$WORKSPACE/.git"
  init_repo_with_baseline

  append_line "$WORKSPACE/$match" "$rule"
  local changed stat
  changed=$(fgit diff --name-only)
  [ "$changed" = "$match" ] || fail_clean "unexpected changes after appending the rule: $changed"
  stat=$(fgit diff --numstat)
  [ "$stat" = "1"$'\t'"0"$'\t'"$match" ] || fail_clean "the rule must add exactly one line; got: $stat"
  fgit add -- "$match"
  fgit commit --quiet -m "Maintainer policy addition" || fail_clean "maintainer commit failed"

  printf '%s\n%s\n' "$match" "$rule" > "$CELL/maintainer-rule.txt"
}

if [ "$STATE" = "rerun" ]; then
  prepare_rerun
else
  mkdir -p "$WORKSPACE"
  copy_tree "$BASE" "$WORKSPACE"
  init_repo_with_baseline
  if [ "$STATE" = "foreign" ]; then
    copy_tree "$OVERLAY" "$WORKSPACE"
    mkdir -p "$CELL/pre-run-copies"
    cp -R "$OVERLAY/." "$CELL/pre-run-copies/"
  fi
  if [ "$SCENARIO" = "legacy-node-service" ] && [ "$STATE" = "fresh" ]; then
    plant_legacy_edits
  fi
fi

fgit rev-parse HEAD > "$CELL/pre-head.txt"
fgit status --porcelain=v2 --untracked-files=all > "$CELL/pre-status.txt"
fgit diff --name-only --cached > "$CELL/pre-staged.txt"
fgit diff --name-only > "$CELL/pre-unstaged.txt"
(cd "$WORKSPACE" && find . -path ./.git -prune -o -type f -print | sort) > "$CELL/initial-files.txt"

echo "prepared $SCENARIO/$STATE in $1"
echo "head: $(cat "$CELL/pre-head.txt")"
echo "initial files: $(wc -l < "$CELL/initial-files.txt" | tr -d ' ')"
