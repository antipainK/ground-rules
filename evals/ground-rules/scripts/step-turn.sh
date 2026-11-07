#!/bin/bash
# Usage: step-turn.sh <run-id> <scenario> <state> <lock-agents|target|persona|workflow-review|apply-fs|git-inspect|transcript|authorization> [arg1] [arg2]
# Script-owned turn processor and append-only audit logger:
#   lock-agents <target-id> <persona-id>
#     Writes <cell>/agent-ids.json once and locks it read-only.
#   target
#     Reads <cell>/staging/target-turn.txt (or <cell>/pending-transcript.md), strips markdown
#     code fences if present, validates the target JSON schema, verifies workspace safety,
#     defaults missing affectedPaths/draftFiles on options to [], appends the resulting
#     canonical JSON line to transcript.md, auto-answers purely mechanical
#     lifecycle prompts when unambiguous, and writes <cell>/staging/next-step.json.
#   persona
#     Reads <cell>/staging/persona-turn.txt, validates the persona JSON schema against the
#     last unanswered target turn, appends accepted entries to authorization.ndjson, compiles
#     deduplicated authorization.json, and writes the target relay payload to
#     <cell>/staging/next-step.json.
#   transcript | authorization
#     Direct append compatibility for pending-transcript.md / pending-authorization.ndjson.

. "$(dirname "$0")/common.sh"

[ $# -ge 4 ] || die "usage: step-turn.sh <run-id> <scenario> <state> <mode> [args...]"
cell_paths "$1" "$2" "$3"
SCENARIO="$2"
STATE="$3"
MODE="$4"
[ -d "$CELL" ] || die "no such cell: $CELL"
mkdir -p "$CELL/staging"

append_newline_safe() {
  local src="$1" dst="$2"
  if [ -s "$dst" ] && [ "$(tail -c1 "$dst" | od -An -c | tr -d ' ')" != '\n' ]; then
    echo >> "$dst"
  fi
  cat "$src" >> "$dst"
}

compile_auth_json() {
  python3 -I -c 'import json,os,sys
ndjson_path, json_path = sys.argv[1:3]
entries = []
seen = set()
if os.path.isfile(ndjson_path):
    with open(ndjson_path, "rb") as f:
        for line in f:
            rec = line[:-1] if line.endswith(b"\n") else line
            if rec.strip() and rec not in seen:
                seen.add(rec)
                entries.append(json.loads(rec))
with open(json_path, "w") as out:
    json.dump(entries, out, indent=2)
    out.write("\n")' "$CELL/authorization.ndjson" "$CELL/authorization.json"
}

case "$MODE" in
  lock-agents)
    [ $# -eq 6 ] || die "usage: step-turn.sh <run-id> <scenario> <state> lock-agents <target-id> <persona-id>"
    TARGET_ID="$5"
    PERSONA_ID="$6"
    [ -n "$TARGET_ID" ] && [ -n "$PERSONA_ID" ] || die "agent ids must be non-empty"
    [ "$TARGET_ID" != "$PERSONA_ID" ] || die "target and persona agent ids must be distinct"
    [ ! -e "$CELL/agent-ids.json" ] || die "agent-ids.json already exists in $CELL"
    python3 -I -c 'import json,sys
with open(sys.argv[3], "w") as f:
    json.dump({"target": sys.argv[1], "persona": sys.argv[2]}, f, indent=2)
    f.write("\n")' "$TARGET_ID" "$PERSONA_ID" "$CELL/agent-ids.json"
    chmod 444 "$CELL/agent-ids.json"
    echo "locked agent-ids.json"
    ;;

  transcript)
    PENDING="$CELL/pending-transcript.md"
    [ -s "$PENDING" ] || die "no pending content: $PENDING"
    append_newline_safe "$PENDING" "$CELL/transcript.md"
    rm "$PENDING"
    echo "appended to transcript.md"
    ;;

  authorization)
    PENDING="$CELL/pending-authorization.ndjson"
    [ -s "$PENDING" ] || die "no pending content: $PENDING"
    append_newline_safe "$PENDING" "$CELL/authorization.ndjson"
    rm "$PENDING"
    compile_auth_json
    echo "appended to authorization.ndjson"
    ;;

  target)
    INPUT="$CELL/staging/target-turn.txt"
    if [ ! -s "$INPUT" ] && [ -s "$CELL/pending-transcript.md" ]; then
      INPUT="$CELL/pending-transcript.md"
    fi
    [ -s "$INPUT" ] || die "no target turn input at $INPUT"
    verify_git_safety || die "workspace Git safety check failed on target turn"

    python3 -I -c 'import json,os,re,sys
