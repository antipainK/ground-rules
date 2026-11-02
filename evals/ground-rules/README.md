# Ground Rules evaluation matrix

The release gate is six repository scenarios in three states:

1. `fresh`: no AI instruction files;
2. `rerun`: the completed fresh result with identical answers; and
3. `foreign`: the pristine fixture plus instructions not written by Ground Rules.

`matrix.json` defines the personas, fixture facts, foreign files, scenario-specific
invariants, rerun requirements, and hard failures. A release run executes all 18
cells. Before each rerun, the harness adds one coherent maintainer rule to an existing
policy file and requires the focused update to preserve it byte-for-byte. The gate does
not average away a failing cell.

## Evidence layers

Use all three layers. None replaces another.

### 1. Release artifact checks

Check final files and Git state mechanically:

- changed paths stay within the approved scope;
- existing staged, unstaged, ignored, and untracked work is preserved;
- every command, path, tool, and enforcement claim works;
- `AGENTS.md` stays at or below 150 lines and each `.ai/*.md` file at or below
  300 lines;
- every rule maps to an authorizing decision and ends with one provenance marker;
- configured tools are referenced rather than duplicated in prose;
- no plugin ownership metadata or marker appears in team-owned Markdown;
- no active rules contradict by value or scope;
- reruns produce no diff; and
- no secret-shaped value enters a shared file.

### 2. Live interaction checks

Drive the real plugin in an isolated repository. Record each question, answer, tool
call, write, check result, and final report. Fail when the skill:

- writes before the required decision;
- asks a dependent question before its prerequisite;
- asks a decided question again;
- hides an alternative behind free text;
- skips a foreign rule or reviewer finding;
- treats an open decision as active policy; or
- reaches completion before review and final artifact reconciliation.

Pre-supplying all persona answers tests artifact generation, not interaction. Label
such a run as simulated.

Claude Code stream-JSON sessions do not currently expose `AskUserQuestion`; the skill
renders the same choices as plain text there. A resumable stream run therefore tests
turn ordering, decisions, writes, and artifacts, but label its UI result
`text-fallback`. Use a trusted interactive PTY run to test the actual selection widget.
Never bypass managed permissions to make either harness pass.

### 3. Blind semantic review

Two fresh reviewers receive only the fixture, final repository, changed-file list,
and sanitized authorization record: final rule wording, origin, accepted current
policy text/selection/verdict/finding, scopes, checking mechanism, and citation
evidence. They do
not receive the persona script, rejected alternatives, expected output, target
transcript, or each other's findings. Each finding needs file-and-line evidence and
one severity:

- blocker;
- major;
- deterministic minor; or
- stylistic nitpick.

Fix every blocker, major, and reproducible minor, then rerun all affected states with
fresh reviewers. A nitpick is acceptable only when it violates no invariant, the
reviewers disagree, and two further reviews do not reproduce it.

## Acceptance

Every cell must:

- avoid every `hardFailures` entry in `matrix.json`;
- score at least 90/100;
- receive full credit for safety, user control, and contradiction handling; and
- finish with no blocker, major, or deterministic minor.

Archive the plugin commit, Claude Code version, model, fixture commit, transcript,
diff, checks, scores, and reviewer verdicts. Keep run outputs under
`evals/ground-rules/results/`; the repository ignores that directory.
The scoring dimensions and weights are defined in `matrix.json`; reviewers must provide
the per-dimension score and evidence as part of the semantic-review output.

## Live matrix command

`live_matrix.py` creates disposable Git fixtures, drives the real plugin through a
resumable stream session, uses a separate tool-less persona actor for each answer, and
archives each final workspace with its transcript. Its `artifactShapeChecksPassed`
field covers only path boundaries, preservation, absence of legacy ownership artifacts,
size limits, provenance shape, secret-shaped values, and rerun bytes. Blind reviewers must assess
command validity, rule-to-decision mapping, and semantic consistency. The driver loads
project and managed settings, uses
explicit tool allowlists and the default permission mode, and never passes a
permission-bypass flag. Fixtures live in an ignored disposable cache inside the repository
so company sandboxes permit the evaluated agent to write and rename files. Fixture Git
metadata uses a standard `.git` pointer to disposable sibling metadata, and the fixture
content remains outside plugin packaging. Claude subprocesses receive an explicit
environment allowlist, empty shell
startup files, unique temporary directories, per-run npm/temp caches, and an ignored
persistent Maven dependency cache so release reruns do not require cold downloads. The runner
also rejects staging, history and worktree-mutating Git tool calls even when the final
HEAD or index was restored. Compound read-only inspection commands remain valid.
Git's own Trace2 event stream records the argv of actual Git processes, including aliases,
wrappers, nested shells and absolute executable paths. The runner classifies those events,
checks the fixture and host repository afterward, and flags literal attempts to alter its
trace environment. Trace2 is evidence, not a security boundary; the restricted tool
allowlist and before/after repository checks provide independent layers.

Prerequisite: Python 3.11 or newer. No project-wide Python environment or Poetry install
is required; the harness uses an ignored standard-library virtual environment.

```sh
python3 -m venv evals/ground-rules/results/.cache/eval-venv
evals/ground-rules/results/.cache/eval-venv/bin/python -m pip install \
  -r evals/ground-rules/requirements.txt
evals/ground-rules/results/.cache/eval-venv/bin/python \
  evals/ground-rules/live_matrix.py \
  --output evals/ground-rules/results/full
```

Run the deterministic safety-classifier tests with:

```sh
evals/ground-rules/results/.cache/eval-venv/bin/python -m unittest \
  evals/ground-rules/test_live_matrix.py
```

Use `--scenario <id>` or repeated `--state <fresh|rerun|foreign>` while developing.
The full release command omits those filters and executes all 18 cells. A nonzero exit
means at least one artifact-shape finding or incomplete run. Even a zero exit writes
`releaseGatePassed: false`: semantic review, scoring, and the actual question widget
remain separate mandatory gates, so this runner cannot claim release acceptance by
itself. `summary.json` records the plugin commit and tree hash, dirty state, Claude Code
version, target and actor models, rubric, and `uiMode: text-fallback`.
