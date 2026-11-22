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
- **Scope: conventions, not application code.** Change only `AGENTS.md`, `.ai/`, `docs/`, AI instruction files, tool configs (linter, formatter, compiler, CI), non-secret example configs, dependency manifests/lockfiles, and `.claude/settings.json` permissions (Step 8). Skip `.claude/skills/` and never edit application code; report code violations at the end. Never read or display `.env` or credential files, and never write secrets or secret-shaped sample tokens into example configs, rules, or docs—keep placeholders empty (e.g. `API_TOKEN=`).
- **Team-owned Markdown, zero hidden state.** `AGENTS.md` and `.ai/*.md` are ordinary repository files. Never write hashes, `ground-rules:managed` markers, `.ai/.ground-rules.json`, or hidden ownership state. Derive every conclusion from current files, repository facts, and answers in this run.

## Asking questions

Use `AskUserQuestion`. If unavailable, render the same numbered questions and options in plain text, end the turn, and continue from the user's reply—never skip decisions or choose silently.

- Ask at most 4 questions per call, 2–4 options each. Rely on the tool's built-in `Other` field; never add your own `Other` option. A single-option prompt is a statement: say it in prose instead.
- Mark exactly one option `(Recommended)`, listed first, whenever primary sources, repo evidence, stated user intent, or a clearly labeled workflow default supports it (for multi-select, mark each option you would select). If no option has backing evidence, recommend none and say why—unless the user asks you to help decide, in which case recommend one, label it your judgment, and keep every valid alternative.
- Keep option labels to 1–5 words (excluding `(Recommended)` and `(Personal)` tags) and descriptions to ~20 words stating the consequence and main trade-off. State once in the message which options lack an external source.
- Use two-option `Apply` / `Skip` confirmations only for concrete displayed changes (diffs, drafts, reference updates, deletions), ending with `(to apply with changes, type them)`. Use specific labels (`Commit` / `Don't commit`, `Continue without commit` / `Stop to clean index`, `Retain` / `Cancel`) for lifecycle choices. When a typed edit alters a shared command, path, or rule, update every affected draft consistently and show changed paths before writing.
- Split lists over 4 items across consecutive questions; never drop candidates silently. When one rule has 5 real alternatives, show the top 3 plus **Show more options** (then the rest plus **Back to first options**).
- Batch independent questions together to minimize turns, but never ask a dependent question in the same turn as its prerequisite (e.g., ask a new dependency install before its config diff).
- Use plain-text questions only for genuinely open input (project intent, custom reasons), bolded on the final line alone.

## Presentation

Keep output scannable in a terminal—never overwhelm the user with walls of prose:

