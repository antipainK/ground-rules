#!/bin/bash
# Usage: test-scripts.sh [scripts|config|all]
#   scripts  behavioural and static tests of the eval scripts
#   config   checks of the published settings, skill, agent and README
# Behavioural tests run in a throwaway run folder under results/ that is removed on exit.

. "$(dirname "$0")/common.sh"
set +e

GROUP="${1:-all}"
case "$GROUP" in scripts | config | all) ;; *) die "usage: test-scripts.sh [scripts|config|all]" ;; esac

SCRIPTS="$EVAL_DIR/scripts"
TEST_RUN="20000101T000000Z-0e5700"
TEST_RUN2="20000101T000000Z-0e5701"
TEST_RUN3="20000101T000000Z-0e5702"
GENERATED=""
TMP_REPO=""
PASSED=0
FAILED=0
SKIPPED=0
NL=$'\n'

pass() { echo "PASS $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL $1: $2"; FAILED=$((FAILED + 1)); }
skip() { echo "SKIP $1: $2"; SKIPPED=$((SKIPPED + 1)); }

run() { OUT=$("$@" 2>&1); RC=$?; }

expect_ok() {
  ID="$1"; shift
  run "$@"
  if [ "$RC" -eq 0 ]; then pass "$ID"; else fail "$ID" "exit $RC: $OUT"; fi
}

expect_fail() {
  ID="$1"; NEEDLE="$2"; shift 2
  run "$@"
  if [ "$RC" -ne 0 ] && echo "$OUT" | grep -Fq "$NEEDLE"; then pass "$ID"; else fail "$ID" "exit $RC, wanted failure containing '$NEEDLE': $OUT"; fi
}

check_cell_for() { run "$SCRIPTS/check-cell.sh" "$TEST_RUN" empty-python-cli "$1"; }
check_cell() { check_cell_for fresh; }

# Helpers for the state tests, which use TEST_RUN2 and TEST_RUN3.
check2() { run "$SCRIPTS/check-cell.sh" "$TEST_RUN2" "$1" "$2"; }

expect2_pass() {
  check2 "$2" "$3"
  if [ "$RC" -eq 0 ]; then pass "$1"; else fail "$1" "$OUT"; fi
}

expect2_fail() {
  ID="$1"; NEEDLE="$4"
  check2 "$2" "$3"
  if [ "$RC" -ne 0 ] && echo "$OUT" | grep -F "$NEEDLE" | grep -Fq "FAIL"; then pass "$ID"; else fail "$ID" "wanted FAIL row '$NEEDLE': $OUT"; fi
}

no_cell() {
  if [ ! -e "$RESULTS/$TEST_RUN2/$2/$3" ]; then pass "$1"; else fail "$1" "a cell was left behind: $2/$3"; fi
}

# Prints the rerun rule text, or the first topic, for a scenario from matrix.json.
matrix_rule() {
  python3 -I -c 'import json,sys
r = [x for x in json.load(open(sys.argv[1]))["scenarios"] if x["id"] == sys.argv[2]][0]["rerunMaintainerRule"]
print(r["text"] if sys.argv[3] == "text" else r["topics"][0])' "$EVAL_DIR/matrix.json" "$1" "$2"
}

expect_check_pass() {
  check_cell
  if [ "$RC" -eq 0 ]; then pass "$1"; else fail "$1" "$OUT"; fi
}

expect_check_fail() {
  ID="$1"; NEEDLE="$2"
  check_cell
  if [ "$RC" -ne 0 ] && echo "$OUT" | grep -F "$NEEDLE" | grep -Fq "FAIL"; then pass "$ID"; else fail "$ID" "wanted FAIL row '$NEEDLE': $OUT"; fi
}

cleanup() {
  rm -rf "${RESULTS:?}/$TEST_RUN" "${RESULTS:?}/$TEST_RUN2" "${RESULTS:?}/$TEST_RUN3"
  if [ -n "$GENERATED" ]; then rm -rf "${RESULTS:?}/$GENERATED"; fi
  if [ -n "$TMP_REPO" ]; then rm -rf "$TMP_REPO"; fi
}
trap cleanup EXIT

