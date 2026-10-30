---
name: ground-rules
description: Interactively set up or audit a repository's AI context (AGENTS.md + .ai/) and human docs (docs/). Inspects the repo, audits existing AI instruction files, interviews the user rule by rule with cited options, writes the files, has them reviewed by a fresh agent, and offers to commit.
disable-model-invocation: true
---

# Ground rules

Set up a tool-neutral convention structure for a repository, or audit an existing one:

```
AGENTS.md          root index for every AI tool: summary, commands, workflow, pointers (at most 150 lines)
.ai/               detailed AI rules, one topic per file; acknowledges docs/ exists, never maps it
docs/              human + AI design docs, plans, decisions
```

## Principles

- **The user decides.** Never write a rule the user did not pick. Never invent a reason for a decision; a rule without a reason has no "Why".
- **Organise, don't legitimise.** What the repo currently does is one option, labelled as such, never recommended just because it exists. Existing code may be unreviewed or generated; judge it.
- **Enforced beats written.** If a linter, formatter, compiler setting or CI check can enforce a rule, propose that config change. The config is then the source of truth: the `.ai/` file doesn't restate tool-enforced rules one by one but points to the config and the command that checks it.
- **Primary sources only.** Options come from official documentation, language/framework style guides, release notes and the recommended configs that tools ship. No blog posts, listicles or AI-generated summaries. Fetch every URL you cite during this run and confirm it supports that specific claim; don't cite from memory.
- **Recommend from evidence; label the operator.** Base recommendations on the repo and cited sources. Stored personal preferences of whoever runs the skill (user-level CLAUDE.md, memories, personal skills) may also inform a recommendation, but then the label ends with `(Personal)` after `(Recommended)` and the description says what the preference is and what else supports the option. A personal preference that differs from the recommended option is a separate option labelled "Your preference (personal config)", never marked recommended. Personal config never becomes a rule without the user's pick and is never used to judge the repo. Preferences the user states during this run are input like any other answer. Their working rules (how to ask, when to commit) apply to how you run the skill, never to what is written into the repo's files.
- **No assumptions about the environment.** Detect the OS, shell, package manager and tooling from the repo; ask when unclear.
- **Scope: conventions, not code.** The skill changes only `AGENTS.md`, `.ai/`, `docs/`, AI instruction files, tool config (linter, formatter, compiler, CI), example config files (e.g. `.env.example`), dependency manifests and the permissions in `.claude/settings.json` (Step 8). It never changes application code. Code that breaks a new rule is reported at the end (Step 10), not fixed.
- **Out of the skill's scope:** `.claude/skills/` (skills are tooling, not conventions) and anything the user did not ask about. Mention other problems you notice in the final report; don't fix them.

## Asking questions

Use multiple choice (`AskUserQuestion`):

- At most 4 questions per call, 2-4 options each. The tool adds "Other" for tweaks; never add your own "Other" option.
- Every choice question has exactly one option marked "(Recommended)", listed first, unless the user is only stating a fact ("which date is it?") or no option has a source, repo evidence, stated preference or personal config behind it (then mark none and say so in the message; when the user asked for help deciding, recommend anyway and say it is your judgment). This includes Apply / Skip confirmations: mark the one you'd pick. Multi-select questions are the exception to "exactly one": mark each option you'd actually select. Put the reasoning in the option description.
- Option labels are 1-5 words, not counting the `(Recommended)` and `(Personal)` tags. Details, sources and trade-offs go in the description.
- Option descriptions are short: about 20 words, the consequence and the main trade-off. Say once in the message which options have no source; don't repeat it in every option.
- Confirmations ("apply these verdicts?", "create this file?") use exactly two options: "Apply" and "Skip". Adjustments come through "Other". Use Apply / Skip only to confirm one concrete change already shown (a config diff, a deletion, a rename, a verdict table), never in place of a choice between approaches.
- "Apply, but with a change" goes through the free-text field. End every Apply / Skip question with a hint like `(to apply with changes, type them)`. Treat a typed answer as Apply plus the typed change, unless it clearly rejects; show the adjusted result before writing if the change is more than a wording tweak. If the intent is unclear, ask. Also read any notes the tool returns with the answer.
- When the user asks you to help decide, answer with a new choice question, not a confirmation: your recommendation first, marked "(Recommended)" with the reasoning in its description, followed by every still-valid alternative with its trade-off. A recommendation never removes an option.
- More than 4 choices in a list (topics, files, rules to pick from): split it into several questions (e.g. topics 1-4, topics 5-8), never drop items silently. For the options of a single rule, Step 6 says which one to leave out and name in the message instead.
- Prefer the question tool whenever the likely answers can be listed, including dates (offer the plausible readings) and "anything else?" rounds (options such as "No more rules" / "Suggest some"; the user types their own through "Other"). A question asked only in prose at the end of a long message looks like the run has stopped.
- Plain text only for truly open answers (project intent, reasons). Then end the message with that question on its own line, in bold, and ask nothing else in that turn.
- Never ask a question in the same round as the question it depends on (a config change that needs a new dependency, a setting that applies only to one of the options). Ask the prerequisite first, the dependent one in the next round. Don't spend a round on a single follow-up: carry it into the next round that has other questions (e.g. the next file's interview); ask it alone only if no such round is left.

