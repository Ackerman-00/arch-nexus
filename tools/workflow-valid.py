#!/usr/bin/env python3
"""workflow-valid.py <file> - is this a workflow file GitHub will accept?

Two rules, from two sources, because neither is the whole truth:

- the key set is actionlint's list. The GitHub docs table and the JSON schema
  both list code-quality and vulnerability-alerts, and a workflow carrying
  either is rejected at parse time - every run of it dies, and the agent that
  would fix it cannot run either (2026-10-20).
- the values per key are the machine-readable schema's:
  https://json.schemastore.org/github-workflow.json (definitions.permissions-event),
  vendored in tools/permissions-schema.json. vulnerability-alerts and models
  take read|none, id-token takes write|none, copilot-requests takes write.

Exit 0 = valid, 1 = not. Usage: workflow-valid.py <file> [<file> ...]
"""
import json
import os
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
VALID_KEYS = {"actions", "artifact-metadata", "attestations", "checks", "contents",
              "deployments", "discussions", "id-token", "issues", "models",
              "packages", "pages", "pull-requests", "repository-projects",
              "security-events", "statuses"}


def values():
    path = os.path.join(HERE, "permissions-schema.json")
    try:
        frag = json.load(open(path))
    except (OSError, ValueError):
        return {}
    return {k: set(v) for k, v in frag.get("scopes", {}).items()}


def problems(path):
    out = []
    try:
        doc = yaml.safe_load(open(path))
    except Exception as exc:
        return ["YAML does not parse: %s" % exc]
    if not isinstance(doc, dict):
        return ["not a mapping"]
    vals = values()
    blocks = []
    if isinstance(doc.get("permissions"), dict):
        blocks.append(("top", doc["permissions"]))
    for jn, job in (doc.get("jobs") or {}).items():
        if isinstance(job, dict) and isinstance(job.get("permissions"), dict):
            blocks.append((jn, job["permissions"]))
    for where, perm in blocks:
        for k, v in perm.items():
            if k not in VALID_KEYS:
                out.append("%s: scope %s is not accepted by GitHub" % (where, k))
                continue
            allowed = vals.get(k, {"read", "write", "none"})
            if v not in allowed:
                out.append("%s: %s=%s is invalid (allowed: %s)"
                           % (where, k, v, ", ".join(sorted(allowed))))
    return out


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    bad = 0
    for path in sys.argv[1:]:
        issues = problems(path)
        if issues:
            bad = 1
            for i in issues:
                print("FAIL %s: %s" % (path, i))
        else:
            print("OK   %s" % path)
    return bad


if __name__ == "__main__":
    sys.exit(main())
