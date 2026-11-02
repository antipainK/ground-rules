---
name: ground-rules
description: Interactively set up, migrate or maintain a repository's AI context (AGENTS.md + .ai/) and human docs (docs/). Inspects the repo, audits foreign AI instructions, interviews the user only for actual decisions, writes the files, has them reviewed by fresh agents, and offers to commit.
disable-model-invocation: true
---

# Ground rules

Set up a tool-neutral convention structure for a repository, or audit an existing one:

```
AGENTS.md          root index for every AI tool: summary, commands, workflow, pointers (at most 150 lines)
.ai/               detailed AI rules, organized by topic; acknowledges docs/ exists, never maps it
docs/              human + AI design docs, plans, decisions
```

## Principles

- **The user decides.** Never write a rule the user did not pick. Never invent a reason for a decision; a rule without a reason has no "Why".
- **Control means informed choices, not repeated consent.** Ask whenever reasonable alternatives change policy, scope or the files affected. Don't ask again for a decision already recorded in the current run, for coherent current team policy, for a fact the repo settles, or for a mechanical consequence the user already approved. Before a consequential choice, show what changes, what remains untouched and how to reverse it.
- **Organise, don't legitimise.** What the repo currently does is one option, labelled as such, never recommended just because it exists. Existing code may be unreviewed or generated; judge it.
- **Enforced beats written.** If a linter, formatter, compiler setting or CI check can enforce a rule, propose that config change. The config is then the source of truth: the `.ai/` file doesn't restate tool-enforced rules one by one but points to the config and the command that checks it.
- **Primary sources only.** Options come from official documentation, language/framework style guides, release notes and the recommended configs that tools ship. No blog posts, listicles or AI-generated summaries. Fetch every URL you cite during this run and confirm it supports that specific claim and keep the sentence that does (Step 6.5); don't cite from memory.
- **Recommend from evidence; label the operator.** Base recommendations on the repo and cited sources. Stored personal preferences of whoever runs the skill (user-level CLAUDE.md, memories, personal skills) may also inform a recommendation, but then the label ends with `(Personal)` after `(Recommended)` and the description says what the preference is and what else supports the option. A personal preference that differs from the recommended option is a separate option labelled "Your preference (personal config)", never marked recommended. Personal config never becomes a rule without the user's pick and is never used to judge the repo. Preferences the user states during this run are input like any other answer. Their working rules (how to ask, when to commit) apply to how you run the skill, never to what is written into the repo's files.
- **No assumptions about the environment.** Detect the OS, shell, package manager and tooling from the repo; ask when unclear.
- **Scope: conventions, not code.** The skill changes only `AGENTS.md`, `.ai/`, `docs/`, AI instruction files, tool config (linter, formatter, compiler, CI), example config files (e.g. `.env.example`), dependency manifests and the permissions in `.claude/settings.json` (Step 8). It never changes application code. Code that breaks a new rule is reported at the end (Step 10), not fixed.
- **Out of the skill's scope:** `.claude/skills/` (skills are tooling, not conventions) and anything the user did not ask about. Mention other problems you notice in the final report; don't fix them.
- **Policy is team-owned Markdown.** `AGENTS.md` and `.ai/*.md` are ordinary editable repository files. Preserve coherent current content and deliberate edits; ask only when intent is ambiguous or content conflicts with verified evidence.
- **No hidden ownership state.** Keep no hashes, plugin markers, ownership registry or persisted decision state. A later run derives conclusions from current files, repository evidence and answers given during that run.

## Asking questions

Use multiple choice (`AskUserQuestion`):

- At most 4 questions per call, 2-4 options each. The tool adds "Other" for tweaks; never add your own "Other" option. A question with fewer than 2 real options is a statement: say it in the message instead.
- Every choice question has exactly one option marked "(Recommended)", listed first, unless the user is only stating a fact ("which date is it?") or no option has a source, repo evidence, stated preference, personal config or clearly labeled skill-process judgment behind it (then mark none and say so; when the user asked for help deciding, recommend and say it is your judgment). Process defaults may be recommended only when the description names the operational benefit and trade-off; they never become repository policy without the user's choice. This includes Apply / Skip confirmations: mark the one you'd pick. Multi-select questions are the exception to "exactly one": mark each option you'd actually select. Put the reasoning in the option description.
- Option labels are 1-5 words, not counting the `(Recommended)` and `(Personal)` tags. Details, sources and trade-offs go in the description.
- Option descriptions are short: about 20 words, the consequence and the main trade-off. Say once in the message which options have no source; don't repeat it in every option.
- Simple confirmations ("apply these verdicts?", "create this file?") use exactly two options: "Apply" and "Skip". Adjustments come through "Other". Lifecycle choices whose outcomes are not equivalent to applying or skipping—such as Commit / Don't commit, Retain / Cancel, or Apply merged change / Skip path / Stop—use those specific labels and explain each consequence. Use Apply / Skip only to confirm one concrete change already shown, never in place of a choice between approaches.
- "Apply, but with a change" goes through the free-text field. End every Apply / Skip question with a hint like `(to apply with changes, type them)`. Treat a typed answer as Apply plus the typed change, unless it clearly rejects; show the adjusted result before writing if the change is more than a wording tweak. If the intent is unclear, ask. Also read any notes the tool returns with the answer.
- When the user asks you to help decide, answer with a new choice question, not a confirmation: your recommendation first, marked "(Recommended)" with the reasoning in its description, followed by every still-valid alternative with its trade-off. A recommendation never removes an option.
- More than 4 choices in a list (topics, files, rules to pick from): split it into several questions (e.g. topics 1-4, topics 5-8), never drop items silently.
- If one rule has 5 meaningful alternatives, first show the recommended option, the next two strongest alternatives and **Show more options**. If selected, ask the remaining alternatives plus **Back to first options**. Never make the user discover a real option through free text or surrounding prose.
- Prefer the question tool whenever the likely answers can be listed, including dates (offer the plausible readings) and "anything else?" rounds (options such as "No more rules" / "Suggest some"; the user types their own through "Other"). A question asked only in prose at the end of a long message looks like the run has stopped.
- Plain text only for truly open answers (project intent, reasons). Then end the message with that question on its own line, in bold, and ask nothing else in that turn.
- Never ask a question in the same round as the question it depends on (a config change that needs a new dependency, a setting that applies only to one of the options). Ask the prerequisite first, the dependent one in the next round. Don't spend a round on a single follow-up: carry it into the next round that has other questions (e.g. the next file's interview); ask it alone only if no such round is left.