- Start every message (except Step 10's final report, which begins with `## Ground Rules final report`) with one bold status line naming the step and outcome.
- Put multi-attribute data in compact tables (evidence, verdicts, renames, findings, changed files, check results, to-do items), with URLs in their own column.
- Show minimal line diffs for edits to existing configs or focused updates; show complete content plus one summary line of dropped items when creating or replacing a file.
- Keep prose before questions under ~12 lines (excluding Step 3 rule-audit tables and file drafts). Omit internal bookkeeping the user does not need to decide.

## Naming and dating

- Filenames use lowercase `kebab-case` within parts, `_` between parts, ISO `YYYY-MM-DD` dates, and lowercase `.md` (`auth-redesign_2026-10-22.md`). Obtain today's date from the system.
- **Snapshots** (sketches, plans, research, meeting notes, `docs/todo/` checklists) carry `_YYYY-MM-DD` in the filename and are immutable after creation, except ticking `[x]` in `docs/todo/`. Newer versions create a new dated file.
- **Living docs** (canonical root `AGENTS.md`, `.ai/*.md`, and `docs/` files explicitly created or classified by the user as living docs) have no date in the filename and place `Last reviewed: YYYY-MM-DD` right after `# Title`. Never inject `Last reviewed` into nested `AGENTS.md` files kept in place, unclassified normalized files, or existing `docs/` files touched only for link updates. Bump `Last reviewed` only when content changes or during an explicit **Full re-audit**.

## Step 1: Inspect

Read only; change nothing yet. Collect:

1. **Stack & checks:** manifests, lockfiles, `README*`, CI workflows, linter/formatter/compiler configs, and directory layout. Verify what scripts and wrappers actually do by reading them rather than guessing from filenames. Never read `.env` or secret/credential files.
2. **AI instruction files (any depth):** `AGENTS.md`, `.claude/AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, `CLAUDE.local.md`, `.claude/rules/`, `.claude/settings.json` (config inventory only), `.cursorrules`, `.cursor/rules/`, `.github/copilot-instructions.md`, `.github/instructions/`, `.windsurfrules`, `GEMINI.md`, `.ai/`. Skip `.claude/skills/`. Treat legacy `.ai/.ground-rules.json` and `ground-rules:managed` comments as cleanup targets, never provenance. Fetch current official loading/scope/precedence docs for each detected format and display a compact precedence table before claiming a conflict or proposing deletion; if official precedence cannot be verified, mark precedence unknown rather than claiming a precedence conflict, never delete without explicit confirmation, and still offer Step 7.4 `Apply / Skip` deletion in migration/re-audit once all of a shared file's rules are migrated or discarded. Separate machine-local overrides—files designated local by format or filename (`CLAUDE.local.md`, `*.local.md`, `.claude/settings.local.json`), gitignored AI files, or untracked personal/machine-path overrides: report them separately, and never audit, migrate, edit, delete, or commit them unless explicitly asked.
3. **`docs/` & `docs/todo/`:** filenames, cross-links, and open vs ticked to-do items (recording items proven complete in code for Step 4; leave uncertain items open).
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
  - **Validate only**: run read-only checks (Steps 3, 7.2, and Step 9's read-only review agent without offering `docs/todo/` writes), then finish with Step 10's `## Ground Rules final report` without writing or committing.
- **Alternate-only**:
  - **Migrate interactively (Recommended)**, **Audit only** (read-only verdict report ending with `## Ground Rules final report`), or **Leave unchanged** (report precedence over `AGENTS.md` and end with `## Ground Rules final report`).

For pre-code repos with AI files in **Migrate interactively** (or **Full re-audit** when no project-intent sketch or canonical `.ai/` baseline exists yet), ask Step 2 project intent/tooling before auditing foreign claims in Step 3.

## Step 2: Empty and pre-code repositories

Run only for an `empty repo` or during **Migrate interactively** (or **Full re-audit** without an existing sketch/baseline) on a `pre-code repo with AI files`; skip Step 2 in **Focused update**, **Validate only**, **Audit only**, and **Leave unchanged**.

1. Ask in plain text what the project builds (goal, intended users, expected stack, open questions). Never invent undecided users or requirements. If the language remains open, ask up to 3 plausible languages plus **Undecided** before drafting the sketch.
2. Draft `docs/first-sketch_<today>.md` starting with:
   > **Initial sketch, not a source of truth.** Written on <today> before any code existed. Plans change; check `.ai/` and the code for what is actually decided.
   List every explicitly unresolved user, product, format, stack, or tooling question under **Open questions** (never write `"None"` while choices remain open). Show the draft and ask `Apply / Skip`.
3. When a language is chosen without a manifest or package manager, ask:
   - **Document rules only (Recommended)**: create no manifest, dependencies, or commands; later interviews cover tool-agnostic rules only, never ask for frameworks, never write commands in `AGENTS.md` or `.ai/`, and never cite test-runner or mocking-library docs (including standard-library mocking modules)—use `Project decision` when no mechanism-neutral language spec entails the rule.
   - **Bootstrap tooling**: choose package manager and minimal manifest/config in the next turn.
   - **Leave language undecided**: omit language-dependent `.ai/` files.

## Step 3: Audit existing AI files

Seed the run-local decision record (Step 6.5) with coherent existing canonical/scoped rules (`existing team policy`, verifying any cited `Source` URLs). In **Validate only** and **Audit only**, record findings/verdicts read-only without asking confirmation questions.

In **Focused update**, inspect only for contradictions, broken commands/paths/pointers, unsupported citations, or precedence conflicts; preserve coherent rules untouched and offer diffs only for concrete findings (**Apply fix**, **Remove rule**, or **Keep as open conflict** for deterministic defects; **Keep current wording**, **Audit this rule**, or proposed fix for ambiguities).

In **Full re-audit** or **Migrate interactively**, present every rule of each file in a table (splitting tables over 15 rows under subheadings so nothing is hidden) with a ~8-word reason and one verdict:

- **Keep**: specific, accurate, matches repo and scope.
- **Rewrite**: sound intent, vague or inaccurate wording (including bare stdin-reading or write-mode commands rewritten to read-only check flags).
- **Enforce**: belongs in tool config (becomes a 1-line pointer in Step 7 if already enforced, or a Step 6 enforcement question if not yet configured).
- **Move**: rationale or plan that belongs in `docs/` (record target living/snapshot type and path, rewrite aspirational or unimplemented present-tense claims against actual repo structure so living docs state future direction rather than false current fact, and confirm the full draft once in Step 7 before deleting source).
- **Delete**: false, obsolete, contradicts repo/policy, duplicates tool defaults, or dictates AI chat tone.

State whether leaving the file overrides `AGENTS.md`, then ask per file: **Use these verdicts (Recommended)**, **Review rule by rule** (asks structured per-rule verdict questions, batched up to 4 per call), or **Leave file untouched** (excludes from migration/deletion; record any active conflict).

Default `(Recommended)` to keeping valid narrowly scoped files (nested `AGENTS.md`, path-scoped `.github/instructions/*.md`, valid scoped `.cursor/rules/*.mdc`) in place at their original path and scope—leaving all-`Keep` files byte-for-byte untouched and applying any accepted in-place `Rewrite`/`Delete` diff without migrating or deleting the file. Consolidate a scoped rule into `.ai/` (with `Applies to: <repo-relative path or glob>` right after `Last reviewed`) only when the user explicitly chooses consolidation, and delete a scoped file only when all of its rules receive `Delete` or `Move` verdicts. Never broaden a narrow scope without approval.

## Step 4: Tidy `docs/`

In non-read-only runs (excluding **Focused update** unless new completion evidence exists), if Step 1 found open `docs/todo/` items proven complete in code, offer one `Apply / Skip` confirmation to tick `[x]` on those items, leaving all other snapshot lines untouched.

When `docs/` exists or Step 2 created a sketch:
- In bootstrap, migration, or full re-audit without an existing docs policy, ask:
  - **Snapshot + living docs (Recommended)**: in the message body above the question, display the exact proposed `AGENTS.md` `## Docs` bullets—dated immutable `_YYYY-MM-DD.md` snapshots (except `[x]` in `docs/todo/`), undated living docs with `Last reviewed: YYYY-MM-DD`, and any concrete read-trigger (including checking `docs/` starting with Step 2's exact `docs/first-sketch_<today>.md` labeled a possibly outdated snapshot when created). Never add undisplayed `## Docs` rules later in Step 7, and add read-triggers to renamed living docs only at their approved final destination (never for unclassified `Normalize filename only` files). Note this is Ground Rules' maintainability convention.
  - **Pointers only**: read-trigger pointers to existing docs without naming/immutability rules.
  - **Custom policy**: user-specified rules.
- In **Focused update**, preserve the presence or absence of a `## Docs` section and leave existing unclassified or nonconforming `docs/` names untouched unless a collision, broken link, new evidence, or user request requires a decision.

After a naming policy is chosen, when `docs/` filenames break it:
1. Build the case-insensitive final-path map first; block `Apply` on any colliding destination until resolved. Show a table of nonconforming files (`current` | `proposed` | `type`).
2. Ask one rename question per nonconforming file (batched up to 4 per call), starting each option description with `→ <final-name>`:
   - Always include **Keep current name** on every rename question, and make **Keep current name (Recommended)** the first option whenever a date is unknown or day/month order is ambiguous (for ambiguous numeric dates, offer **Keep current name (Recommended)** plus both ISO `YYYY-MM-DD` readings; when a snapshot's date is unknown, offer **Keep current name (Recommended)**, **Use naming date** adding `Date approximate (original date unknown; named on <today>).`, and **Treat as living doc** only if actively maintained). Derive clear approximate dates from text (`"January 2026"` -> `2026-01-01` with `Date approximate (...)`); offer first-commit date only when `docs/` files have distinct first-commit dates.
   - When a file's living-vs-snapshot type cannot be determined from its body or title and the filename has no date token, copy/version suffix, or target collision—differing from `<lowercase-hyphenated>.md` only in letter case or spaces/word separators—also offer **Normalize filename only** (`→ <lowercase-hyphenated>.md`, keeping every word token including status words while lowercasing letters/extension and hyphenating spaces/separators), leaving body, type, and date metadata unchanged and reporting it as unclassified.
3. Execute approved renames without staging (never `git mv`; use a two-step temporary rename for case-only changes on case-insensitive filesystems), verify destinations before writing pointers, and update references across living docs, AI files, and configs (report stale links inside immutable snapshots or application code without editing them).

## Step 5: Propose `.ai/` structure and files

In **Focused update**, keep the current `.ai/` layout unless repairing a structural defect (such as domain rules embedded in root `AGENTS.md`), adding a newly requested domain, or splitting a file over ~300 lines.

In bootstrap, migration, or full re-audit, batch structure and file selection concisely in one call:
1. **Structure:** **Focused files (Recommended)** (one `.ai/<topic>.md` per approved domain, created only if >=1 rule is approved), **Compact file** (`.ai/project.md` under 300 lines), or **Custom structure**. Omit language-dependent files when language is **Undecided**. When tech-stack stability is unclear, ask whether **Stack is still changing** (omitting `.ai/tech-stack.md` when chosen).
2. **Candidate `.ai/` files:** Multi-select of domain files warranted by repo evidence and Step 3 verdicts (e.g. `.ai/architecture.md`, `.ai/code-style.md`, `.ai/testing.md`, `.ai/security.md`), naming each candidate's exact `.ai/<file>.md` path and scope, with at most 3 candidates plus **No topics for now** per question (or a 2-option choice `<candidate>` vs **No topics for now** when only one exists). Unselected displayed candidates are declined and never re-offered, and approved mappings are never silently split into extra files.

## Step 6: Interview, file by file

Work through every approved `.ai/` file (skipping unchanged files in **Focused update**):

- **6.1 Topics.** Multi-select of specific rule topics for this file (up to 3 candidates + **No topics for now** per question), noting any Step 3 rules already accepted for it. Unselected displayed topics are declined; ask a split follow-up only for not-yet-displayed candidates when **No topics for now** was not chosen. Honor free-text topics in full. Interview **only** rule families within selected topic boundaries; omit the file and its `AGENTS.md` pointer if zero rules end up approved.
- **6.2 Rules (industry standards first, batched up to 4 questions per call).** Fetch official primary sources and offer up to 4 distinct options:
  - **Best practice `(Recommended)`**: official language/framework/tool standard with URL. When a cohesive official guide covers mechanical conventions, prefer recommending that standard cleanly rather than fragmenting into micro-questions.
  - **Common in the ecosystem**: mainstream practice when distinct from official docs.
  - **Current in this repo**: actual pattern with file counts and honest quality note (merge with Best practice if identical; omit in empty repos).
  - **Alternative** or **Your preference (personal config)** (when applicable).
  - **Project decision** (architecture boundaries, folder conventions, un-sourced team rules): state there is no external source, and keep high-level boundary rules separate from prescriptive folder/library choices unless requested. Include **No rule** (writes no prose rule for that subtopic) on every **Project decision** question and on any optional strictness, gradual-typing, or tool-adjacent prose question where omitting a written rule is a valid team choice. Keep rules at the abstraction level selected—never inject unapproved libraries, test doubles, or implementation techniques.
  - **Rollout timing:** When a chosen rule conflicts with existing code or checks, ask **From now on (Recommended)** (applies to new and changed code immediately; existing code violations go to `docs/todo/`) vs **After migration** (`After migration.` is the sole deferred marker; deferred rules never claim active checking/CI and get a `docs/todo/` entry).
- **6.3 Enforcement.** Point to existing active tool checks in one option (no fake "not enforced" variant unless showing the config-weakening diff). Within audited rules or selected topics, never silently tighten or contradict an existing disabled or non-strict tool setting (e.g. disabled lint rule or partial typechecker)—ask whether to keep it as-is, and never ask about tool settings for declined files or topics. For unconfigured installed tools, offer enforced (with minimal config diff) vs unenforced; ask new package installs one turn before their config diff. Note if existing code will fail the check.
- **6.4 Open round.** For newly created or re-audited files, ask **No more rules (Recommended)** vs **Suggest some** (free-text adds custom rules, sharpened and confirmed via `Apply / Skip`).
- **6.5 Run-local decision record.** Track each authorized rule's ID, `.ai/` destination, scope, exact wording, origin (`existing team policy`, `explicit answer`, `Keep/Rewrite verdict`, `Delete verdict`, `enforcement pointer`, or `review fix`), checking config or fetched `URL` + verbatim supporting sentence, and approved Step 3/4 move, rename, doc-classification, and deletion choices for Step 9. Never write this record into repository files.

## Step 7: Write the files

`AGENTS.md` (at most 150 lines):

```markdown
# <Project name>

Last reviewed: <today>

<1-3 durable sentences describing what the repo is; never document temporary absence of code or tooling.>

## Commands

<Omit section when no valid commands exist, e.g. Document rules only. Name `All commands: <manifest>` only when that manifest's targets are valid; omit broken aggregate manifests/runners and group valid commands by package/directory when needed.>
All commands: <manifest or task runner, e.g. `package.json`, `Makefile`, `Cargo.toml`>. Most used:

- `<install>`
- `<test>`
- `<lint>`

## Workflow

<Only explicitly chosen or kept workflow rules; listing a command above never authorizes adding "Run <cmd> before finishing".>
- Keep `AGENTS.md` and `.ai/` current. If a rule contradicts the code you're changing or a decision made with the user, or your change makes a rule, command or pointer wrong, stop and propose the edit; once approved, make it in the same change and bump `Last reviewed`. Don't silently follow a wrong rule or work around it.

## Rules

<Include `Rules apply to new and changed code. Existing code may not follow them yet.` when existing code violates active `From now on` rules, or `Rules apply to new and changed code, unless marked "After migration.". Existing code may not follow them yet.` when >=1 rule is marked `After migration.`. Omit in empty repos or when no rollout gap exists.>

Detailed rules live in `.ai/`. Read the matching file before working in that area:

- Before changing structure, adding modules or moving code: `.ai/architecture.md`
- Before writing or reviewing code: `.ai/code-style.md`
- <one concrete read-trigger bullet per written `.ai/` file>

## Docs

<Include only accepted Step 4 Docs statements or an approved Step 9 `docs/todo/` pointer; omit section if none.>
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
- **Command & CI accuracy:** Every published command must have valid repository wiring (manifests, declared third-party dependencies, scripts, configs, covered workspaces) and use non-mutating check flags (`gofmt -d .`, `prettier --check .`, `cargo fmt --all --check`—never bare stdin-reading `gofmt` or write/fix flags). Group multi-project commands by area when no valid root aggregate covers all packages.
  - *Missing machine executable* (repo manifests/wiring exist, tool absent/sandboxed locally): keep the command and record `not run here: <reason>` in Step 10—never treat machine absence as repo migration work.
  - *Known baseline failure* (valid command fails on existing code): disclose the baseline failure beside the command in `AGENTS.md` and inside any `.ai/` terminal marker that names it (e.g. ``Checked by: `<tool> (<config>; <command>, baseline currently failing)` ``, or prefer a passing scoped check), and track it in `docs/todo/`.
  - *Missing/broken project wiring* (missing script, undeclared tool dependency in manifest, or broken aggregate target): omit from `AGENTS.md` and active `.ai/` pointers; report as an open problem (or record in `docs/todo/` only if the user deferred wiring it).
  - *CI claims:* Use `Enforced in CI by` (replacing `Checked by`) **only** when a structurally valid required CI workflow (`on` trigger, runnable job/`runs-on`, step running that exact check) is verified; treat incomplete workflows as local-only (`Checked by`) and report the workflow defect as an open problem in Step 10 (never a `docs/todo/` entry unless fixing CI was explicitly deferred).
- **One terminal marker, zero prose duplication:** Every `.ai/` rule ends with **one** marker (`Enforced in CI by`, `Checked by`, `Source`, or `Project decision`—never prefixed with `Basis:` and never combined). Tool pointers never list configured values (quotes, line length, rule IDs) in prose. Use `Source: <URL>` only when the recorded sentence entails the full rule; otherwise use `Project decision`.
- **Durable facts only:** Never copy exact package versions, file counts, or inventories that live in manifests/configs (major-version upper bounds only when material). `AGENTS.md` indexes `.ai/` without duplicating detailed rules. Leave `Last reviewed` and file bytes untouched on a zero-change **Focused update**.

Execute in order:
- **7.1 Dependencies & configs:** Install approved dependencies via the repo's package manager; on failure, restore manifests/lockfiles, clean created artifacts, and ask **Keep rule unenforced (Recommended)**, **Drop the rule**, or **Stop for environment fix**. Apply approved tool configs and non-secret example files.
- **7.2 Run checks safely:** Run only literal, read-only check commands (`gofmt -l .`, `cargo fmt --all --check`, `--noEmit`) so any baseline failures are known before confirming Markdown drafts. Never run fix/write modes, shell loops/`eval`/`xargs`, copy the repo to `/tmp`, redirect tool caches (`GOCACHE`, etc.), or run commands that create untracked lockfiles, build directories, or tool caches (`Cargo.lock`, `target/`, `__pycache__/`, `.pytest_cache/`, `.mypy_cache/`, `.ruff_cache/`) unless they are already gitignored or snapshotted and completely removed afterward. If write/artifact safety is uncertain or sandboxed, skip running the command and record `not run here: <reason>`.
- **7.3 Confirm & write Markdown:** Fold any baseline failures discovered in 7.2 into the drafts, show complete new/rewritten drafts (or minimal diffs for `docs/` Move targets and in-place scoped AI file fixes; do not re-ask diffs already confirmed in Step 3 **Focused update**), batch `Apply / Skip` confirmations (up to 4 files per call), and write approved Markdown. Skipping a new `.ai/` file drops its `AGENTS.md` pointer (if it had dedicated config/dependency approvals, ask `Retain` / `Cancel`).
- **7.4 Deletions & cleanup:** After canonical files and any accepted `docs/` Move targets exist on disk, offer `Apply / Skip` to delete obsolete shared AI files (foreign files whose rules were all migrated or deleted, or superseded `.ai/*.md` files—never files kept in place at narrower scope, skipped via `Leave file untouched`, or machine-local overrides unless asked), without staging (never `git rm`). Remove legacy `.ai/.ground-rules.json` or `ground-rules:managed` markers via approved diffs.

## Step 8: Claude Code permissions

Skip without asking on a zero-defect **Focused update** (unless the user explicitly requested Claude Code permissions in this run). Otherwise, only when shared `.claude/` directory config (`.claude/settings.json`, `.claude/CLAUDE.md`, `.claude/rules/`) already exists in the repository, or the user explicitly asked for Claude Code permissions in this run (never ask unprompted whether the team uses Claude Code, and never infer it solely from a migrated root `CLAUDE.md`), offer merging `"Edit(/AGENTS.md)"` and `"Edit(/.ai/**)"` into `permissions.ask` in `.claude/settings.json` (source: https://code.claude.com/docs/en/permissions). Skip without asking if path-equivalent entries already exist; otherwise preserve all existing keys, show the diff, and ask `Apply / Skip`.

## Step 9: Migration to-do and review by a fresh agent

Outside a zero-defect **Focused update**, reconcile code violations, known baseline check failures, and deferred items (`After migration.` rules or deferred command wiring) against `docs/todo/`:
- Never edit existing snapshot bodies beyond approved `[x]` ticks; omit duplicates of open items.
- When new items remain, show `docs/todo/<descriptive-topic>_<today>.md` (`conventions-migration_<today>.md` for mixed items) and ask `Apply / Skip`:

```markdown
# <Descriptive topic>

Written on <today>. Tick items when done; put new items in a new dated file.

| Done | File | Problem | Rule |
|---|---|---|---|
| [ ] | `<path>` | <violation or baseline failure> | [<rule>](../../.ai/<file>.md) or Baseline command: `<command>` |
```

If applied, confirm a minimal diff adding ``- Open migration tasks are in `docs/todo/`.`` under `AGENTS.md` `## Docs` (creating a minimal `## Docs` section with only that bullet if none exists) and, only when displayed and approved, ``- When you finish a migration item listed in `docs/todo/`, tick it there.`` under `## Workflow`. If the user skips a to-do required by a deferred rule or deferred command, ask whether to **Drop** that deferred item or **Stop and restore** this run's policy changes.

Outside a zero-defect **Focused update** (including in **Validate only**), launch **one** fresh read-only review agent (`eval-reviewer` when available, otherwise a read-only `general-purpose` subagent) that sees **only** the repository, changed file paths, and sanitized Step 6.5 decision/move/rename/delete records—never the interview transcript. Ask it to report `file:line` + quote findings (`blocker`, `major`, `deterministic-minor`, `stylistic-nitpick`) against:
- Active contradictions across `AGENTS.md`, `.ai/*.md`, and tool configs; duplicated rules across files or restated tool settings in prose.
- Unapproved rules, altered scopes, missing moved-doc sections, or snapshot body edits.
- Invalid commands, false `Enforced in CI by` claims, undisclosed baseline failures, machine-local tool absences misrecorded as repo to-dos, or unsupported `Source` / `Why` claims.
- Size limits (`AGENTS.md` > 150, `.ai/*.md` > 300), missing `Last reviewed` on canonical root `AGENTS.md`, `.ai/*.md`, or classified living `docs/` files, broken pointers, unreachable `.ai/` files, or leftover ownership markers.

Verify every finding yourself against the files and decision record; list discarded false positives in one line each (and in **Focused update**, silently discard `stylistic-nitpick` items on unchanged prose or headings). If confirmed findings remain, present them under **1. Fixes to written files** (multi-select, labeling severity), **2. Needs a decision**, **3. Code that breaks the new rules**, and **4. Outside scope**. Apply approved fixes, re-read changed files yourself to confirm zero remaining defects, and record any user-retained deterministic defect (`blocker`, `major`, or `deterministic-minor`—never declined `stylistic-nitpick` items) under **Open conflicts** (never report `Open conflicts: none` when one remains).

## Step 10: Commit and report

Begin every terminal output—including read-only and open-conflict completions—with `## Ground Rules final report`.

1. **Changed files:** Separate Ground Rules changes from untouched or pre-existing dirty paths.
2. **Unverified checks:** Commands `not run here`, baseline failures, or skipped installs.
3. **Commit & push:** When a diff exists and Step 1 found no pre-existing staged/merged-dirty paths, propose a commit message matching `git log` style (fallback: `Bootstrap repository conventions`, `Migrate AI instructions`, or `Update repository conventions`—never include `Generated with ...` or `Co-Authored-By` lines) and ask `Commit` / `Don't commit`. On `Commit`, stage explicit paths only (never `git add .` or `-A`), verify `git diff --cached --name-status`, and commit without skipping hooks. Ask push separately only when a commit was created and a remote exists.
4. **Summary tables:** Written/updated files, migration to-do / code violations, check results, open conflicts, and out-of-scope notes.
