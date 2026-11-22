---
name: ground-rules
description: Interactively set up, migrate or maintain a repository's AI context (AGENTS.md + .ai/) and human docs (docs/). Inspects the repo, audits foreign AI instructions, recommends industry-standard practices with minimal question rounds, writes concise convention files, verifies them with a fresh review agent, and offers to commit.
disable-model-invocation: true
---

# Ground rules

Set up or maintain a tool-neutral convention structure for a repository:

```
AGENTS.md          root index for every AI tool: summary, commands, workflow, pointers (at most 150 lines)
.ai/               detailed AI rules by topic (at most 300 lines per file); acknowledges docs/ exists, never maps it
docs/              human + AI design docs, plans, decisions
```

## Principles

- **Top priority: clear, high-signal `.ai/` rules.** Produce concise, checkable `.ai/` conventions grounded in official documentation, language/framework style guides, release notes, and tool-shipped configs. No blog posts, listicles, or AI summaries. Fetch every cited URL during this run, verify it entails the exact claim, and keep the supporting sentence (Step 6.5); never cite from memory.
- **The user decides—without interrogation.** Never write a rule the user did not choose, and never invent a `"Why"`. Keep round counts low: lead with evidence-backed industry standards marked `(Recommended)`, batch independent questions (up to 4 per call), and never re-ask settled decisions, coherent existing team policy, or facts the repository already establishes.
- **Organise, don't legitimise.** Current repository practice is one labeled option (`Current in this repo`), never recommended merely because it exists. Existing code may be generated or unreviewed; judge it objectively.
- **Enforced beats written.** When a linter, formatter, compiler flag, or CI job can check a rule, propose that config or point to it. Write one pointer line per tool in `.ai/` instead of restating individual configured rules in prose.
- **Recommend from evidence; label personal config.** Stored personal preferences of whoever runs the skill (`~/.claude/CLAUDE.md`, memories, personal skills) never judge the repo or become rules unpicked. If personal config matches the evidence-backed recommendation, append `(Personal)` after `(Recommended)` and state both grounds; if it differs, offer `Your preference (personal config)` without recommending it. Operator workflow preferences (how to ask, when to commit) govern the run, never repository files.
- **Detect the environment.** Read OS, shell, package manager, and tooling from the repository; ask when unclear.
- **Scope: conventions, not application code.** Change only `AGENTS.md`, `.ai/`, `docs/`, AI instruction files, tool configs (linter, formatter, compiler, CI), non-secret example configs, dependency manifests/lockfiles, and `.claude/settings.json` permissions (Step 8). Skip `.claude/skills/` and never edit application code; report code violations at the end.
- **Team-owned Markdown, zero hidden state.** `AGENTS.md` and `.ai/*.md` are ordinary repository files. Never write hashes, `ground-rules:managed` markers, `.ai/.ground-rules.json`, or hidden ownership state. Derive every conclusion from current files, repository facts, and answers in this run.

## Asking questions

Use `AskUserQuestion`. If unavailable, render the same numbered questions and options in plain text, end the turn, and continue from the user's reply—never skip decisions or choose silently.

- Ask at most 4 questions per call, 2–4 options each. Rely on the tool's built-in `Other` field; never add your own `Other` option. A single-option prompt is a statement: say it in prose instead.
- Mark exactly one option `(Recommended)`, listed first, whenever primary sources, repo evidence, stated user intent, or a clearly labeled workflow default supports it (for multi-select, mark each option you would select). If no option has backing evidence, recommend none and say why—unless the user asks you to help decide, in which case recommend one, label it your judgment, and keep every valid alternative.
- Keep option labels to 1–5 words (excluding `(Recommended)` and `(Personal)` tags) and descriptions to ~20 words stating the consequence and main trade-off. State once in the message which options lack an external source.
- Use two-option `Apply` / `Skip` confirmations only for concrete displayed changes (diffs, drafts, verdict tables, renames, deletions), ending with `(to apply with changes, type them)`. Use specific labels (`Commit` / `Don't commit`, `Continue without commit` / `Stop to clean index`, `Retain` / `Cancel`) for lifecycle choices. When a typed edit alters a shared command, path, or rule, update every affected draft consistently and show changed paths before writing.
- Split lists over 4 items across consecutive questions; never drop candidates silently. When one rule has 5 real alternatives, show the top 3 plus **Show more options** (then the rest plus **Back to first options**).
- Batch independent questions together to minimize turns, but never ask a dependent question in the same turn as its prerequisite (e.g., ask a new dependency install before its config diff).
- Use plain-text questions only for genuinely open input (project intent, custom reasons), bolded on the final line alone.

