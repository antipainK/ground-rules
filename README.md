# ground-rules

A Claude Code plugin with one skill that sets up or audits a repository's AI conventions, together with you:

- inspects the repo and audits existing AI instruction files (`CLAUDE.md`, `.cursorrules`, `copilot-instructions.md`, ...)
- interviews you rule by rule, with options from primary sources and from what the repo does today
- writes a short `AGENTS.md`, detailed rules in `.ai/`, and tidies file names in `docs/`
- proposes linter, formatter or compiler config for rules a tool can enforce
- offers to delete old AI instruction files once their content is moved (you confirm each one)
- offers a dated checklist in `docs/todo/` for code that doesn't follow the new rules yet
- has a fresh agent review the result, then asks before committing

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

The plugin has no version number, so every commit on `master` is a new version.

## Use

In the repository you want to set up:

```
/ground-rules:ground-rules
```

## What it writes

| Path | Content |
|---|---|
| `AGENTS.md` | Short index for every AI tool: commands, workflow, pointers into `.ai/` |
| `.ai/*.md` | Rules, one topic per file |
| `docs/` | Renamed to a consistent scheme; dated snapshots, living docs with `Last reviewed` |
| `docs/todo/conventions-migration_<date>.md` | Checklist of code that breaks the new rules |
| `.claude/settings.json` | If you approve it: Claude asks before editing `AGENTS.md` or `.ai/` |
| Tool config | Only the changes you approved |

## License

MIT
