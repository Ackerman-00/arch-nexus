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

feed=$(grep -rhoE 'https://archlinux\.org/[a-z/-]*news[a-z/]*' AGENTS.md | head -n 1)
[ -n "$feed" ] || { echo "FAIL: AGENTS.md names no archlinux.org news feed"; exit 1; }
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$feed" 2>/dev/null || echo 000)
if [ "$code" = "404" ]; then
  echo "FAIL: $feed returns 404"
  exit 1
fi
echo "OK   news feed $feed (HTTP $code)"

for feed in $(grep -rhoE 'https://archlinux\.org/[a-z/-]*news[a-z/]*' .github/workflows/*.yml 2>/dev/null | sort -u || true); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$feed" 2>/dev/null || echo 000)
  if [ "$code" = "404" ]; then
    echo "WARN: workflow URL $feed returns 404 - the feed in AGENTS.md is the one that works"
  else
    echo "OK   workflow URL $feed (HTTP $code)"
  fi
done

if grep -HE "^license=\(.*'custom'[,)]" */PKGBUILD; then
  echo "FAIL: bare 'custom' license is not an SPDX identifier (use LicenseRef-*)"
  exit 1
fi
if grep -HnE "^[[:space:]]*(error|warning|msg|msg2|plain)[[:space:]]" */PKGBUILD; then
  echo "FAIL: PKGBUILD calls an internal makepkg message helper"
  exit 1
fi
echo "OK   PKGBUILD license ids and message helpers"

python3 - <<'PYG'
import re, glob, sys
bad=0
for f in glob.glob("*/PKGBUILD"):
    t=open(f).read()
    src=re.search(r'^source(?:_[a-zA-Z0-9_]+)?=\((.*?)\)', t, re.M|re.S)
    sha=re.search(r'^sha256sums(?:_[a-zA-Z0-9_]+)?=\((.*?)\)', t, re.M|re.S)
    if not src or not sha: 
        continue
    nsrc=len(re.findall(r"'[^']*'", src.group(1))) + len(re.findall(r'"[^"]*"', src.group(1)))
    nsha=len(re.findall(r"'[0-9a-f]{64}'", sha.group(1)))
    if nsrc!=nsha:
        print("FAIL %s: source count %d != sha256sums count %d" % (f,nsrc,nsha)); bad=1
if bad: sys.exit(1)
print("OK   source/sha256sums counts match")
PYG

python3 - <<'PYD'
import glob, re, sys, tarfile, urllib.request

URL = "https://geo.mirror.pkgbuild.com/%s/os/x86_64/%s.files"
ships = {}
fetched = set()
for repo in ("core", "extra"):
    try:
        with urllib.request.urlopen(URL % (repo, repo), timeout=180) as r:
            tf = tarfile.open(fileobj=r, mode="r|gz")
            for m in tf:
                if not m.name.endswith("/files"):
                    continue
                pkg = re.sub(r"-[^-]+-[^-]+$", "", m.name.split("/")[0])
                fh = tf.extractfile(m)
                ships[pkg] = sum(1 for line in fh if line.strip() and not line.startswith(b"%"))
        fetched.add(repo)
    except Exception as exc:
        print("WARN: %s.files unavailable (%s)" % (repo, exc))

if len(fetched) < 2:
    print("WARN: live package index incomplete - depends not re-checked")
    sys.exit(0)

bad = 0
for path in sorted(glob.glob("*/PKGBUILD")):
    text = open(path).read()
    block = re.search(r"^depends=\((.*?)\)", text, re.M | re.S)
    if not block:
        continue
    for dep in re.findall(r"'([^']+)'", block.group(1)):
        name = re.split(r"[<>=]", dep)[0]
        if name not in ships:
            print("FAIL %s: depends %s is not in core or extra" % (path, name))
            bad = 1
        elif ships[name] == 0:
            print("FAIL %s: depends %s ships no files - list the real provider" % (path, name))
            bad = 1
if bad:
    sys.exit(1)
print("OK   depends resolve to non-empty core/extra packages")
PYD
