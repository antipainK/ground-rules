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
GENERATED=""
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
  rm -rf "${RESULTS:?}/$TEST_RUN"
  if [ -n "$GENERATED" ]; then rm -rf "${RESULTS:?}/$GENERATED"; fi
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

  # T6 results-ignored guard exists
  if grep -q 'check-ignore' "$SCRIPTS/common.sh"; then pass T6; else fail T6 "no git check-ignore guard in common.sh"; fi

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
  echo "tampered" >> "$RESULTS/$TEST_RUN/source-status.txt"
  expect_fail T14 "status differs" "$SCRIPTS/snapshot-source.sh" compare "$TEST_RUN"

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

  # T50 and T51 blind-input folder
  expect_ok T50-run "$SCRIPTS/prepare-blind-input.sh" "$TEST_RUN" empty-python-cli fresh
  BLIND_FILES=$(ls -A "$CELL/blind-input" | sort | tr '\n' ' ')
  if [ "$BLIND_FILES" = "changed-paths.txt rubric.json " ]; then pass T50-files; else fail T50-files "unexpected contents: $BLIND_FILES"; fi
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

  skip T33 "optional S9 (rerun state) not built"
  skip T34 "optional S9 (legacy-node-service pre-run edits) not built"
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

  # T29 protection entries
  run python3 -I -c 'import json,sys
d = json.load(open(sys.argv[1]))
ask = d.get("permissions", {}).get("ask", [])
deny = d.get("sandbox", {}).get("filesystem", {}).get("denyWrite", [])
problems = []
if "Edit(/evals/ground-rules/scripts/**)" not in ask:
    problems.append("ask lacks Edit(/evals/ground-rules/scripts/**)")
if not any("evals/ground-rules/scripts" in p for p in deny):
    problems.append("sandbox.filesystem.denyWrite lacks the scripts folder")
print("; ".join(problems) if problems else "ok")
sys.exit(1 if problems else 0)' "$SETTINGS"
  if [ "$RC" -eq 0 ]; then pass T29; else fail T29 "$OUT"; fi

  # T30 skill has no inline constructs that trigger the checks
  HITS=$(grep -nE '<<|<\(|\$\(|python3 -I -' "$SKILL")
  if [ -z "$HITS" ]; then pass T30; else fail T30 "$(echo "$HITS" | head -5 | tr '\n' ' ')"; fi

  # T31 safety boundary unchanged
  sed -n '/^## Safety boundary$/,/^## Inputs$/{/^## Inputs$/!p;}' "$SKILL" > "$RESULTS/.boundary-now.txt"
  if cmp -s "$RESULTS/.boundary-now.txt" "$SCRIPTS/testdata/skill-boundary.txt"; then pass T31; else fail T31 "boundary section differs from testdata/skill-boundary.txt"; fi
  rm -f "$RESULTS/.boundary-now.txt"

  # T35 reviewer agent is read-only, T36 skill uses it, T37 settings allow it
  AGENT="$GR_ROOT/.claude/agents/eval-reviewer.md"
  TOOLS_LINE=$(grep -m1 '^tools:' "$AGENT" 2> /dev/null)
  if [ "$TOOLS_LINE" = "tools: Read, Glob, Grep" ]; then pass T35; else fail T35 "agent tools line is: ${TOOLS_LINE:-missing}"; fi
  if grep -Fq 'eval-reviewer' "$SKILL"; then pass T36; else fail T36 "skill does not name eval-reviewer"; fi
  if grep -Fq '"Agent(eval-reviewer)"' "$SETTINGS"; then pass T37; else fail T37 "settings lack Agent(eval-reviewer)"; fi

  # T52 skill builds the blind inputs with the script
  if grep -Fq 'prepare-blind-input.sh' "$SKILL"; then pass T52; else fail T52 "skill does not use prepare-blind-input.sh"; fi

  # T32 README names every script and the permission entries
  MISSING=""
  for n in new-run.sh prepare-cell.sh snapshot-source.sh check-cell.sh append-log.sh prepare-blind-input.sh test-scripts.sh denyWrite; do
    grep -Fq "$n" "$README" || MISSING="$MISSING $n"
  done
  if [ -z "$MISSING" ]; then pass T32; else fail T32 "README lacks:$MISSING"; fi
}

[ "$GROUP" = "config" ] || run_scripts_group
[ "$GROUP" = "scripts" ] || run_config_group

echo
echo "passed: $PASSED, failed: $FAILED, skipped: $SKIPPED"
[ "$FAILED" -eq 0 ]
