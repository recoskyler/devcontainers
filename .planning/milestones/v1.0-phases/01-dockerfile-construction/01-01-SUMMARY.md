---
phase: 01-dockerfile-construction
plan: 01
subsystem: infra
tags: [docker, android, java, chromium, android-studio, cmdline-tools, devcontainer]

# Dependency graph
requires: []
provides:
  - "Flutter/Android devcontainer Dockerfile with all system-level (root) installs"
  - "OpenJDK 21, Android cmdline-tools, Android Studio, Chromium, GUI library dependencies"
affects: [01-02, 02-runtime-validation, 03-ci-cd-integration]

# Tech tracking
tech-stack:
  added: [openjdk-21-jdk-headless, chromium, android-cmdline-tools-20.0, android-studio-2025.3.1.5]
  patterns: [two-block-user-structure, android-sdk-directory-layout, cmdline-tools-bootstrap]

key-files:
  created:
    - trixie-vnc-flutter-rust-nvm-uv-claude/Dockerfile
  modified: []

key-decisions:
  - "Corrected Android Studio version from 2025.3.1.8 to 2025.3.1.5 (latest available Panda 1 release)"
  - "Used dl.google.com direct download URL instead of redirector.gvt1.com (404 with redirector for this version)"

patterns-established:
  - "VNC variant chaining: new variant extends trixie-vnc-nvm-uv-claude rather than devcontainer-base directly"
  - "Android SDK at /home/dev/android-sdk owned by dev user for sdkmanager write access"

requirements-completed: [SDK-01, IDE-01, DISP-01, WEB-01, CONV-01, CONV-03]

# Metrics
duration: 15min
completed: 2026-02-24
---

# Phase 1 Plan 1: System-Level Installs Summary

**Flutter/Android devcontainer Dockerfile with OpenJDK 21, Android Studio Panda 1, cmdline-tools 20.0, Chromium, and all emulator GUI library dependencies on Debian Trixie**

## Performance

- **Duration:** 15 min
- **Started:** 2026-02-24T01:49:53Z
- **Completed:** 2026-02-24T02:05:07Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Created the Flutter/Android devcontainer Dockerfile extending the VNC variant
- Installed OpenJDK 21 headless with JAVA_HOME configured
- Bootstrapped Android cmdline-tools at correct directory path (sdkmanager v20.0 works)
- Installed Android Studio Panda 1 (2025.3.1.5) at /opt/android-studio
- Installed Chromium with CHROME_EXECUTABLE env var set
- Installed all 18 emulator/Studio GUI shared library dependencies
- All system-level validations passed (ALL_CHECKS_PASSED)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Dockerfile with system-level installs** - `e5ca3f3` (feat)
2. **Task 2: Validate root-level installs inside the built image** - no commit (validation-only, no file changes)

## Files Created/Modified
- `trixie-vnc-flutter-rust-nvm-uv-claude/Dockerfile` - New devcontainer extending VNC variant with Java, Android SDK tools, Android Studio, Chromium, and GUI library dependencies

## Decisions Made
- **Android Studio version correction:** Plan specified version 2025.3.1.8 but this version does not exist on dl.google.com. Probed available versions and found 2025.3.1.5 is the latest Panda 1 release. Used `https://dl.google.com/dl/android/studio/ide-zips/2025.3.1.5/android-studio-2025.3.1.5-linux.tar.gz` instead.
- **Download URL domain:** Used `dl.google.com/dl/android/studio/` direct download rather than `redirector.gvt1.com` since the redirector returned 404 for this version.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Corrected Android Studio download URL**
- **Found during:** Task 1 (Create Dockerfile with system-level installs)
- **Issue:** The plan specified Android Studio version 2025.3.1.8 with URL `https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2025.3.1.8/android-studio-2025.3.1.8-linux.tar.gz` which returned HTTP 404
- **Fix:** Probed available versions on dl.google.com and found 2025.3.1.5 as the latest Panda 1. Updated ARG to `https://dl.google.com/dl/android/studio/ide-zips/2025.3.1.5/android-studio-2025.3.1.5-linux.tar.gz`
- **Files modified:** trixie-vnc-flutter-rust-nvm-uv-claude/Dockerfile
- **Verification:** Docker build completed successfully, /opt/android-studio/bin/studio.sh exists in built image
- **Committed in:** e5ca3f3 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** URL correction was necessary for the build to succeed. No scope creep.

## Issues Encountered
None beyond the URL correction documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- System-level foundation is complete and verified
- Plan 02 can proceed to add user-level installs (FVM, Flutter SDK, sdkmanager components, AVD creation, Rust toolchain, CLAUDE.md append)
- The built image `flutter-test-plan01` can be used as the build verification baseline for Plan 02

## Self-Check: PASSED

- FOUND: trixie-vnc-flutter-rust-nvm-uv-claude/Dockerfile
- FOUND: .planning/phases/01-dockerfile-construction/01-01-SUMMARY.md
- FOUND: e5ca3f3 (Task 1 commit)

---
*Phase: 01-dockerfile-construction*
*Completed: 2026-02-24*
