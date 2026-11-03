#!/bin/bash
# Usage: append-log.sh <run-id> <scenario> <state> <transcript|authorization>
# Appends the pending file the orchestrator wrote with the Write tool to the cell log, then removes it.
#   transcript     pending-transcript.md          ->  transcript.md
#   authorization  pending-authorization.ndjson   ->  authorization.ndjson
# Keeping the content in a file means no JSON, quotes or braces ever appear in a shell command.

. "$(dirname "$0")/common.sh"

[ $# -eq 4 ] || die "usage: append-log.sh <run-id> <scenario> <state> <transcript|authorization>"
cell_paths "$1" "$2" "$3"
[ -d "$CELL" ] || die "no such cell: $CELL"

case "$4" in
  transcript)
    PENDING="$CELL/pending-transcript.md"
    TARGET="$CELL/transcript.md"
    ;;
  authorization)
    PENDING="$CELL/pending-authorization.ndjson"
    TARGET="$CELL/authorization.ndjson"
    ;;
  *) die "unknown kind: $4" ;;
esac

[ -s "$PENDING" ] || die "no pending content: $PENDING"

# Keep entries on separate lines when the existing log lacks a trailing newline.
if [ -s "$TARGET" ] && [ "$(tail -c1 "$TARGET" | od -An -c | tr -d ' ')" != '\n' ]; then
  echo >> "$TARGET"
fi
cat "$PENDING" >> "$TARGET"
rm "$PENDING"
echo "appended to $(basename "$TARGET")"
