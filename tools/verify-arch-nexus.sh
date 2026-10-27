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
