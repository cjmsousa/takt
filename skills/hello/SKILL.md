---
name: hello
description: Smoke test for the Takt plugin. Use only when the user runs /takt:hello to confirm Takt is installed.
---

Confirm that the Takt plugin is installed and loaded.

1. Reply with: "Takt is installed. Plugin root: ${CLAUDE_PLUGIN_ROOT}"
2. Run the machine-level preflight, following the `takt:preflight` skill:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh" node openspec gh
   ```

3. If every check passes, show the OK lines as a short checklist and say: "This machine is ready for Takt."
4. If any check fails, present the failures exactly as the `takt:preflight` skill describes, and end with: "Once that's done, run `/takt:hello` again."

Do nothing else.
