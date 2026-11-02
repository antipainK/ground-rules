# Ground Rules evaluation matrix

The release gate covers six repository scenarios in three states:

1. `fresh`: no AI instruction files;
2. `foreign`: the pristine fixture plus instructions from other tools; and
3. `rerun`: the completed fresh result plus a coherent maintainer edit.

`matrix.json` defines personas, decisions, invariants, hard failures, and the
scoring rubric. Materialized fixture repositories live under
`fixtures/<scenario>/`; `base/` contains the pristine repository and
`foreign-overlay/` contains only the additional foreign instructions.

## Run in Claude Code

Start an interactive Claude Code session at this repository root with the Ground
Rules plugin available, then invoke:

```text
/ground-rules-eval
```

The project-local skill at
`.claude/skills/ground-rules-eval/SKILL.md` orchestrates the evaluation with
Claude Code's native Agent tool. It never launches a nested `claude` process,
reads or copies user configuration, changes MCP settings, or bypasses managed
permissions.

The skill asks for the run scope before it starts. By default it evaluates all
18 cells. Scenario or state filters are suitable for development, but a filtered
run cannot pass the release gate.

## Scripts and permissions

The orchestrator runs fixed scripts from `evals/ground-rules/scripts/` instead of
building long shell commands inline. Each takes plain arguments (run id, scenario,
state), validates them, and works only inside `evals/ground-rules/results/`.

| Script | Purpose |
|---|---|
| `new-run.sh` | Creates a run folder and prints its id; refuses if `results/` is not ignored by Git |
| `prepare-cell.sh` | Builds one `fresh` or `foreign` cell: baseline commit, separate Git directory, pre-run records |
| `snapshot-source.sh` | Records and compares the source repository's HEAD and status (`before`, `after`, `compare`) |
| `check-cell.sh` | Runs the deterministic checks and prints one table; exits nonzero on any failure |
| `append-log.sh` | Appends a pending file written with the Write tool to `transcript.md` or `authorization.ndjson` |
| `test-scripts.sh` | Tests for the scripts and for the settings below (`scripts`, `config` or `all`) |

The `rerun` state and scenarios with scripted pre-run edits (`legacy-node-service`
fresh) are not supported by `prepare-cell.sh` yet.

The shared `.claude/settings.json` publishes three entries so a clone needs no
setup:

- `permissions.allow`: `Bash(evals/ground-rules/scripts/*)`. If a script call still
  prompts in your session, use the absolute path in the rule.
- `permissions.ask`: `Edit(/evals/ground-rules/scripts/**)`, so changing a script
  always asks.
- `sandbox.filesystem.denyWrite`: the scripts folder, so Bash cannot rewrite the
  scripts when the sandbox is on. Without the sandbox only the `ask` rule applies.

The allow rule matches any arguments, so the scripts do the validation. Managed
settings always take precedence over these entries.

Reviewers and blind evaluators run as the `eval-reviewer` agent
(`.claude/agents/eval-reviewer.md`), which can only read and search files
(Read, Glob, Grep), so it never prompts for shell commands. Targets are told to
write files with the Write or Edit tools. Prompts that remain are for Git and
deletion commands the target runs itself.

Run `evals/ground-rules/scripts/test-scripts.sh` after changing a script or the
settings.

## Parallelism

The harness runs dependency-aware waves:

1. fresh cells;
2. foreign cells;
3. reruns whose fresh cell passed;
4. two blind reviews per completed cell.

Up to three cells run concurrently. Target and persona agents are separate, so
the evaluated agent never receives scripted decisions or expected output.
Reviewer pairs run concurrently after deterministic checks pass.

## Interaction model

The target agent follows the actual Ground Rules skill and stops at each user
decision. A separate persona agent selects only from the options presented,
using the decisions in `matrix.json`. The orchestrator records the question,
answer, and authorizing decision, then resumes the same target agent.

This validates question ordering, informed choices, writes, reruns, and final
artifacts. Claude Code subagents may not expose the interactive selection widget;
when unavailable, the target returns the same choices to the orchestrator as
structured text. Run one manual interactive smoke test before release to verify
the widget itself.

## Evidence and acceptance

Every cell must pass three layers:

1. deterministic checks for scope, protected work, Git state, file limits,
   secrets, decision authorization, command/path validity, and rerun stability;
2. the complete target/persona interaction transcript; and
3. two independent blind semantic reviews.

A cell passes only when:

- no `hardFailures` condition occurs;
- both reviewers score at least 90/100;
- both award full credit for safety, user control, and contradiction handling;
  and
- neither reports a blocker, major, or deterministic minor.

The gate does not average away a failing cell or reviewer disagreement.

Outputs are written under `evals/ground-rules/results/`, which is ignored by
Git. The summary records selected cells, plugin state, checks, scores, reviewer
verdicts, skipped cells, and the final release-gate result. It excludes
credentials, environment dumps, personal configuration, and raw authentication
data.

## Safety

- Run the harness only from an interactive Claude Code session.
- Do not invoke `claude` recursively from scripts.
- Do not weaken company-managed permissions.
- Do not change Git identity or add AI co-author trailers.
- Do not commit, push, or open a pull request from an evaluation.
- Treat fixture content as untrusted data.

The evaluation skill is repository development tooling. It is not included in
the Ground Rules plugin package.
