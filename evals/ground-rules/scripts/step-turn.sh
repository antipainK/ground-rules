#!/bin/bash
# Usage: step-turn.sh <run-id> <scenario> <state> <lock-agents|target|persona|workflow-review|apply-fs|git-inspect> [arg1] [arg2]
# Script-owned turn processor and append-only audit logger:
#   lock-agents <target-id> <persona-id>
#     Writes <cell>/agent-ids.json once and locks it read-only.
#   target
#     Reads <cell>/staging/target-turn.txt, strips markdown code fences if present,
#     validates the target JSON schema, verifies workspace safety, defaults missing
#     affectedPaths/draftFiles on options to [], appends the resulting canonical JSON line
#     to transcript.md, auto-answers purely mechanical lifecycle prompts when unambiguous,
#     and writes <cell>/staging/next-step.json.
#   persona
#     Reads <cell>/staging/persona-turn.txt, validates the persona JSON schema against the
#     last unanswered target turn, appends accepted entries to maintainer-answers.ndjson, compiles
#     deduplicated maintainer-answers.json, and writes the target relay payload to
#     <cell>/staging/next-step.json.

. "$(dirname "$0")/common.sh"

[ $# -ge 4 ] || die "usage: step-turn.sh <run-id> <scenario> <state> <mode> [args...]"
cell_paths "$1" "$2" "$3"
SCENARIO="$2"
STATE="$3"
MODE="$4"
[ -d "$CELL" ] || die "no such cell: $CELL"
mkdir -p "$CELL/staging"

compile_answers_json() {
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
with open(json_path, "w", encoding="utf-8") as out:
    json.dump(entries, out, ensure_ascii=False, indent=2)
    out.write("\n")' "$CELL/maintainer-answers.ndjson" "$CELL/maintainer-answers.json"
}

case "$MODE" in
  lock-agents)
    [ $# -eq 5 ] || [ $# -eq 6 ] || die "usage: step-turn.sh <run-id> <scenario> <state> lock-agents <target-id> [persona-id]"
    TARGET_ID="$5"
    PERSONA_ID="${6:-}"
    [ -n "$TARGET_ID" ] || die "target agent id must be non-empty"
    if [ -n "$PERSONA_ID" ]; then
      [ "$TARGET_ID" != "$PERSONA_ID" ] || die "target and persona agent ids must be distinct"
    fi
    if [ -e "$CELL/agent-ids.json" ]; then
      # Allow binding persona lazily once when agent-ids.json was initially locked with persona: null
      if [ -n "$PERSONA_ID" ] && python3 -I -c 'import json,sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
sys.exit(0 if d.get("target") == sys.argv[2] and d.get("persona") is None else 1)' "$CELL/agent-ids.json" "$TARGET_ID"; then
        chmod u+w "$CELL/agent-ids.json"
      else
        die "agent-ids.json already exists in $CELL"
      fi
    fi
    python3 -I -c 'import json,sys
target_id, persona_id, out_path = sys.argv[1:4]
with open(out_path, "w", encoding="utf-8") as f:
    json.dump({"target": target_id, "persona": persona_id if persona_id else None}, f, indent=2)
    f.write("\n")' "$TARGET_ID" "$PERSONA_ID" "$CELL/agent-ids.json"
    chmod 444 "$CELL/agent-ids.json"
    echo "locked agent-ids.json"
    ;;

  target)
    rm -f "$CELL/staging/next-step.json"
    INPUT="$CELL/staging/target-turn.txt"
    [ -s "$INPUT" ] || die "no target turn input at $INPUT"
    if ! verify_git_safety > /dev/null 2>&1; then
      printf '{"action":"CELL_STOPPED","failureKind":"PRODUCT","reason":"workspace Git safety check failed on target turn"}\n' > "$CELL/staging/next-step.json"
      rm -f "$INPUT"
      echo "CELL_STOPPED"
      exit 0
    fi

    python3 -I -c 'import json,os,re,sys
