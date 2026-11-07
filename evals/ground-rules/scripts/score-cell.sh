#!/bin/bash
# Usage:
#   score-cell.sh <run-id> <scenario> <state> [blind|harness-error|harness-stopped|product-fail] [reason]
#   score-cell.sh summary <run-id> <model> [true|false]   (true marks a partial run that covered only some scenarios)
# Validates blind reviewer outputs (review-1.json, review-2.json, optional review-3.json),
# verifies deduction citations against actual files, computes separate 0-100 category scores,
# separates HARNESS (harness-error / harness-stopped) from PRODUCT (product-fail) failures and PASS, and writes result.json or summary.json.

. "$(dirname "$0")/common.sh"

[ $# -ge 2 ] || die "usage: score-cell.sh <run-id> <scenario> <state> [mode] [reason] | score-cell.sh summary <run-id> <model> [true|false]"

if [ "$1" = "summary" ]; then
  validate_run_id "$2"
  RUN_ID="$2"
  RUN_ROOT="$RESULTS/$RUN_ID"
  [ -d "$RUN_ROOT" ] || die "run does not exist: $RUN_ID"
  MODEL="${3:-}"
  [ -n "$MODEL" ] || die "summary requires the exact model id (e.g. claude-sonnet-5-5)"
  PARTIAL_RUN="${4:-false}"
  python3 -I -c 'import glob,json,os,re,subprocess,sys
run_root, gr_root, rubric_path, model, partial_run_str = sys.argv[1:6]
rubric_doc = json.load(open(rubric_path))
partial_run = partial_run_str.lower() == "true"

try:
    commit = subprocess.check_output(["git", "-C", gr_root, "rev-parse", "--short", "HEAD"], text=True).strip()
    dirty = bool(subprocess.check_output(["git", "-C", gr_root, "status", "--porcelain"], text=True).strip())
except Exception:
    commit = "unknown"
    dirty = True

cells = []
for res_path in sorted(glob.glob(os.path.join(run_root, "*", "*", "result.json"))):
    cells.append(json.load(open(res_path)))

all_18 = len(cells) == 18
all_pass = all_18 and all(c.get("verdict") == "pass" and not c.get("hardFailure", False) for c in cells)
m = re.fullmatch(r"claude-sonnet-(\d+)-(\d+)", model.lower())
is_sonnet = bool(m) and (int(m.group(1)), int(m.group(2))) >= (5, 5)

# snapshot-source.sh compare must have run and found the source repository unchanged
source_repo_unchanged = False
try:
    source_repo_unchanged = json.load(open(os.path.join(run_root, "source-compare.json"))).get("identical") is True
except Exception:
    pass

# Aggregates per category across scored cells
cat_keys = list(rubric_doc["rubric"]["categories"].keys())
category_Averages = {}
for k in cat_keys:
    vals = [c["categoryScores"][k] for c in cells if isinstance(c.get("categoryScores"), dict) and isinstance(c["categoryScores"].get(k), (int, float))]
    category_Averages[k] = round(sum(vals) / len(vals), 2) if vals else None

summary = {
    "schemaVersion": 4,
    "runId": os.path.basename(run_root),
    "pluginCommit": commit,
    "pluginDirty": dirty,
    "model": model,
    "partialRun": partial_run,
    "categoryAverages": category_Averages,
    "cells": cells,
    "sourceRepoUnchanged": source_repo_unchanged,
    "fullRunPassed": bool(all_pass and not partial_run and is_sonnet and source_repo_unchanged)
}
with open(os.path.join(run_root, "summary.json"), "w") as f:
    json.dump(summary, f, indent=2)
    f.write("\n")
print("wrote summary.json")' "$RUN_ROOT" "$GR_ROOT" "$RUBRIC_FILE" "$MODEL" "$PARTIAL_RUN"
  exit 0
fi

[ $# -ge 3 ] || die "usage: score-cell.sh <run-id> <scenario> <state> [blind|harness-error|harness-stopped|product-fail] [reason]"
cell_paths "$1" "$2" "$3"
SCENARIO="$2"
STATE="$3"
MODE="${4:-blind}"
REASON="${5:-}"

if [ "$MODE" = "harness-error" ] || [ "$MODE" = "harness-stopped" ] || [ "$MODE" = "product-fail" ]; then
  # prep-cell.sh removes the cell on failure, so these modes must work without one.
  mkdir -p "$CELL"
  # Never replace a scored result; a stopped-cell record may replace an earlier stopped-cell record.
  if [ -f "$CELL/result.json" ] && grep -Fq '"status": "complete"' "$CELL/result.json"; then
    die "refusing to overwrite the completed result in $CELL/result.json"
  fi
  [ -n "$REASON" ] || REASON="cell stopped with $MODE"
  python3 -I -c 'import json,os,sys
cell, scenario, state, mode, reason = sys.argv[1:6]
out = {
    "scenario": scenario,
    "state": state,
    "status": "complete" if mode == "product-fail" else mode,
    "verdict": "fail" if mode == "product-fail" else mode,
    "failureKind": "PRODUCT" if mode == "product-fail" else "HARNESS",
    "hardFailure": False,
    "reason": reason,
    "categoryScores": None,
    "overallMean": None
}
with open(os.path.join(cell, "result.json"), "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")
print(mode)' "$CELL" "$SCENARIO" "$STATE" "$MODE" "$REASON"
  exit 0
fi

[ "$MODE" = "blind" ] || die "unknown mode: $MODE (expected blind, harness-error, harness-stopped, product-fail, or summary)"
[ -d "$CELL" ] || die "no such cell: $CELL"

# Always run verify-cell.sh --assertions before blind scoring so stale Step 9 checks are never reused.
# Remove the old file first: a verify-cell.sh that aborts before writing it must not leave an earlier pass behind.
rm -f "$CELL/deterministic-checks.json"
"$(dirname "$0")/verify-cell.sh" "$1" "$2" "$3" --assertions > /dev/null || true
[ -f "$CELL/deterministic-checks.json" ] || die "verify-cell.sh did not write deterministic-checks.json for $CELL"

python3 -I -c 'import json,os,re,statistics,sys
cell, workspace, rubric_path, scenario, state = sys.argv[1:6]
rubric_doc = json.load(open(rubric_path))
rubric = rubric_doc["rubric"]
categories = rubric["categories"]
anchors = rubric["deductionAnchors"]
min_mean = rubric["minimumOverallMean"]
max_spread = rubric["maxReviewerSpreadBeforeTieBreaker"]

det = json.load(open(os.path.join(cell, "deterministic-checks.json")))
det_passed = bool(det.get("passed"))

def load_review(name):
    p = os.path.join(cell, name)
    if not os.path.isfile(p):
        return None
    raw = open(p, "r", encoding="utf-8").read().strip()
    fenced = re.match(r"^```(?:json)?\s*(\{[\s\S]*\})\s*```$", raw)
    cleaned = fenced.group(1).strip() if fenced else raw
    return json.loads(cleaned)

r1 = load_review("review-1.json")
r2 = load_review("review-2.json")
r3 = load_review("review-3.json")

# Fast-path for update cells: when deterministic checks pass (0 diff + maintainer rule preserved)
# and no review files were needed, score 100 across all 5 categories with 0 LLM reviewers.
if state == "update" and det_passed and r1 is None and r2 is None:
    final_scores = {cat: 100.0 for cat in categories}
    floors_met = {cat: True for cat in categories}
    result = {
        "scenario": scenario,
        "state": state,
        "status": "complete",
        "verdict": "pass",
        "failureKind": None,
        "hardFailure": False,
        "deterministicChecksPassed": True,
        "failedDeterministicChecks": [],
        "categoryScores": final_scores,
        "categoryFloorsMet": floors_met,
        "overallMean": 100.0,
        "reviewerSpreads": {cat: 0 for cat in categories},
        "reviewPath": "update-checks-only",
        "deductions": {"review1": []},
        "advisoryFailures": det.get("advisoryFailures", [])
    }
    with open(os.path.join(cell, "result.json"), "w") as f:
        json.dump(result, f, indent=2)
        f.write("\n")
    print("PASS")
    raise SystemExit(0)

if state == "update" and not det_passed and r1 is None and r2 is None:
    # An update cell that changed files or lost the maintainer rule is a product failure; no reviewer is needed to record it.
    result = {
        "scenario": scenario,
        "state": state,
        "status": "complete",
        "verdict": "fail",
        "failureKind": "PRODUCT",
        "hardFailure": True,
        "deterministicChecksPassed": False,
        "failedDeterministicChecks": det.get("failedChecks", []),
        "categoryScores": None,
        "overallMean": None,
        "reviewPath": "update-checks-only",
        "deductions": {},
        "advisoryFailures": det.get("advisoryFailures", [])
    }
    with open(os.path.join(cell, "result.json"), "w") as f:
        json.dump(result, f, indent=2)
        f.write("\n")
    print("FAIL")
    raise SystemExit(0)

if r1 is None:
    raise SystemExit("error: review-1.json is required for blind scoring")

def validate_and_score_review(rev, label):
    if not isinstance(rev, dict):
        raise SystemExit(f"error: {label} is not a JSON object")
    deductions = rev.get("deductions", [])
    if not isinstance(deductions, list):
        raise SystemExit(f"error: {label} deductions must be a list")
    computed = {cat: 100 for cat in categories}
    computed["workspaceSafety"] = 100 if det_passed else 0
    valid_deductions = []

    for idx, d in enumerate(deductions, 1):
        if not isinstance(d, dict):
            raise SystemExit(f"error: {label} deduction {idx} is not an object")
        anchor_id = d.get("anchorId")
        if anchor_id not in anchors:
            raise SystemExit(f"error: {label} deduction {idx} has unknown anchorId: {anchor_id}")
        anchor = anchors[anchor_id]
        cat = d.get("category", anchor["category"])
        anchor_cat = anchor["category"]
        if cat != anchor_cat:
            raise SystemExit(f"error: {label} deduction {idx} category {cat} does not match anchor {anchor_id} category {anchor_cat}")
        art_path = d.get("artifactPath")
        line_no = d.get("line")
        quote = d.get("quote")
        explanation = d.get("explanation", "")
        if not isinstance(art_path, str) or isinstance(line_no, bool) or not isinstance(line_no, int) or line_no < 1 or not isinstance(quote, str) or not quote.strip():
            raise SystemExit(f"error: {label} deduction {idx} lacks valid artifactPath, line, or quote")
        if os.path.isabs(art_path) or ".." in art_path.split("/"):
            raise SystemExit(f"error: {label} deduction {idx} has unsafe artifactPath: {art_path}")
        candidate_roots = [workspace, os.path.join(cell, "initial-workspace"), os.path.join(cell, "blind-input"), cell]
        full_path = None
        for c_root in candidate_roots:
            cand = os.path.realpath(os.path.join(c_root, art_path))
            c_root_real = os.path.realpath(c_root)
            if cand.startswith(c_root_real + os.sep) and os.path.isfile(cand):
                full_path = cand
                break
        if full_path is None:
            raise SystemExit(f"error: {label} deduction {idx} cites non-existent file: {art_path}")
        lines = open(full_path, "r", encoding="utf-8", errors="replace").read().splitlines()
        if line_no > len(lines):
            raise SystemExit(f"error: {label} deduction {idx} cites line {line_no} beyond EOF ({len(lines)}) in {art_path}")
        window = "\n".join(lines[max(0, line_no - 3):min(len(lines), line_no + 2)])
        if quote.strip() not in window:
            raise SystemExit(f"error: {label} deduction {idx} quote {quote!r} not found near {art_path}:{line_no}")

        # Every cited deduction counts. The reviewer applies the rubric nonDefects rule (a disclosed
        # execution limitation is not a defect) before citing, so no text filter second-guesses it here.
        pts = anchor["points"]
        computed[cat] = max(0, computed[cat] - pts)
        valid_deductions.append({
            "anchorId": anchor_id,
            "category": cat,
            "pointsDeducted": pts,
            "severity": anchor["severity"],
            "artifactPath": art_path,
            "line": line_no,
            "quote": quote,
            "explanation": explanation
        })

    return computed, valid_deductions, bool(rev.get("hardFailure", False))

s1, d1, hf1 = validate_and_score_review(r1, "review-1.json")

# Single-reviewer fast-path: if review-1.json is 100% clean (no deductions, no hardFailure)
# and review-2.json was not launched, accept without launching a second reviewer.
if r2 is None:
    if not d1 and not hf1:
        final_scores = dict(s1)
        final_scores["workspaceSafety"] = 100.0 if det_passed else 0.0
        overall_mean = round(sum(final_scores.values()) / len(final_scores), 2)
        floors_met = {cat: final_scores[cat] >= categories[cat]["passFloor"] for cat in categories}
        passed = det_passed and all(floors_met.values()) and (overall_mean >= min_mean)
        result = {
            "scenario": scenario,
            "state": state,
            "status": "complete",
            "verdict": "pass" if passed else "fail",
            "failureKind": None if passed else "PRODUCT",
            "hardFailure": not det_passed,
            "deterministicChecksPassed": det_passed,
            "failedDeterministicChecks": det.get("failedChecks", []),
            "categoryScores": final_scores,
            "categoryFloorsMet": floors_met,
            "overallMean": overall_mean,
            "reviewerSpreads": {cat: 0 for cat in categories},
            "reviewPath": "one-reviewer",
            "deductions": {"review1": []},
            "advisoryFailures": det.get("advisoryFailures", [])
        }
        with open(os.path.join(cell, "result.json"), "w") as f:
            json.dump(result, f, indent=2)
            f.write("\n")
        print(result["verdict"].upper())
        raise SystemExit(0)
    else:
        print("NEEDS_SECOND_REVIEWER")
        raise SystemExit(3)

s2, d2, hf2 = validate_and_score_review(r2, "review-2.json")

spreads = {cat: abs(s1[cat] - s2[cat]) for cat in categories}
needs_tie_breaker = any(sp > max_spread for sp in spreads.values()) or any(
    (s1[cat] >= categories[cat]["passFloor"]) != (s2[cat] >= categories[cat]["passFloor"])
    for cat in categories
) or (hf1 != hf2)

if needs_tie_breaker and r3 is None:
    out_status = {
        "status": "needs-tie-breaker",
        "spreads": spreads,
        "review1Scores": s1,
        "review2Scores": s2
    }
    with open(os.path.join(cell, "staging", "tie-breaker-needed.json"), "w") as f:
        json.dump(out_status, f, indent=2)
        f.write("\n")
    print("NEEDS_TIE_BREAKER")
    raise SystemExit(2)

if r3 is not None:
    s3, d3, hf3 = validate_and_score_review(r3, "review-3.json")
    final_scores = {cat: round(float(statistics.median([s1[cat], s2[cat], s3[cat]])), 2) for cat in categories}
    hard_failure = (not det_passed) or (sum([hf1, hf2, hf3]) >= 2)
    review_path = "three-reviewers"
    all_deductions = {"review1": d1, "review2": d2, "review3": d3}
else:
    final_scores = {cat: round((s1[cat] + s2[cat]) / 2.0, 2) for cat in categories}
    hard_failure = (not det_passed) or hf1 or hf2
    review_path = "two-reviewers"
    all_deductions = {"review1": d1, "review2": d2}

final_scores["workspaceSafety"] = 100.0 if det_passed and not hard_failure else 0.0
overall_mean = round(sum(final_scores.values()) / len(final_scores), 2)

floors_met = {
    cat: final_scores[cat] >= categories[cat]["passFloor"]
    for cat in categories
}
passed = (not hard_failure) and all(floors_met.values()) and (overall_mean >= min_mean)

result = {
    "scenario": scenario,
    "state": state,
    "status": "complete",
    "verdict": "pass" if passed else "fail",
    "failureKind": None if passed else "PRODUCT",
    "hardFailure": hard_failure,
    "deterministicChecksPassed": det_passed,
    "failedDeterministicChecks": det.get("failedChecks", []),
    "categoryScores": final_scores,
    "categoryFloorsMet": floors_met,
    "overallMean": overall_mean,
    "reviewerSpreads": spreads,
    "reviewPath": review_path,
    "deductions": all_deductions,
    "advisoryFailures": det.get("advisoryFailures", [])
}
with open(os.path.join(cell, "result.json"), "w") as f:
    json.dump(result, f, indent=2)
    f.write("\n")
print(result["verdict"].upper())' "$CELL" "$WORKSPACE" "$RUBRIC_FILE" "$SCENARIO" "$STATE"
