#!/usr/bin/env python3
"""check-payload-deps.py <build-dir> - every library in depends and every service in optdepends must be referenced by the installed payload."""
import glob
import os
import re
import subprocess
import sys

SONAME = r"(lib[A-Za-z0-9+~_]*(-[A-Za-z0-9+~_.]+)*|ld-[A-Za-z0-9_.+~-]*)\.so(\.[0-9]+)*"
SONAME_RE = re.compile(SONAME)
SERVICE = r"org\.[a-zA-Z0-9_.]+"
SERVICE_RE = re.compile(SERVICE)


def payload_tokens(path, pattern):
    out = subprocess.run(["grep", "-aorhE", pattern, path], capture_output=True).stdout
    return set(out.decode("utf-8", "replace").split())


def payload_stems(path):
    stems = set()
    for token in payload_tokens(path, SONAME):
        if SONAME_RE.fullmatch(token):
            stem = token.split(".so")[0]
            if stem:
                stems.add(stem)
    return stems


def payload_services(path):
    services = set()
    for token in payload_tokens(path, SERVICE):
        if SERVICE_RE.fullmatch(token):
            services.add(token)
    return services


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


def array_block(text, name):
    m = re.search(r"^%s=\(" % name, text, re.M)
    if not m:
        return None
    depth = 0
    for i in range(m.end() - 1, len(text)):
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth == 0:
                return text[m.end():i]
    return None


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
    block = array_block(text, "depends")
    deps = re.findall(r"'([^']+)'", block) if block else []
    optdep_block = array_block(text, "optdepends")
    optdeps = re.findall(r"'([^']+)'", optdep_block) if optdep_block else []
    stems = set()
    services = set()
    for payload in payloads:
        stems |= payload_stems(payload)
        services |= payload_services(payload)
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
    if services and optdeps:
        for dep in optdeps:
            found = SERVICE_RE.search(dep)
            if not found:
                continue
            service = found.group(0)
            if service not in services:
                print("FAIL %s: optdepends declares %s but the installed payload never references it - drop it or fix the evidence"
                      % (re.split(r"[<>=:]", dep)[0].strip(), service))
                bad = 1
    if bad:
        return 1
    print("OK   every library in depends and every service in optdepends is referenced by the payload")
    return 0


if __name__ == "__main__":
    sys.exit(main())
