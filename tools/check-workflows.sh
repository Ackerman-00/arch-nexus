#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
FAIL=0

echo "== YAML parse =="
python3 - <<'PY' || FAIL=1
import glob, sys, yaml
for f in sorted(glob.glob(".github/workflows/*.yml")):
    try:
        yaml.safe_load(open(f))
        print(f"OK   {f}")
    except Exception as e:
        print(f"FAIL {f}: {e}")
        sys.exit(1)
PY

echo "== actionlint =="
AL_VERSION=1.7.12
AL_SHA256=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
al=$(command -v actionlint 2>/dev/null)
[ -n "$al" ] || { [ -x /tmp/opencode/actionlint ] && al=/tmp/opencode/actionlint; }
if [ -z "$al" ]; then
  mkdir -p /tmp/opencode
  url="https://github.com/rhysd/actionlint/releases/download/v${AL_VERSION}/actionlint_${AL_VERSION}_linux_amd64.tar.gz"
  if curl -fsSL --max-time 60 "$url" -o /tmp/opencode/actionlint.tgz \
    && echo "$AL_SHA256  /tmp/opencode/actionlint.tgz" | sha256sum -c --status \
    && tar -xzf /tmp/opencode/actionlint.tgz -C /tmp/opencode actionlint; then
    al=/tmp/opencode/actionlint
  fi
fi
if [ -n "$al" ]; then
  "$al" -shellcheck= -no-color .github/workflows/*.yml && echo "OK   actionlint clean" || FAIL=1
else
  echo "FAIL actionlint unavailable and its download failed - cannot prove workflow validity"
  FAIL=1
fi

echo "== permission scopes =="
if python3 tools/workflow-valid.py .github/workflows/*.yml; then
  :
else
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  echo "WORKFLOW VALIDATION FAILED - do not push"
  exit 1
fi
echo "WORKFLOW VALIDATION PASSED"
