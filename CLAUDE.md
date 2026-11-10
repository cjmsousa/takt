# Takt

Takt is a personal software factory: a Claude Code plugin that turns GitHub issues into OpenSpec specs and then code. For now every stage runs interactively in Claude Code on the laptop; unattended runs on GitHub Actions come later.

**Read `docs/design.md` before any work in this repo.** It is the source of truth for the lifecycle, labels, skills and architecture. If a change you're making contradicts it, stop and say so; update the design doc first, then the code.

## Repo layout

- `.claude-plugin/plugin.json` — plugin manifest (name `takt`, so skills are invoked as `/takt:<skill>`)
- `.claude-plugin/marketplace.json` — this repo is also its own marketplace; the plugin source is the repo root
- `skills/<name>/SKILL.md` — one folder per skill
- `scripts/` — shell helpers skills call via `${CLAUDE_PLUGIN_ROOT}/scripts/…` (e.g. `preflight.sh`)
- `docs/design.md` — the design

Only manifests go inside `.claude-plugin/`. Skills, agents, commands and hooks live at the repo root.

## Rules

- **Depend on OpenSpec, never copy it.** Takt skills call OpenSpec's CLI and commands and add conventions on top. Don't vendor OpenSpec prompts or skills into this repo.
- **Interactive now, unattended-ready later.** Skills may ask the user questions. But each stage reads its input from GitHub (the issue, the PR and its comments), not from earlier chat, and writes every decision that matters into the issue, spec or PR. Never let a decision live only in the conversation.
- **No secrets in this repo.** It's public. Tokens and keys live in each project's secrets. No real repo names, tokens or internal URLs in examples or fixtures.
- **Every skill runs preflight first.** Use `scripts/preflight.sh` with the checks listed in `skills/preflight/SKILL.md`; on failure, stop and return the actionable message that skill describes. Never install anything silently.
- **Labels are always prefixed `takt:`.**
- **Idempotent setup.** Running any setup step twice must never break a repo.
- **Bump `version` in `plugin.json`** on any change to skills or scripts.

## Validate before committing

```bash
claude plugin validate .
```
