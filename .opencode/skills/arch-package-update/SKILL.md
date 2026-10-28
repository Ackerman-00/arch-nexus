---
name: arch-package-update
description: Update the personal Arch packages in this repo (every top-level directory with a PKGBUILD, e.g. rootapp-bin) to the latest upstream release - new pkgver/pkgrel, fresh sha256sums, build, commit. Use whenever checking for or applying a package update. Never push to the AUR from the agent step.
---

# Update personal Arch packages

A `PKGBUILD` with a fixed `pkgver` and `sha256sums` never changes by itself. You must edit them yourself. This is possible. Never report "cannot".

## 1. Find the packages

- `find . -mindepth 1 -maxdepth 2 -name PKGBUILD -not -path './.git/*'` and read each one.
- Write a list: name, current pkgver-pkgrel, upstream source (distfile URL / GitHub repo).
- Known: `rootapp-bin` (AppImage from installer.rootapp.com, no GitHub release feed - the version comes from `X-AppImage-Version` inside the AppImage's `.desktop`, which `prepare()` also verifies against `pkgver`).

## 2. Update each package. Use the first method that works

A. GitHub release upstream: latest stable tag with
   `gh api repos/OWNER/REPO/releases/latest --jq .tag_name` (strip a leading `v`; ignore drafts and prereleases). Same as current pkgver: stop, nothing to do.

B. Distrofile-only upstream (no release API): download the distfile to a temp dir
   (`curl -fsSL -o`), and if it is an AppImage run `--appimage-extract` and read
   `X-AppImage-Version=` from the extracted `.desktop`.

C. Then, always:
1. Build the new distfile URL from the pattern already in `source=()`.
2. `sha256sum` the file you actually downloaded. Paste it into `sha256sums=()`. Never guess a hash.
3. Version rules: new upstream version -> `pkgver=` changes and `pkgrel=1`; packaging-only change (deps, install logic, desktop file) -> same `pkgver`, `pkgrel` +1.
4. Edit with str_replace. Never invent a version.

## 3. Verify

- `bash tools/build-all.sh` - every package you changed must build in the clean container. Nothing weaker counts.
- If cheap, run the installed binary with `--version` inside the container.

## 4. Commit

One commit per package: `chore: <name> <old> -> <new>`.

## 5. Failure

- 3 tries per package. Then `git checkout -- <file>`, add `skipped: <name> <short reason>` to `.opencode-relay.md`, go on with the next package. One broken package never blocks the others.
- Upstream renamed its release asset: list assets with `gh api repos/OWNER/REPO/releases/latest --jq '.assets[].name'` and fix the `source=()` pattern.

## 6. Report and publish

- Add `updated: <name> <old> -> <new>` per package to `.opencode-relay.md`.
- Never push to the AUR yourself: this step has no AUR credentials. After you push the bump to `main`, the scheduler's token-scoped AUR step (`tools/aur-push.sh`) publishes it live.