input_path, cell, scenario_file, state = sys.argv[1:5]
raw = open(input_path, "r", encoding="utf-8").read().strip()
fenced = re.match(r"^```(?:json)?\s*(\{[\s\S]*\})\s*```$", raw)
cleaned = fenced.group(1).strip() if fenced else raw

agent_ids = {}
agent_ids_path = os.path.join(cell, "agent-ids.json")
if os.path.isfile(agent_ids_path):
    agent_ids = json.load(open(agent_ids_path))

def write_next(payload):
    with open(os.path.join(cell, "staging", "next-step.json"), "w") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")
    print(payload["action"])

try:
    obj = json.loads(cleaned)
except Exception as exc:
    write_next({
        "action": "RETRY_TARGET_FORMAT",
        "resumeRole": "target",
        "resumeAgentId": agent_ids.get("target"),
        "reason": f"invalid JSON: {exc}",
        "retryPrompt": "Return the previous still-unanswered user decision again, unchanged, as a single valid JSON object in the required target format."
    })
    raise SystemExit(0)

if not isinstance(obj, dict) or "status" not in obj:
    write_next({
        "action": "RETRY_TARGET_FORMAT",
        "resumeRole": "target",
        "resumeAgentId": agent_ids.get("target"),
        "reason": "missing status key",
        "retryPrompt": "Return the previous still-unanswered user decision again, unchanged, as a single valid JSON object in the required target format."
    })
    raise SystemExit(0)

status = obj.get("status")
if status == "needs-answer":
    qs = obj.get("questions")
    if not isinstance(qs, list) or not qs:
        write_next({
            "action": "RETRY_TARGET_FORMAT",
            "resumeRole": "target",
            "resumeAgentId": agent_ids.get("target"),
            "reason": "needs-answer requires non-empty questions list",
            "retryPrompt": "Return the previous still-unanswered user decision again, unchanged, with a non-empty questions array where every question has text and options."
        })
        raise SystemExit(0)
    for idx, q in enumerate(qs, 1):
        if not isinstance(q, dict) or not isinstance(q.get("text"), str) or not isinstance(q.get("options"), list) or not q.get("options"):
            write_next({
                "action": "RETRY_TARGET_FORMAT",
                "resumeRole": "target",
                "resumeAgentId": agent_ids.get("target"),
                "reason": f"question {idx} lacks valid text or options array",
                "retryPrompt": "Return the previous still-unanswered user decision again, unchanged, ensuring every question object includes text and a non-empty options array."
            })
            raise SystemExit(0)
        for opt in q["options"]:
            if not isinstance(opt, dict) or not isinstance(opt.get("text"), str):
                write_next({
                    "action": "RETRY_TARGET_FORMAT",
                    "resumeRole": "target",
                    "resumeAgentId": agent_ids.get("target"),
                    "reason": f"question {idx} has malformed option",
                    "retryPrompt": "Return the previous still-unanswered user decision again, unchanged, ensuring every option has a string text field."
                })
                raise SystemExit(0)
            opt.setdefault("affectedPaths", [])
            opt.setdefault("draftFiles", [])
elif status == "needs-workflow-review":
    if not isinstance(obj.get("writtenPaths"), list) or not isinstance(obj.get("sanitizedDecisionRecord"), list):
        write_next({
            "action": "RETRY_TARGET_FORMAT",
            "resumeRole": "target",
            "resumeAgentId": agent_ids.get("target"),
            "reason": "needs-workflow-review requires writtenPaths and sanitizedDecisionRecord arrays"
        })
        raise SystemExit(0)
    with open(os.path.join(cell, "decision-record.json"), "w") as df:
        json.dump(obj["sanitizedDecisionRecord"], df, indent=2)
        df.write("\n")