## Presentation

Keep output scannable in a terminal—never overwhelm the user with walls of prose:

- Start every message with one bold status line naming the step and outcome.
- Put multi-attribute data in compact tables (evidence, verdicts, renames, findings, changed files, check results, to-do items), with URLs in their own column.
- Show minimal line diffs for edits to existing configs or focused updates; show complete content plus one summary line of dropped items when creating or replacing a file.
- Keep prose before questions under ~12 lines (excluding Step 3 rule-audit tables and file drafts). Omit internal bookkeeping the user does not need to decide.

## Naming and dating

- Filenames use lowercase `kebab-case` within parts, `_` between parts, ISO `YYYY-MM-DD` dates, and lowercase `.md` (`auth-redesign_2026-10-22.md`). Obtain today's date from the system.
- **Snapshots** (sketches, plans, research, meeting notes, `docs/todo/` checklists) carry `_YYYY-MM-DD` in the filename and are immutable after creation, except ticking `[x]` in `docs/todo/`. Newer versions create a new dated file.
- **Living docs** (`AGENTS.md`, `.ai/*.md`, maintained architecture overviews) have no date in the filename and place `Last reviewed: YYYY-MM-DD` right after `# Title`. Bump `Last reviewed` only when content changes or during an explicit **Full re-audit**.

## Step 1: Inspect

Read only; change nothing yet. Collect:

