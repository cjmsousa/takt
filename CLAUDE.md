# Takt

Takt is a personal software factory: a Claude Code plugin plus a reusable GitHub workflow that turns GitHub issues into OpenSpec specs and then code, headless.

**Read `docs/design.md` before any work in this repo.** It is the source of truth for the lifecycle, labels, skills and architecture. If a change you're making contradicts it, stop and say so; update the design doc first, then the code.

## Repo layout

- `.claude-plugin/plugin.json` — plugin manifest (name `takt`, so skills are invoked as `/takt:<skill>`)
- `.claude-plugin/marketplace.json` — this repo is also its own marketplace; the plugin source is the repo root
- `skills/<name>/SKILL.md` — one folder per skill
- `scripts/` — shell helpers skills call via `${CLAUDE_PLUGIN_ROOT}/scripts/…` (e.g. `preflight.sh`)
- `.github/workflows/factory.yml` — the reusable workflow projects call (added in build step 3)
- `docs/design.md` — the design

Only manifests go inside `.claude-plugin/`. Skills, agents, commands and hooks live at the repo root.

## Rules

- **Depend on OpenSpec, never copy it.** Takt skills call OpenSpec's CLI and commands and add conventions on top. Don't vendor OpenSpec prompts or skills into this repo.
- **Headless-safe skills.** `takt:propose` and `takt:code` run in GitHub Actions with no human present. They must never ask questions interactively; ambiguity goes into an "Open questions" section and an issue comment.
- **No secrets in this repo.** It's public. Tokens and keys live in each project's secrets. No real repo names, tokens or internal URLs in examples or fixtures.
- **Every laptop skill runs preflight first.** Use `scripts/preflight.sh` with the checks listed in `skills/preflight/SKILL.md`; on failure, stop and return the actionable message that skill describes. Never install anything silently.
- **Labels are always prefixed `takt:`.**
- **Idempotent setup.** Running any setup step twice must never break a repo.
- **Bump `version` in `plugin.json`** on any change to skills that projects depend on, and tag releases (`v1`, `v1.1.0`, …) for the reusable workflow.

## Validate before committing

```bash
claude plugin validate .
```
