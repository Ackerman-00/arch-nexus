#!/usr/bin/env python3
"""check-payload-deps.py <build-dir> - every library package in depends must be referenced by the installed payload."""
import glob
import os
import re
import subprocess
import sys

SONAME = r"[A-Za-z0-9_+.~-]+\.so(\.[0-9]+)*"


def payload_stems(path):
    out = subprocess.run(["grep", "-aorhE", SONAME, path], capture_output=True).stdout
    return {token.split(".so")[0] for token in out.decode("utf-8", "replace").split()}


def package_stems(pkg):
    try:
        out = subprocess.run(["pacman", "-Ql", pkg], capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    stems = set()
    for line in out.splitlines():
        if " " not in line:
            continue
        base = os.path.basename(line.split(None, 1)[1])
        if ".so" in base:
            stems.add(base.split(".so")[0])
    return stems


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    build = sys.argv[1]
    payloads = sorted(glob.glob(os.path.join(build, "pkg", "*")))
    if not payloads:
        print("FAIL %s: makepkg left no package tree to check" % build)
        return 1
    text = open(os.path.join(build, "PKGBUILD")).read()
    block = re.search(r"^depends=\((.*?)\)", text, re.M | re.S)
    deps = re.findall(r"'([^']+)'", block.group(1)) if block else []
    stems = set()
    for payload in payloads:
        stems |= payload_stems(payload)
    if not stems:
        print("FAIL %s: no shared library name found in the packaged payload" % build)
        return 1
    bad = 0
    for dep in deps:
        name = re.split(r"[<>=:]", dep)[0].strip()
        ships = package_stems(name)
        if ships is None:
            print("FAIL %s: depends entry is not installed, cannot prove it" % name)
            bad = 1
            continue
        if not ships:
            continue
        if not ships & stems:
            print("FAIL %s: ships %s but the payload never references it - drop it or fix the evidence"
                  % (name, ", ".join(sorted(ships)[:4])))
            bad = 1
    if bad:
        return 1
    print("OK   every library in depends is referenced by the payload")
    return 0


if __name__ == "__main__":
    sys.exit(main())
