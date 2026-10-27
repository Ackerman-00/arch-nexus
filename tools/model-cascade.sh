#!/usr/bin/env bash
set -uo pipefail

CATALOG="${OC_MODELS_URL:-https://opencode.ai/inference/v1/models}"
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RANK_FILE="${OC_MODEL_RANK:-$HERE/model-rank.txt}"
EXCLUDE=" glm-5.3-flash-free jev-1.13-free "

live=$(curl -sS --max-time 30 "$CATALOG" 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin).get("data", [])
except Exception:
    sys.exit(0)
for m in data:
    i = m.get("id", "")
    if i and i != "test" and (i.endswith("-free") or i == "big-pickle"):
        print(i)
' 2>/dev/null) || live=""

rank=()
if [ -f "$RANK_FILE" ]; then
  while IFS= read -r id; do
    id=${id%%#*}
    id=$(printf '%s' "$id" | tr -d '[:space:]')
    [ -n "$id" ] && rank+=("$id")
  done < "$RANK_FILE"
fi

is_live() { printf '%s\n' "$live" | grep -qxF -- "$1"; }
is_ranked() {
  local r
  for r in ${rank+"${rank[@]}"}; do
    [ "$r" = "$1" ] && return 0
  done
  return 1
}
excluded() { case "$EXCLUDE" in *" $1 "*) return 0 ;; esac; return 1; }

chain=()
for id in ${rank+"${rank[@]}"}; do
  is_live "$id" && ! excluded "$id" && chain+=("$id")
done
new=()
retired=()
if [ -n "$live" ]; then
  for id in ${rank+"${rank[@]}"}; do
    is_live "$id" && continue
    excluded "$id" && continue
    retired+=("$id")
  done
fi
for id in $live; do
  excluded "$id" && continue
  is_ranked "$id" && continue
  chain+=("$id")
  new+=("$id")
done

if [ "${#chain[@]}" -eq 0 ]; then
  echo "model-cascade: catalog unreachable, using rank file order" >&2
  for id in ${rank+"${rank[@]}"}; do
    excluded "$id" || chain+=("$id")
  done
fi
if [ "${#new[@]}" -gt 0 ]; then
  echo "NEW FREE MODELS (not ranked yet - research and rank them): ${new[*]}" >&2
fi
if [ "${#retired[@]}" -gt 0 ]; then
  echo "RETIRED FREE MODELS (drop them from tools/model-rank.txt): ${retired[*]}" >&2
fi

for id in "${chain[@]}"; do printf 'opencode/%s\n' "$id"; done
