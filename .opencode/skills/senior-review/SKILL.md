---
name: senior-review
description: Peak-quality, no-slop engineering rules for every change in this repo - smallest correct diff, no invented or guessed dependencies, no comments except a short evidence note, self-review before commit. Use on every change, before every commit.
---

# Senior review, no slop

## Before writing

- Read the file you change and its neighbours. Match the existing structure.
- Never invent a dependency or a package name. Confirm it exists in this day's Arch core+extra before using it (see `pkgbuild-style` for the exact resolution method): renamed or merged packages (`atk`, `at-spi2-atk`, `cups-libs`, `pipewire-libs`) are the known trap.
- Never guess a `sha256sum`. Hash the actual distfile.

## The change

- Smallest diff that fixes the root cause. One concern per commit.
- No feature nobody asked for. No wrapper with one caller. No dead code. No TODO.
- Names say what the code does. That is the documentation.
- Comments: only short evidence notes of the form the `rootapp-bin` PKGBUILD header uses - what was verified, how, on which date. Never a comment that just restates the line below it. Never commented-out code.
- Sorted, deduplicated `depends=()` array, one package per line.

## Self-review before commit

1. `git diff` and read it as a stranger. Cut everything that is not needed.
2. `bash -n <changed .sh>` and `bash -n PKGBUILD` for every shell file you touched.
3. Does the change do exactly what the commit message says, nothing more?
4. Did I leave a debug line, commented-out code or unused variable? Remove it.
5. Is a secret, token or private path in the diff? Remove it.

## Commit

`type(scope): what and why`, imperative, under 72 characters. Body only for non-trivial changes: one `source:` URL.
