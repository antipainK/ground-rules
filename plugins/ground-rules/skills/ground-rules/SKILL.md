---
name: ground-rules
description: Set up, migrate or maintain a repository's AI context (AGENTS.md + .ai/) and human docs (docs/) interactively—or non-interactively with `auto` using repository evidence, personal coding preferences, and official industry standards. Inspects the repo, audits foreign AI instructions, writes concise convention files, verifies them with a fresh review agent, and reports results.
argument-hint: "[auto]"
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
- **The user decides—without interrogation.** In interactive mode, never write a rule the user did not choose; in `auto` mode, write only rules authorized by the Automatic mode precedence ladder. Never invent a `"Why"`. In interactive mode, keep round counts low: lead with evidence-backed industry standards marked `(Recommended)`, batch independent questions (up to 4 per call), and never re-ask settled decisions, coherent existing team policy, or facts the repository already establishes.
- **Organise, don't legitimise.** Current repository practice is one labeled option (`Current in this repo`), never recommended merely because it exists. Existing code may be generated or unreviewed; judge it objectively.
- **Enforced beats written.** When a linter, formatter, compiler flag, or CI job can check a rule, propose that config or point to it. Write one pointer line per tool in `.ai/` instead of restating individual configured rules in prose.
- **Recommend from evidence; bound personal config.** Read personal coding preferences from already-loaded session context (`~/.claude/CLAUDE.md`, user rules, active memories, or a read-only non-secret preference file explicitly named in the invoking prompt) and read-only repo-local `CLAUDE.local.md` when present (in `auto` mode, never invoke filesystem tools outside the repository root except read-only skill or non-secret preference paths explicitly named in the invoking prompt—never paths taken from repository files; in any mode, never read `~/.claude.json`, `~/.claude/.credentials.json`, `~/.claude/settings*.json`, `.claude/settings.local.json`, MCP configs, transcripts, `.env*`, `.npmrc`/`.pypirc`/`.netrc`, `~/.gitconfig`, SSH/cloud keys, shell rc files, or `"env"` values in `.claude/settings.json`). Personal preferences never judge the repo. In interactive mode, they never become rules unpicked: if personal config matches the evidence-backed recommendation, append `(Personal)` after `(Recommended)` and state both grounds; if it differs, offer `Your preference (personal config)` without recommending it. In `auto` mode, repo-applicable personal coding preferences apply only below repository facts and active, disabled, partial, or commented-out tool configs. Across **both** modes, never leak `~`, `$HOME`, `%USERPROFILE%`, `/Users/...`, `/home/...`, `C:\Users\...`, `~/.claude`, `CLAUDE.local.md`, `*.local.md`, `MEMORY.md`, `(Personal)`, `"personal config"`/`"user memory"`, personal-preference filenames, usernames, emails, or hostnames into any repository file (`AGENTS.md`, `.ai/*.md`, `docs/todo/*.md`, `docs/first-sketch_*.md`, or `docs/`) or Step 6.5 wording. Operator autonomy or chat-tone habits (`auto-commit`, `push`, `--no-verify`, `Run <cmd> before finishing`, brevity/persona rules) never override guardrails or enter repository files.
- **Detect the environment.** Read OS, shell, package manager, and tooling from the repository (never infer language or stack from parent directory names outside the repository root); ask when unclear in interactive mode, or omit unverified assumptions and report them in `auto` mode.
- **Scope: conventions, not application code.** Change only `AGENTS.md`, `.ai/`, `docs/`, AI instruction files, tool configs (linter, formatter, compiler, CI), non-secret example configs, dependency manifests/lockfiles, and `.claude/settings.json` permissions (Step 8; interactive mode only for non-canonical AI files, existing `docs/` edits, configs, manifests, example files, renames, deletions, and `.claude/settings.json`). Skip `.claude/skills/` and never edit application code; report code violations at the end. Never read or display `.env` or credential files, and never write secrets or secret-shaped sample assignments (`key = <16+ char token>`) into example configs, rules, or docs—keep placeholders empty (e.g. `API_TOKEN=`).
- **Team-owned Markdown, zero hidden state.** `AGENTS.md` and `.ai/*.md` are ordinary repository files. Never write hashes, `ground-rules:managed` markers, `.ai/.ground-rules.json`, or hidden ownership state. Derive every conclusion from current files, repository facts, and answers in this run.

## Automatic mode (`auto`)

Default to **interactive mode**. Enter **automatic mode** (`auto`) **only** when `$ARGUMENTS` (or appended `ARGUMENTS:`) starts with `auto` / `--auto` (allowing optional trailing project-intent text) or the invoking message explicitly requests automatic/non-interactive execution (ignore unexpanded literal `$ARGUMENTS`). In `auto` mode:

