# Ground Rules evaluation suite

This suite measures how well the Ground Rules skill does its job, so that
maintainers can find weak spots and improve the skill. A full run is the complete
baseline for that work. It is not an approval step or a release gate.

A full run covers six repository scenarios in three states.

A **cell** is one scenario in one state, so a full run has 18 cells. The states:

1. `fresh`: no AI instruction files;
2. `foreign`: the pristine fixture plus instructions from other tools; and
3. `update`: the completed fresh result plus a coherent maintainer edit, to check
   that a later focused update asks nothing and changes nothing.

Wording: in this document a **run** is one invocation of the whole eval (one
`run-id`). Doing a cell again is a **repeat**. The plugin skill uses `foreign` and
`fresh` for the same ideas, and uses "rerun" for a later invocation of the skill; the
eval state for that case is `update`.

## Roles

| Role | What it is |
|---|---|
| orchestrator | The Claude Code session that runs `/ground-rules-eval`; it launches the others and runs the scripts |
| target | The agent (Sonnet) that runs the Ground Rules skill under test |
| persona | A cooperative maintainer played by a cheaper model, answering from the scenario's `approvedPolicy` and `decisions` |
| step-9 reviewer | `eval-reviewer` run on the workflow review that the skill performs in its Step 9 |
| blind reviewer | `eval-reviewer` that scores the result from the workspace, the initial workspace and `blind-input/` only. It sees the maintainer's answers but not `scenario.json` (`approvedPolicy`, `artifactAssertions`), so it cannot grade against the answer key |
| tie-breaker | A third reviewer, asked only when the first two disagree |

## Directory layout

- `rubric.json`: global scoring rubric with five independent `0–100` categories
  (`workspaceSafety`, `userControlAndAuthorization`, `policyAndContradictionFidelity`,
  `repositoryAndArtifactAccuracy`, `maintainabilityAndDocsHygiene`), per-category
  pass floors, deduction anchors, and hard failures.
- `scenarios/<scenario>/scenario.json`: per-scenario persona, structured
  `approvedPolicy`, `artifactAssertions`, `allowedChangePrefixes`, and decisions for
  each of the six scenarios (`empty-python-cli`, `legacy-node-service`,
  `polyglot-monorepo`, `enforcement-heavy-python-api`,
  `documentation-heavy-rust-workspace`, `security-sensitive-java-service`).
- `scenarios/<scenario>/base/`: pristine baseline repository files.
- `scenarios/<scenario>/foreign-overlay/`: additional foreign instruction files.

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
18 cells. Scenario or state filters are suitable for development; such a partial
run records `partialRun: true` and can never set `fullRunPassed`.

## Scripts and permissions

The orchestrator runs strictly named scripts from `evals/ground-rules/scripts/`
instead of building shell commands inline. Each takes plain arguments (run id,
scenario, state), validates them in `common.sh`, and works only inside
`evals/ground-rules/results/`.

| Script | Purpose |
|---|---|
| `init-run.sh` | Creates a run folder and prints its id; refuses if `results/` is not ignored by Git |
| `snapshot-source.sh` | Records and compares the source repository's HEAD, status and file-content fingerprints (`before`, `after`, `compare`) |
| `prep-cell.sh` | Builds one cell with a baseline commit, separate Git directory, prepared-workspace snapshot and pre-run safety records |
| `step-turn.sh` | Locks agent IDs, strips markdown fences, validates target/persona JSON, auto-answers mechanical lifecycle prompts, and appends logs (`maintainer-answers.ndjson`, with the deduplicated view in `maintainer-answers.json`) |
| `verify-cell.sh` | Runs deterministic safety/Git/path/pointer checks and scenario `artifactAssertions`; writes `deterministic-checks.json`. Only safety rows (Git, paths, secrets, update diff and rule) can fail a cell. Size limits, pointers, reachability, ownership markers and `artifactAssertions` are advisory: they are listed under `advisoryFailures` and never set `hardFailure` |
| `prep-blind-review.sh` | Safely builds `blind-input/` after verifying Git pointer and config integrity |
| `score-cell.sh` | Verifies reviewer citations, computes the five `0–100` category scores, separates `HARNESS` from `PRODUCT` failures, and compiles `summary.json` |
| `test-eval.sh` | Regression and calibration test suite (`scripts`, `config` or `all`) |

`prep-cell.sh` builds all three states. `legacy-node-service` fresh also gets
an unstaged edit to `src/server.js` and a staged release note in `README.md`. A
`update` cell needs its fresh cell's `result.json` to contain `"verdict": "pass"`.
It appends the scenario's `updateMaintainerRule` from `scenario.json` to the one
`.ai` file that matches a topic by file name or first heading, updates
`Last reviewed` when the date changed, and refuses when none or several match.
The Java scenario uses `application.properties.example` with an empty
`SERVICE_TOKEN=` placeholder so the example configuration is copyable in the
evaluation sandbox without weakening `.env` protections.

The shared `.claude/settings.json` publishes three entries:

