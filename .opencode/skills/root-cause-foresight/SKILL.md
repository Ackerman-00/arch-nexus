---
name: root-cause-foresight
description: After every fix, find the root cause, search for the same bug elsewhere, and add a guard so it cannot silently return. Use after fixing any error, failed build, failed package update, or workflow problem.
---

# Root cause and foresight

A fix is done only when you can answer all five:

1. Why did it happen? State the cause, not the symptom. Reproduce it first: fail, fix, pass.
2. Where else is the same pattern? `grep -rn` the repo. Fix every instance in the same commit or list it in the relay.
3. What will break this later? Check each: upstream renames a release asset, a distfile URL moves, a hash drifts, a package gets renamed or merged in Arch (`atk` -> `at-spi2-core`, `cups` -> `libcups`), a rate limit hits, a token expires, the disk fills, docker pulls fail.
4. Which guard makes a return loud and cheap? Pick one: a check in `tools/`, a `validpgpkeys`/checksum check, a clearer error in a script, the `build-all.sh` proof itself. Skip it if it costs more than the bug.
5. Did the fix create a new failure? Re-run the full verification (`bash tools/build-all.sh`), not just the failing part.

Write to `.opencode-relay.md` after the first two lines: `fixed: <cause in one line>` and `prevent: <guard or none>`.

Fix the class of problem, not the instance. Do not widen scope beyond that.