elif status == "complete":
    if not isinstance(obj.get("finalReport"), str):
        write_next({
            "action": "RETRY_TARGET_FORMAT",
            "resumeRole": "target",
            "resumeAgentId": agent_ids.get("target"),
            "reason": "complete requires finalReport string"
        })
        raise SystemExit(0)
    dec_path = os.path.join(cell, "decision-record.json")
    if not os.path.isfile(dec_path):
        with open(dec_path, "w") as df:
            df.write("[]\n")
    auth_ndjson = os.path.join(cell, "authorization.ndjson")
    if not os.path.isfile(auth_ndjson):
        open(auth_ndjson, "w").close()
    auth_json = os.path.join(cell, "authorization.json")
    if not os.path.isfile(auth_json):
        with open(auth_json, "w") as aj:
            aj.write("[]\n")
elif status == "protocol-error":
    write_next({
        "action": "HARNESS_ERROR",
        "reason": obj.get("reason", "target reported protocol-error")
    })
    raise SystemExit(0)
else:
    write_next({
        "action": "RETRY_TARGET_FORMAT",
        "resumeRole": "target",
        "resumeAgentId": agent_ids.get("target"),
        "reason": f"unknown status: {status}"
    })
    raise SystemExit(0)

# Append canonical single-line JSON to transcript.md
transcript_path = os.path.join(cell, "transcript.md")
with open(transcript_path, "a", encoding="utf-8") as tf:
    tf.write(json.dumps(obj, ensure_ascii=False) + "\n")

with open(os.path.join(cell, "staging", "last-target-turn.json"), "w", encoding="utf-8") as ltf:
    json.dump(obj, ltf, ensure_ascii=False, indent=2)
    ltf.write("\n")

if status == "needs-workflow-review":
    write_next({
        "action": "RUN_WORKFLOW_REVIEW",
        "writtenPaths": obj["writtenPaths"]
    })
    raise SystemExit(0)

if status == "complete":
    write_next({
        "action": "TARGET_COMPLETE",
        "finalReport": obj["finalReport"]
    })
    raise SystemExit(0)

# Check if all questions in this needs-answer turn are purely mechanical lifecycle prompts
scenario = json.load(open(scenario_file))
ps = scenario.get("policySpec", {})
auto_answers = []
for idx, q in enumerate(obj["questions"], 1):
    opts = [o["text"] for o in q["options"]]
    matched = None
    reason = None
    if state == "rerun" and any(o.startswith("Focused update") for o in opts):
        matched = next(o for o in opts if o.startswith("Focused update"))
        reason = "In the rerun state, choose the presented run-choice option whose label starts with Focused update."
    elif state == "foreign" and any(o.startswith(scenario.get("foreignRunChoice", "__none__")) for o in opts):
        frc = scenario["foreignRunChoice"]
        matched = next(o for o in opts if o.startswith(frc))
        reason = f"Foreign run choice: {frc}"
    elif any(o.startswith("Continue without commit") for o in opts) and any("Stop to clean index" in o for o in opts):
        matched = next(o for o in opts if o.startswith("Continue without commit"))
        reason = "When pre-existing staged work is reported, choose Continue without commit."
    elif any(o.startswith("Don'\''t commit") or o.startswith("Do not commit") for o in opts) and any(o.startswith("Commit") for o in opts):
        matched = next(o for o in opts if o.startswith("Don'\''t commit") or o.startswith("Do not commit"))
        reason = "Decline commit and push."
    elif ps.get("docsGovernance") == "Snapshot + living docs" and any(o.startswith("Snapshot + living docs") for o in opts) and any("Pointers only" in o for o in opts):
        matched = next(o for o in opts if o.startswith("Snapshot + living docs"))
        reason = "Choose the Snapshot + living docs governance policy."
    elif ps.get("structure") == "Focused files" and any(o.startswith("Focused files") for o in opts) and any(o.startswith("Compact file") for o in opts):
        matched = next(o for o in opts if o.startswith("Focused files"))
        reason = "Choose Focused files."
    elif ps.get("toolingChoice") == "Document rules only" and any(o.startswith("Document rules only") for o in opts) and any("Bootstrap tooling" in o for o in opts):
        matched = next(o for o in opts if o.startswith("Document rules only"))
        reason = "Document rules only; do not create a manifest or commands."
    if matched is not None:
        auto_answers.append({
            "questionIndex": idx,
            "question": q,
            "selectedOptions": [matched],
            "freeText": None,
            "authorizedBy": [reason]
        })

