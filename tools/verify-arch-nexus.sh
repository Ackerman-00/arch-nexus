#!/usr/bin/env bash
set -euo pipefail
RUN_ID="${RUN_ID:-}"
RELAY=".opencode-relay.md"
echo "----- VERIFICATION REPORT -----"
[[ -f "$RELAY" ]] || { echo "FAIL: missing relay file"; exit 1; }
[[ -n "$RUN_ID" ]] || { echo "FAIL: RUN_ID not set"; exit 1; }
grep -qx "run_id: $RUN_ID" "$RELAY" || { echo "FAIL: relay run_id mismatch"; exit 1; }
grep -qix "status: complete" "$RELAY" || { echo "FAIL: relay status not complete"; exit 1; }
grep -qx "verified: bash tools/build-all.sh" "$RELAY" || { echo "FAIL: relay has no verified build line"; exit 1; }
echo "PASS: relay run_id, status and verified line"
bash tools/check-skills.sh

# The AGENTS.md news feed must not 404 (2026-10-27); other errors only warn.
feed=$(grep -rhoE 'https://archlinux\.org/[a-z/-]*news[a-z/]*' AGENTS.md | head -n 1)
[ -n "$feed" ] || { echo "FAIL: AGENTS.md names no archlinux.org news feed"; exit 1; }
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$feed" 2>/dev/null || echo 000)
if [ "$code" = "404" ]; then
  echo "FAIL: $feed returns 404"
  exit 1
fi
echo "OK   news feed $feed (HTTP $code)"