run_scripts_group() {
  cleanup

  # T1 new-run.sh creates a run
  GENERATED=$("$SCRIPTS/new-run.sh" 2>&1)
  if echo "$GENERATED" | grep -Eq '^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}$' && [ -d "$RESULTS/$GENERATED" ]; then
    pass T1
    rm -rf "${RESULTS:?}/$GENERATED"
  else
    fail T1 "got: $GENERATED"
  fi
  GENERATED=""

  expect_ok setup "$SCRIPTS/new-run.sh" "$TEST_RUN"

  # T2 to T5 argument validation
  expect_fail T2 "invalid run id" "$SCRIPTS/prepare-cell.sh" bad-id empty-python-cli fresh
  expect_fail T3 "unknown scenario" "$SCRIPTS/prepare-cell.sh" "$TEST_RUN" nope-scenario fresh
  if [ ! -e "$RESULTS/$TEST_RUN/nope-scenario" ]; then pass T3-nocreate; else fail T3-nocreate "folder was created"; fi
  expect_fail T4 "invalid state" "$SCRIPTS/prepare-cell.sh" "$TEST_RUN" empty-python-cli bogus
  expect_fail T5a "invalid run id" "$SCRIPTS/prepare-cell.sh" "../x" empty-python-cli fresh
  expect_fail T5b "invalid run id" "$SCRIPTS/new-run.sh" "../x"
  if [ ! -e "$EVAL_DIR/x" ] && [ ! -e "$RESULTS/x" ]; then pass T5c; else fail T5c "traversal id created a path"; fi

  # T38 to T42 whole-argument validation: a newline must not smuggle in a second line
  LS_BEFORE=$(ls -A "$RESULTS" | cksum)
  NL_ID="20260101T000000Z-abcdef${NL}../../../../zz"
  expect_fail T38 "invalid run id" "$SCRIPTS/new-run.sh" "$NL_ID"
  expect_fail T39 "invalid run id" "$SCRIPTS/prepare-cell.sh" "$NL_ID" empty-python-cli fresh
  expect_fail T40 "invalid scenario name" "$SCRIPTS/prepare-cell.sh" "$TEST_RUN" "empty-python-cli${NL}x" fresh
  expect_fail T41 "invalid scenario name" "$SCRIPTS/prepare-cell.sh" "$TEST_RUN" "-x" fresh
  if [ "$LS_BEFORE" = "$(ls -A "$RESULTS" | cksum)" ]; then pass T42; else fail T42 "results folder changed after rejected arguments"; fi

  # T6 the results-ignored guard refuses when results/ is not ignored (run in a throwaway repository)
  TMP_REPO=$(mktemp -d "${TMPDIR:-/tmp}/ground-rules-test.XXXXXX")
  if [ -n "$TMP_REPO" ] && [ -d "$TMP_REPO" ]; then
    mkdir -p "$TMP_REPO/evals/ground-rules/scripts"
    cp "$SCRIPTS/common.sh" "$SCRIPTS/new-run.sh" "$TMP_REPO/evals/ground-rules/scripts/"
    git init -q "$TMP_REPO" 2> /dev/null
    expect_fail T6a "not ignored" "$TMP_REPO/evals/ground-rules/scripts/new-run.sh"
    echo 'evals/ground-rules/results/' > "$TMP_REPO/.gitignore"
    expect_ok T6b "$TMP_REPO/evals/ground-rules/scripts/new-run.sh"
    rm -rf "$TMP_REPO"
  else
    fail T6 "could not create a temporary directory"
  fi
  TMP_REPO=""

  # T7 fresh cell
  expect_ok T7-run "$SCRIPTS/prepare-cell.sh" "$TEST_RUN" empty-python-cli fresh
  cell_paths "$TEST_RUN" empty-python-cli fresh
  if [ -f "$WORKSPACE/LICENSE" ] && [ -f "$WORKSPACE/README.md" ] && [ -z "$(fgit status --porcelain=v2 --untracked-files=all)" ] \
    && [ "$(cat "$CELL/pre-head.txt")" = "$(fgit rev-parse HEAD)" ]; then pass T7; else fail T7 "workspace, status or pre-head wrong"; fi

  # T9 Git layout (fresh)
  TOP=$(fgit rev-parse --show-toplevel)
  if [ -f "$WORKSPACE/.git" ] && [ -f "$GIT_DIR/HEAD" ] && [ "$TOP" = "$(cd "$WORKSPACE" && pwd -P)" ]; then pass T9; else fail T9 "layout wrong, top=$TOP"; fi

  # T11 no identity written by the script
  if [ ! -r "$GIT_DIR/config" ]; then
    fail T11 "git-data/config is missing or unreadable"
  elif grep -q '^\[user\]' "$GIT_DIR/config"; then
    fail T11 "[user] section in git-data/config"
  else
    pass T11
  fi

  # T12 existing cell is not overwritten
  BEFORE=$(cksum < "$WORKSPACE/README.md")
  expect_fail T12 "cell already exists" "$SCRIPTS/prepare-cell.sh" "$TEST_RUN" empty-python-cli fresh
  if [ "$BEFORE" = "$(cksum < "$WORKSPACE/README.md")" ]; then pass T12-intact; else fail T12-intact "existing file changed"; fi

  # T8 foreign cell
  expect_ok T8-run "$SCRIPTS/prepare-cell.sh" "$TEST_RUN" empty-python-cli foreign
  cell_paths "$TEST_RUN" empty-python-cli foreign
  if [ -f "$WORKSPACE/.cursorrules" ] && fgit status --porcelain=v2 --untracked-files=all | grep -Fq '? .cursorrules' \
    && ! fgit ls-tree -r --name-only HEAD | grep -Fq '.cursorrules'; then pass T8; else fail T8 ".cursorrules missing, tracked, or not untracked"; fi

  # T10 every Git call in prepare-cell.sh is qualified
  UNQUAL=$(grep -nE '(^|[[:space:];&|(])git[[:space:]]' "$SCRIPTS/prepare-cell.sh" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -v -e '--git-dir' -e '--separate-git-dir')
  if [ -z "$UNQUAL" ]; then pass T10; else fail T10 "unqualified: $UNQUAL"; fi

  # T48 pre-existing untracked files are compared with their saved copy
  check_cell_for foreign
  if [ "$RC" -eq 0 ] && echo "$OUT" | grep -Fq '| 0 changed |'; then pass T48-baseline; else fail T48-baseline "$OUT"; fi
  echo "extra" >> "$WORKSPACE/.cursorrules"
  check_cell_for foreign
  if [ "$RC" -eq 0 ] && echo "$OUT" | grep -Fq '| 1 changed |'; then pass T48-edited; else fail T48-edited "$OUT"; fi
  rm "$WORKSPACE/.cursorrules"
  check_cell_for foreign
  if [ "$RC" -eq 0 ] && echo "$OUT" | grep -Fq '| 1 changed |'; then pass T48-deleted; else fail T48-deleted "$OUT"; fi
  cp "$CELL/pre-run-copies/.cursorrules" "$WORKSPACE/.cursorrules"
  check_cell_for foreign
  if [ "$RC" -eq 0 ] && echo "$OUT" | grep -Fq '| 0 changed |'; then pass T48-restored; else fail T48-restored "$OUT"; fi

  # T13 and T14 source snapshot
  expect_ok T13-before "$SCRIPTS/snapshot-source.sh" before "$TEST_RUN"
  expect_ok T13-after "$SCRIPTS/snapshot-source.sh" after "$TEST_RUN"
  run "$SCRIPTS/snapshot-source.sh" compare "$TEST_RUN"
  if [ "$RC" -eq 0 ] && echo "$OUT" | grep -Fxq identical; then pass T13; else fail T13 "$OUT"; fi
  if ls -A "$RESULTS/$TEST_RUN" | grep -Fq '.snap-'; then fail T13-clean "temporary snapshot files were left behind"; else pass T13-clean; fi
  echo "tampered" >> "$RESULTS/$TEST_RUN/source-status.txt"
  expect_fail T14 "status differs" "$SCRIPTS/snapshot-source.sh" compare "$TEST_RUN"
  echo "tampered" >> "$RESULTS/$TEST_RUN/source-head.txt"
  expect_fail T14-head "HEAD differs" "$SCRIPTS/snapshot-source.sh" compare "$TEST_RUN"

  # T15 to T21 deterministic checks on the fresh cell
  cell_paths "$TEST_RUN" empty-python-cli fresh
  mkdir -p "$WORKSPACE/.ai" "$WORKSPACE/docs"
  printf '# Title\n\nLast reviewed: 2026-01-01\n\n- Read `.ai/testing.md` before tests.\n' > "$WORKSPACE/AGENTS.md"
  printf '# Testing\n\nLast reviewed: 2026-01-01\n\n- Keep tests isolated. Project decision\n' > "$WORKSPACE/.ai/testing.md"
  printf '# Note\n' > "$WORKSPACE/docs/note.md"
  expect_check_pass T15

  fgit add AGENTS.md
  expect_check_fail T16 "nothing staged"
  fgit reset -q
  expect_check_pass T16-undo

  mkdir -p "$WORKSPACE/src"
  echo "print(1)" > "$WORKSPACE/src/app.py"
  expect_check_fail T17 "changed paths inside allowed prefixes"
  rm -rf "$WORKSPACE/src"
  expect_check_pass T17-undo

  cp "$WORKSPACE/AGENTS.md" "$CELL/AGENTS.md.saved"
  yes line | head -n 151 > "$WORKSPACE/AGENTS.md"
  expect_check_fail T18 "AGENTS.md at most 150 lines"
  cp "$CELL/AGENTS.md.saved" "$WORKSPACE/AGENTS.md"
  expect_check_pass T18-undo

  printf '# Extra\n\n<!-- ground-rules:managed -->\n' > "$WORKSPACE/.ai/extra.md"
  expect_check_fail T19 "no ownership marker or hash registry"
  rm "$WORKSPACE/.ai/extra.md"
  expect_check_pass T19-undo

  printf 'token: ghp_%s\n' "$(yes a | head -n 36 | tr -d '\n')" > "$WORKSPACE/docs/leak.md"
  expect_check_fail T20 "no secret-shaped value"
  printf 'key AKIAIOSFODNN7EXAMPLE\n' > "$WORKSPACE/docs/leak.md"
  expect_check_fail T20-aws "no secret-shaped value"
  printf 'x xoxb-1234567890-abcdefghij\n' > "$WORKSPACE/docs/leak.md"
  expect_check_fail T20-slack "no secret-shaped value"
  printf -- '-----BEGIN RSA PRIVATE KEY-----\n' > "$WORKSPACE/docs/leak.md"
  expect_check_fail T20-pem "no secret-shaped value"
  rm "$WORKSPACE/docs/leak.md"
  expect_check_pass T20-undo

  fgit commit --allow-empty -q -m "temporary"
  expect_check_fail T21 "HEAD unchanged"
  fgit reset -q --soft HEAD~1
  expect_check_pass T21-undo

  # T43 to T47 the remaining check-cell rows can fail
  echo "extra" >> "$WORKSPACE/README.md"
  expect_check_fail T43 "no tracked file modified"
  fgit checkout -q -- README.md
  expect_check_pass T43-undo

  rm "$WORKSPACE/LICENSE"
  expect_check_fail T44 "changed paths inside allowed prefixes"
  if echo "$OUT" | grep -Fq 'outside: LICENSE'; then pass T44-detail; else fail T44-detail "$OUT"; fi
  fgit checkout -q -- LICENSE
  expect_check_pass T44-undo

  printf -- '- Also read `.ai/missing.md`.\n' >> "$WORKSPACE/AGENTS.md"
  expect_check_fail T45 "AGENTS.md pointers resolve"
  cp "$CELL/AGENTS.md.saved" "$WORKSPACE/AGENTS.md"
  expect_check_pass T45-undo

  printf '# Orphan\n' > "$WORKSPACE/.ai/orphan.md"
  expect_check_fail T46 ".ai files reachable from AGENTS.md"
  rm "$WORKSPACE/.ai/orphan.md"
  expect_check_pass T46-undo

  yes line | head -n 301 > "$WORKSPACE/.ai/long.md"
  expect_check_fail T47 ".ai files at most 300 lines"
  rm "$WORKSPACE/.ai/long.md"
  expect_check_pass T47-undo

  # T53 to T55 nested AGENTS.md files and docs are checked too
  mkdir -p "$WORKSPACE/docs/sub"
  printf '# Nested\n\n<!-- ground-rules:managed -->\n' > "$WORKSPACE/docs/sub/AGENTS.md"
  expect_check_fail T53 "no ownership marker or hash registry"
  yes line | head -n 151 > "$WORKSPACE/docs/sub/AGENTS.md"
  expect_check_fail T54 "AGENTS.md at most 150 lines"
  rm -rf "$WORKSPACE/docs/sub"
  printf '# Doc\n\n<!-- ground-rules:managed -->\n' > "$WORKSPACE/docs/marked.md"
  expect_check_fail T55 "no ownership marker or hash registry"
  rm "$WORKSPACE/docs/marked.md"
  expect_check_pass T53-undo

  # T56 a command configured in the agent-writable git-data does not run during checks
  MARK="$CELL/fsmonitor-ran"
  rm -f "$MARK"
  fgit config core.fsmonitor "sh -c 'touch $MARK' --"
  GIT_CEILING_DIRECTORIES="$RUN_ROOT" git --git-dir="$GIT_DIR" --work-tree="$WORKSPACE" status --porcelain=v2 > /dev/null 2>&1
  if [ -e "$MARK" ]; then
    rm -f "$MARK"
    check_cell
    if [ ! -e "$MARK" ]; then pass T56; else fail T56 "core.fsmonitor command ran during check-cell"; fi
  else
    skip T56 "control did not fire: this Git version did not run the core.fsmonitor command"
  fi
  rm -f "$MARK"
  fgit config --unset core.fsmonitor
  expect_check_pass T56-undo

  # T50 and T51 blind-input folder
  expect_ok T50-run "$SCRIPTS/prepare-blind-input.sh" "$TEST_RUN" empty-python-cli fresh
  BLIND_FILES=$(ls -A "$CELL/blind-input" | sort | tr '\n' ' ')
  if [ "$BLIND_FILES" = "changed-paths.txt rubric.json " ]; then pass T50-files; else fail T50-files "unexpected contents: $BLIND_FILES"; fi
  if ls -A "$CELL" | grep -Fq '.blind-'; then fail T50-clean "temporary folders were left behind"; else pass T50-clean; fi
  if python3 -I -c 'import json,sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if d.get("rubric") and d.get("hardFailures") else 1)' "$CELL/blind-input/rubric.json"; then pass T50-rubric; else fail T50-rubric "rubric.json lacks rubric or hardFailures"; fi
  if grep -Fxq 'created: AGENTS.md' "$CELL/blind-input/changed-paths.txt" \
    && grep -Fxq 'created: .ai/testing.md' "$CELL/blind-input/changed-paths.txt" \
    && grep -Fxq 'created: docs/note.md' "$CELL/blind-input/changed-paths.txt"; then pass T50-paths; else fail T50-paths "$(cat "$CELL/blind-input/changed-paths.txt")"; fi
  expect_fail T51 "already exists" "$SCRIPTS/prepare-blind-input.sh" "$TEST_RUN" empty-python-cli fresh

  # T22 to T24 append-log.sh
  printf 'first\n' > "$CELL/pending-transcript.md"
  expect_ok T22-a "$SCRIPTS/append-log.sh" "$TEST_RUN" empty-python-cli fresh transcript
  printf 'second\n' > "$CELL/pending-transcript.md"
  expect_ok T22-b "$SCRIPTS/append-log.sh" "$TEST_RUN" empty-python-cli fresh transcript
  if [ "$(cat "$CELL/transcript.md")" = "$(printf 'first\nsecond')" ] && [ ! -e "$CELL/pending-transcript.md" ]; then pass T22; else fail T22 "log content or pending file wrong"; fi

  expect_fail T23-kind "unknown kind" "$SCRIPTS/append-log.sh" "$TEST_RUN" empty-python-cli fresh bogus
  expect_fail T23-pending "no pending content" "$SCRIPTS/append-log.sh" "$TEST_RUN" empty-python-cli fresh transcript

  TRICKY='{"q":"$HOME `id` \"x\" {a,b}","r":"it'"'"'s"}'
  printf '%s\n' "$TRICKY" > "$CELL/pending-authorization.ndjson"
  expect_ok T24-run "$SCRIPTS/append-log.sh" "$TEST_RUN" empty-python-cli fresh authorization
  if grep -Fxq "$TRICKY" "$CELL/authorization.ndjson"; then pass T24; else fail T24 "tricky line was altered"; fi

  # T25 static scan: no eval, process substitution or xargs; syntax valid
  BAD=""
  for f in "$SCRIPTS"/*.sh; do
    [ "$(basename "$f")" = "test-scripts.sh" ] && continue
    if grep -vE '^[[:space:]]*#' "$f" | grep -qE '(^|[^a-zA-Z_])eval[[:space:]]|<\(|>\(|xargs'; then BAD="$BAD $(basename "$f")"; fi
  done
  for f in "$SCRIPTS"/*.sh; do
    bash -n "$f" 2> /dev/null || BAD="$BAD syntax:$(basename "$f")"
  done
  if [ -z "$BAD" ]; then pass T25; else fail T25 "$BAD"; fi

}

# T33 (rerun state) and T34 (legacy pre-run edits) are covered by T60 to T84.
run_states_group() {
  rm -rf "${RESULTS:?}/$TEST_RUN2" "${RESULTS:?}/$TEST_RUN3"
  expect_ok states-setup "$SCRIPTS/new-run.sh" "$TEST_RUN2"

  # T60 and T61 the matrix carries a usable rule for every scenario
  run python3 -I -c 'import json,sys
m = json.load(open(sys.argv[1]))
ok = m.get("schemaVersion") == 3
print("ok" if ok else "schemaVersion is " + str(m.get("schemaVersion")))
sys.exit(0 if ok else 1)' "$EVAL_DIR/matrix.json"
  if [ "$RC" -eq 0 ]; then pass T60; else fail T60 "$OUT"; fi
  run python3 -I -c 'import json,re,sys
m = json.load(open(sys.argv[1]))
problems = []
for s in m["scenarios"]:
    r = s.get("rerunMaintainerRule")
    if not r:
        problems.append(s["id"] + ": no rerunMaintainerRule")
        continue
    t = r.get("topics")
    if not t or not all(isinstance(x, str) and re.match(r"^[a-z0-9-]+$", x) for x in t):
        problems.append(s["id"] + ": bad topics")
    x = r.get("text", "")
    if "\n" in x or not x.startswith("- ") or not x.endswith("Project decision"):
        problems.append(s["id"] + ": bad text")
print("; ".join(problems) if problems else "ok")
sys.exit(1 if problems else 0)' "$EVAL_DIR/matrix.json"
  if [ "$RC" -eq 0 ]; then pass T61; else fail T61 "$OUT"; fi

  # T62 to T68 legacy-node-service fresh: planted edits and what the checks do with them
  expect_ok T62-run "$SCRIPTS/prepare-cell.sh" "$TEST_RUN2" legacy-node-service fresh
  cell_paths "$TEST_RUN2" legacy-node-service fresh
  if [ "$(cat "$CELL/pre-staged.txt")" = "README.md" ] && [ "$(cat "$CELL/pre-unstaged.txt")" = "src/server.js" ] \
    && [ "$(tail -n1 "$WORKSPACE/src/server.js")" = "// operator edit: do not commit" ] \
    && [ "$(tail -n1 "$WORKSPACE/README.md")" = "- Unreleased: operator note." ] \
    && [ "$(fgit rev-list --count HEAD)" = "1" ] && [ "$(fgit diff --cached --name-only)" = "README.md" ]; then
    pass T62
  else
    fail T62 "planted edits, staging or records are wrong"
  fi
  if cmp -s "$CELL/pre-run-copies/README.md" "$WORKSPACE/README.md" && cmp -s "$CELL/pre-run-copies/src/server.js" "$WORKSPACE/src/server.js"; then pass T63; else fail T63 "saved copies differ from the workspace"; fi
  check2 legacy-node-service fresh
  if [ "$RC" -eq 0 ] && echo "$OUT" | grep -Fq '| 0 changed |'; then pass T64; else fail T64 "$OUT"; fi

  echo "// target edit" >> "$WORKSPACE/src/server.js"
  expect2_fail T65 legacy-node-service fresh "changed paths inside allowed prefixes"
  if echo "$OUT" | grep -Fq 'outside: src/server.js'; then pass T65-detail; else fail T65-detail "$OUT"; fi
  cp "$CELL/pre-run-copies/src/server.js" "$WORKSPACE/src/server.js"
  expect2_pass T65-undo legacy-node-service fresh

  echo "{}" >> "$WORKSPACE/package.json"
  fgit add -- package.json
  expect2_fail T66 legacy-node-service fresh "nothing staged"
  fgit reset -q -- package.json
  fgit checkout -q -- package.json
  expect2_pass T66-undo legacy-node-service fresh

  fgit reset -q -- README.md
  expect2_fail T67 legacy-node-service fresh "nothing staged"
  fgit add -- README.md
  expect2_pass T67-undo legacy-node-service fresh

  echo "- extra" >> "$WORKSPACE/README.md"
  expect2_fail T68 legacy-node-service fresh "no tracked file modified"
  if echo "$OUT" | grep -F "changed paths inside allowed prefixes" | grep -Fq FAIL; then pass T68-path; else fail T68-path "$OUT"; fi
  cp "$CELL/pre-run-copies/README.md" "$WORKSPACE/README.md"
  expect2_pass T68-undo legacy-node-service fresh

  # T69 a fixture file that cannot be copied stops the script and leaves no cell
  if [ "$(id -u)" = "0" ]; then
    skip T69 "running as root: file permissions cannot block a copy"
  else
    TMP_REPO=$(mktemp -d "${TMPDIR:-/tmp}/ground-rules-test.XXXXXX")
    if [ -n "$TMP_REPO" ] && [ -d "$TMP_REPO" ]; then
      mkdir -p "$TMP_REPO/evals/ground-rules/scripts" "$TMP_REPO/evals/ground-rules/fixtures/x/base"
      cp "$SCRIPTS/common.sh" "$SCRIPTS/new-run.sh" "$SCRIPTS/prepare-cell.sh" "$TMP_REPO/evals/ground-rules/scripts/"
      printf 'ok\n' > "$TMP_REPO/evals/ground-rules/fixtures/x/base/ok.txt"
      printf 'blocked\n' > "$TMP_REPO/evals/ground-rules/fixtures/x/base/blocked.txt"
      chmod 000 "$TMP_REPO/evals/ground-rules/fixtures/x/base/blocked.txt"
      echo 'evals/ground-rules/results/' > "$TMP_REPO/.gitignore"
      git init -q "$TMP_REPO" 2> /dev/null
      "$TMP_REPO/evals/ground-rules/scripts/new-run.sh" "$TEST_RUN2" > /dev/null 2>&1
      expect_fail T69 "could not copy" "$TMP_REPO/evals/ground-rules/scripts/prepare-cell.sh" "$TEST_RUN2" x fresh
      if [ ! -e "$TMP_REPO/evals/ground-rules/results/$TEST_RUN2/x" ]; then pass T69-clean; else fail T69-clean "a half-built cell was left behind"; fi
      rm -rf "$TMP_REPO"
    else
      fail T69 "could not create a temporary directory"
    fi
    TMP_REPO=""
  fi

  # T70 to T82 rerun preparation on empty-python-cli, refusals first
  expect_ok T70-setup "$SCRIPTS/prepare-cell.sh" "$TEST_RUN2" empty-python-cli fresh
  cell_paths "$TEST_RUN2" empty-python-cli fresh
  FRESH2="$CELL"
  expect_fail T70 "has not passed" "$SCRIPTS/prepare-cell.sh" "$TEST_RUN2" empty-python-cli rerun
  no_cell T70-nocell empty-python-cli rerun
  printf '{"verdict": "fail"}\n' > "$FRESH2/result.json"
  expect_fail T71 "has not passed" "$SCRIPTS/prepare-cell.sh" "$TEST_RUN2" empty-python-cli rerun
  no_cell T71-nocell empty-python-cli rerun
  printf '{"verdict": "pass"}\n' > "$FRESH2/result.json"

  expect_fail T82 "no .ai file matches" "$SCRIPTS/prepare-cell.sh" "$TEST_RUN2" empty-python-cli rerun
  no_cell T82-nocell empty-python-cli rerun

  mkdir -p "$WORKSPACE/.ai"
  printf '# Other\n\n- x. Project decision\n' > "$WORKSPACE/.ai/other.md"
  expect_fail T79 "no .ai file matches" "$SCRIPTS/prepare-cell.sh" "$TEST_RUN2" empty-python-cli rerun
  if echo "$OUT" | grep -Fq 'other.md'; then pass T79-lists; else fail T79-lists "the message does not list the .ai files found: $OUT"; fi
  no_cell T79-nocell empty-python-cli rerun

  printf '# Testing\n\n- a. Project decision\n' > "$WORKSPACE/.ai/testing.md"
  printf '# Tests\n\n- b. Project decision\n' > "$WORKSPACE/.ai/tests.md"
  expect_fail T78 "ambiguous" "$SCRIPTS/prepare-cell.sh" "$TEST_RUN2" empty-python-cli rerun
  if echo "$OUT" | grep -Fq 'testing.md' && echo "$OUT" | grep -Fq 'tests.md'; then pass T78-lists; else fail T78-lists "$OUT"; fi
  no_cell T78-nocell empty-python-cli rerun
  rm "$WORKSPACE/.ai/tests.md"

  RULE=$(matrix_rule empty-python-cli text)
  printf '%s\n' "$RULE" >> "$WORKSPACE/.ai/testing.md"
  expect_fail T80 "already present" "$SCRIPTS/prepare-cell.sh" "$TEST_RUN2" empty-python-cli rerun
  no_cell T80-nocell empty-python-cli rerun
  printf '# Testing\n\n- a. Project decision\n' > "$WORKSPACE/.ai/testing.md"

  # T72 and T73 rerun succeeds with exactly one added line in exactly one file
  expect_ok T72-run "$SCRIPTS/prepare-cell.sh" "$TEST_RUN2" empty-python-cli rerun
  cell_paths "$TEST_RUN2" empty-python-cli rerun
  SUBJECTS=$(fgit log --format=%s | tr '\n' '|')
  if [ "$SUBJECTS" = "Maintainer policy addition|Fixture baseline|" ] && [ -z "$(fgit status --porcelain=v2 --untracked-files=all)" ] \
    && [ -f "$WORKSPACE/.git" ] && [ "$(grep -Fxc -e "$RULE" "$WORKSPACE/.ai/testing.md")" = "1" ] \
    && [ "$(sed -n 1p "$CELL/maintainer-rule.txt")" = ".ai/testing.md" ] && [ "$(sed -n 2p "$CELL/maintainer-rule.txt")" = "$RULE" ]; then
    pass T72
  else
    fail T72 "commits: $SUBJECTS; rule count: $(grep -Fxc -e "$RULE" "$WORKSPACE/.ai/testing.md")"
  fi
  if [ "$(fgit diff --name-only HEAD~1 HEAD)" = ".ai/testing.md" ] && [ "$(fgit diff --numstat HEAD~1 HEAD)" = "1"$'\t'"0"$'\t'".ai/testing.md" ]; then pass T73; else fail T73 "the maintainer commit is not a one-line addition to .ai/testing.md"; fi

  # T74 to T76 the rerun checks
  check2 empty-python-cli rerun
  if [ "$RC" -eq 0 ] && echo "$OUT" | grep -F "rerun produced no diff" | grep -Fq PASS && echo "$OUT" | grep -F "maintainer rule preserved" | grep -Fq PASS; then pass T74; else fail T74 "$OUT"; fi

  mkdir -p "$WORKSPACE/docs"
  printf '# New\n' > "$WORKSPACE/docs/new.md"
  expect2_fail T75 empty-python-cli rerun "rerun produced no diff"
  rm -rf "$WORKSPACE/docs"
  expect2_pass T75-undo empty-python-cli rerun

  grep -vxF -e "$RULE" "$WORKSPACE/.ai/testing.md" > "$CELL/testing.md.without"
  cp "$CELL/testing.md.without" "$WORKSPACE/.ai/testing.md"
  expect2_fail T76 empty-python-cli rerun "maintainer rule preserved"
  fgit checkout -q -- .ai/testing.md
  expect2_pass T76-undo empty-python-cli rerun

  # T77 an existing rerun cell is not overwritten
  BEFORE=$(cksum < "$WORKSPACE/.ai/testing.md")
  expect_fail T77 "cell already exists" "$SCRIPTS/prepare-cell.sh" "$TEST_RUN2" empty-python-cli rerun
  if [ "$BEFORE" = "$(cksum < "$WORKSPACE/.ai/testing.md")" ]; then pass T77-intact; else fail T77-intact "an existing file changed"; fi

  # T81 a file is matched by its first heading, not only by its name
  expect_ok T81-setup "$SCRIPTS/prepare-cell.sh" "$TEST_RUN2" polyglot-monorepo fresh
  cell_paths "$TEST_RUN2" polyglot-monorepo fresh
  printf '{"verdict": "pass"}\n' > "$CELL/result.json"
  mkdir -p "$WORKSPACE/.ai"
  printf '# Architecture\n\n- Layers stay separate. Project decision\n' > "$WORKSPACE/.ai/rules.md"
  expect_ok T81-run "$SCRIPTS/prepare-cell.sh" "$TEST_RUN2" polyglot-monorepo rerun
  cell_paths "$TEST_RUN2" polyglot-monorepo rerun
  RULE_P=$(matrix_rule polyglot-monorepo text)
  if [ "$(sed -n 1p "$CELL/maintainer-rule.txt")" = ".ai/rules.md" ] && [ "$(grep -Fxc -e "$RULE_P" "$WORKSPACE/.ai/rules.md")" = "1" ]; then pass T81; else fail T81 "the rule did not go into .ai/rules.md exactly once"; fi
  expect2_pass T81-check polyglot-monorepo rerun

  # T83 and T84 every scenario prepares cleanly in each state, and every rerun rule resolves
  expect_ok T83-setup "$SCRIPTS/new-run.sh" "$TEST_RUN3"
  for d in "$FIXTURES"/*/; do
    s=$(basename "$d")
    for st in fresh foreign; do
      run "$SCRIPTS/prepare-cell.sh" "$TEST_RUN3" "$s" "$st"
      if [ "$RC" -ne 0 ] && echo "$OUT" | grep -Fq 'could not copy'; then
        skip "T83-$s-$st" "blocked by the sandbox: $(echo "$OUT" | head -1 | cut -c1-150)"
        continue
      fi
      if [ "$RC" -ne 0 ]; then fail "T83-$s-$st" "prepare failed: $OUT"; continue; fi
      run "$SCRIPTS/check-cell.sh" "$TEST_RUN3" "$s" "$st"
      if [ "$RC" -eq 0 ]; then pass "T83-$s-$st"; else fail "T83-$s-$st" "$OUT"; fi
    done
  done
  for d in "$FIXTURES"/*/; do
    s=$(basename "$d")
    if [ ! -d "$RESULTS/$TEST_RUN3/$s/fresh/workspace" ]; then skip "T84-$s" "no fresh cell (blocked earlier)"; continue; fi
    cell_paths "$TEST_RUN3" "$s" fresh
    TOPIC=$(matrix_rule "$s" topic)
    RULE_S=$(matrix_rule "$s" text)
    printf '{"verdict": "pass"}\n' > "$CELL/result.json"
    mkdir -p "$WORKSPACE/.ai"
    printf '# %s\n\n- Existing rule. Project decision\n' "$TOPIC" > "$WORKSPACE/.ai/$TOPIC.md"
    run "$SCRIPTS/prepare-cell.sh" "$TEST_RUN3" "$s" rerun
    if [ "$RC" -ne 0 ]; then fail "T84-$s" "rerun prepare failed: $OUT"; continue; fi
    cell_paths "$TEST_RUN3" "$s" rerun
    run "$SCRIPTS/check-cell.sh" "$TEST_RUN3" "$s" rerun
    if [ "$RC" -eq 0 ] && [ "$(grep -Fxc -e "$RULE_S" "$WORKSPACE/.ai/$TOPIC.md")" = "1" ]; then pass "T84-$s"; else fail "T84-$s" "$OUT"; fi
  done
}

run_config_group() {
  SETTINGS="$GR_ROOT/.claude/settings.json"
  SKILL="$GR_ROOT/.claude/skills/ground-rules-eval/SKILL.md"
  README="$EVAL_DIR/README.md"

  # T26 settings parse
  if python3 -I -m json.tool "$SETTINGS" > /dev/null 2>&1; then pass T26; else fail T26 "settings.json is not valid JSON"; fi

  # T27 existing entries preserved
  run python3 -I -c 'import json,sys
allow = json.load(open(sys.argv[1])).get("permissions", {}).get("allow", [])
need = sys.argv[2:]
missing = [e for e in need if e not in allow]
print("missing: " + ", ".join(missing)) if missing else print("ok")
sys.exit(1 if missing else 0)' "$SETTINGS" 'Bash(git check-ignore *)' 'Bash(echo "exit=$?")' 'Edit(evals/ground-rules/results/**)' 'Write(evals/ground-rules/results/**)' 'SendMessage' 'Agent(general-purpose)'
  if [ "$RC" -eq 0 ]; then pass T27; else fail T27 "$OUT"; fi

  # T28 one exact allow entry per script; no folder wildcard, no broad Bash
  run python3 -I -c 'import json,re,sys
allow = json.load(open(sys.argv[1])).get("permissions", {}).get("allow", [])
need = ["new-run.sh", "prepare-cell.sh", "snapshot-source.sh", "check-cell.sh", "append-log.sh", "prepare-blind-input.sh"]
known = ["Bash(git check-ignore *)", "Bash(echo \"exit=$?\")", "Bash(cmp *)"]
problems = []
found = []
for e in allow:
    if not (e == "Bash" or e.startswith("Bash(")):
        continue
    if e in ("Bash", "Bash(*)", "Bash(**)"):
        problems.append("broad: " + e)
        continue
    m = re.match(r"^Bash\(evals/ground-rules/scripts/([a-z-]+\.sh) \*\)$", e)
    if m:
        found.append(m.group(1))
    elif "evals/ground-rules/scripts" in e:
        problems.append("not an exact script entry: " + e)
    elif e not in known:
        problems.append("unexpected: " + e)
for n in need:
    if n not in found:
        problems.append("missing entry for " + n)
for n in found:
    if n not in need:
        problems.append("script not in the expected list: " + n)
print("; ".join(problems) if problems else "ok")
sys.exit(1 if problems else 0)' "$SETTINGS"
  if [ "$RC" -eq 0 ]; then pass T28; else fail T28 "$OUT"; fi

  # T29 protection entries for the scripts, the settings file, the agent and the skill
  run python3 -I -c 'import json,sys
d = json.load(open(sys.argv[1]))
ask = d.get("permissions", {}).get("ask", [])
deny = d.get("sandbox", {}).get("filesystem", {}).get("denyWrite", [])
problems = []
for e in ["Edit(/evals/ground-rules/scripts/**)", "Edit(/.claude/settings.json)", "Edit(/.claude/agents/**)", "Edit(/.claude/skills/**)"]:
    if e not in ask:
        problems.append("ask lacks " + e)
for part in ["evals/ground-rules/scripts", ".claude/agents"]:
    if not any(part in p for p in deny):
        problems.append("sandbox.filesystem.denyWrite lacks " + part)
print("; ".join(problems) if problems else "ok")
sys.exit(1 if problems else 0)' "$SETTINGS"
  if [ "$RC" -eq 0 ]; then pass T29; else fail T29 "$OUT"; fi

  # T30 skill has no inline constructs that trigger the checks
  HITS=$(grep -nE '<<|<\(|\$\(|python3 -I -' "$SKILL")
  if [ -z "$HITS" ]; then pass T30; else fail T30 "$(echo "$HITS" | head -5 | tr '\n' ' ')"; fi

  # T31 safety boundary unchanged (compared through a temporary file, so results/ need not exist)
  BOUNDARY_NOW=$(mktemp "${TMPDIR:-/tmp}/ground-rules-boundary.XXXXXX")
  sed -n '/^## Safety boundary$/,/^## Inputs$/{/^## Inputs$/!p;}' "$SKILL" > "$BOUNDARY_NOW"
  if cmp -s "$BOUNDARY_NOW" "$SCRIPTS/testdata/skill-boundary.txt"; then pass T31; else fail T31 "boundary section differs from testdata/skill-boundary.txt"; fi
  rm -f "$BOUNDARY_NOW"

  # T35 reviewer agent is read-only, T36 skill launches it in both places, T37 settings allow it (and do not deny it)
  AGENT="$GR_ROOT/.claude/agents/eval-reviewer.md"
  TOOLS_LINE=$(grep -m1 '^tools:' "$AGENT" 2> /dev/null)
  if [ "$TOOLS_LINE" = "tools: Read, Glob, Grep" ]; then pass T35; else fail T35 "agent tools line is: ${TOOLS_LINE:-missing}"; fi
  if [ "$(grep -c 'fresh `eval-reviewer`' "$SKILL")" -ge 2 ]; then pass T36; else fail T36 "skill does not launch eval-reviewer for both review loops"; fi
  run python3 -I -c 'import json,sys
d = json.load(open(sys.argv[1])).get("permissions", {})
ok = "Agent(eval-reviewer)" in d.get("allow", []) and "Agent(eval-reviewer)" not in d.get("deny", [])
sys.exit(0 if ok else 1)' "$SETTINGS"
  if [ "$RC" -eq 0 ]; then pass T37; else fail T37 "Agent(eval-reviewer) is not allowed, or is denied, in settings"; fi

  # T52 skill builds the blind inputs with the script
  if grep -Fq 'prepare-blind-input.sh <run-id> <scenario> <state>' "$SKILL"; then pass T52; else fail T52 "skill does not use prepare-blind-input.sh <run-id> <scenario> <state>"; fi

  # T32 README names every script and the permission entries
  MISSING=""
  for n in new-run.sh prepare-cell.sh snapshot-source.sh check-cell.sh append-log.sh prepare-blind-input.sh test-scripts.sh denyWrite; do
    grep -Fq "$n" "$README" || MISSING="$MISSING $n"
  done
  if [ -z "$MISSING" ]; then pass T32; else fail T32 "README lacks:$MISSING"; fi

  # T85 the skill no longer lists the states as unsupported and requires a verdict in result.json
  if ! grep -Fq 'Not yet scripted' "$SKILL" && grep -Fq '"verdict": "pass"' "$SKILL"; then pass T85; else fail T85 "skill still lists unsupported states or does not mention the verdict"; fi

  # T86 the README documents the matrix field
  if grep -Fq 'rerunMaintainerRule' "$README" && grep -Fq 'legacy-node-service' "$README"; then pass T86; else fail T86 "README does not document rerunMaintainerRule and the legacy state"; fi
}

if [ "$GROUP" != "config" ]; then
  run_scripts_group
  run_states_group
fi
[ "$GROUP" = "scripts" ] || run_config_group

echo
echo "passed: $PASSED, failed: $FAILED, skipped: $SKIPPED"
[ "$FAILED" -eq 0 ]