if len(auto_answers) == len(obj["questions"]):
    auth_ndjson = os.path.join(cell, "authorization.ndjson")
    with open(auth_ndjson, "a", encoding="utf-8") as af:
        for entry in auto_answers:
            af.write(json.dumps(entry, ensure_ascii=False) + "\n")
    relay = [
        {
            "questionIndex": a["questionIndex"],
            "selectedOptions": a["selectedOptions"],
            "freeText": a["freeText"]
        }
        for a in auto_answers
    ]
    write_next({
        "action": "AUTO_ANSWERED_RESUME_TARGET",
        "resumeRole": "target",
        "resumeAgentId": agent_ids.get("target"),
        "relayAnswers": relay
    })
else:
    write_next({
        "action": "ASK_PERSONA",
        "resumeRole": "persona",
        "resumeAgentId": agent_ids.get("persona"),
        "questions": obj["questions"]
    })
' "$INPUT" "$CELL" "$SCENARIO_FILE" "$STATE"
    rm -f "$INPUT"
    if [ -f "$CELL/authorization.ndjson" ]; then
      compile_auth_json
    fi
    ;;

  persona)
    INPUT="$CELL/staging/persona-turn.txt"
    [ -s "$INPUT" ] || die "no persona turn input at $INPUT"
    [ -f "$CELL/staging/last-target-turn.json" ] || die "no last-target-turn.json to bind persona answers to"

    python3 -I -c 'import json,os,re,sys
input_path, cell, state = sys.argv[1:4]
raw = open(input_path, "r", encoding="utf-8").read().strip()
fenced = re.match(r"^```(?:json)?\s*(\{[\s\S]*\})\s*```$", raw)
cleaned = fenced.group(1).strip() if fenced else raw

agent_ids = {}
agent_ids_path = os.path.join(cell, "agent-ids.json")
if os.path.isfile(agent_ids_path):
    agent_ids = json.load(open(agent_ids_path))

def write_next(payload):
    with open(os.path.join(cell, "staging", "next-step.json"), "w") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")
    print(payload["action"])

try:
    p = json.loads(cleaned)
except Exception as exc:
    write_next({
        "action": "RETRY_PERSONA_FORMAT",
        "resumeRole": "persona",
        "resumeAgentId": agent_ids.get("persona"),
        "reason": f"invalid persona JSON: {exc}"
    })
    raise SystemExit(0)

if not isinstance(p, dict) or p.get("status") not in ("answered", "unresolved"):
    write_next({
        "action": "RETRY_PERSONA_FORMAT",
        "resumeRole": "persona",
        "resumeAgentId": agent_ids.get("persona"),
        "reason": "persona status must be answered or unresolved"
    })
    raise SystemExit(0)

if p["status"] == "unresolved":
    write_next({
        "action": "CELL_BLOCKED",
        # In rerun the persona holds no answers, so a question it cannot answer means the target
        # re-interviewed the maintainer: a product failure. Elsewhere it is a harness or scenario gap.
        "failureKind": "PRODUCT_FAIL" if state == "rerun" else "HARNESS_ERROR",
        "questionIndex": p.get("questionIndex", 1),
        "reason": p.get("reason", "persona returned unresolved")
    })
    raise SystemExit(0)