## Presentation

Messages are read in a terminal; make them scannable, not a column of prose.

- Start each message with one bold status line: the step and what just happened.
- Put anything with more than one attribute in a table: evidence, verdicts, renames, findings, files changed, check results, the to-do list. Sources go in their own column, not inside sentences.
- Show config changes as a diff of only the changed lines, not the whole file. When a file is rewritten completely (e.g. an existing `AGENTS.md` put into the template), show the new content plus one line on what was dropped, not a diff of every line.
- Keep the text before the questions to about 15 lines. Leave out what the user doesn't need to decide now.
- Don't repeat decisions the user already made; refer to the file they live in.
- The final report (Step 10) is tables plus at most a few lines: commit, files, to-do (file | problem), check results (check | result), open conflicts, out-of-scope notes.

## Naming and dating

- File names: lowercase, `-` between words inside a part, `_` between parts: `auth-redesign_2026-10-22.md`. Dates are ISO `YYYY-MM-DD`.
- Extensions are lowercase: `.md`, not `.MD`.
- **Snapshot docs** (sketches, plans, research, meeting notes) carry the date in the file name and are not edited later; a newer version is a new file.
- **To-do checklists** in `docs/todo/` are snapshots with one exception: ticking a checkbox is allowed. New items go into a new dated file.
- **Living docs** (`AGENTS.md`, `.ai/*`, architecture overviews) have no date in the name. They start with `Last reviewed: YYYY-MM-DD` and get the date bumped whenever they are reviewed or changed.
- Get today's date from the system, not from memory.

## How Claude Code finds AGENTS.md

Claude Code (v2.1.277+) reads `AGENTS.md` instead of `CLAUDE.md` only when there is no `CLAUDE.md`, `.claude/CLAUDE.md` or `CLAUDE.local.md` in the working directory or any directory above it. A subdirectory's `AGENTS.md` is read when Claude works in that subdirectory and it has no `CLAUDE.md` of its own. The user-level `~/.claude/CLAUDE.md` does not block it. Source: https://code.claude.com/docs/en/memory

## Step 1: Inspect

Read, don't change anything yet. Collect:

