#!/usr/bin/env bash
# Takt labels: create or update every takt: label in the current repo.
#
# Usage:   labels.sh
# Safe to run any number of times (gh label create --force updates in place).
#
# Output: one line per label, pipe-separated:
#   OK|<label>|created
#   OK|<label>|already there
#   FAIL|<label>|<error>
# Exit code: 0 if every label is in place, 1 otherwise.

set -u

# name|color|description  (keep in sync with the Labels table in docs/design.md)
LABELS="
takt:inbox|BFD4F2|Raw input, not yet a proper change
takt:proposing|FBCA04|Propose in progress
takt:proposed|0E8A16|Spec PR open, awaiting review
takt:building|FBCA04|Code in progress
takt:built|0E8A16|Code PR open, awaiting review
takt:failed|D93F0B|A stage stopped without finishing; see the issue comment
takt:propose|5319E7|Reserved: will start propose in unattended mode
"

existing="$(gh label list --limit 500 --json name --jq '.[].name' 2>/dev/null || true)"
failed=0

while IFS='|' read -r name color desc; do
  [ -z "$name" ] && continue
  if err="$(gh label create "$name" --color "$color" --description "$desc" --force 2>&1)"; then
    if printf '%s\n' "$existing" | grep -qx "$name"; then
      echo "OK|$name|already there"
    else
      echo "OK|$name|created"
    fi
  else
    failed=$((failed + 1))
    echo "FAIL|$name|$(printf '%s' "$err" | tr '\n' ' ')"
  fi
done <<EOF
$LABELS
EOF

[ "$failed" -eq 0 ]