target_turn = json.load(open(os.path.join(cell, "staging", "last-target-turn.json")))
questions = target_turn["questions"]
answers = p.get("answers")
if not isinstance(answers, list) or len(answers) != len(questions):
    write_next({
        "action": "RETRY_PERSONA_FORMAT",
        "resumeRole": "persona",
        "resumeAgentId": agent_ids.get("persona"),
        "reason": "persona answers length does not match target questions length"
    })
    raise SystemExit(0)

records = []
relay = []
for idx, (q, ans) in enumerate(zip(questions, answers), 1):
    if not isinstance(ans, dict) or ans.get("questionIndex") != idx:
        write_next({
            "action": "RETRY_PERSONA_FORMAT",
            "resumeRole": "persona",
            "resumeAgentId": agent_ids.get("persona"),
            "reason": f"questionIndex mismatch at {idx}"
        })
        raise SystemExit(0)
    sel = ans.get("selectedOptions")
    ft = ans.get("freeText")
    auth_by = ans.get("authorizedBy")
    if not isinstance(sel, list) or (not sel and not isinstance(ft, str)) or (sel and ft is not None):
        write_next({
            "action": "RETRY_PERSONA_FORMAT",
            "resumeRole": "persona",
            "resumeAgentId": agent_ids.get("persona"),
            "reason": f"question {idx} must provide either selectedOptions or freeText, not both"
        })
        raise SystemExit(0)
    if not isinstance(auth_by, list) or not auth_by:
        write_next({
            "action": "RETRY_PERSONA_FORMAT",
            "resumeRole": "persona",
            "resumeAgentId": agent_ids.get("persona"),
            "reason": f"question {idx} lacks authorizedBy array"
        })
        raise SystemExit(0)
    opt_texts = {o["text"] for o in q.get("options", [])}
    for s in sel:
        if s not in opt_texts:
            write_next({
                "action": "RETRY_PERSONA_FORMAT",
                "resumeRole": "persona",
                "resumeAgentId": agent_ids.get("persona"),
                "reason": f"selected option {s!r} is not in question {idx} options"
            })
            raise SystemExit(0)
    records.append({
        "questionIndex": idx,
        "question": q,
        "selectedOptions": sel,
        "freeText": ft,
        "authorizedBy": auth_by
    })
    relay.append({
        "questionIndex": idx,
        "selectedOptions": sel,
        "freeText": ft
    })

auth_ndjson = os.path.join(cell, "authorization.ndjson")
with open(auth_ndjson, "a", encoding="utf-8") as af:
    for r in records:
        af.write(json.dumps(r, ensure_ascii=False) + "\n")

write_next({
    "action": "RESUME_TARGET",
    "resumeRole": "target",
    "resumeAgentId": agent_ids.get("target"),
    "relayAnswers": relay
})
' "$INPUT" "$CELL" "$STATE"
    rm -f "$INPUT"
    compile_auth_json
    ;;

  workflow-review)
    REV_A="$CELL/workflow-reviews/round-1-reviewer-a.json"
    REV_B="$CELL/workflow-reviews/round-1-reviewer-b.json"
    [ -s "$REV_A" ] || die "round-1-reviewer-a.json is required"
    python3 -I -c 'import json,os,re,sys
cell, rev_a_path, rev_b_path = sys.argv[1:4]
def parse_rev(p):
    if not os.path.isfile(p) or os.path.getsize(p) == 0:
        return None
    raw = open(p, "r", encoding="utf-8").read().strip()
    fenced = re.match(r"^```(?:json)?\s*([\s\S]*?)\s*```$", raw)
    cleaned = fenced.group(1).strip() if fenced else raw
    try:
        return json.loads(cleaned)
    except Exception:
        return {"raw": raw}

agent_ids = {}
agent_ids_path = os.path.join(cell, "agent-ids.json")
if os.path.isfile(agent_ids_path):
    agent_ids = json.load(open(agent_ids_path))

reviews = {"reviewerA": parse_rev(rev_a_path)}
rev_b = parse_rev(rev_b_path)
if rev_b is not None:
    reviews["reviewerB"] = rev_b

