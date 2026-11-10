# Takt — Design

Takt is a personal software factory for solo projects. A human defines *what* to build and approves at gates; Takt writes the spec and the code.

**For now, everything runs interactively in Claude Code on the laptop**, with the human present. Running unattended on GitHub Actions comes later (see [Later: unattended mode](#later-unattended-mode)). The records Takt keeps (issues, labels, branches, PRs) are shaped so that switching to unattended only changes *what starts each step*, not what the step does.

Built on:
- **OpenSpec** — the spec engine (specs, changes, propose/apply/archive)
- **Claude Code** — the worker, in an interactive session on the laptop
- **GitHub** — issues, labels and PRs (the conveyor belt and the record)

## Principles

1. **Interactive first, unattended later.** Every stage runs in a Claude Code session with the human present. Each stage's input and output live on GitHub, never only in the chat, so a later unattended mode can run the same stages.
2. **Humans decide, Takt reports.** The human starts each stage and approves at the gates. Labels only show state.
3. **Specs live in the repo.** `openspec/specs/` is the living truth; `openspec/changes/<id>-<slug>/` holds proposed changes until archived.
4. **Depend on OpenSpec, don't copy it.** Takt skills orchestrate OpenSpec's own commands and add conventions on top.
5. **Fix the factory, not just the product.** When something goes wrong, ask what rule, hook or test would have caught it, and add it to Takt.
6. **No silent assumptions.** Claude never fills gaps with guesses. It asks the human, and records the answer in the issue, spec or PR. Anything still unresolved goes in an "Open questions" section.

## Architecture

### Where things live

| Where | What |
|---|---|
| **Your machine** | OpenSpec CLI (npm), Takt plugin installed globally (user scope), `gh` signed in |
| **takt repo** | Takt skills and scripts (Claude Code plugin + its own marketplace). No copy of OpenSpec. |
| **Each project repo** | `openspec/` (specs + changes), OpenSpec's skills and commands (from `openspec init`), `.takt.yml`, the `takt:` labels |

### The Takt config (`.takt.yml`)

One small file at the project root, written by `takt:setup` and editable by hand. Running setup again keeps your edits. For now it holds only the project's **checks**: the commands that prove a change works (tests, lint, typecheck, build).

```yaml
checks:
  - name: web
    paths: [apps/web/**]
    run: pnpm --filter web test
  - name: web-lint
    paths: [apps/web/**]
    run: pnpm --filter web lint
  - name: api
    paths: [services/api/**]
    run: cd services/api && pytest
```

- **Scoped by paths,** so a monorepo with several languages and test suites works. `takt:code` runs every check whose `paths` overlap the files the change touches. A simple repo has one or a few checks with `paths: ["**"]`.
- **Detected, then confirmed.** `takt:setup` proposes checks from what it finds (`package.json` scripts, `pyproject.toml`, `go.mod`, `Makefile`, …) and asks you only where detection fails or is ambiguous.
- **Read by the skills,** not by `preflight.sh`, so the shell scripts never parse YAML.
- **No OpenSpec version in it.** See below.

Spec *rules* (e.g. "every scenario maps to a test") don't go here; they go in `openspec/config.yaml` (`rules`, `operations`), which OpenSpec reads itself. Takt doesn't add its own keys to that file, since it belongs to OpenSpec.

### Versioning

- The plugin's `version` in `plugin.json` is bumped on every skill or script change; you update with `claude plugin marketplace update takt` and `claude plugin update takt@takt`.
- **OpenSpec has no Takt pin.** OpenSpec stamps every skill it installs with the CLI version that generated it (`generatedBy` in `.claude/skills/openspec-*/SKILL.md`), and `openspec update` regenerates them for the installed CLI. Preflight's `openspec-init` check compares the two: CLI newer → run `openspec update` and commit; CLI older → install the stamped version.

## Labels

All labels are prefixed `takt:` to avoid colliding with labels existing repos already use. Skills set them; they show state, they don't trigger anything (yet).

| Label | Meaning | Set by |
|---|---|---|
| *(none)* | Backlog: a well-formed change, not started | `takt:backlog` |
| `takt:inbox` | Raw input (e.g. customer bug), not yet a proper change | intake |
| `takt:proposing` | Propose in progress | `takt:propose` |
| `takt:proposed` | Spec PR open, awaiting review | `takt:propose` |
| `takt:building` | Code in progress | `takt:code` |
| `takt:built` | Code PR open, awaiting review | `takt:code` |
| `takt:failed` | A stage stopped without finishing; reason in an issue comment | any stage |

`takt:propose` is reserved for unattended mode, where adding it will start the stage.

## Lifecycle

| # | You run / do | What happens | Label after |
|---|---|---|---|
| 0 | `/takt:setup` (once per repo) | Onboards the repo | — |
| 1 | `/takt:explore` | Discuss the idea (runs OpenSpec's explore) | — |
| 2 | `/takt:backlog` | Distills the session into a change and creates the issue | *(none)*: backlog |
| 3 | `/takt:propose 42` | Writes the OpenSpec change for issue #42, opens the spec PR | `takt:proposed` |
| 4 | Review the spec PR; run `/takt:propose 42` again to revise | Revises the spec on the same PR, using your PR comments | `takt:proposed` |
| 5 | **Merge the spec PR** | Approves the spec | `takt:proposed` |
| 6 | `/takt:code 42` | Implements, verifies, archives the change, opens the code PR | `takt:built` |
| 7 | Review the code PR; run `/takt:code 42` again to revise | Fixes on the same PR, using your PR comments | `takt:built` |
| 8 | **Merge the code PR** | Issue closed, living specs updated | closed |

Human decisions: rows 3, 5, 6, 8 (start it, approve the spec, start the build, accept the code). Rows 4 and 7 are optional revision loops.

Guards:
- `takt:code` refuses to start until the spec PR for that issue is merged.
- Running a stage again on the same issue always continues its existing branch and PR; it never opens a second one.

### Exits

- **Reject a spec:** close the spec PR → labels removed, issue returns to backlog.
- **Reject the code:** close the code PR → issue returns to `takt:proposed`; the approved spec stays on `main`, so `/takt:code 42` can run again without re-specifying.
- **Stopped:** if a stage can't finish (e.g. tests stay red), it sets `takt:failed` and comments why on the issue. Running the stage again resumes it.

### Notes

- No queue or WIP limit: the human decides what runs.
- If two changes build in parallel, both code PRs start from the same `main`; after merging one, rebase the other (`/takt:code 43` again).

## Naming and traceability

One ID follows a change everywhere: issue `#42` → change folder `openspec/changes/42-dark-theme/` → branches `takt/42-spec` and `takt/42-code` → both PRs reference `#42`.

## The change (issue body)

A change is the output of an explore session. It must be **self-contained**: the propose stage reads only the issue, not the explore conversation (which may be a different session, and in unattended mode won't exist at all).

Sections:
- **Problem / why** — what's wrong or missing today
- **Desired outcome** — what's true when this is done
- **Scope** — in, and explicitly out
- **Decisions made** — including rejected alternatives and why
- **Constraints** — tech, data, performance, non-negotiables
- **Examples** — concrete "when X, then Y" cases (they become spec scenarios, then tests)
- **Open questions** — anything deliberately left for propose to resolve or flag

## Skills

All skills run in Claude Code on the laptop.

| Skill | Purpose |
|---|---|
| `takt:setup` | Onboard a new or existing repo |
| `takt:preflight` | Check machine and repo prerequisites; used by every skill |
| `takt:explore` | Discuss an idea; runs OpenSpec's explore with Takt context |
| `takt:backlog` | Add the explored change to the backlog (creates the issue) |
| `takt:propose <issue>` | Issue → spec PR (wraps OpenSpec propose) |
| `takt:code <issue>` | Merged spec → code PR, plus archive (wraps OpenSpec apply + archive) |
| `takt:status` | Show the factory floor (issues by label) |

Each skill wraps the matching OpenSpec skill where one exists, and adds the Takt conventions: the issue as input, the naming, the labels, branches and PRs, and verification. OpenSpec's skills may ask questions; with the human present, they are answered in the session, and the answers that matter are written into the spec or PR.

## Prerequisites and preflight

Plugins can't install npm packages, so a laptop can have Takt without OpenSpec, Node or a signed-in `gh`. Every skill therefore starts with a **preflight** and stops before doing any work if something is missing.

- **One script, shared:** `scripts/preflight.sh <check>...` runs every requested check (never stopping at the first), and prints `OK|…` or `FAIL|<problem>|<why>|<fix>` per check plus a summary line. Exit 0 on pass, 1 on any failure. Portable to macOS's default bash.
- **Checks:** `node` (≥ 20.19.0), `openspec` (installed), `gh` (installed and signed in), `git` (inside a repo), `github-remote` (origin is on GitHub), `openspec-init` (`openspec/` exists, and the CLI matches the repo's `generatedBy` stamp), `takt-init` (Takt labels exist).
- **A useful failure, always:** the skill replies with what it was about to do, then for each failure *what's missing*, *why Takt needs it* and *the exact fix command*, then what's already fine, then "run `/takt:<skill>` again". Fixes are OS-aware (Homebrew on macOS when available).
- **No silent installs:** preflight never installs anything. Only `takt:setup` may offer to run a fix command, and only after the user says yes.
- **`/takt:preflight`** runs every check on demand.

| Skill | Checks |
|---|---|
| `takt:setup` | `node openspec gh git github-remote` |
| `takt:explore` | `node openspec git openspec-init` |
| `takt:backlog` | `gh git github-remote takt-init` |
| `takt:propose` | `node openspec gh git github-remote openspec-init takt-init` |
| `takt:code` | `node openspec gh git github-remote openspec-init takt-init` |
| `takt:status` | `gh git github-remote takt-init` |

### `takt:setup` (onboarding a repo)

Idempotent: running it again on an onboarded repo changes nothing, and on a half-onboarded repo finishes the job. File changes arrive as one PR ("takt: onboard") on branch `takt/onboard`; labels are created directly on GitHub (they aren't files).
1. Preflight (`node openspec gh git github-remote`); offer to run the fix commands, only with the user's yes
2. Start clean: working tree must be clean; branch `takt/onboard` from the up-to-date default branch
3. `openspec init --tools claude --no-animation`, or `openspec update` if `openspec/` exists
4. Create the `takt:` labels (`scripts/labels.sh`, safe to rerun)
5. Add the change issue template (`templates/takt-change.md` → `.github/ISSUE_TEMPLATE/takt-change.md`); never overwrite an edited one without asking
6. Detect the project's checks (tests, lint, typecheck, build, per path) and write `.takt.yml`; existing CI workflows are the best source. Confirm with the user; keep an existing `.takt.yml` and only offer additions
7. If anything changed: commit, push, open or update the "takt: onboard" PR. If nothing changed: say the repo is already onboarded
8. Readiness check: no check that runs tests → offer to file "establish a test harness" as the first change

Branch protection is left to the user for now.

### Existing (brownfield) repos

- Don't spec the whole system upfront. Specs accumulate change by change.
- Optionally run a one-off "baseline" change that reverse-engineers specs for the area about to be touched.
- Mechanical verification is the factory's safety: no tests means the first change is a test harness.

## Verification

- Every spec scenario (Given/When/Then) maps to a test.
- **While working,** `takt:code` runs the `.takt.yml` checks whose paths match the changed files, plus `openspec validate`, until they pass.
- **Before calling it done,** if the repo has CI, `takt:code` waits for the PR's checks (`gh pr checks --watch`); CI is the final gate. Without CI, the local checks are the gate. A CI failure the local checks missed means `.takt.yml` needs a check added (fix the factory).
- A reviewer subagent checks the diff against the spec.
- Claude may not declare `takt:code` done while tests are red.

## Build order

1. Design doc + plugin skeleton (this repo, installable, `takt:hello`) — plus the shared preflight ✅
2. `takt:setup`, iterated against a throwaway repo until it works (rerunning it is the test)
3. `takt:explore` and `takt:backlog`
4. `takt:propose`: issue → spec PR, including revision
5. `takt:code`: merged spec → code PR + archive, including revision
6. `takt:status`
7. Later: unattended mode

## Later: unattended mode

Not built yet. Kept here so today's choices don't block it.

- **Trigger:** adding the `takt:propose` label (repo owner only) and merging a spec PR start the stages on GitHub Actions instead of the human running them.
- **Workflows:** each project has a thin caller workflow declaring *when* to run; it uses a reusable workflow from the takt repo (`uses: <owner>/takt/.github/workflows/factory.yml@vN`) declaring *what* to run. The reusable workflow runs inside the project repo, with the project's token and secrets; the takt repo gets no access to any project. Projects pin it to a version tag (`takt:upgrade` bumps it).
- **Identity:** the default `GITHUB_TOKEN` doesn't trigger other workflows, so Takt would use its own GitHub App, installed on selected repositories only.
- **No one to ask:** OpenSpec's skills ask for confirmation (e.g. archiving with incomplete tasks). Unattended, the Takt skills must pass the change name explicitly, answer those confirmations with fixed rules (incomplete tasks → `takt:failed`, ambiguity → "Open questions"), and the workflow must check the result mechanically (change folder exists, `openspec validate` passes, tests green) so a run that stopped to ask a question shows up as a failure instead of a silent success.
- **Revision loops:** `@claude` comments on the spec or code PR.