1. Stack signals: manifests and lockfiles (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `*.csproj`, ...), `README*`, CI config, lint/format/compiler configs, top-level folder layout.
2. Existing AI instruction files, at any depth: `AGENTS.md`, `.claude/AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, `CLAUDE.local.md`, `.claude/rules/`, `.claude/settings.json` (config: inventory only, not audited as rules), `.cursorrules`, `.cursor/rules/`, `.github/copilot-instructions.md`, `.github/instructions/`, `.windsurfrules`, `GEMINI.md`, `.ai/`. Skip `.claude/skills/`.
3. `docs/`: file list, naming, and links between docs. For existing `docs/todo/` files, count the open and ticked items; report them, and check whether open items are still true in the code.
4. Git state: current branch, remote and upstream, uncommitted and staged changes. Remember them; they are not this skill's to commit.

Report in at most 10 lines, including the detected mode as a bold line: **Mode: empty repo (Step 2, then Steps 5-10)**, **existing repo without AI files (Steps 4-10)** or **existing repo with AI files (Steps 3-10)**. The evidence decides it: nothing but `.git` and housekeeping files (README, LICENSE, `.gitignore`) is an empty repo; AI instruction files (not `.claude/settings.json`) plus code or manifests mean with AI files; no AI instruction files plus code or manifests mean without. The user can correct the mode at the next question.

Ask a question here only if something is unclear: the mode (AI files but no code or manifests, e.g. a lone `.cursorrules`) or the environment (e.g. which package manager when several lockfiles exist). If nothing is unclear, ask nothing and continue with the next step.

## Step 2: Empty repo only

1. Ask in plain text what the repository is for: goal, users, expected stack if known, open questions.
2. Write `docs/first-sketch_<today>.md` from the answer, starting with:
   > **Initial sketch, not a source of truth.** Written on <today> before any code existed. Plans change; check `.ai/` and the code for what is actually decided.
3. Show it and ask: Apply / Skip.

## Step 3: Audit existing AI files

For each existing AI instruction file, go rule by rule. Propose one verdict each, with a one-line reason:

- **Keep**: specific, correct, still matches the code.
- **Rewrite**: right intent, vague or wrong wording ("write clean code" is not a rule).
- **Enforce**: belongs in tool config. If the tool isn't set up yet, it becomes an enforcement question in Step 6.
- **Move**: belongs in `docs/` (rationale, plans) rather than in AI rules.
- **Delete**: wrong, obsolete, contradicts the code or another rule, restates tool defaults, or is about the AI's tone rather than the repo.

Present a table per file, then confirm each file with one Apply / Skip question covering its whole table; adjustments to single verdicts come through "Other". Skip means the file stays as it is: it is not offered for deletion in Step 7, and its rules are neither decided nor offered again.

- Kept and rewritten rules go to Step 6 as already decided, not asked again: kept rules keep their wording, rewritten rules use the wording proposed in this step. If a topic in Step 6 conflicts with one, raise the conflict.
- Every Enforce verdict goes to Step 6 even if its topic is later struck.
- Deleted rules are gone: don't offer them again as an option.
- A kept rule that names a path must still make sense after Steps 3-4; if the path would be empty or gone, say so.
- Note existing tool settings that weaken checks (e.g. a disabled lint rule) and ask whether to keep them.

Don't delete anything yet. AI instruction files that would block `AGENTS.md` (see above) or contradict the new rules are offered for deletion in Step 7, after their content has been migrated. Files the user skipped are not offered; if a skipped file blocks `AGENTS.md`, say so in the final report.

## Step 4: Tidy docs/

Only if `docs/` exists and names break the convention:

1. Show a table: current name, proposed name. Allowed changes: lowercase, separators, ISO dates, dropping copy suffixes like ` (1)`, and lowercase extensions (`.MD` -> `.md`). No moving between folders, no content edits. Names that already comply are not listed.
2. Ask one question per file, in a single round: with more than 4 files, send consecutive question calls (4 per call) with no other message in between. The label says what differs ("Living doc", "Snapshot, 12 March", "Keep current name"); the description starts with the complete final name (`→ meeting-notes_2026-03-12.md`). If a snapshot's date can't be derived at all, use today's date and the approximate-date line below with "date unknown" (no extra question). Build the date options from what the file and its name say (`12.03` -> both readings; "January 2026" -> `2026-01-01`, approximate). Offer the file's first-commit date only when files in `docs/` have different first-commit dates; otherwise that date says nothing about when the doc was written. A different date or name comes through "Other".
3. If the chosen date is approximate, use it in the name and add a first line `Date approximate (<what is known, e.g. "January 2026", or "date unknown, named on <today>">).` to the file; this is the one allowed content edit.
4. Rename with `git mv`. Search the repo case-insensitively for references to each old path (a rename that only changes case is otherwise missed on case-insensitive file systems), including relative links between docs. Update them in docs, AI instruction files and config; references in application code are listed for the final report, not edited. Report what was updated.

## Step 5: Propose the .ai/ structure

Always:
- `.ai/architecture.md`: layers, boundaries, data flow, where things go, anti-patterns.
- `.ai/code-style.md`: naming, file layout, typing, error handling, tests.

Only when the stack is decided, meaning the user confirms the core libraries and tools are not about to change:
- `.ai/tech-stack.md`: chosen libraries and tools, what is explicitly not used.

Proposed from what Step 1 found, for example `.ai/testing.md`, `.ai/api.md`, `.ai/database.md`, `.ai/ui.md`, `.ai/git-workflow.md`. Ask with multi-select; the user can add their own topics through "Other".

Any file may later grow into a folder (`.ai/architecture/` with a short `index.md`). Suggest splitting when a file passes ~300 lines.

## Step 6: Interview, file by file

Keep a checklist of the files approved in Step 5 and go through all of them. Before Step 7, confirm every file on the list was interviewed; if one was missed, interview it now.

If the user asks for fewer rounds, combine a file's topic list and its rule questions into one round (up to 4 questions), researching the likely topics first.

For each approved file:

1. **Topics.** List the topics you intend to cover as a multi-select; the user strikes or adds. Name the rules already decided in Step 3 for this file, so the user sees them. Research only after the topics are confirmed.
2. **One question per rule.** Research each topic (Principles: primary sources, fetched), then offer up to 4 options (the tool's limit) from the list below. If five apply, leave out the one you'd recommend least and name it in the message, so the user can still pick it through "Other":
   - **Best practice**: current guidance from primary sources, with URL.
   - **Common in the ecosystem**: what most well-maintained projects of this stack do, if different.
   - **Current in this repo**: what the code does now, with evidence ("seen in 31 of 40 files") and an honest note on consistency and quality. Omit in empty repos. If it equals best practice, merge it into that option and say so.
   - **Alternative**: a reasonable different approach, if one exists.
   - **Your preference (personal config)**: only if the user-level config of whoever runs the skill covers the topic and differs from the recommended option. If it equals it, merge it into that option and tag it `(Personal)`; see Principles.

   Rules apply to new and changed code. When the chosen rule conflicts with how the existing code is laid out (e.g. "new components go in `src/features/`" while that folder doesn't exist yet), ask in the next round when it takes effect: "From now on (Recommended)": new code follows it immediately and existing code is migrated later; or "After migration": new code keeps following the current layout until the migration is done. Record the answer with the rule.

   Design choices with no primary source (layering, folder layout, library choice) are offered as **Project decision** options: say there is no source and give the trade-off. Recommend one only on evidence from the repo, the user's stated preferences in this run or personal config (then tagged `(Personal)`), or when the user asked for help deciding (then say it is your judgment).
3. **Enforcement.** If a rule can be enforced by a tool:
   - Tool works already: offer the rule's options in enforced and not-enforced variants ("PEP 8 names, enforced" / "PEP 8 names, not enforced") and show the config diff in the message, so the rule and its enforcement are decided in one answer, without a separate Apply / Skip round.
   - Tool needs a new dependency (also when an installed tool needs a plugin or parser to work): first ask about the dependency, naming the package and version; then ask about the config change.
   - If the change will make the current code fail (lint errors, type errors), say so in the option description. The code is not fixed by this skill; failures are reported in Step 10.
   - Never weaken or disable an existing tool rule without asking.
4. **Open round.** After all questions for a file are answered, ask with the question tool whether the user has more rules for this file: options "No more rules (Recommended)" and "Suggest some"; the user types their own rules through "Other". For each typed rule, propose a sharpened wording (specific, checkable) and ask Apply / Skip. On "Suggest some", propose 2-3 complementary rules based on what was chosen, as a multi-select. These follow the same sourcing rules; a design choice without a source is marked as such and recommended only on the grounds in Step 6.2.
5. **Record** for every rule: the rule, the reason if the user or the source gave one, and how it is enforced or the source URL.

## Step 7: Write the files

`AGENTS.md`:

```markdown
# <Project name>

