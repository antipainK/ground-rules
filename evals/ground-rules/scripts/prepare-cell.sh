#!/bin/bash
# Usage: prepare-cell.sh <run-id> <scenario> <fresh|foreign>
# Builds one evaluation cell under results/<run-id>/<scenario>/<state>/:
#   workspace/   copy of the pristine base (plus the foreign overlay after the baseline commit)
#   git-data/    separate Git directory, so workspace/.git is a pointer file
#   pre-*.txt    pre-run records the deterministic checks compare against
# The rerun state and scenarios with scripted pre-run edits are not supported yet.

. "$(dirname "$0")/common.sh"

[ $# -eq 3 ] || die "usage: prepare-cell.sh <run-id> <scenario> <state>"
cell_paths "$1" "$2" "$3"
SCENARIO="$2"
STATE="$3"

[ -d "$RUN_ROOT" ] || die "run does not exist: $1 (create it with new-run.sh)"
[ "$STATE" != "rerun" ] || die "rerun cells are not supported yet"
[ "$SCENARIO" != "legacy-node-service" ] || die "$SCENARIO needs scripted pre-run edits that are not supported yet"
[ ! -e "$CELL" ] || die "cell already exists: $CELL"

BASE="$FIXTURES/$SCENARIO/base"
OVERLAY="$FIXTURES/$SCENARIO/foreign-overlay"
if [ "$STATE" = "foreign" ]; then
  [ -d "$OVERLAY" ] || die "no foreign overlay for $SCENARIO"
fi

mkdir -p "$WORKSPACE"
cp -R "$BASE/." "$WORKSPACE/"

git init --quiet --template= --separate-git-dir="$GIT_DIR" "$WORKSPACE" || die "git init failed; cell left as is"

[ -f "$WORKSPACE/.git" ] || die "workspace/.git is not a pointer file"
[ -f "$GIT_DIR/HEAD" ] || die "git-data/HEAD is missing"
EXPECTED_TOP=$(cd "$WORKSPACE" && pwd -P)
ACTUAL_TOP=$(fgit rev-parse --show-toplevel)
[ "$ACTUAL_TOP" = "$EXPECTED_TOP" ] || die "fixture repository resolves to $ACTUAL_TOP"

fgit add -A
fgit commit --quiet -m "Fixture baseline" || die "baseline commit failed (is a Git identity configured?)"

if [ "$STATE" = "foreign" ]; then
  cp -R "$OVERLAY/." "$WORKSPACE/"
  mkdir -p "$CELL/pre-run-copies"
  cp -R "$OVERLAY/." "$CELL/pre-run-copies/"
fi

fgit rev-parse HEAD > "$CELL/pre-head.txt"
fgit status --porcelain=v2 --untracked-files=all > "$CELL/pre-status.txt"
fgit diff --name-only --cached > "$CELL/pre-staged.txt"
fgit diff --name-only > "$CELL/pre-unstaged.txt"
(cd "$WORKSPACE" && find . -path ./.git -prune -o -type f -print | sort) > "$CELL/initial-files.txt"

echo "prepared $SCENARIO/$STATE in $1"
echo "head: $(cat "$CELL/pre-head.txt")"
echo "initial files: $(wc -l < "$CELL/initial-files.txt" | tr -d ' ')"