## Presentation

Messages are read in a terminal; make them scannable, not a column of prose.

- Start each message with one bold status line: the step and what just happened.
- Put anything with more than one attribute in a table: evidence, verdicts, renames, findings, files changed, check results, the to-do list. Sources go in their own column, not inside sentences.
- Show config changes as a diff of only the changed lines, not the whole file. When a file is rewritten completely (e.g. an existing `AGENTS.md` put into the template), show the new content plus one line on what was dropped, not a diff of every line.
- Keep the text before the questions to about 15 lines, not counting the Step 3 rule tables, which show every rule. Leave out what the user doesn't need to decide now.
- Don't repeat decisions the user already made; refer to the file they live in.
- The final report (Step 10) is tables plus at most a few lines: commit, files, to-do (file | problem), check results (check | result), open conflicts, out-of-scope notes.

## Naming and dating

- File names: lowercase, `-` between words inside a part, `_` between parts: `auth-redesign_2026-10-22.md`. Dates are ISO `YYYY-MM-DD`.
- Extensions are lowercase: `.md`, not `.MD`.
- **Snapshot docs** (sketches, plans, research, meeting notes) carry the date in the file name and are not edited later; a newer version is a new file.
- **To-do checklists** in `docs/todo/` are snapshots with one exception: ticking a checkbox is allowed. New items go into a new dated file.
- **Living docs** (`AGENTS.md`, `.ai/*.md`, architecture overviews) have no date in the name. After the title, they include `Last reviewed: YYYY-MM-DD`; bump it only when their content changes or the user explicitly chooses a full re-audit.
- Get today's date from the system, not from memory.

## Instruction loading and precedence

Loading behavior changes across tools and versions. The matrix fetched from current official documentation in Step 1.2 is authoritative for this run. Never recommend deleting or consolidating an instruction file from a remembered precedence rule or this skill's static text.

## Step 1: Inspect

Read, don't change anything yet. Collect:

1. Stack signals: manifests and lockfiles (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `*.csproj`, ...), `README*`, CI config, lint/format/compiler configs, top-level folder layout.
2. Existing AI instruction files, at any depth: `AGENTS.md`, `.claude/AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, `CLAUDE.local.md`, `.claude/rules/`, `.claude/settings.json` (config: inventory only, not audited as rules), `.cursorrules`, `.cursor/rules/`, `.github/copilot-instructions.md`, `.github/instructions/`, `.windsurfrules`, `GEMINI.md`, `.ai/`. Skip `.claude/skills/`. Treat legacy `.ai/.ground-rules.json` files and `ground-rules:managed` comments as cleanup artifacts, never as evidence of provenance or prior decisions. For every detected format, fetch its official loading, scope and precedence documentation. Show a matrix of tool, file, effective scope, precedence and source before making a conflict or deletion claim. If official behavior cannot be confirmed, mark it unknown and preserve the file unless the user decides otherwise.
3. `docs/`: file list, naming, and links between docs. For existing `docs/todo/` files, count the open and ticked items; check whether open items are still true in the code. Offer one Apply / Skip confirmation to tick only items proven complete; leave uncertain items open and report why.
4. Git state: current branch, remote and upstream, uncommitted and staged changes. Remember them; they are not this skill's to commit.
5. Convention structure:
   - **canonical**: `AGENTS.md` is a concise index at or below 150 lines, its `.ai/*.md` pointers resolve, and every detailed policy file is reachable from it;
   - **partial**: `AGENTS.md` or `.ai/*.md` exists, but the structure has broken pointers, unreachable policy files, a root file over 150 lines, or language/architecture/testing/security rules embedded in the root instead of indexed from `.ai/`;
   - **alternate-only**: shared AI instructions exist without the canonical structure;
   - **none**: no shared AI instruction file exists.
6. Additional shared instruction formats: report these separately from the canonical structure and compare their effective scope and precedence.
7. Local overrides: inventory ignored or untracked local instruction files separately. They may override `AGENTS.md`, but they never get migrated, deleted or committed unless the user explicitly asks.

Report in at most 12 lines. Include the detected repository mode, convention structure, additional shared instructions, branch, staged/unstaged summary and the exact checks you expect to run later. Say that this skill never stages pre-existing work and that checks may expose existing failures. Repository modes are:

- **empty repo**: nothing but `.git` and housekeeping files (README, LICENSE, `.gitignore`);
- **pre-code repo with AI files**: housekeeping plus AI instructions, but no code or manifest;
- **existing repo without AI files**: code or manifests exist without AI instructions; and
- **existing repo with AI files**: code or manifests and AI instructions both exist.

For a pre-code repo, choose the run in Step 1.5, then ask the Step 2 project-intent and tooling questions before auditing or migrating foreign claims in Step 3. Read-only and leave-unchanged paths still ask project intent when it is needed to judge whether a foreign claim is correct.

Ask a question here if the repository mode or environment is unclear. If the mode is clear and the convention structure is `none`, continue to bootstrap. Otherwise continue to Step 1.5.

If anything was staged before the run, decide before the first write: offer **Continue without commit (Recommended)** and **Stop to clean index**. Continuing permanently disables Step 10's staging, commit and push actions for this run. Never ask at the end how to mix pre-existing staged work into the conventions commit.

Before changing any path that was already staged or dirty, fold the safety choice into that path's single preflight question: show the exact merged result, identify the pre-existing and proposed portions, and offer **Apply merged change**, **Skip this path**, and **Stop**, recommending the safest evidence-backed outcome. Track the pre-run bytes so the final report can separate the skill's contribution. Applying a merged change disables commit and push for this run; never stage a file containing pre-existing changes.

## Step 1.5: Choose the run

This choice controls the work; it does not ask the user to confirm facts already reported.

- **Canonical or partial**: offer **Focused update (Recommended)**, **Full re-audit**, and **Validate only**.
  - Focused update validates every current instruction against commands, paths, stack, tool configuration, citations, precedence and contradictions. It treats coherent current Markdown as team policy and asks only about defects, ambiguity, conflicts, requested changes, or a new manifest/package/tool/config that makes current policy incomplete or wrong. An absent optional topic, setting, docs policy or prior declined change is not a defect: report it once as not configured and revisit it only on request or in a full re-audit. Do not rewrite coherent text merely to add explanatory precision, style, or a disclaimer already implied by the format. Current Git diffs may narrow the presentation, but never describe Git as a baseline from a prior Ground Rules run.
  - Full re-audit follows Steps 3-10 for every rule.
  - Validate only performs the read-only parts of Steps 3, 7.4 and 9, reports findings and stops without writing, committing or pushing.
- **Alternate-only**: state that every rule will be audited before migration. Offer **Migrate interactively (Recommended)**, **Audit only**, and **Leave unchanged**. Audit only reports proposed verdicts and contradictions without writing. Leave unchanged stops after reporting which files take precedence over `AGENTS.md`.
- **Canonical or partial with additional shared instructions**: use the canonical choices above, then report semantic overlap and precedence. Equivalent and unique non-conflicting rules need no verdict in a focused update; migrate them only on request. Conflicting or stale rules enter the selected audit flow.

Before the question, show a compact table for the three choices: **reads**, **may write**, **decisions revisited**, and **typical use**. If the user chooses a read-only path, do not ask write, permissions, commit or push questions later.

## Step 2: Empty and pre-code repositories

1. Ask in plain text what the repository is for: goal, users, expected stack if known, open questions. If the language remains open, ask the language choice next, before drafting the sketch.
2. Draft `docs/first-sketch_<today>.md` from the project answer and resolved language choice. Reconcile the whole draft before showing it: if the stack, package manager, dependencies, tooling, behavior or another decision is explicitly undecided, list it under **Open questions** even when the user said they had no other questions; never write "None" while another section names an unresolved choice. A pre-code repository with existing AI instructions gets a sketch only when the user applies it. Start with:
   > **Initial sketch, not a source of truth.** Written on <today> before any code existed. Plans change; check `.ai/` and the code for what is actually decided.
3. Show the complete draft and ask Apply / Skip. Write it only on Apply.
4. Language: the earlier choice offers up to 3 plausible languages for the goal, plus "Undecided". Rules in `.ai/` depend on it.
5. Tooling: when the language is known but no dependency manifest or package manager exists, show that no install, test, lint or typecheck command can be written yet. Ask:
   - **Document rules only (Recommended)**: create no manifest, dependencies or commands; rerun after the project chooses tooling. This choice is binding for the rest of the run: later topic interviews may establish tool-agnostic practices, but must not ask for a framework/tool choice, write a command anywhere (including `.ai/`), or claim an executable is available.
   - **Bootstrap tooling**: in the next round, choose a package manager and the exact minimal manifest/config changes before asking about dependent rules.
   - **Leave language undecided**: omit language-dependent files as described in Step 5.

Never create a manifest, choose a package manager or name a command from the language choice alone.

## Step 3: Audit existing AI files

In a focused update, inspect every current instruction file for contradictions, stale commands or paths, unsupported citations, changed enforcement, precedence problems and ambiguity. Treat coherent existing rules as current team policy; do not re-interview them. When a file differs from `HEAD`, show the relevant diff, but never infer when, why or by whom it changed. Preserve current wording by default and replace or delete it only through an approved displayed diff.

For an ambiguous or judgment-based finding, offer **Keep current wording and report the concern**, **Audit this rule**, and the exact proposed correction when available. For a deterministic defect, offer the correction, **Remove the rule**, and **Keep it as an open conflict**; never imply that keeping a known defect can produce a clean result. Never require the user to adopt their own current file. In a full re-audit, or for every rule selected for interactive migration, go rule by rule and propose one verdict each, with a one-line reason:

- **Keep**: specific, correct, still matches the code.
- **Rewrite**: right intent, vague or wrong wording ("write clean code" is not a rule).
- **Enforce**: belongs in tool config. If a configured tool already enforces it (confirm its command or globs reach the files the rule is about), the verdict stands and Step 7 writes the pointer line; no further question. If no configured tool covers it yet, it becomes an enforcement question in Step 6.
- **Move**: belongs in `docs/` (rationale, plans) rather than in AI rules.
- **Delete**: wrong, obsolete, contradicts the code or another rule, restates tool defaults, or is about the AI's tone rather than the repo.

Present every rule of a file in a table, each with its one-line reason (about 8 words). A table over 15 rows is split under sub-headings in the same message, so no rule is hidden: the file's own sections, or "Rules 1-15", "Rules 16-30" and so on when it has none. Then ask one choice per file:

- **Use these verdicts (Recommended)**: accepts the table; adjustments to individual verdicts come through the free-text field.
- **Review rule by rule**: ask one verdict question per rule, batched up to 4 questions.
- **Leave file untouched**: makes no decision about its rules and excludes the file from migration or deletion.

Before the choice, say whether leaving the file will override or conflict with `AGENTS.md` for any supported tool. "Leave untouched" is not a deferral and must never be described as one. Record the file as an open conflict when it blocks or contradicts the canonical rules.

- Kept and rewritten rules go to Step 6 as already decided, not asked again: kept rules keep their wording, rewritten rules use the wording proposed in this step. If a topic in Step 6 conflicts with one, raise the conflict.
- Every Enforce verdict that no configured tool covers yet goes to Step 6 even if its topic is later struck.
- Every accepted Move verdict becomes a concrete docs draft in Step 7: record the proposed type, path and source sections now, asking a type choice first when living and snapshot forms both remain plausible. Do not ask a second Move confirmation here; Step 7 shows the complete draft and asks once. A source file cannot be deleted unless every accepted Move section exists in an approved written destination.
- Deleted rules are gone: don't offer them again as an option.
- A kept rule that names a path must still make sense after Steps 3-4; if the path would be empty or gone, say so.
- Note existing tool settings that weaken checks (e.g. a disabled lint rule) and ask whether to keep them.

Record each imported rule's original directory and any path/glob applicability from its file or frontmatter. Preserve that scope in the destination, or ask explicitly before broadening or narrowing it. A scoped `.ai/` file starts with `Applies to: <repo-relative path or glob>` after `Last reviewed`; a root `AGENTS.md` pointer names the same trigger.

Don't delete anything yet. AI instruction files that would block `AGENTS.md` (see above) or contradict the new rules are offered for deletion in Step 7, after their content has been migrated. Files left untouched are not offered for deletion; report their precedence and conflicts both immediately and in the final report. If migrated content remains in its source file, report its continuing precedence. On later runs, compare its current meaning with canonical policy; equivalent content requires no repeated verdict.

## Step 4: Tidy docs/

When `docs/` exists or Step 2 will create it, first inspect whether the repo already states a docs-governance policy. Never infer one from filenames. During bootstrap, migration or full re-audit, ask when no current policy exists. During a focused update, preserve the presence or absence of a Docs section and ask only about a defect or requested change:

- **Snapshot + living docs (Recommended)**: show the exact proposed `AGENTS.md` Docs section: docs live in `docs/`; snapshots use `topic_YYYY-MM-DD.md`, are treated as possibly outdated and are immutable except for ticking a to-do checkbox; living docs have no date and carry a bumped `Last reviewed`; the relevant-doc pointer is checked before planning or changing its area. Say this is the skill's maintainability recommendation, not an external standard.
- **Pointers only**: list existing docs with concrete read triggers, but add no naming, dating, review-date or immutability policy.
- **Custom policy**: the user states which of those rules apply and any different naming or lifecycle.

Record each accepted Docs statement as an explicit-answer rule with destination `AGENTS.md`; pass those records to Step 9. Applying the Step 2 sketch authorizes creating that snapshot, not any general docs-governance policy. A focused update does not revisit a coherent Docs section or treat its absence as missing policy.

Only when `docs/` names break the current, explicitly kept or selected convention:

1. Show a table: current name, proposed name and document type. Allowed path changes are lowercase, separators, ISO dates, dropping copy suffixes like ` (1)`, and lowercase extensions (`.MD` -> `.md`). Names that already comply are not listed. Renaming a snapshot does not change its body.
2. Build the complete final-path map before asking. Detect collisions case-insensitively, including existing destinations, copy-suffix collapse, case-only renames and cycles. A colliding proposal has no Apply option until the user chooses a unique name or skips it.
3. Ask one question per file, in a single round: with more than 4 files, send consecutive question calls (4 per call) with no other message in between. The label says what differs ("Living doc", "Snapshot, 12 March", "Keep current name"); the description starts with the complete final name (`→ meeting-notes_2026-03-12.md`). Build date options from what the file and its name say (`12.03` -> both readings; "January 2026" -> `2026-01-01`, approximate). Offer the file's first-commit date only when files in `docs/` have different first-commit dates; otherwise that date says nothing about when the doc was written.
4. When a snapshot date is unknown, present real choices instead of assigning today:
   - **Keep current name (Recommended)**: preserves the unknown date and body.
   - **Use naming date**: uses today's date and adds `Date approximate (original date unknown; named on <today>).`
   - **Treat as living doc**: offer only when its content is maintained current; omit the date and add `Last reviewed`.

   Adding date provenance or converting type is a one-time, explicitly approved migration edit. After adoption, snapshot bodies remain immutable except for ticking a to-do checkbox.
5. Execute every approved rename without staging. Use unique temporary names for case-only renames and cycles, then move to final names. Search the repo case-insensitively for references to each old path, including relative links between docs. Update references in living docs, AI instructions and config. Do not edit snapshot bodies merely to update an outbound link; report stale outbound links from snapshots. References in application code are listed for the final report, not edited.

## Step 5: Propose the .ai/ structure

In a focused update, preserve the existing structure. Propose a new file only when the repo gained a distinct topic, a structural defect must be repaired, or an existing file would exceed about 300 lines. Moving language, architecture, testing or security rules from root `AGENTS.md` into `.ai/` is a structural repair, not a full re-audit.

For a bootstrap, full re-audit or migration, show the topics found in Steps 1-3, then ask for the structure:

- **Focused files (Recommended)**: `.ai/architecture.md` for boundaries and data flow, `.ai/code-style.md` for language-level rules, plus approved optional topics.
- **Compact file**: `.ai/project.md` with separate topic headings; use only when the expected result stays under 300 lines.
- **Custom structure**: the user names or groups files; validate that every approved topic has exactly one home and no file mixes conflicting scopes.

If the language of an empty repo is still undecided, leave out `.ai/code-style.md` and every file whose rules depend on the language (e.g. testing, api), and say they can be added by running the skill again once it is chosen.

Offer `.ai/tech-stack.md` only when repo evidence or the user's answer shows the core libraries and tools are settled. If this is unclear, include **Stack is still changing** in the structure question; choosing it omits tech-stack rules without requiring another round.

Proposed from what Step 1 found, for example `.ai/testing.md`, `.ai/api.md`, `.ai/database.md`, `.ai/ui.md`, `.ai/git-workflow.md`.

After the structure choice, ask about optional topics in a multi-select (split into several questions of up to 4 options when there are more); the user can add their own topics through the free-text field. With only one candidate, show its proposed scope and ask Apply / Skip; with none, don't ask.

Build candidates from verified repo facts and accepted Step 3 verdicts, excluding claims the user rejected or deleted. File provenance never changes the proposed topic set: identical repo facts and answers must produce the same structure.

Any file may later grow into a folder (`.ai/architecture/` with a short `index.md`). Suggest splitting when a file passes ~300 lines.

## Step 6: Interview, file by file

Keep a checklist of the files approved in Step 5 and go through all of them. Before Step 7, confirm every file on the list was interviewed; if one was missed, interview it now.

If the user asks for fewer rounds, combine a file's topic list and its rule questions into one round (up to 4 questions), researching the likely topics first.

For each approved file:

1. **Topics.** List the topics you intend to cover as a multi-select; the user strikes or adds. Name the rules already decided in Step 3 for this file, so the user sees them. Research only after the topics are confirmed. In a focused update, do this only for a new file or a file whose scope genuinely changed.
2. **One question per rule.** Research each topic (Principles: primary sources, fetched), then offer up to 4 options (the tool's limit) from the list below. Merge genuinely equivalent options; when five remain meaningful, use the **Show more options** flow under Asking questions:
   - **Best practice**: current guidance from primary sources, with URL.
   - **Common in the ecosystem**: what most well-maintained projects of this stack do, if different.
   - **Current in this repo**: what the code does now, with evidence ("seen in 31 of 40 files") and an honest note on consistency and quality. Omit in empty repos. If it equals best practice, merge it into that option and say so.
   - **Alternative**: a reasonable different approach, if one exists.
   - **Your preference (personal config)**: only if the user-level config of whoever runs the skill covers the topic and differs from the recommended option. If it equals it, merge it into that option and tag it `(Personal)`; see Principles.

   Rules apply to new and changed code. When the chosen rule conflicts with how the existing code is laid out (e.g. "new components go in `src/features/`" while that folder doesn't exist yet), ask in the next round when it takes effect: "From now on (Recommended)": new code follows it immediately and existing code is migrated later; or "After migration": new code keeps following the current layout until the migration is done. Record the answer with the rule. `After migration.` is the only deferred marker; never substitute `Deferred`, `Later` or similar wording. A deferred rule cannot claim active checking or CI enforcement, and its future config stays disabled. Give it a migration entry with destination path, current rule wording and enough semantic context to recognize a later equivalent rewording. On a focused rerun, remove the marker only when all semantically matching work is complete, the repo and non-writing check prove the current equivalent rule passes, and the user separately approves the marker-removal diff. Show any stored config diff as its own Apply / Skip question. A renamed rule file or equivalent rewording does not orphan completed work; stale links inside immutable snapshots are reported, not treated as editable defects.

   Design choices with no primary source (layering, folder layout, library choice) are offered as **Project decision** options: say there is no source and give the trade-off. Every Project decision question includes "No rule" as one of the up to 4 options (never the one left out when five apply), so the user can strike the topic. Recommend one only on evidence from the repo, the user's stated preferences in this run or personal config (then tagged `(Personal)`), or when the user asked for help deciding (then say it is your judgment).
3. **Enforcement.** If a rule can be enforced by a tool:
   - Tool already enforces the current policy: present one enforced option and point to the existing config; there is no config diff. Do not offer an impossible "not enforced" variant.
   - A valid alternative conflicts with existing enforcement: show the exact weakening or replacement diff in that alternative and label the loss of coverage. Choosing it counts as explicit approval to change the tool; never weaken configuration as a hidden consequence.
   - Tool is installed but needs new config: offer enforced and not-enforced variants and show the config diff with the enforced option.
   - Tool needs a new dependency (also when an installed tool needs a plugin or parser to work): first ask about the dependency, naming the package and version; then ask about the config change.
   - If the change will make the current code fail (lint errors, type errors), say so in the option description. The code is not fixed by this skill; failures are reported in Step 10.
   - Never weaken or disable an existing tool rule without asking.
4. **Open round.** After all questions for a newly created or fully re-audited file are answered, ask with the question tool whether the user has more rules for this file: options "No more rules (Recommended)" and "Suggest some"; the user types their own rules through the free-text field. Skip this round for unchanged files in a focused update. For each typed rule, propose a sharpened wording (specific, checkable) and ask Apply / Skip. On "Suggest some", propose 2-3 complementary rules based on what was chosen, as a multi-select. These follow the same sourcing rules; a design choice without a source is marked as such and recommended only on the grounds in Step 6.2.
5. **Record** every rule in a run-local decision record: stable ID, destination file, original and destination scope, exact wording, origin (**existing team policy**, **explicit answer**, **accepted Keep/Rewrite verdict**, **accepted enforcement pointer**, or later **accepted review fix**), the current policy text, answer, verdict or finding that authorized it, the reason if the user or source gave one, and how it is checked or the source URL plus the supporting sentence. Existing coherent policy is authorized by its current exact wording and scope; infer no prior-run decision. Keep this record only for Step 9 and never write it into repository files. A rule carrying a citation gets the same record when you can fetch the page; if you can't, say so and the review skips that citation.

## Step 7: Write the files

`AGENTS.md`:

```markdown
# <Project name>

Last reviewed: <today>

<1-3 sentences: what this is. Only facts from the repo or the user.>

## Commands

All commands: <where they live: `package.json` scripts, `Taskfile.yml`, `Makefile`, `pyproject.toml`, ...>. Most used:

- `<install>`
- `<test>`
- `<lint>`

## Workflow

<rules about how to work, not about code: e.g. "Run `<test command>` before finishing a task.">
- Keep `AGENTS.md` and `.ai/` current. If a rule contradicts the code you're changing or a decision made with the user, or your change makes a rule, command or pointer wrong, stop and propose the edit; once approved, make it in the same change and bump `Last reviewed`. Don't silently follow a wrong rule or work around it.

## Rules

<Include only when at least one rule is deferred: `Rules apply to new and changed code, unless marked "After migration.". Existing code may not follow them yet.`>

Detailed rules live in `.ai/`. Read the matching file before working in that area:

- Before changing structure, adding modules or moving code: `.ai/architecture.md`
- Before writing or reviewing code: `.ai/code-style.md`
- <one line per further .ai/ file, each with a concrete trigger>

## Docs

<Only the Docs statements explicitly kept or selected in Step 4. For example, when the full bundle was selected:>

- Design docs, plans and decisions for humans and AI go in `docs/`.
- Snapshots (plans, research, notes) carry the date in the name, `topic_YYYY-MM-DD.md`, and are not edited later; a newer version is a new file. They may be outdated.
- Living docs (e.g. an architecture overview) have no date in the name and include `Last reviewed: YYYY-MM-DD` after the title; bump it when content changes or during an explicit full re-audit.
- Ticking a checkbox in a to-do checklist is the one allowed edit to a snapshot.
- Before planning a feature or changing <the main area>: check `docs/`<, starting with the most relevant file>.
```

Commands: first identify the repository's real orchestrator and every area it covers. In a single-project repository, list the most useful exact commands for install, dev, build, test, lint and typecheck. In a multi-project repository without a valid aggregate, organize commands by area and include enough to cover each area; concise pointers to each area's manifest may replace repetitive bullets. A command is valid when its manifest/script/config and required project dependency or documented toolchain exist; the executable need not be installed on the machine running this skill. Mark a valid command that could not be executed here as `not run here: <environment reason>` in the final report, not as repository migration work. If a command runs but has a known baseline failure, say so beside it in `AGENTS.md`, distinguish that baseline from failures caused by new work, and give a verified changed-file or package-scoped alternative when one exists. Never publish a planned command, an invalid aggregate whose transitive task is missing or broken, or a command from a failed dependency install. In a multi-project repository, cover every area or state explicitly that it has no structurally valid project command or no project-specific rule; never point readers to `.ai/` as the location of missing commands. Write the Docs section only when Step 4 produced at least one accepted statement. When Step 2 created an initial sketch, name it in a read-trigger bullet only if Step 4's selected policy authorized that pointer, and label it a possibly outdated snapshot. Leave out other sections that would be empty, boilerplate that does not apply, and pointers to files that were not written. Adapt the Rules pointers to the structure chosen in Step 5. On bootstrap, migration or full re-audit, rewrite an existing `AGENTS.md` or `.ai/` file into this template: keep the Keep and Rewrite rules from Step 3, turn tool-covered rules into the one-line-per-tool pointer below, drop the deleted ones, and show the user the new content and what was dropped before writing (Apply / Skip). In a focused update, make the smallest coherent edit and show only that diff.

Each `.ai/` file:

```markdown
# <Topic>

Last reviewed: <today>

<When scoped: `Applies to: <repo-relative path or glob>`>

## <Subtopic>

- <Active rule.> Why: <reason>. <Enforced in CI by: `<workflow/tool/rule>` | Checked by: `<tool/rule>` | Source: <URL> | Project decision>
- <Deferred rule.> After migration. Why: <reason>. <Source: <URL> | Project decision>
```

Tool-checked rules get one line per tool instead of one line per rule, e.g. "Follow the naming, typing and import rules. Checked by: ESLint (`eslint.config.js`; `pnpm lint`)." `Checked by` already means a repository-local check and does not claim CI; do not add `local only` or `not run in CI` unless that distinction resolves a concrete ambiguity. Use `Enforced in CI by` only when a required CI job runs the check; that one terminal marker includes the tool, config, command and CI job, and replaces rather than accompanies `Checked by`. A fully tool-defined rule ends at its checking marker—never append `Project decision` or `Source`. If selected project policy extends beyond what the tool checks, split the unchecked requirement into its own rule with its own basis. Write a tool-covered rule separately only when its reason isn't visible in config and matters; then include `Why` before the same single terminal marker.

Write only durable facts. No exact versions, counts, line numbers or lists of files that a manifest, lockfile or config already holds; point to that file instead ("Versions: `package.json`"). A constraint that matters (an upper bound, a pinned tool) stays: name the tool and give at most the major version ("TypeScript below 6"), never minor or patch. If the bound isn't a clean major, name what sets it ("until typescript-eslint supports the next TypeScript") instead of a number, and point only to a file you have checked. `AGENTS.md` owns the command catalog; `.ai/` rules and Workflow may reference the exact command that checks a rule but do not repeat the catalog. Rules describe patterns, not inventories. Don't describe where current code falls short; that belongs in Step 9 migration work, except a known baseline command failure that must be disclosed beside the command.

Mark a rule "After migration." only if the user chose that; otherwise it applies from now on. A "Why" is the user's own reason or a phrase from the recorded sentence (Step 6.5); never paraphrase a source into a reason. Omit "Why" when there is none.

`Last reviewed` records the last content change or explicit full re-audit. Bump it when the file changes or during an explicit full re-audit. An unchanged focused update must leave both content and date byte-for-byte unchanged.

Before writing, check every statement about the current code (what exists, where, how many, what a tool or test does) by reading or searching the repo. Drop or correct an unsupported new claim. Preserve coherent existing team policy when only a missing local tool or network access prevents re-verification; report it as not verified here instead of changing the file. Describe a command from its contents or documentation, not its filename: for example, call `mvnw` a Maven wrapper only when the standard wrapper files or script behavior establishes that. A plan or intention ("automation is planned") goes in only if the user said it or a doc in the repo says it; otherwise drop it, or ask and mark it "Project decision".

The command-validity invariant applies everywhere, not only the `AGENTS.md` Commands section. Before retaining, importing or adding a command in policy or docs, verify every transitive script, project dependency, manifest, workspace and required config exists after approved writes. A missing local executable is an execution limitation, not proof that a repository command is invalid. An aggregate task is invalid when any covered package command is missing or broken. A nonzero exit caused by existing code violations is valid but must be disclosed beside the command and tracked as migration work; a command with missing project wiring must be omitted or shown as a known broken orchestrator target, never silently replaced. Never weaken or discard the durable practice behind an invalid command. Show exact command-free wording and ask Apply / Skip. For a command-only rule with missing project wiring, offer **Defer as migration work (Recommended)**, **Drop the rule**, and **Stop for project fix**. **Defer** creates one command-work row and names the command only there. A machine-local tool absence goes only in check results and creates no repository to-do. Do not edit a task runner or workspace merely to make a command look complete unless the user approved every dependency/config change and the aggregate is then structurally valid. This gate also applies to commands imported from additional instruction files and accepted Keep verdicts.

Match every proposed rule to exactly one entry in the Step 6.5 decision record. Repo facts may populate the project summary, commands and pointers; they never authorize new unchecked policy. Drop any unmatched new rule instead of inferring a preference. A rule may end in `Source: <URL>` only when the recorded supporting sentence entails its complete normative content. Documentation for a mechanism does not authorize a project-specific value or contract built on that mechanism: mark that rule `Project decision` instead. Project decisions include a durable reason when one exists; never invent one or store a person's identity as provenance. If one sentence mixes independently useful sourced and project-decision requirements, split it. `AGENTS.md` indexes detailed rules and must not duplicate them. Every `.ai/` rule has exactly one terminal basis/checking marker—`Enforced in CI by`, `Checked by`, `Source`, or `Project decision`—and contains none of the other three. Use that exact marker directly; prefixes such as `Basis: Project decision` are invalid. Rules are short imperatives. Code examples are complete and working, never placeholders.

Then, in this order:

1. **Draft preflight.** Build every final policy and moved-doc draft from the decision and Move records. For a new or fully rewritten file, show its complete content and what it replaces; for a focused update, show only the diff. An unchanged focused-update file needs no question or write. Ask one Apply / Skip question per changed file. Applying the complete draft authorizes its displayed workflow and pointer sentences; create one transient explicit-answer record for each normative sentence so reviewers can trace it. Skipping a new rule file removes its proposed `AGENTS.md` pointer; skipping a diff to an existing file leaves that file and its existing pointer unchanged. Before that question, list every separately approved dependency or config change used only by the file; if the file is skipped, ask Retain / Cancel for each such enforcement choice in the next round and record the answer. Never cancel or weaken enforcement as an implicit consequence of skipping Markdown. A skipped moved-doc draft preserves its source section and prevents that source's deletion. Write nothing yet.
2. **Dependencies.** For each approved new dependency, run the repo's own package manager command to add it, so the lockfile stays in sync. Before the command, record relevant existing ignored and untracked paths. If it fails (no network, wrong toolchain), restore the manifest and lockfile to their pre-command bytes and remove only new install artifacts the failed command created, including ignored paths such as a new `.venv/` or `node_modules/`. Then ask one recovery choice:
   - **Keep rule unenforced (Recommended)** when the rule remains useful without the tool;
   - **Drop the rule**;
   - **Stop for environment fix** and print the exact command to retry.

   Never retain a tool-checking claim for a dependency that is absent from the project. Record a kept-but-unchecked rule with its source or as a project decision, and put an approved missing project dependency in Step 9's migration to-do. A dependency present in the project but unavailable on this machine is reported as `not run`, without changing policy.
3. **Tool config.** Apply the approved config changes. Also write example config files a decided rule needs (e.g. `.env.example` documenting a required environment variable), never with real secrets.
4. **Run the checks.** Inspect each command and its config first. Never run fix/write/format mode as a check. Issue each check as its own literal command/tool call; do not execute command strings through a shell variable, loop, `eval`, `xargs`, or an interpreter. When the worktree is dirty or a command's write behavior is uncertain, run checks against a disposable copy containing the exact current bytes and required installed dependencies; never copy outputs back, and remove the copy after recording results. Otherwise, snapshot normal, untracked and ignored paths and file bytes before running lint, typecheck and quick tests. Prefer explicit non-writing modes (e.g. type-check with `--noEmit`); don't run a build unless it is the only typecheck. Remove new outputs and restore every unexpected mutation to its pre-check bytes. If concurrent user editing makes attribution uncertain, stop cleanup and ask instead of overwriting. Successful approved dependency installs from item 2 (e.g. `node_modules/`, lockfile updates) are not check output; keep them. Record all failures as the baseline for Step 9. If a safe copy cannot run, record why instead of risking the working tree.
5. **Write final Markdown.** Rebuild drafts after dependency, config and check outcomes. If failure recovery changed more than wording, show the affected draft again and ask Apply / Skip. Write only approved final content.
6. **Deletions.** Now that the content is migrated, offer to delete each obsolete shared AI instruction file and each stray file the user asked to remove, one Apply / Skip question per file. Delete without staging. If a deletion would leave a folder empty, say so; recheck kept rules that name that folder. Never offer an ignored or untracked local override for deletion unless the user explicitly brought it into scope.
7. **Legacy cleanup.** Create no ownership metadata or markers. If `.ai/.ground-rules.json` or `ground-rules:managed` comments exist, show their removal with the other proposed changes and ask through the normal per-file Apply / Skip flow. They never influence classification, auditing or write decisions.

## Step 8: Claude Code permissions

Only when the repository already uses shared Claude Code configuration or the user says the team uses Claude Code, propose adding this to `.claude/settings.json`, so Claude asks before changing the rules it works under (this applies even in accept-edits mode; `Edit(...)` rules cover every file-writing tool, source: https://code.claude.com/docs/en/permissions). In a focused update, do not offer an absent setting unless the user requests it:

```json
{
  "permissions": {
    "ask": ["Edit(/AGENTS.md)", "Edit(/.ai/**)"]
  }
}
```

The file is committed and applies to everyone working in the repo; say so. Normalize path-equivalent existing ask entries before comparison so the skill never adds a duplicate. If the effective protection already exists, report it and make no write or question. Otherwise, merge without dropping keys, show only the resulting diff, and ask Apply / Skip.

## Step 9: Review by fresh agents

Before review, reconcile anything left for a separate change (code that breaks the new rules, dependencies not installed, checks that fail) against existing `docs/todo/` rows:

- Do not add an issue already represented by an equivalent open row.
- Offer to tick a row only when the issue is proven resolved.
- Never append new work to an existing snapshot.
- For new work, use `docs/todo/conventions-migration_<today>.md`; if it exists, use a unique topic such as `conventions-migration-follow-up_<today>.md`, then `...-follow-up-2_<today>.md`.

If new rows remain, show this draft and ask Apply / Skip:

```markdown
# Conventions migration

Written on <today>. Tick items when done; put new items in a new dated file.

| Done | File | Problem | Rule |
|---|---|---|---|
| [ ] | `<path>` | <what breaks> | [<rule>](../../.ai/<file>.md) or [`AGENTS.md` workflow](../../AGENTS.md#workflow) |
| [ ] | `<path or project configuration>` | <missing project wiring that makes the command invalid> | Command work approved `<today>`: `<exact command>` |
| [ ] | `<affected scope>` | Known baseline failure: `<verified failure>` | Baseline command: `<exact command>` |
```

Use the first row for code or config migration linked to policy in `.ai/` or `AGENTS.md`. Use the second only for an explicitly deferred command-only choice with missing repository wiring—not for a tool absent on the current machine. Use the third for any valid command with a verified baseline failure when a policy link would add no useful context. During creation review, give reviewers the matching transient evidence. For each deferred rule, include its destination, wording and semantic context. If checking is deferred, add a **Deferred checking** section with that same context and exact future config diff; this records a proposal, not active policy.

A published `After migration.` rule and an accepted deferred command must each have an approved migration entry. If the user skips a to-do containing either, do not strand the prior decision. For each affected deferred rule, ask **Drop the rule** or **Stop and restore this run's affected policy changes**. For each command-work item, ask **Drop the command choice** or **Stop and restore this run's affected policy changes**. On Stop, restore affected paths to their pre-run bytes and remove only files this run created after confirming no concurrent edits; if attribution is uncertain, require an explicit drop or retain-as-open-conflict choice. Update every affected transient record and draft.

Applying the to-do draft authorizes only that file. If migration work exists, include at most one pointer in each relevant `AGENTS.md` section: the Docs bullet "Open migration tasks are in `docs/todo/`." and, only when useful, the Workflow bullet "When you finish a migration item listed in `docs/todo/`, tick it there." Show the separate diff and ask Apply / Skip. Write only approved files and bump `Last reviewed` only when content changes. Reviewers must see the final artifacts.

Launch two general-purpose subagents independently. Neither sees the interview transcript, rejected alternatives, expected artifacts, persona script or the other review. Give each only the repository, the list of written and changed files (not `.claude/skills/`), and sanitized copies of the full Step 6.5 decision record and Move record: IDs, exact final wording/content, origin, authorizing current policy text, selection, verdict or finding, original and destination path/scope, checking mechanism, URL and supporting sentence. These records are review evidence, not repository content. Give each this checklist:

- Rules that contradict each other, across files or with tool config.
- Rules with no exact authorizing entry in the decision record, or two policy files that state the same detailed rule.
- Moved human-doc content with no accepted Move record, missing source sections, or a destination differing from the accepted type/path.
- Imported rules whose destination scope differs from the accepted scope, and precedence claims not supported by the recorded official source.
- Vague rules that can't be checked.
- Rules that don't match the repo: invalid commands, paths, tools or project dependencies. Distinguish missing project wiring from a valid command that merely could not run on the reviewer's machine. Check that real orchestrators and every project area are represented or explicitly out of scope; known baseline failures must be disclosed beside commands. A rule without "After migration." applies from now on and may name a folder that doesn't exist yet; that alone is not a finding. Code that breaks a rule goes under "code that breaks the new rules". Do flag a deferred rule whose wording contradicts its deferral, and any `.ai/` sentence that describes current code instead of policy.
- Judge the repo only against itself and the cited sources, never against user-level config (personal CLAUDE.md, memories).
- Citations whose recorded sentence doesn't support the rule they're attached to, and "Why" lines that aren't a phrase from the recorded sentence (you check the user's own reasons yourself).
- Rules that restate configured checks instead of pointing to their config; `Enforced in CI by` claims without a required CI check; and local checks mislabeled as CI enforcement.
- Facts that will go stale quickly (versions, counts, line numbers, file lists) where a source of truth could be named instead. The `AGENTS.md` Commands section and major-version bounds (Step 7) are exempt.
- `AGENTS.md` over 150 lines, a `.ai/` policy file over 300 lines, or missing `Last reviewed`.
- Pointers in `AGENTS.md` without a concrete trigger.
- Rules that can't be checked against the code (no reader could tell whether the code follows them).
- Broken canonical structure: missing pointed-to files, unreachable `.ai/` policy files, or legacy ownership metadata/markers left after an approved cleanup.
- Migration to-do rows that describe only the reviewer's machine or lack the evidence required by their row type. A rule row needs a semantically matching current rule; a command-work row needs `Command work approved <ISO date>: <exact command>` matching missing project wiring and its creation-run **Defer as migration work** record; a baseline row needs the exact command, affected scope and verified failure. None creates active policy. A row whose rule no longer exists is obsolete and report-only; optionally offer a new dated follow-up that supersedes it. Equivalent rewording and stale outbound links in immutable snapshots are also report-only.
- Snapshot bodies changed without the explicit one-time migration choice, unresolved rename collisions, or broken updated references.

Tell each reviewer to give file:line evidence (and the quoted source text, for citation findings) for every finding and classify it as blocker, major, deterministic minor or stylistic nitpick. Verify every finding yourself against the files and discard false positives. Present the confirmed ones in four groups:

1. **Fixes to the written files**: ask which to apply (multi-select).
2. **Needs a decision**: ask, or leave open if the user prefers.
3. **Code that breaks the new rules**: no action; goes to the final report.
4. **Outside the skill's scope**: no action; goes to the final report.

Resolve every **Needs a decision** item before calling the artifact clean. If the user leaves one open, omit new or guessed policy written by this run; preserve existing team policy unless the user explicitly removes it, record the concern as an open conflict, and describe the run as completed with open decisions.

Before Step 10, perform a hard review gate over every confirmed blocker, major and deterministic minor on a writing run. Each must have an explicitly approved terminal state: **fixed and re-reviewed clean**, **rule removed**, or **policy retained and recorded as an open conflict**. Never remove team-owned policy merely because the user declined a fix. A retained deterministic finding prevents a clean verdict but does not trap the run. If the user chooses Stop for defective policy newly written by this run, restore the affected paths to their pre-run bytes and remove only files this run created, after confirming no concurrent edits; if attribution is uncertain, require an explicit retain-as-conflict or remove choice. On validate-only or audit-only runs, make no terminal-state decision request: report all findings as open and make no clean claim. Never report `Open conflicts: none` while a finding remains.

For every accepted review fix, update the matching decision-record wording and set its origin to **accepted review fix**, preserving the prior authorization and adding the accepted finding. A review item that needs a new policy choice creates a new **explicit answer** record. Drop a rule when neither exists.

Report discarded findings in one line each, with the reason. After applying fixes, re-read the changed lines and update the transient decision record, then launch two new blind reviews with fresh contexts. Repeat until neither finds a blocker, major or deterministic minor, or the user explicitly retains every remaining finding as an open conflict. Only the clean branch passes the release-quality gate. A finding is a nondeterministic nitpick only when it violates no invariant, is stylistic, reviewers disagree, and it does not reproduce in two further fresh reviews.

## Step 10: Commit and report

Every terminal path, including validate-only and completed-with-conflicts, begins with the exact heading `## Ground Rules final report`.

1. List exactly the files this skill created, changed, renamed or deleted. For a path that was already dirty, show **pre-existing** and **Ground Rules contribution** separately from the saved baseline. List untouched pre-existing work in its own row; never count it as this run's output or omit a path the skill also changed.
2. List what is not verified: checks that failed or couldn't run, dependencies not installed, lockfiles out of sync.
3. If there is an actual diff and Step 1 found no pre-existing staged work or merged dirty paths, propose a commit message following the repo's existing commit style (check `git log`). When no style is established, use `Bootstrap repository conventions`, `Migrate AI instructions`, or `Update repository conventions` as the fallback. Ask Commit / Don't commit; a different message comes through "Other". With no diff, report "No changes" and ask neither commit nor push. If the run continued with a pre-existing index or changed a pre-existing dirty path, state that commit and push are disabled and skip this question.
4. On Commit: stage every listed path explicitly (never `git add .` or `-A`), including renames and deletions by their old and new paths. Verify with `git diff --cached --name-status` that nothing else is staged, then commit. Never skip hooks.
5. If a commit was created and there is a remote and an upstream (or a remote to push a new branch to), ask separately whether to push, unless the user already approved the push in their commit answer. If there is no remote, say so instead of asking.
6. Final report:
   - What was written and decided.
   - **Code that breaks the new rules**, with file paths: a to-do list for a separate change (or a link to the to-do file, if written).
   - Check failures from Step 7.4.
   - Other problems noticed outside the skill's scope.
