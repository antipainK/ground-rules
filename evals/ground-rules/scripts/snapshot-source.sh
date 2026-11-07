#!/bin/bash
# Usage: snapshot-source.sh <before|after|compare> <run-id>
# Records the source repository's HEAD and status in the run folder, then compares them.
# The source repository is only read. A snapshot is written aside and moved into place,
# so a failed recording leaves nothing behind and can be retried.

. "$(dirname "$0")/common.sh"

[ $# -eq 2 ] || die "usage: snapshot-source.sh <before|after|compare> <run-id>"
MODE="$1"
validate_run_id "$2"
RUN_ROOT="$RESULTS/$2"
[ -d "$RUN_ROOT" ] || die "run does not exist: $2"

trap 'rm -f "$RUN_ROOT/.snap-head.tmp" "$RUN_ROOT/.snap-status.tmp" "$RUN_ROOT/.snap-files.tmp" "$RUN_ROOT/.snap-deleted.tmp" "$RUN_ROOT/.snap-content.tmp"' EXIT

record() {
  (cd "$GR_ROOT" && git rev-parse HEAD) > "$RUN_ROOT/.snap-head.tmp"
  (cd "$GR_ROOT" && git status --porcelain=v2) > "$RUN_ROOT/.snap-status.tmp"
  (cd "$GR_ROOT" && git ls-files -z --cached --others --exclude-standard) > "$RUN_ROOT/.snap-files.tmp"
  (cd "$GR_ROOT" && git ls-files -z --deleted) > "$RUN_ROOT/.snap-deleted.tmp"
  write_source_content_manifest "$GR_ROOT" "$RUN_ROOT/.snap-files.tmp" \
    "$RUN_ROOT/.snap-deleted.tmp" > "$RUN_ROOT/.snap-content.tmp"
  mv "$RUN_ROOT/.snap-head.tmp" "$RUN_ROOT/source-head$1.txt"
  mv "$RUN_ROOT/.snap-status.tmp" "$RUN_ROOT/source-status$1.txt"
  mv "$RUN_ROOT/.snap-content.tmp" "$RUN_ROOT/source-content$1.txt"
}

case "$MODE" in
  before)
    [ ! -e "$RUN_ROOT/source-head.txt" ] || die "a before snapshot already exists"
    record ""
    echo "recorded before snapshot"
    ;;
  after)
    [ -e "$RUN_ROOT/source-head.txt" ] || die "no before snapshot to compare with"
    record "-after"
    echo "recorded after snapshot"
    ;;
  compare)
    [ -e "$RUN_ROOT/source-head.txt" ] || die "no before snapshot"
    [ -e "$RUN_ROOT/source-head-after.txt" ] || die "no after snapshot"
    FAILED=0
    cmp -s "$RUN_ROOT/source-head.txt" "$RUN_ROOT/source-head-after.txt" || { echo "HEAD differs"; FAILED=1; }
    cmp -s "$RUN_ROOT/source-status.txt" "$RUN_ROOT/source-status-after.txt" || { echo "status differs"; FAILED=1; }
    cmp -s "$RUN_ROOT/source-content.txt" "$RUN_ROOT/source-content-after.txt" || { echo "content differs"; FAILED=1; }
    # The release gate in score-cell.sh summary reads this file.
    if [ "$FAILED" -eq 0 ]; then
      printf '{"identical": true}\n' > "$RUN_ROOT/source-compare.json"
    else
      printf '{"identical": false}\n' > "$RUN_ROOT/source-compare.json"
      exit 1
    fi
    echo "identical"
    ;;
  *) die "unknown mode: $MODE" ;;
esac
