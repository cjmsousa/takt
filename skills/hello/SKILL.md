---
name: hello
description: Smoke test for the Takt plugin. Use only when the user runs /takt:hello to confirm Takt is installed.
---

Confirm that the Takt plugin is installed and loaded.

Reply with exactly:

"Takt is installed. Plugin root: ${CLAUDE_PLUGIN_ROOT}"

Then, in one line each, report:
- whether the `openspec` CLI is available (run `openspec --version`)
- whether `gh` is authenticated (run `gh auth status`)

Do nothing else.
