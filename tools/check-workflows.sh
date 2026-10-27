#!/usr/bin/env bash
# check-workflows.sh - validate .github/workflows/*.yml before pushing them.
#
# A workflow file that GitHub rejects kills every run of it: the push creates
# a failed run with no jobs and the schedule dies silently. That happened on
# 2026-09-09 (commit ad69ca3 added the invalid scope `workflows: write`) and
# again on 2026-10-20 (the scopes `code-quality` and `vulnerability-alerts` are
# NOT valid in a permissions block, even though the docs table lists them).
# actionlint is the authority on the accepted scope list, not the docs prose.
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
# -shellcheck= disables shellcheck integration: its style infos are not
# workflow validity and would otherwise fail a valid file.
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
