#!/bin/bash
# Shared helpers for the Ground Rules eval scripts. Source this file; do not run it.
# Every script takes plain arguments only and validates them here, so a broad
# allow rule on this folder never grants more than the scripts themselves do.

set -eu

GR_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
EVAL_DIR="$GR_ROOT/evals/ground-rules"
RESULTS="$EVAL_DIR/results"
FIXTURES="$EVAL_DIR/fixtures"

die() {
  echo "error: $*" >&2
  exit 1
}

validate_run_id() {
  echo "$1" | grep -Eq '^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}$' || die "invalid run id: $1"
}

validate_scenario() {
  echo "$1" | grep -Eq '^[a-z0-9-]+$' || die "invalid scenario name: $1"
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
# repository is never discovered.
fgit() {
  GIT_CEILING_DIRECTORIES="$RUN_ROOT" git --git-dir="$GIT_DIR" --work-tree="$WORKSPACE" "$@"
}
