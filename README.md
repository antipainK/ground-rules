# ground-rules

A Claude Code plugin that sets up, migrates, validates, or updates a repository's AI conventions—either **interactively** with you or **non-interactively** in `auto` mode:

- inspects the repo and audits existing AI instruction files (`CLAUDE.md`, `.cursorrules`, `copilot-instructions.md`, ...)
- distinguishes canonical conventions, additional shared instructions, and machine-local overrides
- **interactive mode (default):** asks about policy and consequential workflow choices with minimal question rounds, without re-asking settled decisions or facts the repository establishes
- **`auto` mode (`/ground-rules:ground-rules auto`):** synthesizes `AGENTS.md` and `.ai/` without human prompts from repository evidence, compatible personal coding preferences, and fetched official industry standards—leaving destructive changes, config edits, and commits as explicit follow-up recommendations
- writes a short `AGENTS.md`, detailed rules in `.ai/`, and—with a chosen docs policy and per-file approval in interactive mode—tidies nonconforming names in `docs/`
- proposes linter, formatter or compiler config for rules a tool can enforce
- offers to delete old AI instruction files in interactive mode once their accepted rules are migrated or discarded (you confirm each one)
- creates or offers a dated checklist in `docs/todo/` for code that doesn't follow the new rules yet
- treats current Markdown as team-owned policy, with no plugin markers, hashes, or hidden ownership state
- has a fresh read-only agent review the result; deterministic findings are fixed, removed, or explicitly reported as open conflicts

The skill never changes application code.

## Install

In a Claude Code session:

```
/plugin marketplace add antipainK/ground-rules
/plugin install ground-rules@ground-rules
```

Or from a shell:

```bash
claude plugin marketplace add antipainK/ground-rules
claude plugin install ground-rules@ground-rules
```

On a machine without a GitHub SSH key, set `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` first.

## Stay up to date

Auto-update is off for third-party marketplaces by default. Turn it on in `/plugin` → **Marketplaces** → `ground-rules` → **Enable auto-update**, or in your user `settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "ground-rules": {
      "source": { "source": "github", "repo": "antipainK/ground-rules" },
      "autoUpdate": true
    }
  },
  "enabledPlugins": { "ground-rules@ground-rules": true }
}
```

Plugin releases use the version declared in both plugin manifests.

## Use

Interactive mode (default) in the repository you want to set up:

```
/ground-rules:ground-rules
```

When `AGENTS.md` or `.ai/*.md` already exists, choose:

- **Focused update** to validate current policy and ask only about findings or new decisions;
- **Full re-audit** to revisit every rule; or
- **Validate only** for a read-only review.

When only another instruction format exists, choose **Migrate interactively**, **Audit only**, or **Leave unchanged**.

Automatic mode (zero human prompts):

```
/ground-rules:ground-rules auto
```

In `auto` mode, Ground Rules runs in a single pass with no questions, combining verified repository tool/CI configurations, compatible coding preferences from your personal configuration (without leaking personal paths or identities into team files), and fetched official industry standards. It writes only canonical `AGENTS.md`, `.ai/*.md`, `docs/todo/<topic>_<date>.md`, and (for pre-code repos with stated intent) `docs/first-sketch_<date>.md`—leaving existing `docs/` filenames, foreign AI files, tool configs, `.claude/settings.json`, and Git commits untouched and listing follow-up actions in the final report.

Additional instruction formats are precedence-checked on every run. During a focused update, equivalent and unique non-conflicting content is reported without another interview; conflicting or stale rules are brought to you (or reported under **Open conflicts** in `auto` mode). Ignored and untracked local override files (`CLAUDE.local.md`, `*.local.md`, `.claude/settings.local.json`) are never edited, deleted, committed, or migrated as files unless you explicitly include them, though general coding preferences in `CLAUDE.local.md` may inform anonymized rules in `auto` mode.

## What it writes

| Path | Content |
|---|---|
| `AGENTS.md` | Short index for every AI tool: commands, workflow, pointers into `.ai/` |
| `.ai/*.md` | Team-owned rules organized by topic; no plugin ownership markers or metadata |
| `docs/` | Interactive mode, with a chosen docs policy and per-file approval: consistent names, dated snapshots, and living docs with `Last reviewed` (`auto` mode writes only `docs/first-sketch_<date>.md` in pre-code repos with stated intent, plus `docs/todo/` checklists below) |
| `docs/todo/<topic>_<date>.md` | Dated migration checklists; mixed convention work defaults to `conventions-migration_<date>.md` |
| `.claude/settings.json` | Interactive mode only, in repositories using shared Claude Code config and with your approval: Claude asks before editing `AGENTS.md` or `.ai/` |
| Tool config, manifests and lockfiles | Interactive mode only: dependency or enforcement changes you approved |
| Example config | Interactive mode only: approved non-secret examples required by a rule |

## License

MIT
