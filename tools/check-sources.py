#!/usr/bin/env python3
import glob
import re
import sys

HEX64 = r"'[0-9a-f]{64}'"

bad = 0
for path in (sys.argv[1:] or sorted(glob.glob("*/PKGBUILD"))):
    text = open(path).read()
    src = re.search(r"^source(?:_[a-zA-Z0-9_]+)?=\((.*?)\)", text, re.M | re.S)
    sha = re.search(r"^sha256sums(?:_[a-zA-Z0-9_]+)?=\((.*?)\)", text, re.M | re.S)
    if not src or not sha:
        continue
    nsrc = len(re.findall(r"'[^']*'", src.group(1))) + len(re.findall(r'"[^"]*"', src.group(1)))
    nsum = len(re.findall(HEX64, sha.group(1)))
    if nsrc != nsum:
        print("FAIL %s: %d sources but %d sha256sums - makepkg refuses this PKGBUILD" % (path, nsrc, nsum))
        bad = 1

if bad:
    sys.exit(1)
print("OK   source/sha256sums counts match")
