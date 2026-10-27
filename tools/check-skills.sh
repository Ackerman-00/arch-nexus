#!/usr/bin/env bash
# check-skills.sh - the skill list in AGENTS.md and the CI prompt must match .opencode/skills.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

listed=$(python3 - <<'PY'
import re

ids = set()
for path in ("AGENTS.md", ".github/workflows/opencode-schedule.yml"):
    for line in open(path):
        if ".opencode/skills" in line and "skills" in line:
            ids.update(re.findall(r"`([a-z0-9]+(?:-[a-z0-9]+)+)`", line))
print("\n".join(sorted(ids)))
PY
) || exit 1

fail=0
for id in $listed; do
  [ -f ".opencode/skills/$id/SKILL.md" ] || {
    echo "FAIL listed but missing: .opencode/skills/$id/SKILL.md"
    fail=1
  }
done
for dir in .opencode/skills/*/; do
  id=$(basename "$dir")
  printf '%s\n' "$listed" | grep -qxF -- "$id" || {
    echo "FAIL present but unlisted: $id"
    fail=1
  }
done
[ "$fail" -eq 0 ] && echo "OK   skill list matches .opencode/skills"
exit "$fail"
