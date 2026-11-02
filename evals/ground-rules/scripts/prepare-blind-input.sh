#!/bin/bash
# Usage: prepare-blind-input.sh <run-id> <scenario> <state>
# Builds <cell>/blind-input/ for the final blind evaluators:
#   rubric.json        the rubric and hard failures from matrix.json
#   changed-paths.txt  created, deleted and modified paths, one per line
# The orchestrator then writes the sanitized authorization record into the same folder
# as authorization.json with the Write tool. Give the evaluators that folder, the pristine
# base fixture, the final workspace and the Ground Rules skill, and nothing else.

. "$(dirname "$0")/common.sh"

[ $# -eq 3 ] || die "usage: prepare-blind-input.sh <run-id> <scenario> <state>"
cell_paths "$1" "$2" "$3"
[ -d "$WORKSPACE" ] || die "no workspace: $WORKSPACE"
[ -f "$CELL/initial-files.txt" ] || die "no pre-run records; was the cell prepared with prepare-cell.sh?"

BLIND="$CELL/blind-input"
[ ! -e "$BLIND" ] || die "blind-input already exists: $BLIND"

TMP="$CELL/.blind-tmp"
rm -rf "$TMP"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$BLIND"
write_changed_lists "$TMP"

python3 -I -c 'import json,sys
m = json.load(open(sys.argv[1]))
out = {"rubric": m["rubric"], "hardFailures": m["hardFailures"]}
json.dump(out, open(sys.argv[2], "w"), indent=1)' "$EVAL_DIR/matrix.json" "$BLIND/rubric.json"

: > "$BLIND/changed-paths.txt"
sed 's/^/created: /' "$TMP/created.txt" >> "$BLIND/changed-paths.txt"
sed 's/^/deleted: /' "$TMP/deleted.txt" >> "$BLIND/changed-paths.txt"
sort -u "$TMP/modified.txt" | sed 's/^/modified: /' >> "$BLIND/changed-paths.txt"

echo "prepared $BLIND"
echo "write authorization.json there with the Write tool"