1. **Stack & checks:** manifests, lockfiles, `README*`, CI workflows, linter/formatter/compiler configs, and directory layout. Verify what scripts and wrappers actually do by reading them rather than guessing from filenames.
2. **AI instruction files (any depth):** `AGENTS.md`, `.claude/AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, `CLAUDE.local.md`, `.claude/rules/`, `.claude/settings.json` (config inventory only), `.cursorrules`, `.cursor/rules/`, `.github/copilot-instructions.md`, `.github/instructions/`, `.windsurfrules`, `GEMINI.md`, `.ai/`. Skip `.claude/skills/`. Treat legacy `.ai/.ground-rules.json` and `ground-rules:managed` comments as cleanup targets, never provenance. Fetch current official loading/scope/precedence docs for each detected format and display a compact precedence table before claiming a conflict or proposing deletion; if official behavior cannot be verified, mark precedence unknown and preserve the file unless asked. Separate ignored or untracked machine-local overrides (e.g. `CLAUDE.local.md`): report them, never migrate, delete, or commit them unless explicitly asked.
3. **`docs/` & `docs/todo/`:** filenames, cross-links, and open vs ticked to-do items. Offer one `Apply / Skip` confirmation to tick items proven complete in code; leave uncertain items open.
4. **Git state:** branch, remote/upstream, staged changes, and unstaged changes. Never stage pre-existing work.
5. **Classification:**
   - *Convention structure:* `canonical` (`AGENTS.md` <= 150 lines, resolving `.ai/*.md` pointers, all detailed rules indexed in `.ai/`), `partial` (broken pointers, unreachable `.ai/` files, root > 150 lines, or detailed domain rules embedded in `AGENTS.md`), `alternate-only` (only non-canonical shared AI files), or `none`.
   - *Repository mode:* `empty repo` (only `.git` and README/LICENSE/`.gitignore`), `pre-code repo with AI files`, `existing repo without AI files`, or `existing repo with AI files`.

Report findings in at most 12 lines (mode, structure, other instruction files, Git state, and candidate checks, noting that pre-existing work is never staged and checks may expose existing failures).

- **Pre-existing staged or dirty files:** If anything is already staged, ask **Continue without commit (Recommended)** vs **Stop to clean index** before any write; continuing disables Step 10 commit/push for the run. Never touch pre-existing dirty files unless a convention file itself is dirty—then show the exact merged result and offer **Apply merged change** (also disables commit/push), **Skip this path**, or **Stop**.
- If convention structure is `none`, proceed to Step 2 (empty repo) or Step 4 (existing repo). Whenever **any** shared AI instruction file exists, always stop at Step 1.5—even if inspection found zero defects.

## Step 1.5: Choose the run

Show a compact 3-row table (`reads` | `may write` | `decisions revisited` | `typical use`) and ask:

- **Canonical or partial** (with or without additional shared formats):
  - **Focused update (Recommended)**: validate current files against commands, paths, configs, citations, precedence, and contradictions. Treat coherent existing Markdown, absent optional topics/settings, and existing `docs/` names/classifications as settled team policy—ask only about concrete defects, contradictions, or new manifest/tool gaps, and never rewrite coherent prose or headings for style. In additional shared formats, report equivalent or non-conflicting scoped rules without re-interviewing them.
  - **Full re-audit**: run Steps 3–10 across every rule.
  - **Validate only**: run read-only checks (Steps 3, 7.3, 9), report findings, and stop without writing or committing.
- **Alternate-only**:
  - **Migrate interactively (Recommended)**, **Audit only** (read-only verdict report), or **Leave unchanged** (report precedence over `AGENTS.md` and stop).

For pre-code repos with AI files, ask Step 2 project intent/tooling before auditing foreign claims in Step 3.

## Step 2: Empty and pre-code repositories

1. Ask in plain text what the project builds (goal, intended users, expected stack, open questions). If the language remains open, ask up to 3 plausible languages plus **Undecided** before drafting the sketch.
2. Draft `docs/first-sketch_<today>.md` starting with:
   > **Initial sketch, not a source of truth.** Written on <today> before any code existed. Plans change; check `.ai/` and the code for what is actually decided.
   List every explicitly unresolved stack, format, or tooling question under **Open questions** (never write `"None"` while choices remain open). Show the draft and ask `Apply / Skip`.
3. When a language is chosen without a manifest or package manager, ask:
   - **Document rules only (Recommended)**: create no manifest, dependencies, or commands; later interviews cover tool-agnostic rules only and never ask for frameworks or write commands in `AGENTS.md` or `.ai/`.
   - **Bootstrap tooling**: choose package manager and minimal manifest/config in the next turn.
   - **Leave language undecided**: omit language-dependent `.ai/` files.

## Step 3: Audit existing AI files

In **Focused update**, inspect only for contradictions, broken commands/paths/pointers, unsupported citations, or precedence conflicts; preserve coherent rules untouched and offer diffs only for concrete findings (**Apply fix**, **Remove rule**, or **Keep as open conflict** for deterministic defects; **Keep current wording**, **Audit this rule**, or proposed fix for ambiguities).

In **Full re-audit** or **Migrate interactively**, present every rule of each file in a table (splitting tables over 15 rows under subheadings so nothing is hidden) with a ~8-word reason and one verdict:

- **Keep**: specific, accurate, matches repo and scope.
- **Rewrite**: sound intent, vague or inaccurate wording.
- **Enforce**: belongs in tool config (becomes a 1-line pointer in Step 7 if already enforced, or a Step 6 enforcement question if not yet configured).
- **Move**: rationale or plan that belongs in `docs/` (record target living/snapshot type and path; confirm full draft once in Step 7 before deleting source).
- **Delete**: false, obsolete, contradicts repo/policy, duplicates tool defaults, or dictates AI chat tone.

State whether leaving the file overrides `AGENTS.md`, then ask per file: **Use these verdicts (Recommended)**, **Review rule by rule**, or **Leave file untouched** (excludes from migration/deletion; record any active conflict). Also ask whether to keep any existing weakened lint/compiler setting (e.g. a disabled rule).

Preserve each imported rule's directory or glob scope (`Applies to: <repo-relative path or glob>` after `Last reviewed` in `.ai/`, or leave valid narrowly scoped files such as nested `AGENTS.md` or path-scoped `.github/instructions/*.md` in place at their original scope unless the user chooses to broaden them).

## Step 4: Tidy `docs/`

When `docs/` exists or Step 2 created a sketch:
- In bootstrap, migration, or full re-audit without an existing docs policy, ask:
  - **Snapshot + living docs (Recommended)**: show the proposed `AGENTS.md` Docs bullets (naming Step 2's exact sketch path as a possibly outdated snapshot when created); note this is Ground Rules' maintainability convention.
  - **Pointers only**: read-trigger pointers to existing docs without naming/immutability rules.
  - **Custom policy**: user-specified rules.
- In **Focused update**, preserve the presence or absence of a Docs section and leave existing unclassified or nonconforming `docs/` names untouched unless a collision, broken link, new evidence, or user request requires a decision.

When `docs/` filenames break the active convention:
1. Build the case-insensitive final-path map first; block `Apply` on any colliding destination until resolved. Show a table of nonconforming files (`current` | `proposed` | `type`).
2. Ask one rename question per nonconforming file (batched up to 4 per call), starting each option description with `→ <final-name>`:
   - Derive date options from filename/content (`12.03` -> offer both readings; `"January 2026"` -> `2026-01-01` with `Date approximate (...)`). Offer first-commit date only when `docs/` files have distinct first-commit dates.
   - When snapshot date is unknown, offer **Keep current name (Recommended)**, **Use naming date** (adds `Date approximate (original date unknown; named on <today>).`), and **Treat as living doc** (only if actively maintained; adds `Last reviewed`).
   - When document type is unknown and only letter case, spaces/separators, or `.MD` extension violate naming (no date token, copy suffix, or collision), also offer **Normalize filename only** (`→ <lowercase-hyphenated>.md`), leaving body, type, and date metadata unchanged and reporting it as unclassified.
3. Execute approved renames without staging (using a two-step temporary rename for case-only changes on case-insensitive filesystems), verify destinations before writing pointers, and update references across living docs, AI files, and configs (report stale links inside immutable snapshots or application code without editing them).

## Step 5: Propose `.ai/` structure and files

In **Focused update**, keep the current `.ai/` layout unless repairing a structural defect (such as domain rules embedded in root `AGENTS.md`), adding a newly requested domain, or splitting a file over ~300 lines.

In bootstrap, migration, or full re-audit, batch structure and file selection concisely:
1. **Structure:** **Focused files (Recommended)** (one `.ai/<topic>.md` per approved domain, created only if >=1 rule is approved), **Compact file** (`.ai/project.md` under 300 lines), or **Custom structure** (include **Stack is still changing** when tech-stack stability is unclear so `.ai/tech-stack.md` is omitted cleanly). Omit language-dependent files when language is **Undecided**.
2. **Candidate `.ai/` files:** Multi-select of domain files warranted by repo evidence and Step 3 verdicts (e.g. `.ai/architecture.md`, `.ai/code-style.md`, `.ai/testing.md`, `.ai/security.md`), naming each candidate's exact `.ai/<file>.md` path and scope, with at most 3 candidates plus **No topics for now** per question (or a 2-option choice `<candidate>` vs **No topics for now** when only one exists). Omitted candidates are declined and never re-offered, and approved mappings are never silently split into extra files.

## Step 6: Interview, file by file

Work through every approved `.ai/` file (skipping unchanged files in **Focused update**):

1. **Topics.** Multi-select of specific rule topics for this file (up to 3 candidates + **No topics for now** per question), noting any Step 3 rules already accepted for it. Unselected displayed topics are declined; ask a split follow-up only for not-yet-displayed candidates when **No topics for now** was not chosen. Honor free-text topics in full. Interview **only** rule families within selected topic boundaries; omit the file and its `AGENTS.md` pointer if zero rules end up approved.
2. **Rules (industry standards first, batched up to 4 questions per call).** Fetch official primary sources and offer up to 4 distinct options:
   - **Best practice `(Recommended)`**: official language/framework/tool standard with URL. When a cohesive official guide covers mechanical conventions, prefer recommending that standard cleanly rather than fragmenting into micro-questions.
   - **Common in the ecosystem**: mainstream practice when distinct from official docs.
   - **Current in this repo**: actual pattern with file counts and honest quality note (merge with Best practice if identical; omit in empty repos).
   - **Alternative** or **Your preference (personal config)** (when applicable).
   - **Project decision** (architecture boundaries, folder conventions, un-sourced team rules): state there is no external source, include **No rule** among the up to 4 options, and keep high-level boundary rules separate from prescriptive folder/library choices unless requested. Keep rules at the abstraction level selected—never inject unapproved libraries, test doubles, or implementation techniques.
   - **Rollout timing:** When a chosen rule conflicts with existing code or checks, ask **From now on (Recommended)** vs **After migration** (`After migration.` is the sole deferred marker; deferred rules never claim active checking/CI and get a `docs/todo/` entry).
3. **Enforcement.** Point to existing active tool checks in one option (no fake "not enforced" variant unless showing the config-weakening diff). For unconfigured installed tools, offer enforced (with minimal config diff) vs unenforced; ask new package installs one turn before their config diff. Note if existing code will fail the check.
4. **Open round.** For newly created or re-audited files, ask **No more rules (Recommended)** vs **Suggest some** (free-text adds custom rules, sharpened and confirmed via `Apply / Skip`).
5. **Run-local decision record.** Track each authorized rule's ID, `.ai/` destination, scope, exact wording, origin (`existing team policy`, `explicit answer`, `Keep/Rewrite verdict`, `Delete verdict`, `enforcement pointer`, or `review fix`), and checking config or fetched `URL` + verbatim supporting sentence for Step 9. Never write this record into repository files.

## Step 7: Write the files

`AGENTS.md` (at most 150 lines):

```markdown
# <Project name>

Last reviewed: <today>

<1-3 durable sentences describing what the repo is; never document temporary absence of code or tooling.>

## Commands

All commands: <manifest or task runner, e.g. `package.json`, `Taskfile.yml`, `Cargo.toml`>. Most used:

- `<install>`
- `<test>`
- `<lint>`

## Workflow

<Only explicitly chosen or kept workflow rules; listing a command above never authorizes adding "Run <cmd> before finishing".>
- Keep `AGENTS.md` and `.ai/` current. If a rule contradicts the code you're changing or a decision made with the user, or your change makes a rule, command or pointer wrong, stop and propose the edit; once approved, make it in the same change and bump `Last reviewed`. Don't silently follow a wrong rule or work around it.

## Rules

<Include only when >=1 rule is marked `After migration.`: `Rules apply to new and changed code, unless marked "After migration.". Existing code may not follow them yet.`>

Detailed rules live in `.ai/`. Read the matching file before working in that area:

- Before changing structure, adding modules or moving code: `.ai/architecture.md`
- Before writing or reviewing code: `.ai/code-style.md`
- <one concrete read-trigger bullet per written `.ai/` file>

## Docs

<Include only accepted Step 4 Docs statements; omit section if none.>
```

Each `.ai/*.md` file (at most 300 lines):

```markdown
# <Topic>

Last reviewed: <today>

<Optional when scoped: `Applies to: <repo-relative path or glob>`>

## <Subtopic>

- <Active imperative rule.> <Optional `Why: <user reason or exact source phrase>.`> <Enforced in CI by: `<tool/config/command/job>` | Checked by: `<tool> (<config>; <command>)` | Source: <URL> | Project decision>
- <Deferred imperative rule.> After migration. <Optional `Why: <reason>.`> <Source: <URL> | Project decision>
```

Writing invariants:
- **Command & CI accuracy:** Every published command must have valid repository wiring (manifests, scripts, configs, covered workspaces). Group multi-project commands by area when no valid root aggregate covers all packages.
  - *Missing machine executable* (repo wiring exists, tool absent/sandboxed locally): keep the command and record `not run here: <reason>` in Step 10—never treat machine absence as repo migration work.
  - *Known baseline failure* (valid command fails on existing code): disclose the baseline failure beside the command in `AGENTS.md` (and in any `.ai/` pointer that names it, or prefer a passing scoped check) and track it in `docs/todo/`.
  - *Missing/broken project wiring* (missing script, dependency, or broken aggregate target): omit from `AGENTS.md` and active `.ai/` pointers; report as an open problem (or record in `docs/todo/` only if the user deferred wiring it).
  - *CI claims:* Use `Enforced in CI by` (replacing `Checked by`) **only** when a structurally valid required CI workflow (`on` trigger, runnable job/`runs-on`, step running that exact check) is verified; treat incomplete workflows as local-only (`Checked by`) and report the workflow defect.
- **One terminal marker, zero prose duplication:** Every `.ai/` rule ends with **one** marker (`Enforced in CI by`, `Checked by`, `Source`, or `Project decision`—never prefixed with `Basis:` and never combined). Tool pointers never list configured values (quotes, line length, rule IDs) in prose. Use `Source: <URL>` only when the recorded sentence entails the full rule; otherwise use `Project decision`.
- **Durable facts only:** Never copy exact package versions, file counts, or inventories that live in manifests/configs (major-version upper bounds only when material). `AGENTS.md` indexes `.ai/` without duplicating detailed rules. Leave `Last reviewed` and file bytes untouched on a zero-change **Focused update**.

Execute in order:
1. **Confirm drafts:** Show complete new/rewritten drafts (or minimal diffs in **Focused update**) and batch `Apply / Skip` confirmations (up to 4 files per call). Skipping a new `.ai/` file drops its `AGENTS.md` pointer (if it had dedicated config/dependency approvals, ask `Retain` / `Cancel`).
2. **Dependencies & configs:** Install approved dependencies via the repo's package manager; on failure, restore manifests/lockfiles, clean created artifacts, and ask **Keep rule unenforced (Recommended)**, **Drop the rule**, or **Stop for environment fix**. Apply approved tool configs and non-secret example files.
3. **Run checks safely:** Run only literal, read-only check commands (`gofmt -l`, `cargo fmt --all --check`, `--noEmit`). Never run fix/write modes, shell loops/`eval`/`xargs`, copy the repo to `/tmp`, or redirect tool caches (`GOCACHE`, etc.). If a check's write safety is uncertain or sandboxed, skip running it and record `not run here: <reason>`. Snapshot and restore any unexpected check artifacts.
4. **Write Markdown, deletions & cleanup:** Write approved Markdown (re-confirming if dependency recovery altered policy). Offer `Apply / Skip` to delete obsolete migrated shared AI files (never local overrides unless asked), without staging. Remove legacy `.ai/.ground-rules.json` or `ground-rules:managed` markers via approved diffs.

## Step 8: Claude Code permissions

Only when shared `.claude/` config already exists or the user confirms team Claude Code usage (and never unprompted when absent during **Focused update**), offer merging `"Edit(/AGENTS.md)"` and `"Edit(/.ai/**)"` into `permissions.ask` in `.claude/settings.json` (source: https://code.claude.com/docs/en/permissions). Skip without asking if path-equivalent entries already exist; otherwise preserve all existing keys, show the diff, and ask `Apply / Skip`.

## Step 9: Migration to-do and review by a fresh agent

Reconcile code violations, known baseline check failures, and deferred items (`After migration.` rules or deferred command wiring) against `docs/todo/`:
- Never edit existing snapshot bodies beyond approved `[x]` ticks; omit duplicates of open items.
- When new items remain, show `docs/todo/<descriptive-topic>_<today>.md` (`conventions-migration_<today>.md` for mixed items) and ask `Apply / Skip`:

```markdown
# <Descriptive topic>

Written on <today>. Tick items when done; put new items in a new dated file.

| Done | File | Problem | Rule |
|---|---|---|---|
| [ ] | `<path>` | <violation or baseline failure> | [<rule>](../../.ai/<file>.md) or Baseline command: `<command>` |
```

If applied, confirm a minimal diff adding `"Open migration tasks are in docs/todo/."` under `AGENTS.md` Docs (and optional Workflow tick note). If the user skips a to-do required by a deferred rule or deferred command, ask whether to **Drop** that deferred item or **Stop and restore** this run's policy changes.

Launch **one** fresh read-only review agent (`eval-reviewer` when available, otherwise a read-only `general-purpose` subagent) that sees **only** the repository, changed file paths, and sanitized Step 6.5 decision/move/delete records—never the interview transcript. Ask it to report `file:line` + quote findings (`blocker`, `major`, `deterministic-minor`, `stylistic-nitpick`) against:
- Active contradictions across `AGENTS.md`, `.ai/*.md`, and tool configs; duplicated rules across files or restated tool settings in prose.
- Unapproved rules, altered scopes, missing moved-doc sections, or snapshot body edits.
- Invalid commands, false `Enforced in CI by` claims, undisclosed baseline failures, machine-local tool absences misrecorded as repo to-dos, or unsupported `Source` / `Why` claims.
- Size limits (`AGENTS.md` > 150, `.ai/*.md` > 300), missing `Last reviewed`, broken pointers, unreachable `.ai/` files, or leftover ownership markers.

Verify every finding yourself against the files and decision record; list discarded false positives in one line each. Present confirmed items under **1. Fixes to written files** (multi-select), **2. Needs a decision**, **3. Code that breaks the new rules**, and **4. Outside scope**. Apply approved fixes, re-read changed files yourself to confirm zero remaining defects, and record any user-retained defect under **Open conflicts** (never report `Open conflicts: none` when one remains).

## Step 10: Commit and report

Begin every terminal output—including read-only and open-conflict completions—with `## Ground Rules final report`.

1. **Changed files:** Separate Ground Rules changes from untouched or pre-existing dirty paths.
2. **Unverified checks:** Commands `not run here`, baseline failures, or skipped installs.
3. **Commit & push:** When a diff exists and Step 1 found no pre-existing staged/merged-dirty paths, propose a commit message matching `git log` style (fallback: `Bootstrap repository conventions`, `Migrate AI instructions`, or `Update repository conventions`—never include `Generated with ...` or `Co-Authored-By` lines) and ask `Commit` / `Don't commit`. On `Commit`, stage explicit paths only (never `git add .` or `-A`), verify `git diff --cached --name-status`, and commit without skipping hooks. Ask push separately only when a commit was created and a remote exists.
4. **Summary tables:** Written/updated files, migration to-do / code violations, check results, open conflicts, and out-of-scope notes.
