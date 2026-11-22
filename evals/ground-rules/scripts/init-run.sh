#!/bin/bash
# Usage: init-run.sh [run-id]
# Creates evals/ground-rules/results/<run-id>/ and prints the run id.
# Without an argument the id is an ISO UTC timestamp plus a short random suffix.

. "$(dirname "$0")/common.sh"

[ $# -le 1 ] || die "usage: init-run.sh [run-id]"

require_results_ignored

if [ $# -eq 1 ]; then
  RUN_ID="$1"
else
  RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"
fi
validate_run_id "$RUN_ID"

[ ! -e "$RESULTS/$RUN_ID" ] || die "run already exists: $RUN_ID"
mkdir -p "$RESULTS/$RUN_ID"
echo "$RUN_ID"
