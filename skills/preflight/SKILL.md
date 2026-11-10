---
name: preflight
description: Shared prerequisite check used by every Takt laptop skill before it does any work. Also use when the user runs /takt:preflight to check whether their machine and the current repo are ready for Takt.
---

# Takt preflight

Run the preflight script with the checks the calling skill needs:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh" <check> [<check> ...]
```

If the user ran `/takt:preflight` directly, run every check:
`node openspec gh git github-remote openspec-init takt-init`.

If the repo has a Takt config that pins an OpenSpec version, pass it as
`TAKT_OPENSPEC_VERSION=<x.y.z>` in front of the command.

## Reading the result

Each line is pipe-separated:
- `OK|<check>|<detail>`
- `FAIL|<check>|<problem>|<why Takt needs it>|<fix>`
- last line: `SUMMARY|PASS|…` or `SUMMARY|FAIL|…`

## When everything passes

Say nothing about preflight unless the user ran `/takt:preflight` directly (then show the OK lines as a short checklist). Continue with the calling skill.

## When anything fails

Stop. Do not start the calling skill's work, and do not try to work around a missing tool.

Reply with, in this order:

1. One sentence: what you were about to do and that it can't start yet. For example: "I can't start `/takt:explore` yet: 2 things are missing on this machine."
2. One block per failed check, in the order the script printed them:
   - **What's missing**: the `<problem>`
   - **Why Takt needs it**: the `<why>`
   - **Fix**: the `<fix>`, with any command in a code block so it can be copied
3. The OK checks as one short line, so the user knows what's already fine (e.g. "Already fine: Node.js 22.11.0, git repo.")
4. The exact next step: "Once that's done, run `/takt:<skill>` again."

Never run an install command yourself from preflight. If the calling skill is `/takt:setup`, it may offer to run the fix commands, but only after the user says yes.

## Which checks each skill uses

| Skill | Checks |
|---|---|
| `takt:setup` | `node openspec gh git github-remote` |
| `takt:explore` | `node openspec git openspec-init` |
| `takt:backlog` | `gh git github-remote takt-init` |
| `takt:status` | `gh git github-remote takt-init` |
| `takt:upgrade` | `gh git github-remote takt-init` |
