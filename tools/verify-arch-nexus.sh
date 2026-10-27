#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
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

# The CI prompt lives in a file this step cannot push to (no workflows scope); a dead URL there is a warning.
for feed in $(grep -rhoE 'https://archlinux\.org/[a-z/-]*news[a-z/]*' .github/workflows/*.yml 2>/dev/null | sort -u || true); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$feed" 2>/dev/null || echo 000)
  if [ "$code" = "404" ]; then
    echo "WARN: workflow URL $feed returns 404 - the feed in AGENTS.md is the one that works"
  else
    echo "OK   workflow URL $feed (HTTP $code)"
  fi
done

# namcap: bare 'custom' is not SPDX, msg/error are makepkg internals (2026-10-27).
if grep -HE "^license=\(.*'custom'[,)]" */PKGBUILD; then
  echo "FAIL: bare 'custom' license is not an SPDX identifier (use LicenseRef-*)"
  exit 1
fi
if grep -HnE "^[[:space:]]*(error|warning|msg|msg2|plain)[[:space:]]" */PKGBUILD; then
  echo "FAIL: PKGBUILD calls an internal makepkg message helper"
  exit 1
fi
echo "OK   PKGBUILD license ids and message helpers"