Last reviewed: <today>

<1-3 sentences: what this is. Only facts from the repo or the user.>

## Commands

<install, dev, build, lint, typecheck, test: exact commands as found in the repo>

## Workflow

<rules about how to work, not about code: e.g. "Run `<test command>` before finishing a task.">
- If a rule in `.ai/` contradicts the code you're changing or a decision made with the user, stop and propose updating the rule; don't silently follow it or work around it.
- When you finish a migration item listed in `docs/todo/`, tick it there.

## Rules

Rules apply to new and changed code, unless marked "After migration.". Existing code may not follow them yet.

Detailed rules live in `.ai/`. Read the matching file before working in that area:

- Before changing structure, adding modules or moving code: `.ai/architecture.md`
- Before writing or reviewing code: `.ai/code-style.md`
- <one line per further .ai/ file, each with a concrete trigger>

## Docs

Design docs, plans and decisions for humans and AI are in `docs/`. Files with a date in the name are snapshots and may be outdated.

- Before planning a feature or changing <the main area>: check `docs/`<, starting with the most relevant file>.
```

Leave out sections that would be empty. If `AGENTS.md` (or an `.ai/` file) already exists, rewrite it into this template: keep the Keep and Rewrite rules from Step 3, drop the deleted ones, and show the user the new content and what was dropped before writing (Apply / Skip).

Each `.ai/` file:

```markdown
# <Topic>

