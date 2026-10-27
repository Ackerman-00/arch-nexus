#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

IMAGE="${ARCH_BUILD_IMAGE:-archlinux:latest}"

mapfile -t PKGS < <(find . -mindepth 1 -maxdepth 2 -name PKGBUILD -not -path './.git/*' \
  | sed 's|^\./||; s|/PKGBUILD$||' | sort)
if [ "${#PKGS[@]}" -eq 0 ]; then
  echo "FAIL: no PKGBUILDs found in this repo"
  exit 1
fi

if ! docker pull "$IMAGE" >/dev/null 2>&1; then
  echo "WARN: docker pull $IMAGE failed, falling back to a cached image if present"
fi

fail=0
for pkg in "${PKGS[@]}"; do
  echo "== build $pkg =="
  if docker run --rm -v "$PWD":/repo:ro -e pkg="$pkg" "$IMAGE" bash -ec '
    pacman -Sy --noconfirm --needed archlinux-keyring >/dev/null 2>&1
    pacman -Syu --noconfirm --needed base-devel sudo >/dev/null
    useradd -m builder
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
    cp -r "/repo/$pkg" "/tmp/$pkg"
    chown -R builder:builder "/tmp/$pkg"
    cd "/tmp/$pkg"
    runuser -u builder -- makepkg -sC --noconfirm
  '; then
    echo "OK   $pkg"
  else
    echo "FAIL $pkg"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "PKGBUILD BUILD FAILED"
  exit 1
fi
echo "ALL PKGBUILDS BUILT (${#PKGS[@]} packages)"