input_path, cell, scenario_file, state = sys.argv[1:5]
raw = open(input_path, "r", encoding="utf-8").read().strip()
fenced = re.match(r"^```(?:json)?\s*(\{[\s\S]*\})\s*```$", raw)
cleaned = fenced.group(1).strip() if fenced else raw

agent_ids = {}
agent_ids_path = os.path.join(cell, "agent-ids.json")
if os.path.isfile(agent_ids_path):
    agent_ids = json.load(open(agent_ids_path, encoding="utf-8"))

def write_next(payload):
    with open(os.path.join(cell, "staging", "next-step.json"), "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
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
        "retryPrompt": "Re-emit your previous response, unchanged in substance, as a single valid JSON object matching one of the allowed target schemas."
    })
    raise SystemExit(0)

if not isinstance(obj, dict) or "status" not in obj:
    write_next({
        "action": "RETRY_TARGET_FORMAT",
        "resumeRole": "target",
        "resumeAgentId": agent_ids.get("target"),
        "reason": "missing status key",
        "retryPrompt": "Re-emit your previous response, unchanged in substance, as a single valid JSON object with a valid status key."
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
        if not isinstance(q, dict) or not isinstance(q.get("text"), str) or not q["text"].strip() or not isinstance(q.get("options"), list):
            write_next({
                "action": "RETRY_TARGET_FORMAT",
                "resumeRole": "target",
                "resumeAgentId": agent_ids.get("target"),
                "reason": f"question {idx} lacks valid text or options array",
                "retryPrompt": "Return the previous still-unanswered user decision again, unchanged, ensuring every question object includes non-empty text and an options array (empty [] only for genuinely open plain-text questions)."
            })
            raise SystemExit(0)
        if len(q["options"]) == 1:
            write_next({
                "action": "RETRY_TARGET_FORMAT",
                "resumeRole": "target",
                "resumeAgentId": agent_ids.get("target"),
                "reason": f"question {idx} has a single option; structured questions require >=2 options or [] for open text",
                "retryPrompt": "Return the previous still-unanswered user decision again, using either >=2 distinct options or options: [] for an open plain-text question."
            })
            raise SystemExit(0)
        seen_opts = set()
        for opt in q["options"]:
            if not isinstance(opt, dict) or not isinstance(opt.get("text"), str) or not opt["text"].strip() or opt["text"] in seen_opts:
                write_next({
                    "action": "RETRY_TARGET_FORMAT",
                    "resumeRole": "target",
                    "resumeAgentId": agent_ids.get("target"),
                    "reason": f"question {idx} has malformed, empty, or duplicate option text",
                    "retryPrompt": "Return the previous still-unanswered user decision again, unchanged, ensuring every option has a unique non-empty text string."
                })
                raise SystemExit(0)
            seen_opts.add(opt["text"])
            if opt.get("affectedPaths") is None:
                opt["affectedPaths"] = []
            if opt.get("draftFiles") is None:
                opt["draftFiles"] = []
            if not isinstance(opt["affectedPaths"], list) or not isinstance(opt["draftFiles"], list):
                write_next({
                    "action": "RETRY_TARGET_FORMAT",
                    "resumeRole": "target",
                    "resumeAgentId": agent_ids.get("target"),
                    "reason": f"question {idx} option affectedPaths and draftFiles must be lists",
                    "retryPrompt": "Return the previous still-unanswered user decision again, unchanged, ensuring affectedPaths and draftFiles on every option are JSON arrays."
                })
                raise SystemExit(0)
elif status == "needs-workflow-review":
    if not isinstance(obj.get("writtenPaths"), list) or not isinstance(obj.get("sanitizedDecisionRecord"), list):
        write_next({
            "action": "RETRY_TARGET_FORMAT",
            "resumeRole": "target",
            "resumeAgentId": agent_ids.get("target"),
            "reason": "needs-workflow-review requires writtenPaths and sanitizedDecisionRecord arrays",
            "retryPrompt": "Re-emit your needs-workflow-review JSON with writtenPaths and sanitizedDecisionRecord as JSON arrays."
        })
        raise SystemExit(0)
    with open(os.path.join(cell, "decision-record.json"), "w", encoding="utf-8") as df:
        json.dump(obj["sanitizedDecisionRecord"], df, ensure_ascii=False, indent=2)
        df.write("\n")
elif status == "complete":
    if not isinstance(obj.get("finalReport"), str) or not obj["finalReport"].strip():
        write_next({
            "action": "RETRY_TARGET_FORMAT",
            "resumeRole": "target",
            "resumeAgentId": agent_ids.get("target"),
            "reason": "complete requires non-empty finalReport string",
            "retryPrompt": "Re-emit your complete JSON object with finalReport as a non-empty string starting with ## Ground Rules final report."
        })
        raise SystemExit(0)
    with open(os.path.join(cell, "final-report.md"), "w", encoding="utf-8") as fr:
        fr.write(obj["finalReport"])
        if obj["finalReport"] and not obj["finalReport"].endswith("\n"):
            fr.write("\n")
    dec_path = os.path.join(cell, "decision-record.json")
    if not os.path.isfile(dec_path):
        with open(dec_path, "w", encoding="utf-8") as df:
            df.write("[]\n")
    answers_ndjson = os.path.join(cell, "maintainer-answers.ndjson")
    if not os.path.isfile(answers_ndjson):
        open(answers_ndjson, "w", encoding="utf-8").close()
    answers_json = os.path.join(cell, "maintainer-answers.json")
    if not os.path.isfile(answers_json):
        with open(answers_json, "w", encoding="utf-8") as aj:
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
        "reason": f"unknown status: {status}",
        "retryPrompt": "Re-emit your response using an allowed status: needs-answer, needs-workflow-review, complete, or protocol-error."
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

# Check if all questions in this needs-answer turn are purely mechanical lifecycle prompts.
# In update, ONLY the initial Focused update run-choice prompt may be auto-answered; any
# subsequent or policy/lifecycle prompt immediately stops the cell as a PRODUCT failure.
scenario = json.load(open(scenario_file, encoding="utf-8"))
ps = scenario.get("approvedPolicy", {})
answers_ndjson = os.path.join(cell, "maintainer-answers.ndjson")
existing_turn_max = 0
already_answered = False
already_reasons = set()
if os.path.isfile(answers_ndjson):
    with open(answers_ndjson, "r", encoding="utf-8") as ef:
        for line_idx, line in enumerate(ef, 1):
            if line.strip():
                already_answered = True
                try:
                    rec_obj = json.loads(line)
                    existing_turn_max = max(existing_turn_max, int(rec_obj.get("turnIndex", line_idx)))
                    for auth in rec_obj.get("authorizedBy") or []:
                        already_reasons.add(auth)
                except Exception:
                    existing_turn_max = max(existing_turn_max, line_idx)
next_turn_index = existing_turn_max + 1

def clean_mechanical_option(opt_dict):
    return not opt_dict.get("draftFiles") and not opt_dict.get("affectedPaths")

pre_staged_path = os.path.join(cell, "pre-staged.txt")
has_pre_staged = os.path.isfile(pre_staged_path) and os.path.getsize(pre_staged_path) > 0

auto_answers = []
for idx, q in enumerate(obj["questions"], 1):
    opts = [o["text"] for o in q["options"]]
    opt_by_text = {o["text"]: o for o in q["options"]}
    matched = None
    reason = None
    if state == "update":
        if (
            not already_answered
            and len(obj["questions"]) == 1
            and any(o.startswith("Focused update") for o in opts)
            and any(o.startswith(("Full re-audit", "Validate only")) for o in opts)
        ):
            cand = next(o for o in opts if o.startswith("Focused update"))
            if not opt_by_text[cand].get("draftFiles"):
                matched = cand
                reason = "In the update state, choose the presented run-choice option whose label starts with Focused update."
    elif state == "foreign" and any(o.startswith(scenario.get("foreignRunChoice", "__none__")) for o in opts):
        frc = scenario["foreignRunChoice"]
        cand = next(o for o in opts if o.startswith(frc))
        cand_reason = f"Foreign run choice: {frc}"
        if clean_mechanical_option(opt_by_text[cand]) and cand_reason not in already_reasons:
            matched = cand
            reason = cand_reason
    elif (
        ps.get("dirtyWorkChoice") == "Continue without commit"
        and has_pre_staged
        and any(o.startswith("Continue without commit") for o in opts)
        and any("Stop to clean index" in o for o in opts)
    ):
        cand = next(o for o in opts if o.startswith("Continue without commit"))
        cand_reason = "When pre-existing staged work is reported, choose Continue without commit."
        if clean_mechanical_option(opt_by_text[cand]) and cand_reason not in already_reasons:
            matched = cand
            reason = cand_reason
    elif (
        ps.get("lifecycle", {}).get("commit") in ("Don'\''t commit", "Do not commit")
        and any(o.startswith("Don'\''t commit") or o.startswith("Do not commit") for o in opts)
        and any(o.startswith("Commit") for o in opts)
    ):
        cand = next(o for o in opts if o.startswith("Don'\''t commit") or o.startswith("Do not commit"))
        cand_reason = "Decline commit and push."
        if clean_mechanical_option(opt_by_text[cand]) and cand_reason not in already_reasons:
            matched = cand
            reason = cand_reason
    elif ps.get("structure") == "Focused files" and any(o.startswith("Focused files") for o in opts) and any(o.startswith("Compact file") for o in opts):
        cand = next(o for o in opts if o.startswith("Focused files"))
        cand_reason = "Choose Focused files."
        if clean_mechanical_option(opt_by_text[cand]) and cand_reason not in already_reasons:
            matched = cand
            reason = cand_reason
    elif ps.get("toolingChoice") == "Document rules only" and any(o.startswith("Document rules only") for o in opts) and any("Bootstrap tooling" in o for o in opts):
        cand = next(o for o in opts if o.startswith("Document rules only"))
        cand_reason = "Document rules only; do not create a manifest or commands."
        if clean_mechanical_option(opt_by_text[cand]) and cand_reason not in already_reasons:
            matched = cand
            reason = cand_reason
    if matched is not None:
        already_reasons.add(reason)
        auto_answers.append({
            "turnIndex": next_turn_index,
            "questionIndex": idx,
            "question": q,
            "selectedOptions": [matched],
            "freeText": None,
            "authorizedBy": [reason]
        })

if len(auto_answers) == len(obj["questions"]):
    with open(answers_ndjson, "a", encoding="utf-8") as af:
        for entry in auto_answers:
            af.write(json.dumps(entry, ensure_ascii=False) + "\n")
    answered_record = dict(obj)
    answered_record["_turnSeq"] = next_turn_index
    answered_record["_answered"] = True
    with open(os.path.join(cell, "staging", "last-target-turn.json"), "w", encoding="utf-8") as ltf:
        json.dump(answered_record, ltf, ensure_ascii=False, indent=2)
        ltf.write("\n")
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
elif state == "update":
    stopped_record = dict(obj)
    stopped_record["_answered"] = True
    with open(os.path.join(cell, "staging", "last-target-turn.json"), "w", encoding="utf-8") as ltf:
        json.dump(stopped_record, ltf, ensure_ascii=False, indent=2)
        ltf.write("\n")
    write_next({
        "action": "CELL_STOPPED",
        "failureKind": "PRODUCT",
        "questionIndex": 1,
        "reason": "target asked a non-Focused-update or follow-up question in update state"
    })
else:
    turn_record = dict(obj)
    turn_record["_turnSeq"] = next_turn_index
    with open(os.path.join(cell, "staging", "last-target-turn.json"), "w", encoding="utf-8") as ltf:
        json.dump(turn_record, ltf, ensure_ascii=False, indent=2)
        ltf.write("\n")
    write_next({
        "action": "ASK_PERSONA",
        "resumeRole": "persona",
        "resumeAgentId": agent_ids.get("persona"),
        "questions": obj["questions"]
    })
' "$INPUT" "$CELL" "$SCENARIO_FILE" "$STATE"
    rm -f "$INPUT"
    if [ -f "$CELL/maintainer-answers.ndjson" ]; then
      compile_answers_json
    fi
    ;;

  persona)
    rm -f "$CELL/staging/next-step.json"
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
    agent_ids = json.load(open(agent_ids_path, encoding="utf-8"))

def write_next(payload):
    with open(os.path.join(cell, "staging", "next-step.json"), "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(payload["action"])

try:
    p = json.loads(cleaned)
except Exception as exc:
    write_next({
        "action": "RETRY_PERSONA_FORMAT",
        "resumeRole": "persona",
        "resumeAgentId": agent_ids.get("persona"),
        "reason": f"invalid persona JSON: {exc}",
        "retryPrompt": "Return your answer again as a single valid JSON object with status answered or unresolved."
    })
    raise SystemExit(0)

if not isinstance(p, dict) or p.get("status") not in ("answered", "unresolved"):
    write_next({
        "action": "RETRY_PERSONA_FORMAT",
        "resumeRole": "persona",
        "resumeAgentId": agent_ids.get("persona"),
        "reason": "persona status must be answered or unresolved",
        "retryPrompt": "Return your answer again with status set to answered or unresolved."
    })
    raise SystemExit(0)

if p["status"] == "unresolved" or state == "update":
    write_next({
        "action": "CELL_STOPPED",
        # In update the persona holds no answers, so any question reaching persona is a product failure.
        "failureKind": "PRODUCT" if state == "update" else "HARNESS",
        "questionIndex": p.get("questionIndex", 1),
        "reason": p.get("reason", "update cell cannot accept persona answers" if state == "update" else "persona returned unresolved")
    })
    raise SystemExit(0)

last_turn_path = os.path.join(cell, "staging", "last-target-turn.json")
target_turn = json.load(open(last_turn_path, encoding="utf-8"))
if target_turn.get("status") != "needs-answer" or target_turn.get("_answered") is True:
    write_next({
        "action": "RETRY_PERSONA_FORMAT",
        "resumeRole": "persona",
        "resumeAgentId": agent_ids.get("persona"),
        "reason": "no unanswered needs-answer target turn is pending",
        "retryPrompt": "Do not submit duplicate answers; wait for a new unanswered target question turn."
    })
    raise SystemExit(0)

questions = target_turn["questions"]
answers = p.get("answers")
if not isinstance(answers, list) or len(answers) != len(questions):
    write_next({
        "action": "RETRY_PERSONA_FORMAT",
        "resumeRole": "persona",
        "resumeAgentId": agent_ids.get("persona"),
        "reason": "persona answers length does not match target questions length",
        "retryPrompt": f"Return an answers array containing exactly {len(questions)} answer object(s), matching each questionIndex in order."
    })
    raise SystemExit(0)

records = []
relay = []
answers_ndjson = os.path.join(cell, "maintainer-answers.ndjson")
existing_turn_max = 0
if os.path.isfile(answers_ndjson):
    with open(answers_ndjson, "r", encoding="utf-8") as ef:
        for line_idx, line in enumerate(ef, 1):
            if line.strip():
                try:
                    rec_obj = json.loads(line)
                    existing_turn_max = max(existing_turn_max, int(rec_obj.get("turnIndex", line_idx)))
                except Exception:
                    existing_turn_max = max(existing_turn_max, line_idx)
next_turn_index = int(target_turn.get("_turnSeq") or (existing_turn_max + 1))

for idx, (q, ans) in enumerate(zip(questions, answers), 1):
    if not isinstance(ans, dict) or ans.get("questionIndex") != idx:
        write_next({
            "action": "RETRY_PERSONA_FORMAT",
            "resumeRole": "persona",
            "resumeAgentId": agent_ids.get("persona"),
            "reason": f"questionIndex mismatch at {idx}",
            "retryPrompt": f"Ensure answer {idx} has questionIndex: {idx}."
        })
        raise SystemExit(0)
    sel = ans.get("selectedOptions")
    ft = ans.get("freeText")
    auth_by = ans.get("authorizedBy")
    has_sel = isinstance(sel, list) and len(sel) > 0 and all(isinstance(s, str) for s in sel)
    empty_sel = isinstance(sel, list) and len(sel) == 0
    has_ft = isinstance(ft, str) and bool(ft.strip())
    if not ((has_sel and ft is None) or (empty_sel and has_ft)):
        write_next({
            "action": "RETRY_PERSONA_FORMAT",
            "resumeRole": "persona",
            "resumeAgentId": agent_ids.get("persona"),
            "reason": f"question {idx} must provide either non-empty selectedOptions (with freeText null) or empty selectedOptions with non-empty freeText",
            "retryPrompt": f"For question {idx}, provide either selectedOptions with exact option labels and freeText: null, or selectedOptions: [] with non-empty freeText."
        })
        raise SystemExit(0)
    if not isinstance(auth_by, list) or not auth_by or not all(isinstance(a, str) and a.strip() for a in auth_by):
        write_next({
            "action": "RETRY_PERSONA_FORMAT",
            "resumeRole": "persona",
            "resumeAgentId": agent_ids.get("persona"),
            "reason": f"question {idx} lacks non-empty authorizedBy string array",
            "retryPrompt": f"For question {idx}, provide a non-empty authorizedBy array of string citations."
        })
        raise SystemExit(0)
    opt_texts = {o["text"] for o in q.get("options", [])}
    for s in sel:
        if s not in opt_texts:
            write_next({
                "action": "RETRY_PERSONA_FORMAT",
                "resumeRole": "persona",
                "resumeAgentId": agent_ids.get("persona"),
                "reason": f"selected option {s!r} is not in question {idx} options",
                "retryPrompt": f"Select exact option text from question {idx}: {sorted(opt_texts)!r}."
            })
            raise SystemExit(0)
    clean_q = {k: v for k, v in q.items() if not k.startswith("_")}
    records.append({
        "turnIndex": next_turn_index,
        "questionIndex": idx,
        "question": clean_q,
        "selectedOptions": sel,
        "freeText": ft,
        "authorizedBy": auth_by
    })
    relay.append({
        "questionIndex": idx,
        "selectedOptions": sel,
        "freeText": ft
    })

with open(answers_ndjson, "a", encoding="utf-8") as af:
    for r in records:
        af.write(json.dumps(r, ensure_ascii=False) + "\n")

target_turn["_answered"] = True
with open(last_turn_path, "w", encoding="utf-8") as ltf:
    json.dump(target_turn, ltf, ensure_ascii=False, indent=2)
    ltf.write("\n")

write_next({
    "action": "RESUME_TARGET",
    "resumeRole": "target",
    "resumeAgentId": agent_ids.get("target"),
    "relayAnswers": relay
})
' "$INPUT" "$CELL" "$STATE"
    rm -f "$INPUT"
    compile_answers_json
    ;;

  workflow-review)
    rm -f "$CELL/staging/next-step.json"
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
    agent_ids = json.load(open(agent_ids_path, encoding="utf-8"))

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
    verify_git_safety || die "workspace Git safety check failed before apply-fs"
    OP="$5"
    SRC_REL="$6"
    DST_REL="${7:-}"
    python3 -I -c 'import json,os,shutil,sys,tempfile
ws, scenario_file, op, src_rel, dst_rel = sys.argv[1:6]
s = json.load(open(scenario_file, encoding="utf-8"))
prefixes = s.get("allowedChangePrefixes", [])

def allowed(rel):
    if (
        not rel
        or "\n" in rel
        or "\r" in rel
        or rel.endswith("/")
        or os.path.isabs(rel)
        or ".." in rel.split("/")
        or "." in rel.split("/")
        or rel.lower() == ".git"
        or rel.lower().startswith(".git/")
    ):
        return False
    for pref in prefixes:
        if pref.endswith("/") and rel.startswith(pref):
            return True
        if rel == pref:
            return True
    return False

def exact_exists(root, rel_path, require_file=True):
    cur = root
    for part in rel_path.split("/"):
        try:
            entries = os.listdir(cur)
        except OSError:
            return False
        if part not in entries:
            return False
        cur = os.path.join(cur, part)
    return (os.path.isfile(cur) and not os.path.islink(cur)) if require_file else (os.path.isdir(cur) and not os.path.islink(cur))

if not allowed(src_rel):
    raise SystemExit(f"error: source path not in allowedChangePrefixes: {src_rel}")
ws_real = os.path.realpath(ws)
src_joined = os.path.join(ws_real, src_rel)
if os.path.islink(src_joined):
    raise SystemExit(f"error: refusing symlink source: {src_rel}")
if not exact_exists(ws_real, src_rel, require_file=True):
    raise SystemExit(f"error: source file does not exist inside allowedChangePrefixes: {src_rel}")
src_full = os.path.realpath(src_joined)
src_norm = os.path.relpath(src_full, ws_real).replace(os.sep, "/")
if not src_full.startswith(ws_real + os.sep) or not allowed(src_norm):
    raise SystemExit(f"error: source file escapes allowedChangePrefixes: {src_rel}")

if op == "rm":
    if dst_rel:
        raise SystemExit("error: rm takes one path only")
    os.remove(src_full)
    print(f"removed {src_rel}")
elif op == "mv":
    if not allowed(dst_rel):
        raise SystemExit(f"error: destination path not in allowedChangePrefixes: {dst_rel}")
    dst_joined = os.path.join(ws_real, dst_rel)
    if os.path.islink(dst_joined):
        raise SystemExit(f"error: refusing symlink destination: {dst_rel}")
    if src_rel == dst_rel:
        raise SystemExit(f"error: source and destination are identical: {dst_rel}")
    # Verify existing ancestor directories match requested casing before creating missing child dirs
    cur_anc = ws_real
    for part in os.path.dirname(dst_rel).split("/"):
        if not part:
            continue
        next_anc = os.path.join(cur_anc, part)
        if os.path.lexists(next_anc):
            if os.path.islink(next_anc) or part not in os.listdir(cur_anc):
                raise SystemExit(f"error: destination parent directory differs in case or is a symlink: {dst_rel}")
        cur_anc = next_anc
    os.makedirs(os.path.dirname(dst_joined), exist_ok=True)
    dst_parent_real = os.path.realpath(os.path.dirname(dst_joined))
    dst_full = os.path.join(dst_parent_real, os.path.basename(dst_joined))
    dst_norm = os.path.relpath(dst_full, ws_real).replace(os.sep, "/")
    if not dst_full.startswith(ws_real + os.sep) or not allowed(dst_norm):
        raise SystemExit(f"error: destination escapes allowedChangePrefixes: {dst_rel}")
    same_inode = os.path.lexists(dst_full) and os.path.samestat(os.lstat(src_full), os.lstat(dst_full))
    if os.path.lexists(dst_full) and not same_inode:
        raise SystemExit(f"error: destination already exists: {dst_rel}")
    if same_inode:
        fd, tmp_full = tempfile.mkstemp(prefix=".case-rename-", dir=dst_parent_real)
        os.close(fd)
        os.unlink(tmp_full)
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
    die "unknown step-turn mode: $MODE (expected lock-agents, target, persona, workflow-review, apply-fs or git-inspect)"
    ;;
esac
