# Takt — Design

Takt is a personal software factory for solo projects. A human defines *what* to build and approves at gates; the factory writes the spec and the code, headless, on GitHub Actions.

Built on:
- **OpenSpec** — the spec engine (specs, changes, propose/apply/archive)
- **Claude Code** — the worker, interactive on the laptop and headless in CI
- **GitHub** — issues, labels, PRs, Actions (the conveyor belt and the record)

## Principles

1. **Never interactive in production.** The only interactive work is thinking: exploring an idea and writing a change. Everything after the issue runs headless.
2. **Humans decide, the factory reports.** Humans trigger each stage. The factory only moves labels to show state.
3. **Specs live in the repo.** `openspec/specs/` is the living truth; `openspec/changes/<id>-<slug>/` holds proposed changes until archived.
4. **Depend on OpenSpec, don't copy it.** Takt skills orchestrate OpenSpec's own commands and add factory conventions on top.
5. **Fix the factory, not just the product.** When something goes wrong, ask what rule, hook or test would have caught it, and add it to Takt.
6. **No ambiguity guessing.** In headless mode, Claude never fills gaps with assumptions. It writes an "Open questions" section and surfaces it for review.

## Architecture

### Three layers

| Where | What |
|---|---|
| **Your machine** | OpenSpec CLI (npm), Takt plugin installed globally (user scope), `gh` authenticated |
| **takt repo** | Takt skills (Claude Code plugin + its own marketplace) and the reusable GitHub workflow `factory.yml`. No copy of OpenSpec. |
| **Each project repo** | `openspec/` (specs + changes), OpenSpec's commands (from `openspec init`), a thin caller workflow, a small Takt config file |

### How workflows run

- GitHub only triggers workflows in the repo where the event happens, so each project has one thin caller workflow that declares *when* to run.
- The caller uses a **reusable workflow** from the takt repo (`uses: <owner>/takt/.github/workflows/factory.yml@vN`), which declares *what* to run.
- The reusable workflow **executes inside the project repo**, with the project's token, secrets and code. The takt repo gets no access to any project. Projects trust Takt's code, so they pin it to a version tag.

### Factory identity

The default `GITHUB_TOKEN` does not trigger other workflows (CI won't run on PRs it opens; labels it adds won't wake the factory). Takt uses its own **GitHub App** identity, installed on *selected repositories only*.

### Versioning

- Projects pin Takt with `@vN`. Upgrading is deliberate (`takt:upgrade`).
- The OpenSpec version is pinned in the project's Takt config, so local and CI runs agree on formats.

## Labels

All labels are prefixed `takt:` to avoid colliding with labels existing repos already use.

| Label | Meaning | Set by |
|---|---|---|
| *(none)* | Backlog: a well-formed change, not started | `takt:backlog` |
| `takt:inbox` | Raw input (e.g. customer bug), not yet a proper change | intake |
| `takt:propose` | "Propose this" | **human only** |
| `takt:proposing` | Propose running | factory |
| `takt:proposed` | Spec PR open, awaiting review | factory |
| `takt:building` | Apply running | factory |
| `takt:built` | Code PR open, awaiting review | factory |
| `takt:failed` | A run failed; log linked in an issue comment | factory |

The `takt:propose` label triggers the skill of the same name. It is honored only when added by the repo owner. This is both control and a security boundary (no one else can make the factory run on their text).

## Lifecycle

