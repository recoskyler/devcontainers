---
phase: 01-dockerfile-construction
plan: 02
subsystem: infra
tags: [docker, flutter, fvm, android-sdk, avd, rust, rustup, devcontainer]

# Dependency graph
requires:
  - phase: 01-dockerfile-construction/01
    provides: "System-level installs (Java, Android Studio, cmdline-tools, Chromium, GUI libs)"
provides:
  - "Complete Flutter/Android/Rust devcontainer Dockerfile with all user-level tools"
  - "FVM-managed Flutter stable SDK"
  - "Android SDK components (platform-tools, build-tools, API 35+36, emulator, system image)"
  - "Pre-created AVD flutter_pixel7 with SwiftShader"
  - "Rust toolchain with cargo-watch, cargo-edit, cargo-nextest"
affects: [02-runtime-validation, 03-ci-cd-integration]

# Tech tracking
tech-stack:
  added: [fvm-4.0.5, flutter-3.41.2-stable, android-sdk-36, build-tools-28.0.3, rustup, cargo-nextest-0.9.129]
  patterns: [fvm-global-flutter-management, sdkmanager-license-acceptance, avd-precreation-with-swiftshader]

key-files:
  created: []
  modified:
    - trixie-vnc-flutter-rust-nvm-uv-claude/Dockerfile

key-decisions:
  - "FVM installs to ~/fvm/bin (not ~/.fvm/bin) -- corrected PATH from plan"
  - "Added Android SDK 36 + build-tools 28.0.3 alongside API 35 to satisfy Flutter 3.41.2 requirements"
  - "Kept API 35 system image for AVD (emulator image separate from compile SDK)"

patterns-established:
  - "FVM PATH: $HOME/fvm/bin for FVM binary, $HOME/fvm/default/bin for flutter/dart symlinks"
  - "Android SDK version pinning: install both the SDK version Flutter requires (36) and the emulator API (35)"
  - "Rust install block duplicated from trixie-rust-nvm-uv-claude for consistency"

requirements-completed: [FLUT-01, FLUT-02, SDK-02, SDK-03, SDK-04, EMUL-01, EMUL-02, EMUL-03, TOOL-01, CONV-02]

# Metrics
duration: 27min
completed: 2026-02-24
---

# Phase 1 Plan 2: User-Level Installs Summary

**FVM-managed Flutter 3.41.2 with Android SDK 36, pre-created Pixel 7 AVD (SwiftShader), and Rust toolchain in Flutter devcontainer**

## Performance

- **Duration:** 27 min
- **Started:** 2026-02-24T02:08:03Z
- **Completed:** 2026-02-24T02:35:49Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Android SDK components installed via sdkmanager (platform-tools, API 35+36, build-tools 28.0.3+35.0.0, emulator, x86_64 system image)
- Pre-created AVD "flutter_pixel7" with Pixel 7 profile, SwiftShader rendering, 2048MB RAM, 4096MB storage
- FVM 4.0.5 installed with Flutter 3.41.2 stable SDK managed via fvm global
- Flutter Android licenses accepted, Android Studio path configured for flutter doctor
- Rust 1.93.1 toolchain installed (rustup, clippy, rustfmt, cargo-watch, cargo-edit, cargo-nextest)
- CLAUDE.md has Flutter/Android and Rust tools sections appended
- flutter doctor -v shows green checks for Flutter, Android toolchain, Chrome, Connected devices, Network
- All 13 validation checks passed inside the built container (ALL_CHECKS_PASSED)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add user-level installs to Dockerfile** - `369795e` (feat)
2. **Task 2: Validate complete image end-to-end** - no commit (validation-only, no file changes)

## Files Created/Modified
- `trixie-vnc-flutter-rust-nvm-uv-claude/Dockerfile` - Extended with Android SDK components, AVD creation, FVM/Flutter, Rust toolchain, CLAUDE.md append, and flutter doctor verification

## Decisions Made
- **FVM PATH correction:** The FVM install script (v4.0.5) places the binary at `$HOME/fvm/bin/fvm`, not `$HOME/.fvm/bin/` as the plan suggested. Corrected the ENV PATH line accordingly.
- **Android SDK 36 addition:** Flutter 3.41.2 stable now requires Android SDK 36 and build-tools 28.0.3. Added `platforms;android-36` and `build-tools;28.0.3` alongside the original API 35 components. The system image for the AVD remains API 35 (emulator target is separate from compile SDK).
- **Linux toolchain not required:** flutter doctor shows red X for Linux desktop toolchain (missing clang++, ninja, GTK 3.0). This is for Linux desktop app development only and is not a Phase 1 requirement. The check exited with "issues in 1 category" which is acceptable.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed FVM binary PATH**
- **Found during:** Task 1 (Add user-level installs)
- **Issue:** Plan specified `$HOME/.fvm/bin` but FVM 4.0.5 install script places the binary at `$HOME/fvm/bin/fvm`. Build failed with "fvm: command not found".
- **Fix:** Changed ENV PATH from `$HOME/.fvm/bin:$HOME/fvm/default/bin:$PATH` to `$HOME/fvm/bin:$HOME/fvm/default/bin:$PATH`
- **Files modified:** trixie-vnc-flutter-rust-nvm-uv-claude/Dockerfile
- **Verification:** Build succeeded, `fvm --version` returns 4.0.5
- **Committed in:** 369795e (Task 1 commit)

**2. [Rule 3 - Blocking] Added Android SDK 36 and build-tools 28.0.3**
- **Found during:** Task 1 (Add user-level installs)
- **Issue:** Flutter 3.41.2 stable requires Android SDK 36 and BuildTools 28.0.3, but the plan specified only API 35 and build-tools 35.0.0. flutter doctor reported critical error: "Flutter requires Android SDK 36 and the Android BuildTools 28.0.3"
- **Fix:** Added `"platforms;android-36"` and `"build-tools;28.0.3"` to the sdkmanager install command. Updated CLAUDE.md append text to reflect both versions.
- **Files modified:** trixie-vnc-flutter-rust-nvm-uv-claude/Dockerfile
- **Verification:** flutter doctor shows green check for Android toolchain, reports "Platform android-36, build-tools 35.0.0"
- **Committed in:** 369795e (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes were necessary for the build to succeed and flutter doctor to pass. No scope creep.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 1 (Dockerfile Construction) is fully complete -- both plans executed
- The complete Dockerfile builds end-to-end and produces a functional Flutter/Android/Rust devcontainer
- Image is ready for Phase 2 (Runtime Validation): emulator boot testing, Android Studio connectivity, web target verification
- Image is ready for Phase 3 (CI/CD Integration): workflow configuration with the VNC variant parent image remapping

## Self-Check: PASSED

- FOUND: trixie-vnc-flutter-rust-nvm-uv-claude/Dockerfile
- FOUND: .planning/phases/01-dockerfile-construction/01-02-SUMMARY.md
- FOUND: 369795e (Task 1 commit)

---
*Phase: 01-dockerfile-construction*
*Completed: 2026-02-24*
