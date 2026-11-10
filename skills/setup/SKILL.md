---
name: setup
description: Onboard the current repo to Takt (OpenSpec, takt labels, change issue template, .takt.yml checks), delivered as a "takt: onboard" PR. Safe to run again; it only fills in what's missing. Use when the user runs /takt:setup or asks to set up or onboard a repo for Takt.
---

# Takt setup

Onboard the repo in the current folder. Follow the steps in order. Running this again must never break anything: each step checks what's already there and only adds what's missing.

Keep the user informed with one short line per step ("OpenSpec: already set up, updated skills." / "Labels: 7 created."). Ask only where this skill says to ask.

## 1. Preflight

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh" node openspec gh git github-remote
```

Follow the `takt:preflight` skill. On failure, present the failures as it describes, then offer to run the fix commands for the user. Run them only after the user says yes; never run `gh auth login` yourself (it's interactive: tell the user to type `! gh auth login`). Re-run preflight after fixing. Stop if it still fails.

## 2. Start clean

- Run `git status --porcelain`. If anything is uncommitted, stop and tell the user to commit or stash first. Don't stash for them.
- Find the default branch: `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`.
- `git fetch origin`, then `git switch -C takt/onboard origin/<default>`. This always starts from the latest default branch, so a rerun redoes the steps instead of piling commits on an old branch.

## 3. OpenSpec

- No `openspec/` folder: `openspec init --tools claude --no-animation`
- `openspec/` exists: `openspec update`

Report what it created or changed (`git status --short`). If it touched files the repo already had outside `openspec/` and `.claude/skills/openspec-*` / `.claude/commands/opsx/` (for example an existing `CLAUDE.md` or `AGENTS.md`), show the user the diff and ask whether to keep it.

## 4. Labels

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/labels.sh"
```

These go straight to GitHub, not into the PR. Report how many were created and how many were already there. On any `FAIL` line, show it and continue with the other steps; mention it again in the final summary.

## 5. Change issue template

Target: `.github/ISSUE_TEMPLATE/takt-change.md`. Source: `${CLAUDE_PLUGIN_ROOT}/templates/takt-change.md`.

- Missing: copy it.
- Identical: nothing to do.
- Different: the user may have edited it. Show the diff and ask whether to replace it. Default is keep.

## 6. Checks (`.takt.yml`)

`.takt.yml` lists the commands that prove a change works, each scoped to paths:

```yaml
checks:
  - name: <short name>
    paths: [<glob>, ...]
    run: <command, run from the repo root>
```

**If `.takt.yml` exists:** keep it. Check it has a `checks` list where every entry has `name`, `paths` and `run`. Then detect (below) and, if you find checks it doesn't have, offer to add them. Never remove or rewrite the user's entries.

**If it doesn't exist:** detect, then propose.

**Detecting.** Look, in this order of trust:
1. CI workflows (`.github/workflows/*.yml`): the commands CI actually runs, and any `paths:` filters. Best source.
2. Task runners: `Makefile`, `justfile`, `Taskfile.yml`, `turbo.json`, `nx.json`.
3. Per-language manifests, at the root and in subfolders (monorepos): `package.json` scripts (`test`, `lint`, `typecheck`, `build`) and workspaces (`pnpm-workspace.yaml`, `package.json` `workspaces`); `pyproject.toml` / `pytest.ini` / `tox.ini`; `go.mod`; `Cargo.toml`; and so on. Pick the package manager from the lockfile.

One check per command per area. Scope `paths` to the area's folder; a single-package repo uses `["**"]`. Don't run any of the commands during setup.

**Proposing.** Show the proposed checks as a table (name, paths, command, where you found it) and ask the user to confirm, edit or remove any. Ask specifically where detection was unclear (e.g. two test commands, or a folder with code but no test command). Write the file only after the user confirms.

## 7. Commit and PR

- `git status --porcelain` empty: nothing changed. Delete the local branch (`git switch <default> && git branch -D takt/onboard`) and say: "This repo is already onboarded; nothing to change."
- Otherwise:
  - `git add -A && git commit -m "takt: onboard"` (one commit; list what's included in the body).
  - `git push --force-with-lease -u origin takt/onboard`. Force is expected: the branch is always rebuilt from the default branch (step 2).
  - If an open PR exists for `takt/onboard` (`gh pr list --head takt/onboard --state open`), it's now updated; otherwise `gh pr create --title "takt: onboard" --body <summary>`. The body lists each step's outcome and the checks table.
  - Don't merge it. Merging is the user's decision.

## 8. Readiness

If no check runs tests (only lint/build, or none), say so and offer to file the first change, "Establish a test harness", as an issue using the change template. Create it only after the user says yes.

## 9. Summary

End with:
- The PR link (or "already onboarded").
- One line per step: done / already there / skipped / failed.
- Next step: "Merge the PR, then run `/takt:preflight`. Everything should be green."
