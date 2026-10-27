---
name: pkgbuild-style
description: Arch packaging standards and evidence rules for PKGBUILDs in this repo - dependency sets re-derived from the payload and resolved against the live package databases, checksums, options, desktop/icon install paths, lint. Use on any PKGBUILD edit or when auditing one.
---

# PKGBUILD style and evidence

## Dependencies are evidence, never memory

1. Re-derive the runtime set from the payload itself: `readelf -d` DT_NEEDED union of every shipped ELF (minus glibc and any bundled-runtime-only lib), plus the libraries loaded **by name** (dlopen lists, .NET `DllImport` probe tables - scan strings in ASCII **and** UTF-16).
2. Resolve every soname to a package against the live Arch databases, the same way `pkgbuild-style` was itself written:
   `curl -fsSL -o /tmp/core.files https://geo.mirror.pkgbuild.com/core/os/x86_64/core.files` and the same for `extra.files` (also `core.db`/`extra.db` for package names), then match the file basenames.
   The name-only check is not enough: Arch merges and splits packages (`atk` and `at-spi2-atk` merged into `at-spi2-core`; `libcups` and `libpipewire` split out of `cups`/`pipewire`). A name that is not in the index is a broken package, not a shrug.
3. Never add a dependency "because Electron apps need it" or because another distro's recipe has it - only payload evidence.
4. Document the method and date in a short comment header above `depends=()` (see `rootapp-bin`).

## Structure

- `-bin` suffix for prebuilt payloads, `arch=('x86_64')` when the payload is x86_64-only, `options=('!strip')` when the vendor ships prebuilt ELFs whose stripping breaks them.
- Sorted, deduplicated `depends=()`, one package per line.
- Extract in `prepare()`, install in `package()`; build in a copy, never mutate `${srcdir}` outside extraction.
- Drop dead weight the payload drags in (split debug files like `Root.dbg`, unused helpers) exactly like the RPM/DEB recipes in `opensuse-nexus/rootapp` do - keep the three recipes in agreement.
- No setuid bits, no `!net` games with upstream self-updaters: if the payload ships one, note it, do not silently enable it.

## Desktop entry and icon

- `Exec=` must be the wrapper/symlink name you install to `/usr/bin`, with `%U` when the app handles URLs (`MimeType=x-scheme-handler/...` must match).
- The icon size class must match the PNG's real IHDR dimensions (read them: `python3 -c "import struct;d=open(f,'rb').read();print(struct.unpack('>II',d[16:24]))"`), installed under `usr/share/icons/hicolor/<size>/apps/`; the legacy `usr/share/pixmaps` copy stays alongside.
- Validate when available: `desktop-file-validate <the .desktop>`.

## Lint before you claim done

- `bash -n PKGBUILD` and `bash -n tools/*.sh`.
- `bash tools/build-all.sh` - the mandatory proof, per AGENTS.md.
- `makepkg --printsrcinfo` succeeds inside the container (the AUR step regenerates `.SRCINFO`; the repo does not commit it).
