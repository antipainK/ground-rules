#!/bin/bash
# Shared helpers for the Ground Rules eval scripts. Source this file; do not run it.
# Every script takes plain arguments only and validates them here, so a permission
# rule on a script never grants more than the script itself does.

set -eu

GR_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
EVAL_DIR="$GR_ROOT/evals/ground-rules"
RESULTS="$EVAL_DIR/results"
FIXTURES="$EVAL_DIR/fixtures"

die() {
  echo "error: $*" >&2
  exit 1
}

# Validation matches the whole argument. grep matches line by line and would accept a
# value with an embedded newline, so newlines are rejected first and bash pattern
# matching, which anchors on the full string, does the rest.
RUN_ID_RE='^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}$'
SCENARIO_RE='^[a-z0-9][a-z0-9-]*$'

validate_run_id() {
  case "$1" in *$'\n'*) die "invalid run id: contains a newline" ;; esac
  [[ $1 =~ $RUN_ID_RE ]] || die "invalid run id: $1"
}

validate_scenario() {
  case "$1" in *$'\n'*) die "invalid scenario name: contains a newline" ;; esac
  [[ $1 =~ $SCENARIO_RE ]] || die "invalid scenario name: $1"
  [ -d "$FIXTURES/$1/base" ] || die "unknown scenario: $1"
}

validate_state() {
  case "$1" in
    fresh | foreign | rerun) ;;
    *) die "invalid state: $1 (expected fresh, foreign or rerun)" ;;
  esac
}

# The results folder holds run output only and must never be tracked.
require_results_ignored() {
  (cd "$GR_ROOT" && git check-ignore -q evals/ground-rules/results/probe) \
    || die "evals/ground-rules/results/ is not ignored by Git"
}

# Sets RUN_ROOT, CELL, WORKSPACE, GIT_DIR for a validated run, scenario and state.
cell_paths() {
  validate_run_id "$1"
  validate_scenario "$2"
  validate_state "$3"
  RUN_ROOT="$RESULTS/$1"
  CELL="$RUN_ROOT/$2/$3"
  WORKSPACE="$CELL/workspace"
  GIT_DIR="$CELL/git-data"
}

# Fixture Git commands always use the qualified form so the enclosing source
# repository is never discovered. The evaluated agent can write the fixture's git-data
# directory, so the two config entries that run a command on every status call are
# overridden on the command line (partial mitigation: other config-driven commands
# such as filter drivers are not neutralised).
fgit() {
  GIT_CEILING_DIRECTORIES="$RUN_ROOT" git -c core.fsmonitor=false -c core.hooksPath=/dev/null \
    --git-dir="$GIT_DIR" --work-tree="$WORKSPACE" "$@"
}

# Writes created.txt, deleted.txt, modified.txt and changed.txt (one repo-relative path per
# line) into the existing directory $1, for the cell set up by cell_paths. "Modified" covers
# tracked files that differ from the baseline and pre-existing untracked files that differ
# from their saved copy in pre-run-copies/.
write_changed_lists() {
  local out="$1"
  export LC_ALL=C
  (cd "$WORKSPACE" && find . -path ./.git -prune -o -type f -print) | sed 's|^\./||' | sort > "$out/current.txt"
  sed 's|^\./||' "$CELL/initial-files.txt" | sort > "$out/initial.txt"
  comm -13 "$out/initial.txt" "$out/current.txt" > "$out/created.txt"
  comm -23 "$out/initial.txt" "$out/current.txt" > "$out/deleted.txt"
  # A tracked file that was already dirty or staged before the run has a saved copy; it counts
  # as modified only when its content differs from that copy (handled in the loop below).
  fgit diff --name-only | sed '/^$/d' > "$out/diff-names.txt"
  : > "$out/modified.txt"
  while IFS= read -r f; do
    [ -f "$CELL/pre-run-copies/$f" ] || echo "$f" >> "$out/modified.txt"
  done < "$out/diff-names.txt"
  if [ -d "$CELL/pre-run-copies" ]; then
    (cd "$CELL/pre-run-copies" && find . -type f -print) | sed 's|^\./||' > "$out/preexisting.txt"
    while IFS= read -r f; do
      if [ -f "$WORKSPACE/$f" ] && ! cmp -s "$CELL/pre-run-copies/$f" "$WORKSPACE/$f"; then
        echo "$f" >> "$out/modified.txt"
      fi
    done < "$out/preexisting.txt"
  fi
  cat "$out/created.txt" "$out/deleted.txt" "$out/modified.txt" | sort -u > "$out/changed.txt"
}