payload = {
    "action": "RESUME_TARGET_WITH_WORKFLOW_REVIEWS",
    "resumeRole": "target",
    "resumeAgentId": agent_ids.get("target"),
    "workflowReviews": reviews
}
with open(os.path.join(cell, "staging", "next-step.json"), "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=2)
    f.write("\n")
print(payload["action"])' "$CELL" "$REV_A" "$REV_B"
    ;;

  apply-fs)
    [ $# -ge 6 ] && [ $# -le 7 ] || die "usage: step-turn.sh <run-id> <scenario> <state> apply-fs <rm|mv> <src-rel> [dst-rel]"
    OP="$5"
    SRC_REL="$6"
    DST_REL="${7:-}"
    python3 -I -c 'import json,os,shutil,sys
ws, scenario_file, op, src_rel, dst_rel = sys.argv[1:6]
s = json.load(open(scenario_file))
prefixes = s.get("allowedChangePrefixes", [])

def allowed(rel):
    if not rel or os.path.isabs(rel) or ".." in rel.split("/") or rel == ".git" or rel.startswith(".git/"):
        return False
    for pref in prefixes:
        if pref.endswith("/") and rel.startswith(pref):
            return True
        if rel == pref:
            return True
    return False

if not allowed(src_rel):
    raise SystemExit(f"error: source path not in allowedChangePrefixes: {src_rel}")
ws_real = os.path.realpath(ws)
src_full = os.path.realpath(os.path.join(ws, src_rel))
if not src_full.startswith(ws_real + os.sep) or not os.path.isfile(src_full):
    raise SystemExit(f"error: source file does not exist inside workspace: {src_rel}")

if op == "rm":
    if dst_rel:
        raise SystemExit("error: rm takes one path only")
    os.remove(src_full)
    print(f"removed {src_rel}")
elif op == "mv":
    if not allowed(dst_rel):
        raise SystemExit(f"error: destination path not in allowedChangePrefixes: {dst_rel}")
    dst_full = os.path.realpath(os.path.join(ws, dst_rel))
    if not dst_full.startswith(ws_real + os.sep):
        raise SystemExit(f"error: destination escapes workspace: {dst_rel}")
    # A case-only rename resolves to the source itself on case-insensitive filesystems, so allow that.
    if os.path.lexists(dst_full) and dst_full.lower() != src_full.lower():
        raise SystemExit(f"error: destination already exists: {dst_rel}")
    os.makedirs(os.path.dirname(dst_full), exist_ok=True)
    # Two-step rename when only letter case differs on case-insensitive filesystems
    if src_rel.lower() == dst_rel.lower() and src_rel != dst_rel:
        tmp_full = dst_full + ".case-rename-tmp"
        os.rename(src_full, tmp_full)
        os.rename(tmp_full, dst_full)
    else:
        shutil.move(src_full, dst_full)
    print(f"moved {src_rel} -> {dst_rel}")
else:
    raise SystemExit(f"error: unknown apply-fs op: {op} (expected rm or mv)")' "$WORKSPACE" "$SCENARIO_FILE" "$OP" "$SRC_REL" "$DST_REL"
    ;;

  git-inspect)
    [ $# -eq 5 ] || die "usage: step-turn.sh <run-id> <scenario> <state> git-inspect <status|diff|diff-cached|head|toplevel|branch|ls-files>"
    verify_git_safety || die "workspace Git safety check failed before git-inspect"
    case "$5" in
      status) fgit status --porcelain=v2 --branch --untracked-files=all ;;
      diff) fgit diff --no-ext-diff ;;
      diff-cached) fgit diff --cached --no-ext-diff ;;
      head) fgit rev-parse HEAD ;;
      toplevel) fgit rev-parse --show-toplevel ;;
      branch) fgit branch --show-current ;;
      ls-files) fgit ls-files ;;
      *) die "unknown git-inspect subcommand: $5 (expected status, diff, diff-cached, head, toplevel, branch or ls-files)" ;;
    esac
    ;;

  *)
    die "unknown step-turn mode: $MODE (expected lock-agents, target, persona, workflow-review, apply-fs, git-inspect, transcript or authorization)"
    ;;
esac