- `permissions.allow`: one `Bash(evals/ground-rules/scripts/<name>.sh *)` entry per
  runtime script (`init-run.sh`, `snapshot-source.sh`, `prep-cell.sh`,
  `step-turn.sh`, `verify-cell.sh`, `prep-blind-review.sh`, `score-cell.sh`), not
  a folder wildcard. `test-eval.sh` is deliberately omitted so running the test
  suite still asks.
- `permissions.ask`: `Edit(...)` for the scripts folder, `rubric.json`, `scenarios/`,
  `plugins/`, `.claude/settings.json`, `.claude/agents/` and `.claude/skills/`.
- `sandbox.filesystem.denyWrite`: the scripts folder, `rubric.json`, `scenarios`,
  `plugins`, `.claude/settings.json`, `.claude/agents` and `.claude/skills`, so Bash
  cannot rewrite them when the sandbox is on.

Run `evals/ground-rules/scripts/test-eval.sh` after changing a script or the
settings.

## Scoring and acceptance

Each cell is evaluated across five independent `0–100` categories:

| Category | Floor | What it checks | Example deduction |
|---|---|---|---|
| `workspaceSafety` | `100`, deterministic | What the run did to the workspace, from the deterministic checks: Git state, paths written and secrets. An unchanged source repository is checked separately and only affects `fullRunPassed` | A write outside the allowed paths |
| `userControlAndAuthorization` | `85` | Every rule, move, config edit and deletion traces to a maintainer choice or existing policy | A rule the maintainer never chose |
| `policyAndContradictionFidelity` | `85` | No active contradictions across `AGENTS.md`, `.ai/*.md` and tool configs; scopes and deferred markers kept | Two files that disagree |
| `repositoryAndArtifactAccuracy` | `85` | Commands, paths, pointers and claims match the repository | A pointer to a file that does not exist |
| `maintainabilityAndDocsHygiene` | `80` | Size limits, no volatile inventories, clean renames, stays idempotent on a later update | A duplicated rule |

A cell passes when `hardFailure` is `false`, every category meets its floor, and
the unweighted mean across the five categories is at least `88.0`. One blind
reviewer scores each `fresh` and `foreign` cell. A second is requested only when
the first reports a deduction or hard failure (`score-cell.sh` exits 3). If the
two reviewers diverge by more than `10` points on any category, split on a pass
floor, or disagree on `hardFailure`, `score-cell.sh` requests a third tie-breaker
reviewer and uses the per-category median. `update` cells need no reviewers: a
zero diff with the maintainer rule preserved scores `100`, and an update cell that
fails the deterministic checks is recorded as a `PRODUCT` failure.

`result.json` records which path produced the score in `reviewPath`:
`update-checks-only`, `one-reviewer`, `two-reviewers` or `three-reviewers`. A lone
reviewer's `100` has no second opinion, so read `one-reviewer` results with that in mind.

`summary.json` sets `fullRunPassed` only for a full run: all 18 cells present and
passing with no `hardFailure`, `partialRun` false, a Sonnet 5.5 or later model, and
`sourceRepoUnchanged` true (`snapshot-source.sh compare` was run and found the
source repository unchanged).

### `score-cell.sh` exit codes

| Code | Meaning | What to do |
|---|---|---|
| `0` | A result was recorded. A `FAIL` verdict also exits `0` | Read the printed `PASS` or `FAIL`, or `result.json` |
| `1` | Any other error | Read the message |
| `2` | `NEEDS_TIE_BREAKER` | Launch a third reviewer |
| `3` | `NEEDS_SECOND_REVIEWER` | Launch a second reviewer |

### Failure outcomes

| Outcome | Who is at fault | What you fix |
|---|---|---|
| `harness-error` | The harness or the target's protocol (the target reported `protocol-error`, or a second format failure occurred) | The harness or the scenario |
| `harness-stopped` | The harness, which stopped the cell (`prep-cell.sh` failed, or the persona had no answer outside the `update` state) | The harness or the scenario |
| `product-fail` | The skill under test (for example it asked a maintainer question in an `update` cell) | The skill |

`failureKind` in `result.json` is `HARNESS` for the first two and `PRODUCT` for the last.

`step-turn.sh` reports these as actions in `next-step.json`, which the orchestrator turns into the outcomes above:

| Action | Recorded as |
|---|---|
| `HARNESS_ERROR` (the target reported `protocol-error`) | `harness-error` |
| `RETRY_TARGET_FORMAT` / `RETRY_PERSONA_FORMAT`, on a second failure | `harness-error` |
| `CELL_STOPPED`, `failureKind` `HARNESS` | `harness-stopped` |
| `CELL_STOPPED`, `failureKind` `PRODUCT` (an `update` target asked a rule question) | `product-fail` |

Runs created before the `update` naming change (they contain `rerun` cells and the old
result keys) cannot be resumed, re-scored or summarised with these scripts. Start a new run.

### Records

- `decision-record.json`: the run-local record of the rules the target applied, with id, origin, wording and source. It is the same concept as the plugin skill's decision record (its Step 6.5).
- `maintainer-answers.ndjson`: the append-only log of every answer the persona or the script gave to the target. `maintainer-answers.json` is its deduplicated view.

Outputs are written under `evals/ground-rules/results/`, which is ignored by
Git.
