# Takt

A personal software factory: explore a change, and Takt specs and builds it with [OpenSpec](https://github.com/Fission-AI/OpenSpec) and Claude Code, from GitHub issue to merged PR.

> Status: early. Building in public, step by step. See [`docs/design.md`](docs/design.md).

## How it works

1. **`/takt:explore`** an idea with Claude Code in your project.
2. **`/takt:backlog`** turns the session into a GitHub issue (the backlog).
3. **`/takt:propose 42`** writes the spec for issue #42 and opens a spec PR.
4. **Merge the spec PR**, then **`/takt:code 42`** implements it and opens a code PR.
5. **Merge the code PR** → done; the living specs are updated.

Every stage runs in Claude Code, with you in the session. You decide when each stage starts and approve at the two merges. Running unattended on GitHub Actions is planned for later.

## Install (local)

```bash
claude plugin marketplace add <owner>/takt
claude plugin install takt@takt
```

Then, in any Claude Code session: `/takt:hello`.

## License

MIT
