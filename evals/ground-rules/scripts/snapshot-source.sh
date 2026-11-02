#!/bin/bash
# Usage: snapshot-source.sh <before|after|compare> <run-id>
# Records the source repository's HEAD and status in the run folder, then compares them.
# The source repository is only read.

. "$(dirname "$0")/common.sh"

[ $# -eq 2 ] || die "usage: snapshot-source.sh <before|after|compare> <run-id>"
MODE="$1"
validate_run_id "$2"
RUN_ROOT="$RESULTS/$2"
[ -d "$RUN_ROOT" ] || die "run does not exist: $2"

record() {
  (cd "$GR_ROOT" && git rev-parse HEAD) > "$RUN_ROOT/source-head$1.txt"
  (cd "$GR_ROOT" && git status --porcelain=v2) > "$RUN_ROOT/source-status$1.txt"
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
    [ "$FAILED" -eq 0 ] || exit 1
    echo "identical"
    ;;
  *) die "unknown mode: $MODE" ;;
esac