| # | Trigger | Who | What runs | Label after |
|---|---|---|---|---|
| 0 | `takt:setup` in a repo (once) | human | Onboards the repo | — |
| 1 | Run `takt:explore` | human | Discuss the idea (local, interactive; runs OpenSpec's explore) | — |
| 2 | Run `takt:backlog` | human | Distills the session into a change and creates the issue | *(none)*: backlog |
| 3 | Add the `takt:propose` label | **human** | Action starts the `takt:propose` skill | `takt:proposing` |
| 4 | Propose finishes | factory | Spec PR opened | `takt:proposed` |
| 5 | Comment `@claude …` on the spec PR | human | Claude revises the spec on the same PR | `takt:proposed` |
| 6 | **Merge the spec PR** | **human** | Action starts the `takt:code` skill | `takt:building` |
| 7 | Coding finishes | factory | Implemented + archived, code PR opened; CI runs | `takt:built` |
| 8 | Comment `@claude …` on the code PR | human | Claude fixes on the same PR | `takt:built` |
| 9 | **Merge the code PR** | **human** | Issue closed, living specs updated | closed |

Human decisions: rows 3, 6, 9 (start it, approve the spec, accept the code). Rows 5 and 8 are optional revision loops.

### Exits

- **Reject a spec:** close the spec PR → labels removed, issue returns to backlog.
- **Reject the code:** close the code PR → issue returns to `takt:proposed`; the approved spec stays on `main`, so coding can be re-triggered without re-specifying.
- **Failure:** the run sets `takt:failed` and comments the log link on the issue. Retry by re-adding the `takt:propose` label (or re-running `takt:code`).

### Notes

- No queue or WIP limit: what runs is controlled by labels and by the human.
- If two changes build in parallel, both code PRs start from the same `main`; after merging one, comment `@claude rebase onto main` on the other.

## Naming and traceability

One ID follows a change everywhere: issue `#42` → change folder `openspec/changes/42-dark-theme/` → branches and both PRs reference `#42`.

## The change (issue body)

A change is the output of an explore session. It must be **self-contained**: the headless run never sees the explore conversation.

Sections:
- **Problem / why** — what's wrong or missing today
- **Desired outcome** — what's true when this is done
- **Scope** — in, and explicitly out
- **Decisions made** — including rejected alternatives and why
- **Constraints** — tech, data, performance, non-negotiables
- **Examples** — concrete "when X, then Y" cases (they become spec scenarios, then tests)
- **Open questions** — anything deliberately left for propose to resolve or flag

## Skills

| Skill | Runs | Purpose |
|---|---|---|
| `takt:setup` | laptop | Onboard a new or existing repo |
| `takt:explore` | laptop | Discuss an idea; runs OpenSpec's explore with Takt context |
| `takt:backlog` | laptop | Add the explored change to the backlog (creates the issue) |
| `takt:status` | laptop | Show the factory floor (issues by label) |
| `takt:upgrade` | laptop | Bump a repo to a newer Takt version |
| `takt:propose` | Actions | Issue → spec PR (wraps OpenSpec propose) |
| `takt:code` | Actions | Approved change → code PR, plus archive (wraps OpenSpec apply + archive) |

Laptop skills wrap OpenSpec where one exists (`takt:explore` → OpenSpec explore). Actions skills wrap OpenSpec propose, apply and archive.

### `takt:setup` (onboarding a repo)

Idempotent; delivers its changes as a PR ("takt: onboard").
1. Check prerequisites: `gh auth status`, Node, OpenSpec at the pinned version
2. `openspec init` for Claude Code (non-interactive), or `openspec update` if `openspec/` exists
3. Create the `takt:` labels
4. Add the thin caller workflow (pinned to a Takt version) and the change issue template
5. Detect test/lint/build commands and write the Takt config; ask only where detection fails
6. Set the Claude token secret (prompted, piped straight to `gh secret set`, never written to disk); check the Takt GitHub App and Claude GitHub app are installed on this repo
7. Branch protection on `main`
8. Readiness check: no usable tests/CI → file "establish a test harness" as the first change

### Existing (brownfield) repos

- Don't spec the whole system upfront. Specs accumulate change by change.
- Optionally run a one-off "baseline" change that reverse-engineers specs for the area about to be touched.
- Mechanical verification is the factory's safety: no tests means the first change is a test harness.

## Verification

- Every spec scenario (Given/When/Then) maps to a test.
- CI runs tests, lint, typecheck and `openspec validate`.
- A reviewer subagent checks the diff against the spec.
- Claude may not declare `takt:code` done while tests are red.

## Build order

1. Design doc + plugin skeleton (this repo, installable, `takt:hello`)
2. Sandbox repo (`takt-sandbox`) set up manually; record every step
3. Label → spec PR: `factory.yml` (propose job), caller workflow, `takt:propose`, GitHub App identity
4. `takt:explore` and `takt:backlog`
5. Code + archive: spec PR merge → code PR
6. Revision loops (`@claude`) and `takt:failed`
7. `takt:setup` (codify the manual sandbox notes)
8. `takt:status`, `takt:upgrade`