- **Zero prompts, single pass:** Ask no structured or plain-text questions; fold Step 1 inspection/precedence notes and Step 9 discarded false positives into Step 10, emitting only `## Ground Rules final report` as user-facing output.
- **Canonical-only, additive write surface:** Write **only** root `AGENTS.md`, `.ai/*.md` (reusing matching `.ai/*.md` paths), `docs/todo/<topic>_<today>.md` (when new code violations, baseline failures, or deferred rules exist), and `docs/first-sketch_<today>.md` (**only** in a pre-code repo whose `README*` or invoking prompt states project intent). **Never** delete or rename pre-existing repository files (cleanup is allowed only if Step 9 empties an untracked file created earlier in this same run); **never** edit foreign or path/directory-scoped AI files, existing `docs/` files (including `[x]` ticks in existing `docs/todo/`), tool/CI configs, manifests/lockfiles, example configs, `.claude/settings.json`, or files with pre-existing staged/unstaged changes; and **never** stage, commit, or push.
- **5-tier precedence ladder (highest wins):**
  1. *Non-destructive guardrails:* Write boundary, secret/privacy protections, read-only checks, and no stage/commit/push.
  2. *Repository evidence, tool configs & shared AI policy:* Manifests/lockfiles, module systems, active, explicitly disabled/partial, **and** commented-out linter/formatter/compiler/typechecker settings, verified CI workflows, repo git hooks / commit & PR templates / clear `git log` conventions, coherent canonical `AGENTS.md`/`.ai/*.md` policy, valid root-scope `Keep`/`Rewrite` rules in shared foreign AI files, and valid narrowly scoped AI files.
  3. *Repo-applicable personal coding preferences:* Session-context, caller-supplied preference file, or `CLAUDE.local.md` general coding/testing/security/git conventions (excluding machine-local paths/binaries and autonomy/tone habits) **only** when every language, framework, library, workspace layout, and tool they name is already declared in repository manifests/configs (**language- and tool-agnostic** preferences such as deterministic offline test isolation or secret-placeholder hygiene apply in any repo, including pre-code repos whose language is `Undecided`) and they neither contradict Tier 2, weaken security or memory/type safety (e.g. unrestricted `unsafe`), violate snapshot immutability, nor duplicate tool-enforced settings in prose (scoped via `Applies to:` in polyglot repos).
  4. *Fetched primary-source standards:* Official language/framework/tool docs verified in this run (`Source: <URL>` **only** when the recorded sentence entails the full rule—in `auto` mode, drop any Tier 4 candidate whose fetched sentence does not entail the full claim).
  5. *Omit (`No rule`):* Never invent ungrounded architecture patterns, folder layouts, third-party/mocking libraries, strictness mandates, or product requirements. Use `Project decision` in `auto` mode **only** for preserved shared policy, repo hook/template conventions, factual workspace-area boundaries, secret-placeholder hygiene, pre-code test isolation, or compatible Tier 3 personal rules without an entailing source URL.

## Asking questions

In interactive mode (skip this section in `auto` mode), use `AskUserQuestion`. If unavailable, render the same numbered questions and options in plain text, end the turn, and continue from the user's reply—never skip decisions or choose silently.

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
- **Snapshots** (sketches, plans, research, meeting notes, `docs/todo/` checklists) carry `_YYYY-MM-DD` in the filename and are immutable after creation, except ticking `[x]` in `docs/todo/`. Newer versions create a new dated file (if `<topic>_<today>.md` already exists on disk, choose a distinct slug or `<topic>-2_<today>.md` rather than overwriting it).
- **Living docs** (canonical root `AGENTS.md`, `.ai/*.md`, and `docs/` files explicitly created or classified by the user as living docs) have no date in the filename and place `Last reviewed: YYYY-MM-DD` right after `# Title`. Never inject `Last reviewed` into nested `AGENTS.md` files kept in place, unclassified normalized files, or existing `docs/` files touched only for link updates. Bump `Last reviewed` only when content changes or during an explicit **Full re-audit**.

## Step 1: Inspect

Read only; change nothing yet. Collect:

1. **Stack & checks:** manifests, lockfiles, `README*`, CI workflows, linter/formatter/compiler configs, and directory layout. Verify what scripts and wrappers actually do by reading them rather than guessing from filenames. Never read `.env` or secret/credential files.
2. **AI instruction files (any depth):** `AGENTS.md`, `.claude/AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, `CLAUDE.local.md`, `.claude/rules/`, `.claude/settings.json` (`permissions` inventory only), `.cursorrules`, `.cursor/rules/`, `.github/copilot-instructions.md`, `.github/instructions/`, `.windsurfrules`, `GEMINI.md`, `.ai/`. Skip `.claude/skills/`. Treat legacy `.ai/.ground-rules.json` and `ground-rules:managed` comments as cleanup targets, never provenance. Fetch current official loading/scope/precedence docs for each detected non-canonical or nested format and display a compact precedence table before claiming a conflict or proposing deletion (in `auto` mode, include that table in Step 10 when such formats exist); if official precedence cannot be verified, mark precedence unknown rather than claiming a precedence conflict, never delete without explicit confirmation, and still offer Step 7.4 `Apply / Skip` deletion in migration/re-audit once all of a shared file's rules are migrated or discarded. Separate machine-local overrides—files designated local by format or filename (`CLAUDE.local.md`, `*.local.md`, `.claude/settings.local.json`), gitignored AI files, or untracked personal/machine-path overrides: report them separately, and never edit, delete, commit, or migrate them as files unless explicitly asked (general non-machine-specific coding rules in `CLAUDE.local.md` may inform anonymized personal preferences per Principles).
3. **`docs/` & `docs/todo/`:** filenames, cross-links, and open vs ticked to-do items (recording items proven complete in code for Step 4; leave uncertain items open).
4. **Git state:** branch, remote/upstream (redacting any embedded URL credentials), staged changes, and unstaged changes. Never stage pre-existing work.
5. **Classification:**
   - *Convention structure:* `canonical` (`AGENTS.md` <= 150 lines, resolving `.ai/*.md` pointers, all detailed rules indexed in `.ai/`), `partial` (broken pointers, unreachable `.ai/` files, root > 150 lines, or detailed domain rules embedded in `AGENTS.md`), `alternate-only` (only non-canonical shared AI files), or `none`.
   - *Repository mode:* `empty repo` (only `.git` and README/LICENSE/`.gitignore`), `pre-code repo with AI files`, `existing repo without AI files`, or `existing repo with AI files`.

In interactive mode, report findings in at most 12 lines (mode, structure, other instruction files, Git state, and candidate checks, noting that pre-existing work is never staged and checks may expose existing failures); in `auto` mode, fold this summary into Step 10.

- **Pre-existing staged or dirty files:** In `auto` mode, continue without commit automatically on unrelated staged/dirty files (if root `AGENTS.md` has staged or unstaged changes, abort all writes and report under **Open conflicts**; if a target `.ai/*.md` path has staged or unstaged changes, skip writing that path and report it under **Open conflicts**). In interactive mode, if anything is already staged, ask **Continue without commit (Recommended)** vs **Stop to clean index** before any write; continuing disables Step 10 commit/push for the run. Never touch pre-existing dirty files unless a convention file itself is dirty—then in interactive mode show the exact merged result and offer **Apply merged change** (also disables commit/push), **Skip this path**, or **Stop**.
- If convention structure is `none`, proceed to Step 2 (empty repo) or Step 4 (existing repo). Whenever **any** shared AI instruction file exists in interactive mode, always stop at Step 1.5—even if inspection found zero defects.

## Step 1.5: Choose the run

In **Focused update** (interactive or `auto` when `canonical`) and `auto` `partial` repair, validate current files against commands, paths, configs, citations, precedence, and contradictions: treat coherent existing canonical Markdown, headings, `.ai/` filenames, absent optional topics/settings, and existing `docs/` names/classifications as settled team policy—change only concrete defects, contradictions, structural `partial` gaps, or newly evidenced manifest/tool gaps, and never rewrite coherent prose or inject unrequested personal/optional rules.

In `auto` mode, skip asking and run: **Focused update** when `canonical`; structural + deterministic-defect repair when `partial`; or automatic bootstrap/migration into `AGENTS.md` + `.ai/*.md` when `alternate-only` or `none`.

In interactive mode, show a compact 3-row table (`reads` | `may write` | `decisions revisited` | `typical use`) and ask:

- **Canonical or partial** (with or without additional shared formats):
  - **Focused update (Recommended)** (semantics above; ask only about concrete findings or new manifest/tool gaps, and report equivalent or non-conflicting scoped rules in additional shared formats without re-interviewing them).
  - **Full re-audit**: run Steps 3–10 across every rule.
  - **Validate only**: run read-only checks (Steps 3, 7.2, and Step 9's read-only review agent without offering `docs/todo/` writes), then finish with Step 10's `## Ground Rules final report` without writing or committing.
- **Alternate-only**:
  - **Migrate interactively (Recommended)**, **Audit only** (read-only verdict report ending with `## Ground Rules final report`), or **Leave unchanged** (report precedence over `AGENTS.md` and end with `## Ground Rules final report`).

For pre-code repos with AI files in **Migrate interactively** (or **Full re-audit** or `auto` bootstrap/migration when no project-intent sketch or canonical `.ai/` baseline exists yet), run Step 2 before auditing foreign claims in Step 3.

## Step 2: Empty and pre-code repositories

Run only for an `empty repo` or during **Migrate interactively** (or **Full re-audit** or `auto` bootstrap/migration without an existing sketch/baseline) on a `pre-code repo with AI files`; skip Step 2 in **Focused update**, `auto` `partial` repair (when `AGENTS.md` already states intent), **Validate only**, **Audit only**, and **Leave unchanged**.

Every `docs/first-sketch_<today>.md` starts with:
> **Initial sketch, not a source of truth.** Written on <today> before any code existed. Plans change; check `.ai/` and the code for what is actually decided.
and lists every unresolved user, product, format, stack, or tooling question under **Open questions** (never write `"None"` while choices remain open).

In `auto` mode: fail closed with zero writes (reporting in Step 10) **only** when neither `README*` nor the invoking prompt names any domain or artifact purpose beyond an absent/empty file or bare placeholder title (a brief stated purpose such as `# URL checker` + `command-line tool` suffices). Otherwise write `docs/first-sketch_<today>.md` recording **only** facts explicitly stated in `README*` or the prompt (never session memories, personal config, or parent directory names), enforce **Document rules only**, keep language **Undecided** unless `README*` or the prompt explicitly names it, and never adopt unbacked foreign stack claims.

In interactive mode:
1. Ask in plain text what the project builds (goal, intended users, expected stack, open questions). Never invent undecided users or requirements. If the language remains open, ask up to 3 plausible languages plus **Undecided** before drafting the sketch.
2. Draft `docs/first-sketch_<today>.md` using the header and **Open questions** format above, show the draft, and ask `Apply / Skip`.
3. When a language is chosen without a manifest or package manager, ask:
   - **Document rules only (Recommended)**: create no manifest, dependencies, or commands; later rules cover tool-agnostic conventions only, never ask for frameworks, never write commands in `AGENTS.md` or `.ai/`, and never cite test-runner or mocking-library docs (including standard-library mocking modules)—use `Project decision` when no mechanism-neutral language spec entails the rule.
   - **Bootstrap tooling**: choose package manager and minimal manifest/config in the next turn.
   - **Leave language undecided**: omit language-dependent `.ai/` files.

## Step 3: Audit existing AI files

Seed the run-local decision record (Step 6.5) with coherent existing canonical/scoped rules (`existing team policy`, verifying any cited `Source` URLs). In **Validate only** and **Audit only**, record findings/verdicts read-only without asking confirmation questions.

In `auto` mode, audit foreign and scoped AI files read-only: carry valid root-scope `Keep`/`Rewrite`/`Enforce` rules into canonical files, keep valid narrowly scoped files untouched in place, repair only concrete defects/contradictions in existing `.ai/*.md` files during **Focused update** or `partial` repair (leaving any pre-existing `.ai/*.md` file with zero valid rules unindexed and untouched on disk rather than deleting or emptying it), never edit or delete foreign/scoped files, put rewritten `Move` drafts and cleanup steps in Step 10 **Recommended follow-ups**, and record active foreign/scoped contradictions, unindexed obsolete `.ai/*.md` files, or conflicting precedence overrides under **Open conflicts**.

In interactive **Focused update**, inspect only for contradictions, broken commands/paths/pointers, unsupported citations, or precedence conflicts; preserve coherent rules untouched and offer diffs only for concrete findings (**Apply fix**, **Remove rule**, or **Keep as open conflict** for deterministic defects; **Keep current wording**, **Audit this rule**, or proposed fix for ambiguities).

In **Full re-audit** or **Migrate interactively**, present every rule of each file in a table (splitting tables over 15 rows under subheadings so nothing is hidden) with a ~8-word reason and one verdict:

- **Keep**: specific, accurate, matches repo and scope.
- **Rewrite**: sound intent, vague or inaccurate wording (including bare stdin-reading or write-mode commands rewritten to read-only check flags).
- **Enforce**: belongs in tool config (becomes a 1-line pointer in Step 7 if already enforced, or a Step 6 enforcement question if not yet configured).
- **Move**: rationale or plan that belongs in `docs/` (record target living/snapshot type and path, rewrite aspirational or unimplemented present-tense claims against actual repo structure so living docs state future direction rather than false current fact, and confirm the full draft once in Step 7 before deleting source).
- **Delete**: false, obsolete, contradicts repo/policy, duplicates tool defaults, or dictates AI chat tone.

State whether leaving the file overrides `AGENTS.md`, then ask per file: **Use these verdicts (Recommended)**, **Review rule by rule** (asks structured per-rule verdict questions, batched up to 4 per call), or **Leave file untouched** (excludes from migration/deletion; record any active conflict).

Default `(Recommended)` to keeping valid narrowly scoped files (nested `AGENTS.md`, path-scoped `.github/instructions/*.md`, valid scoped `.cursor/rules/*.mdc`) in place at their original path and scope—leaving all-`Keep` files byte-for-byte untouched and applying any accepted in-place `Rewrite`/`Delete` diff without migrating or deleting the file. Consolidate a scoped rule into `.ai/` (with `Applies to: <repo-relative path or glob>` right after `Last reviewed`) only when the user explicitly chooses consolidation, and delete a scoped file only when all of its rules receive `Delete` or `Move` verdicts. Never broaden a narrow scope without approval.

## Step 4: Tidy `docs/`

In `auto` mode, leave existing `docs/` and `docs/todo/` files untouched (no renames, body edits, or `[x]` ticks); preserve any existing `AGENTS.md` `## Docs` policy, otherwise include only factual pointers to newly written `docs/first-sketch_<today>.md` (labeled a possibly outdated snapshot) or `docs/todo/`, and report completed to-dos and candidate renames in Step 10.

In interactive non-read-only runs (excluding **Focused update** unless new completion evidence exists), if Step 1 found open `docs/todo/` items proven complete in code, offer one `Apply / Skip` confirmation to tick `[x]` on those items, leaving all other snapshot lines untouched.

When `docs/` exists or Step 2 created a sketch in interactive mode:
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

In **Focused update** and `auto` `partial` repair, keep the current `.ai/` layout (including `.ai/project.md` or custom `.ai/*.md` filenames) unless extracting domain rules embedded in root `AGENTS.md`, adding a newly evidenced domain, or splitting a file over ~300 lines.

In `auto` bootstrap/migration (`none` or `alternate-only`), unless reusing an existing `.ai/*.md` filename, choose filenames strictly from `.ai/architecture.md` (only when >=2 packages/areas have real boundaries), `.ai/code-style.md` (consolidating formatting, linting, typing, naming, and error handling—never split into `.ai/typing.md`, `.ai/style.md`, or `.ai/<lang>.md` in single-language repos; use `.ai/code-style-<lang>.md` only when polyglot languages require distinct `Applies to:` globs, and always omit `.ai/code-style*.md` when language is `Undecided`), `.ai/testing.md` (including language-neutral test isolation in pre-code repos), `.ai/security.md`, `.ai/tech-stack.md` (omit unless single and settled), and `.ai/git-workflow.md` (omit unless repo hooks/templates or compatible personal git rules establish it), creating only files with >=1 grounded rule.

In interactive bootstrap, migration, or full re-audit, batch structure and file selection concisely in one call:
1. **Structure:** **Focused files (Recommended)** (one `.ai/<topic>.md` per approved domain, created only if >=1 rule is approved), **Compact file** (`.ai/project.md` under 300 lines), or **Custom structure**. Omit language-dependent files when language is **Undecided**. When tech-stack stability is unclear, ask whether **Stack is still changing** (omitting `.ai/tech-stack.md` when chosen).
2. **Candidate `.ai/` files:** Multi-select of domain files warranted by repo evidence and Step 3 verdicts (e.g. `.ai/architecture.md`, `.ai/code-style.md`, `.ai/testing.md`, `.ai/security.md`), naming each candidate's exact `.ai/<file>.md` path and scope, with at most 3 candidates plus **No topics for now** per question (or a 2-option choice `<candidate>` vs **No topics for now** when only one exists). Unselected displayed candidates are declined and never re-offered, and approved mappings are never silently split into extra files.

## Step 6: Interview, file by file

In `auto` bootstrap/migration (and for concrete defects or newly evidenced tool gaps in `auto` **Focused update** / `partial` repair), replace 6.1–6.4 with concise synthesis via the 5-tier precedence ladder: write one `Enforced in CI by` / `Checked by` pointer per configured tool, never edit configs or tighten disabled/partial/commented-out checks, default code-violated local conventions to `From now on` + `docs/todo/` (using `After migration.` + `docs/todo/` when existing code/config cleanup is a prerequisite before a blanket prohibition applies), and record sanitized origins in 6.5.

In interactive mode, work through every approved `.ai/` file (skipping unchanged files in **Focused update**):

- **6.1 Topics.** Multi-select of specific rule topics for this file (up to 3 candidates + **No topics for now** per question), noting any Step 3 rules already accepted for it. Unselected displayed topics are declined; ask a split follow-up only for not-yet-displayed candidates when **No topics for now** was not chosen. Honor free-text topics in full. Interview **only** rule families within selected topic boundaries; omit the file and its `AGENTS.md` pointer if zero rules end up approved.
- **6.2 Rules (industry standards first, batched up to 4 questions per call).** Fetch official primary sources and offer up to 4 distinct options:
  - **Best practice `(Recommended)`**: official language/framework/tool standard with URL. When a cohesive official guide covers mechanical conventions, prefer recommending that standard cleanly rather than fragmenting into micro-questions.
  - **Common in the ecosystem**: mainstream practice when distinct from official docs.
  - **Current in this repo**: actual pattern with file counts and honest quality note (merge with Best practice if identical; omit in empty repos).
  - **Alternative** or **Your preference (personal config)** (when applicable).
  - **Project decision** (architecture boundaries, folder conventions, un-sourced team rules): state there is no external source, and keep high-level boundary rules separate from prescriptive folder/library choices unless requested. Include **No rule** (writes no prose rule for that subtopic) on every **Project decision** question and on any optional strictness, gradual-typing, or tool-adjacent prose question where omitting a written rule is a valid team choice. Keep rules at the abstraction level selected—never inject unapproved libraries, test doubles, or implementation techniques.
  - **Rollout timing:** When a chosen rule conflicts with existing code or checks, ask **From now on (Recommended)** (applies to new and changed code immediately; existing code violations go to `docs/todo/`) vs **After migration** (`After migration.` is the sole deferred marker; deferred rules never claim active checking/CI and get a `docs/todo/` entry).
- **6.3 Enforcement.** Point to existing active tool checks in one option (no fake "not enforced" variant unless showing the config-weakening diff). Within audited rules or selected topics, never silently tighten or contradict an existing disabled, partial, or commented-out tool setting—ask whether to keep it as-is, and never ask about tool settings for declined files or topics. For unconfigured installed tools, offer enforced (with minimal config diff) vs unenforced; ask new package installs one turn before their config diff. Note if existing code will fail the check.
- **6.4 Open round.** For newly created or re-audited files, ask **No more rules (Recommended)** vs **Suggest some** (free-text adds custom rules, sharpened and confirmed via `Apply / Skip`).
- **6.5 Run-local decision record.** Track each authorized rule's ID, `.ai/` destination, scope, exact anonymized wording (stripped of any personal paths/handles), origin (`existing team policy`, `explicit answer`, `Keep/Rewrite verdict`, `Delete verdict`, `enforcement pointer`, `auto standard`, `personal config`, `repo structure`, or `review fix`), checking config or fetched `URL` + verbatim supporting sentence, and approved Step 3/4 move, rename, doc-classification, and deletion choices for Step 9. Never write this record into repository files.

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

<Include the maintenance bullet below by default on bootstrap/migration (preserving coherent existing Workflow in Focused update); add other workflow bullets only when explicitly chosen or kept from shared AI files—listing a command above never authorizes adding "Run <cmd> before finishing".>
- Keep `AGENTS.md` and `.ai/` current. If a rule contradicts the code you're changing or a decision made with the user, or your change makes a rule, command or pointer wrong, stop and propose the edit; once approved, make it in the same change and bump `Last reviewed`. Don't silently follow a wrong rule or work around it.

## Rules

<Omit section when zero `.ai/*.md` files exist. Include `Rules apply to new and changed code. Existing code may not follow them yet.` when existing code violates active `From now on` rules, or `Rules apply to new and changed code, unless marked "After migration.". Existing code may not follow them yet.` when >=1 rule is marked `After migration.`. Omit that rollout line in empty repos or when no rollout gap exists.>

Detailed rules live in `.ai/`. Read the matching file before working in that area:

- Before changing structure, adding modules or moving code: `.ai/architecture.md`
- Before writing or reviewing code: `.ai/code-style.md`
- <one concrete read-trigger bullet per written `.ai/` file>

## Docs

<Include only accepted Step 4 Docs statements or an approved/auto Step 9 `docs/todo/` pointer (plus Step 2's `docs/first-sketch_<today>.md` snapshot pointer in `auto` mode); omit section if none.>
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
- **Command & CI accuracy:** Every published command—including per-package scripts (`apps/*/package.json`)—must have valid repository wiring (manifests, third-party runners/linters declared in package or workspace `dependencies`/`devDependencies`, scripts, configs, and covered workspaces), scope nested modules lacking a root workspace file (e.g. a sub-directory `go.mod` without root `go.work`) to that module's directory, and use non-mutating check flags (`gofmt -d .`, `prettier --check .`, `cargo fmt --all --check`—never bare stdin-reading `gofmt` or write/fix flags).
  - *Missing machine executable* (repo manifests/wiring exist, tool/install absent locally): keep the command and record `not run here: <reason>` in Step 10—never treat machine absence alone as repo migration work, **but always inspect invoked scripts and source files statically** against configured checks so unconditional nonzero scripts or clear configured-rule violations (`camelcase`, `warn_unused_ignores`, etc.) are classified as *Known baseline failures* below.
  - *Known baseline failure* (valid command fails—or is statically proven to fail—on existing code/scripts): disclose the baseline failure beside the command in `AGENTS.md` and inside any `.ai/` terminal marker that names it (e.g. ``Checked by: `<tool> (<config>; <command>, baseline currently failing)` ``, or prefer a passing scoped check), and track it in `docs/todo/`.
  - *Missing/broken project wiring* (missing script, undeclared tool dependency in manifest, or broken aggregate target): omit from `AGENTS.md` and active `.ai/` pointers; report as an open problem (or record in `docs/todo/` only if the user deferred wiring it).
  - *CI claims:* Use `Enforced in CI by` (replacing `Checked by`) **only** when a structurally valid required CI workflow (`on` trigger, runnable job/`runs-on`, step running that exact check) is verified; treat incomplete workflows as local-only (`Checked by`) and report the workflow defect as an open problem in Step 10 (never a `docs/todo/` entry unless fixing CI was explicitly deferred).
- **One terminal marker, zero prose duplication, affirmative prose:** Every `.ai/` rule ends with **one** marker (`Enforced in CI by`, `Checked by`, `Source`, or `Project decision`—never prefixed with `Basis:` and never combined). Tool pointers never list configured values, flags, or rule/check names (quotes, line length, rule IDs, `warn_unused_ignores`, `AvoidStarImport`, `camelcase`) in prose. Use `Source: <URL>` only when the recorded sentence entails the full rule; otherwise use `Project decision` in interactive mode or when authorized by `auto` Tier 5 (drop unentailed Tier 4 candidates in `auto` mode). State canonical commands, pointers, and rules affirmatively: never mention rejected foreign commands/phrases, machine-local paths, skipped personal-config tools/values, uncreated rename targets, bare non-root filenames, or negated `Enforced in CI by` explanations inside `AGENTS.md` or `.ai/*.md`—record rejected/conflicting items strictly in Step 10.
- **Durable facts only:** Never copy exact package versions, file counts, or inventories that live in manifests/configs (major-version upper bounds only when material). `AGENTS.md` indexes `.ai/` without duplicating detailed rules, and every backticked `.md` path in `AGENTS.md` must exist case-exactly at that repo-relative path. Leave `Last reviewed` and file bytes untouched on a zero-change **Focused update**.

Execute in order (in `auto` mode, skip 7.1 and 7.4 deletions, run 7.2 read-only checks, and write canonical files directly in 7.3 without confirmation prompts):
- **7.1 Dependencies & configs:** Install approved dependencies via the repo's package manager; on failure, restore manifests/lockfiles, clean created artifacts, and ask **Keep rule unenforced (Recommended)**, **Drop the rule**, or **Stop for environment fix**. Apply approved tool configs and non-secret example files.
- **7.2 Run checks safely:** Run only literal, read-only check commands (`gofmt -l .`, `cargo fmt --all --check`, `--noEmit`) so any baseline failures are known before confirming/writing Markdown drafts. Never run fix/write modes, shell loops/`eval`/`xargs`, copy the repo to `/tmp`, redirect tool caches (`GOCACHE`, etc.), or run commands that create untracked environments, lockfiles, build directories, or tool caches (`Cargo.lock`, `target/`, `.venv/`, `node_modules/`, `.gradle/`, `__pycache__/`, `.pytest_cache/`, `.mypy_cache/`, `.ruff_cache/`) unless those paths are already ignored in `.gitignore`—never create and delete temporary artifacts inside the workspace; skip running the command instead, inspect scripts/source statically for baseline violations, and record `not run here: <reason>`.
- **7.3 Confirm & write Markdown:** Fold any baseline failures discovered in 7.2 into the drafts. In interactive mode, show complete new/rewritten drafts (or minimal diffs for `docs/` Move targets and in-place scoped AI file fixes; do not re-ask diffs already confirmed in Step 3 **Focused update**), batch `Apply / Skip` confirmations (up to 4 files per call), and write approved Markdown; skipping a new `.ai/` file drops its `AGENTS.md` pointer (if it had dedicated config/dependency approvals, ask `Retain` / `Cancel`). In `auto` mode, write canonical Markdown directly.
- **7.4 Deletions & cleanup:** In interactive mode, after canonical files and any accepted `docs/` Move targets exist on disk, offer `Apply / Skip` to delete obsolete shared AI files (foreign files whose rules were all migrated or deleted, or superseded `.ai/*.md` files—never files kept in place at narrower scope, skipped via `Leave file untouched`, or machine-local overrides unless asked), without staging (never `git rm`), and remove legacy `.ai/.ground-rules.json` or `ground-rules:managed` markers via approved diffs.

## Step 8: Claude Code permissions

In `auto` mode, never edit `.claude/settings.json`; when shared `.claude/` config exists and lacks `"Edit(/AGENTS.md)"` and `"Edit(/.ai/**)"` in `permissions.ask`, include the merge snippet under Step 10 **Recommended follow-ups**. In interactive non-read-only runs, skip without asking on a zero-defect **Focused update** (unless the user explicitly requested Claude Code permissions in this run); otherwise, only when shared `.claude/` directory config (`.claude/settings.json`, `.claude/CLAUDE.md`, `.claude/rules/`) already exists in the repository, or the user explicitly asked for Claude Code permissions in this run (never ask unprompted whether the team uses Claude Code, and never infer it solely from a migrated root `CLAUDE.md`), offer merging `"Edit(/AGENTS.md)"` and `"Edit(/.ai/**)"` into `permissions.ask` in `.claude/settings.json` (source: https://code.claude.com/docs/en/permissions). Skip without asking if path-equivalent entries already exist; otherwise preserve all existing keys, show the diff, and ask `Apply / Skip`.

## Step 9: Migration to-do and review by a fresh agent

Outside read-only runs (**Validate only**, **Audit only**, **Leave unchanged**), a zero-defect **Focused update**, or an early zero-write abort, reconcile code violations, known baseline check failures, and deferred items (`After migration.` rules or deferred command wiring) against `docs/todo/`:
- Never edit existing snapshot bodies beyond approved `[x]` ticks; omit duplicates of open items, and use repo-relative `<path>` entries only (never local home paths).
- When new items remain, write `docs/todo/<descriptive-topic>_<today>.md` (`conventions-migration_<today>.md` for mixed items)—directly in `auto` mode (adding ``- Open migration tasks are in `docs/todo/`.`` under `AGENTS.md` `## Docs`), or in interactive mode after showing the draft and asking `Apply / Skip`:

```markdown
# <Descriptive topic>

Written on <today>. Tick items when done; put new items in a new dated file.

| Done | File | Problem | Rule |
|---|---|---|---|
| [ ] | `<path>` | <violation or baseline failure> | [<rule>](../../.ai/<file>.md) or Baseline command: `<command>` |
```

In interactive mode, if applied, confirm a minimal diff adding ``- Open migration tasks are in `docs/todo/`.`` under `AGENTS.md` `## Docs` (creating a minimal `## Docs` section with only that bullet if none exists) and, only when displayed and approved, ``- When you finish a migration item listed in `docs/todo/`, tick it there.`` under `## Workflow`. If the user skips a to-do required by a deferred rule or deferred command, ask whether to **Drop** that deferred item or **Stop and restore** this run's policy changes.

Outside **Audit only**, **Leave unchanged**, a zero-defect **Focused update**, or an early zero-write abort (including in **Validate only**), launch **one** fresh read-only review agent (`eval-reviewer` when available, otherwise a read-only `general-purpose` subagent) that sees **only** the repository, changed file paths, and sanitized Step 6.5 decision/move/rename/delete records—never the interview transcript. Ask it to report `file:line` + quote findings (`blocker`, `major`, `deterministic-minor`, `stylistic-nitpick`) against:
- Active contradictions across `AGENTS.md`, `.ai/*.md`, and tool configs; duplicated rules across files or restated tool settings in prose.
- Unapproved rules, leaked personal-config paths/identities across `AGENTS.md`, `.ai/*.md`, `docs/todo/*.md`, or `docs/first-sketch_*.md`, altered scopes, missing moved-doc sections, or snapshot body edits.
- Invalid commands, false `Enforced in CI by` claims, undisclosed baseline failures, machine-local tool absences misrecorded as repo to-dos, or unsupported `Source` / `Why` claims.
- Size limits (`AGENTS.md` > 150, `.ai/*.md` > 300), missing `Last reviewed` on canonical root `AGENTS.md`, `.ai/*.md`, or classified living `docs/` files, broken pointers, unreachable `.ai/` files, or leftover ownership markers.

Verify every finding yourself against the files and decision record; list discarded false positives in one line each (inside Step 10 in `auto` mode, and silently discarding `stylistic-nitpick` items on unchanged prose or headings in **Focused update**). In `auto` mode, auto-apply confirmed `blocker`, `major`, and `deterministic-minor` fixes across canonical paths permitted in `auto` mode (dropping ungrounded rules rather than inventing policy, and removing any file newly created in this run whose sole rule was dropped), re-read written files, and record remaining untouched-file conflicts (including unindexed obsolete pre-existing `.ai/*.md` files) under **Open conflicts**. In **Validate only**, report confirmed findings read-only in Step 10 without fix prompts and record confirmed deterministic defects (`blocker`, `major`, `deterministic-minor`) under **Open conflicts**. In interactive write runs, if confirmed findings remain, present them under **1. Fixes to written files** (multi-select, labeling severity), **2. Needs a decision**, **3. Code that breaks the new rules**, and **4. Outside scope**, apply approved fixes, re-read changed files yourself to confirm zero remaining defects, and record any user-retained deterministic defect (`blocker`, `major`, or `deterministic-minor`—never declined `stylistic-nitpick` items) under **Open conflicts** (never report `Open conflicts: none` when one remains).

## Step 10: Commit and report

Begin Step 10's final message—including read-only, `auto`, and open-conflict completions—with `## Ground Rules final report`.

1. **Changed files:** Separate Ground Rules changes from untouched or pre-existing dirty paths.
2. **Unverified checks:** Commands `not run here`, baseline failures, or skipped installs.
3. **Commit & push:** In `auto` mode, never stage, commit, or push—include a suggested commit message under **Recommended follow-ups**. In interactive mode, when a diff exists and Step 1 found no pre-existing staged/merged-dirty paths, propose a commit message matching `git log` style (fallback: `Bootstrap repository conventions`, `Migrate AI instructions`, or `Update repository conventions`—never include `Generated with ...` or `Co-Authored-By` lines) and ask `Commit` / `Don't commit`. On `Commit`, stage explicit paths only (never `git add .` or `-A`), verify `git diff --cached --name-status`, and commit without skipping hooks. Ask push separately only when a commit was created and a remote exists.
4. **Summary tables:** Written/updated files, migration to-do / code violations, check results, open conflicts, and out-of-scope notes. In `auto` mode, also tag written rules by origin (`existing team policy`, `Keep/Rewrite verdict`, `enforcement pointer`, `auto standard`, `personal config`, `repo structure`, `review fix`), note skipped conflicting/inapplicable personal preferences, and add a **Recommended follow-ups** table (foreign deletions/moves, scoped fixes, `docs/` renames/`[x]` ticks, config/`.claude/settings.json` snippets, and suggested commit message).
