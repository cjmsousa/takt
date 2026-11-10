# Takt

A personal software factory: write a change, label it, and Takt specs and builds it with [OpenSpec](https://github.com/Fission-AI/OpenSpec) and Claude Code, all on GitHub Actions.

> Status: early. Building in public, step by step. See [`docs/design.md`](docs/design.md).

## How it works

1. **`/takt:explore`** an idea with Claude Code in your project.
2. **`/takt:backlog`** turns the session into a GitHub issue (the backlog).
3. Add the **`takt:propose`** label → the factory proposes a spec as a PR.
4. **Merge the spec PR** → the factory implements it and opens a code PR.
5. **Merge the code PR** → done; the living specs are updated.

You make three decisions: start it, approve the spec, accept the code. Everything else runs headless.

## Install (local)

```bash
claude plugin marketplace add <owner>/takt
claude plugin install takt@takt
```

Then, in any Claude Code session: `/takt:hello`.

## License

MIT
