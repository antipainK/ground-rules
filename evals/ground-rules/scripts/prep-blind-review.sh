#!/bin/bash
# Usage: prep-blind-review.sh <run-id> <scenario> <state>
# Builds <cell>/blind-input/ for the blind evaluators:
#   rubric.json        the 5x 0-100 category rubric, deduction anchors, and hard failures
#   changed-paths.txt  created, deleted and modified paths, one per line
#   maintainer-answers.json exact accepted answers and their selected bindings
#   decision-record.json the target's exact sanitized Ground Rules decision record
# The folder is built aside and moved into place at the end, so a failure leaves nothing
# behind and the script can be run again.

. "$(dirname "$0")/common.sh"

[ $# -eq 3 ] || die "usage: prep-blind-review.sh <run-id> <scenario> <state>"
cell_paths "$1" "$2" "$3"
[ -d "$WORKSPACE" ] || die "no workspace: $WORKSPACE"
[ -f "$CELL/initial-files.txt" ] || die "no pre-run records; was the cell prepared with prep-cell.sh?"
[ -d "$CELL/initial-workspace" ] || die "prepared initial workspace is missing"
[ -f "$CELL/pre-initial-workspace-manifest.txt" ] || die "prepared initial workspace manifest is missing"

BLIND="$CELL/blind-input"
[ ! -e "$BLIND" ] || die "blind-input already exists: $BLIND"

TMP="$CELL/.blind-tmp"
NEW="$CELL/.blind-new"
rm -rf "$TMP" "$NEW"
mkdir -p "$TMP" "$NEW"
trap 'rm -rf "$TMP" "$NEW"' EXIT

write_tree_manifest "$CELL/initial-workspace" "$TMP/initial-workspace-manifest.txt"
cmp -s "$TMP/initial-workspace-manifest.txt" "$CELL/pre-initial-workspace-manifest.txt" \
  || die "prepared initial workspace changed after cell preparation"

verify_git_safety || die "Git pointer, configuration or symlink safety check failed before building blind input"

[ -f "$CELL/maintainer-answers.json" ] || die "maintainer-answers.json is missing"
[ -f "$CELL/maintainer-answers.ndjson" ] || die "maintainer-answers.ndjson is missing"
[ -f "$CELL/decision-record.json" ] || die "decision-record.json is missing"

write_changed_lists "$TMP"

python3 -I -c 'import json,sys
m = json.load(open(sys.argv[1]))
out = {"rubric": m["rubric"], "hardFailures": m["hardFailures"]}
json.dump(out, open(sys.argv[2], "w"), indent=1)' "$RUBRIC_FILE" "$NEW/rubric.json"

python3 -I -c 'import json,sys
compiled = json.load(open(sys.argv[1]))
if not isinstance(compiled, list):
    raise SystemExit("maintainer-answers.json must be an array")
raw = []
raw_lines = []
with open(sys.argv[2], "rb") as f:
    for number, line in enumerate(f, 1):
        record = line[:-1] if line.endswith(b"\n") else line
        if record.strip():
            try:
                raw.append(json.loads(record))
                raw_lines.append(record)
            except json.JSONDecodeError as exc:
                raise SystemExit(f"invalid maintainer-answers.ndjson line {number}: {exc}")
entries = []
seen = set()
for entry, record in zip(raw, raw_lines):
    if record not in seen:
        seen.add(record)
        entries.append(entry)
if compiled != entries:
    raise SystemExit("maintainer-answers.json does not match the complete deduplicated maintainer-answers.ndjson log")
out = []
for entry in entries:
    q = entry["question"]
    selected = entry.get("selectedOptions", [])
    free_text = entry.get("freeText")
    if not isinstance(q, dict) or not isinstance(selected, list):
        raise SystemExit("malformed maintainer-answers entry")
    options = q.get("options", [])
    bindings = []
    for text in selected:
        matches = [o for o in options if o.get("text") == text]
        if len(matches) != 1:
            raise SystemExit("selected option does not have exactly one binding")
        bindings.append(matches[0])
    if not selected and free_text is None:
        raise SystemExit("maintainer-answers entry has neither option nor free text")
    out.append({
        "questionIndex": entry["questionIndex"],
        "questionText": q.get("text"),
        "selectedOptions": selected,
        "freeText": free_text,
        "selectedBindings": bindings,
    })
json.dump(out, open(sys.argv[3], "w"), indent=1)' \
  "$CELL/maintainer-answers.json" "$CELL/maintainer-answers.ndjson" "$NEW/maintainer-answers.json"

python3 -I -c 'import json,sys
record = json.load(open(sys.argv[1]))
if not isinstance(record, list):
    raise SystemExit("decision-record.json must be an array")
json.dump(record, open(sys.argv[2], "w"), indent=1)' \
  "$CELL/decision-record.json" "$NEW/decision-record.json"

: > "$NEW/changed-paths.txt"
sed 's/^/created: /' "$TMP/created.txt" >> "$NEW/changed-paths.txt"
sed 's/^/deleted: /' "$TMP/deleted.txt" >> "$NEW/changed-paths.txt"
sort -u "$TMP/modified.txt" | sed 's/^/modified: /' >> "$NEW/changed-paths.txt"

mv "$NEW" "$BLIND"

echo "prepared $BLIND"
