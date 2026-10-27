#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

: "${AUR_SSH_PRIVATE_KEY:?AUR_SSH_PRIVATE_KEY is required}"
: "${AUR_USERNAME:?AUR_USERNAME is required}"
AUR_EMAIL="${AUR_EMAIL:-${AUR_USERNAME}@users.noreply.github.com}"
IMAGE="${ARCH_BUILD_IMAGE:-archlinux:latest}"

if [ "$#" -eq 0 ]; then
  echo "no package directories given"
  exit 0
fi

git fetch -q origin main || true
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
  echo "HEAD is not on origin/main - pushing the bump to GitHub first"
  if [ -z "${REPO_FULL_ACCESS_TOKEN:-}" ]; then
    echo "FAIL: REPO_FULL_ACCESS_TOKEN missing, cannot publish the bump"
    exit 1
  fi
  origin_path="$(git remote get-url origin | sed 's#^https://github.com/##; s#^git@github.com:##; s#\.git$##')"
  git push "https://x-access-token:${REPO_FULL_ACCESS_TOKEN}@github.com/${origin_path}.git" HEAD:main
fi

mkdir -p ~/.ssh
ssh-keyscan aur.archlinux.org >> ~/.ssh/known_hosts 2>/dev/null || true
umask 077
printf '%s\n' "$AUR_SSH_PRIVATE_KEY" > ~/.ssh/aur_key
cat > ~/.ssh/config <<SSHEOF
Host aur.archlinux.org
    IdentityFile ~/.ssh/aur_key
    User aur
SSHEOF
chmod 600 ~/.ssh/aur_key ~/.ssh/config

docker pull "$IMAGE" >/dev/null 2>&1 || echo "WARN: docker pull failed, hoping for a cached image"

for dir in "$@"; do
  pkgbuild="$dir/PKGBUILD"
  if [ ! -f "$pkgbuild" ]; then
    echo "skip $dir: no PKGBUILD"
    continue
  fi
  pkgname=$(grep -m1 '^pkgname=' "$pkgbuild" | sed 's/^pkgname=//' | tr -d "\"'")
  pkgver=$(grep -m1 '^pkgver=' "$pkgbuild" | sed 's/^pkgver=//' | tr -d "\"'")
  pkgrel=$(grep -m1 '^pkgrel=' "$pkgbuild" | sed 's/^pkgrel=//' | tr -d "\"'" | sed 's/[^0-9].*//')
  fullver="${pkgver}-${pkgrel:-1}"
  echo "== $pkgname $fullver =="

  aur_ver=$(curl -fsS --max-time 20 "https://aur.archlinux.org/rpc/v5/info?arg%5B%5D=${pkgname}" \
    | python3 -c "import sys,json; r=json.load(sys.stdin).get('results',[]); print(r[0]['Version'] if r else '')" 2>/dev/null || echo "")
  if [ "$aur_ver" = "$fullver" ]; then
    echo "AUR already at $fullver - nothing to push"
    continue
  fi
  if [ -n "$aur_ver" ]; then
    echo "AUR has $aur_ver, pushing $fullver"
  else
    echo "not on AUR yet, pushing $fullver"
  fi

  work=$(mktemp -d)
  git clone -q "ssh://aur@aur.archlinux.org/${pkgname}.git" "$work"
  cp "$pkgbuild" "$work/"
  for f in "$dir"/*.install "$dir"/*.patch "$dir"/*.diff; do
    [ -f "$f" ] && cp "$f" "$work/"
  done
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -f "$dir/$f" ] || { echo "FAIL: local source $f missing in $dir"; exit 1; }
    cp "$dir/$f" "$work/"
  done < <(cd "$dir" && bash -c 'source PKGBUILD >/dev/null 2>&1; printf "%s\n" "${source[@]}"' \
    | sed 's|^[^:]*::||' | grep -vE '^[a-zA-Z][a-zA-Z0-9+.-]*://')

  (
    cd "$work"
    rm -f .SRCINFO
    docker run --rm -v "$work:/work" "$IMAGE" bash -c \
      'mkdir -p /tmp/build && cp /work/PKGBUILD /tmp/build/ && chown -R nobody: /tmp/build && cd /tmp/build && runuser -u nobody -- makepkg --printsrcinfo > /work/.SRCINFO' \
      || true
    git config user.name "$AUR_USERNAME"
    git config user.email "$AUR_EMAIL"
    git add -A
    if [ -s .SRCINFO ]; then
      git add -f .SRCINFO
      echo "generated .SRCINFO"
    else
      echo "FAIL: .SRCINFO empty - AUR metadata would not refresh"
      exit 1
    fi
    if git diff --cached --quiet; then
      echo "no AUR-side changes to push"
      exit 0
    fi
    git commit -q -m "Update to ${fullver}"
    git push -q origin HEAD
  )
  echo "pushed $pkgname $fullver to AUR"
  rm -rf "$work"
done
echo "AUR PUSH DONE"