Last reviewed: <today>

## <Subtopic>

- <Rule.> <After migration.> Why: <reason>. <Enforced by: `<tool/rule>` | Source: <URL> | Project decision>
```

Tool-enforced rules get one line per tool instead of one line per rule, e.g. "Follow the naming, typing and import rules; check with `pnpm lint`. Enforced by: ESLint (`eslint.config.js`)." Write a tool-enforced rule out separately only when its reason isn't visible in the config and matters for decisions; then one line with "Why".

Write only durable facts. No exact versions, counts, line numbers or lists of files that a manifest, lockfile or config already holds; point to that file instead ("Versions: `package.json`"). Rules describe patterns, not inventories. Don't describe where the current code falls short of the rules; that belongs in the `docs/todo/` file (Step 10), not in `.ai/`.

Mark a rule "After migration." only if the user chose that; otherwise it applies from now on. Omit "Why" when no reason was given.

Before writing, check every statement about the current code (what exists, where, how many, what a tool or test does) by reading or searching the repo; drop or correct anything you can't confirm. A plan or intention ("automation is planned") goes in only if the user said it or a doc in the repo says it; otherwise drop it, or ask and mark it "Project decision". Every rule ends with exactly one of: "Enforced by", "Source", "Project decision". Rules are short imperative statements. Code examples only when a rule is hard to state in words, and then complete and working, never placeholder code.

Then, in this order:

1. **Dependencies.** For each approved new dependency, run the repo's own package manager command to add it, so the lockfile stays in sync. If it fails (no network, wrong toolchain), leave the manifest unchanged and print the exact command for the user to run.
2. **Tool config.** Apply the approved config changes. Also write example config files a decided rule needs (e.g. `.env.example` documenting a required environment variable), never with real secrets.
3. **Deletions.** Now that the content is migrated, offer to delete each obsolete AI instruction file and each stray file the user asked to remove, one Apply / Skip question per file, with `git rm`. If a deletion would leave a folder empty, say so; recheck kept rules that name that folder.
4. **Run the checks.** Run lint and typecheck (and tests if quick) with the repo's commands. Prefer checks that don't write files (e.g. type-check with `--noEmit`); don't run a build unless it is the only typecheck. Note `git status` before the checks and compare afterwards: remove files the checks created and restore files they changed that were unchanged before, so no output is left behind. Never restore a file that already had uncommitted changes before the checks; report what the check changed in it instead. Dependency installs from item 1 of this step (e.g. `node_modules/`, lockfile updates) are not check output; keep them. Record all failures as the baseline for Step 10. If they can't run, record why.

## Step 8: Claude Code permissions

Propose adding this to the shared `.claude/settings.json`, so that Claude asks before changing the rules it works under (this applies even in accept-edits mode; `Edit(...)` rules cover every file-writing tool, source: https://code.claude.com/docs/en/permissions):

```json
{
  "permissions": {
    "ask": ["Edit(/AGENTS.md)", "Edit(/.ai/**)"]
  }
}
```

The file is committed and applies to everyone working in the repo; say so. If the file exists, merge without dropping keys; otherwise create it. Show the resulting content or diff and ask Apply / Skip.

## Step 9: Review by a fresh agent

Launch a general-purpose subagent with a small, cheap model (e.g. haiku). It must not see the interview. Give it only the list of written and changed files (not `.claude/skills/`) and this checklist:

- Rules that contradict each other, across files or with tool config.
- Vague rules that can't be checked.
- Rules that don't match the repo: commands, paths or tools that don't exist. A rule without "After migration." applies from now on and may name a folder that doesn't exist yet; that is not a finding. Code that breaks a rule is not a docs error either: it goes to "code that breaks the new rules". Do flag a rule marked "After migration." whose wording contradicts the migration deferral, and any sentence in `.ai/` that describes the current code instead of a rule.
- Judge the repo only against itself and the cited sources, never against user-level config (personal CLAUDE.md, memories).
- Citations that don't support the rule they're attached to.
- Rules that restate what a configured tool already enforces, instead of pointing to the config.
- Facts that will go stale quickly (versions, counts, line numbers, file lists) where a source of truth could be named instead.
- `AGENTS.md` over 150 lines, `.ai/` files over 300 lines, missing `Last reviewed`.
- Pointers in `AGENTS.md` without a concrete trigger.
- Rules that can't be checked against the code (no reader could tell whether the code follows them).

Tell it to give file:line evidence (and the quoted source text, for citation findings) for every finding. Verify every finding yourself against the files and discard false positives. Present the confirmed ones in four groups:

1. **Fixes to the written files**: ask which to apply (multi-select).
2. **Needs a decision**: ask, or leave open if the user prefers.
3. **Code that breaks the new rules**: no action; goes to the final report.
4. **Outside the skill's scope**: no action; goes to the final report.

Report discarded findings in one line each, with the reason. After applying fixes, re-read the changed lines yourself; no second review.

## Step 10: Commit and report

1. **To-do file.** If anything is left for a separate change (code that breaks the new rules, dependencies not installed, checks that fail), show it and ask Apply / Skip for writing it to `docs/todo/conventions-migration_<today>.md`:

   ```markdown
   # Conventions migration

   Written on <today> by the ground-rules run. Tick items when done; new items go into a new dated file.

   | Done | File | Problem | Rule |
   |---|---|---|---|
   | [ ] | `<path>` | <what breaks> | [<rule>](../../.ai/<file>.md) |
   ```

   On Apply it is part of this commit, and add the line "Open migration tasks are in `docs/todo/`." to the Docs section of `AGENTS.md` and bump its `Last reviewed` (if Step 8's permission rule is in place, Claude Code will ask before this edit; that is expected).
2. List exactly the files this skill created, changed, renamed or deleted. Leave out anything that was already uncommitted before Step 1, and say that you left it out.
3. List what is not verified: checks that failed or couldn't run, dependencies not installed, lockfiles out of sync.
4. Propose a commit message following the repo's existing commit style (check `git log`); default `Bootstrap repository conventions`. Ask Commit / Don't commit; a different message comes through "Other".
5. On yes: stage the listed paths by explicit path (never `git add .` or `-A`). Renames and deletions done with `git mv` / `git rm` (Steps 4 and 7) have been staged since then; stage only the remaining paths, and pass new paths, not old ones. If anything was already staged before Step 1, ask the user how to handle it before staging anything; never commit it along. Verify with `git diff --cached --name-status` that nothing else is staged, then commit. Never skip hooks.
6. If there is a remote and an upstream (or a remote to push a new branch to), ask separately whether to push, unless the user already approved the push in their commit answer. If there is no remote, say so instead of asking.
7. Final report:
   - What was written and decided.
   - **Code that breaks the new rules**, with file paths: a to-do list for a separate change (or a link to the to-do file, if written).
   - Check failures from Step 7.4.
   - Other problems noticed outside the skill's scope.
