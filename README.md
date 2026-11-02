# ground-rules

A Claude Code plugin with one interactive skill that sets up, migrates, validates, or updates a repository's AI conventions with you:

- inspects the repo and audits existing AI instruction files (`CLAUDE.md`, `.cursorrules`, `copilot-instructions.md`, ...)
- distinguishes canonical conventions, additional shared instructions, and machine-local overrides
- asks about policy and consequential workflow choices, without re-asking settled decisions or facts the repository establishes
- writes a short `AGENTS.md`, detailed rules in `.ai/`, and—with a chosen docs policy and per-file approval—tidies nonconforming names in `docs/`
- proposes linter, formatter or compiler config for rules a tool can enforce
- offers to delete old AI instruction files once their content is moved (you confirm each one)
- offers a dated checklist in `docs/todo/` for code that doesn't follow the new rules yet
- treats current Markdown as team-owned policy, with no plugin markers, hashes, or hidden ownership state
- has two fresh agents review the result; deterministic findings are fixed, removed, or explicitly reported as open conflicts before any commit choice

You decide every rule. The skill never changes application code.

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

In the repository you want to set up:

```
/ground-rules:ground-rules
```

When `AGENTS.md` or `.ai/*.md` already exists, choose:

- **Focused update** to validate current policy and ask only about findings or new decisions;
- **Full re-audit** to revisit every rule; or
- **Validate only** for a read-only review.

When only another instruction format exists, choose **Migrate interactively**, **Audit only**, or **Leave unchanged**.

Additional instruction formats are precedence-checked on every run. During a focused update, equivalent and unique non-conflicting content is reported without another interview; conflicting or stale rules are brought to you. Ignored and untracked local overrides remain outside shared migration unless you explicitly include them.

## What it writes

| Path | Content |
|---|---|
| `AGENTS.md` | Short index for every AI tool: commands, workflow, pointers into `.ai/` |
| `.ai/*.md` | Team-owned rules organized by topic; no plugin ownership markers or metadata |
| `docs/` | With a chosen docs policy and per-file approval: consistent names, dated snapshots, and living docs with `Last reviewed` |
| `docs/todo/<topic>_<date>.md` | Dated migration checklists; mixed convention work defaults to `conventions-migration_<date>.md` |
| `.claude/settings.json` | In repositories using shared Claude Code config, if you approve it: Claude asks before editing `AGENTS.md` or `.ai/` |
| Tool config, manifests and lockfiles | Only dependency or enforcement changes you approved |
| Example config | Only approved non-secret examples required by a rule |

## License

MIT
