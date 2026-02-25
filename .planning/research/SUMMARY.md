# Project Research Summary

**Project:** Flutter Full-Stack Mobile DevContainer
**Domain:** Docker-based DevContainer image with Flutter, Android SDK, Android Studio (VNC), Rust, Node.js, Python
**Researched:** 2026-02-24
**Confidence:** MEDIUM

## Executive Summary

This project adds a `trixie-vnc-flutter-rust-nvm-uv-claude` Docker image to an existing collection of Debian Trixie DevContainer variants. The target is a single, self-contained development environment for Flutter full-stack mobile development that includes: the Flutter SDK (managed via FVM), Android SDK with emulator, the full Android Studio IDE accessible over VNC, a Rust toolchain for FFI work, and the inherited Node.js/Python/Claude Code stack from the base image. This category of image — full IDE + emulator in a container — is uncommon in the wild; most competing images focus on CLI-only builds or omit the IDE entirely, which is the primary differentiator of this image.

The recommended build strategy is to extend `devcontainer-base:latest` directly (not the VNC variant) and inline the three VNC packages, keeping the CI matrix flat and parallel. The Dockerfile layers must follow a strict dependency order: VNC packages, JDK 21, Android SDK (via cmdline-tools bootstrap and sdkmanager), Android Studio IDE, Rust toolchain, then FVM + Flutter SDK with a final `flutter doctor` validation. All components should be installed as pinned versions, with Android SDK licenses accepted non-interactively during build. The expected image size is 7-10 GB, which is large but unavoidable for this tool combination.

The single greatest risk is the Android emulator's dependency on KVM hardware virtualization, which is unavailable on most cloud hosts and Docker Desktop on macOS/Windows. This must be treated as a first-class architectural concern: the Dockerfile and devcontainer.json must configure software rendering (SwiftShader) as the default, document KVM as an optional performance enhancement, and pre-create an AVD with conservative memory settings. A secondary risk is CI cache budget: this variant will exceed the historical 10 GB GHA cache threshold (now expandable) and will cause cache eviction for other variants if not isolated with its own `flutter` cache scope and potentially a registry-based cache backend.

## Key Findings

### Recommended Stack

The Flutter variant extends `devcontainer-base:latest` and layers components in dependency order. FVM 4.0.5 (standalone install script) manages Flutter SDK 3.41.x stable, with `fvm install stable` run at build time. Android SDK is bootstrapped from cmdline-tools 14742923 and sdkmanager installs platform-tools, build-tools;36.0.0, platforms;android-36, the emulator, and `system-images;android-35;google_apis;x86_64`. Android Studio Panda 1 (2025.3.1.8) is extracted from its tar.gz to `/opt/android-studio`. OpenJDK 21 is the JDK version because Android Studio Panda bundles JBR 21, and it matches the AGP 8.x + Gradle 8.5+ requirement. Rust 1.93.x is installed via rustup as `user dev`, identical to the existing rust variant. NVM 0.40.4, Node 24.x, and UV 0.10.4 are inherited from the base image without modification.

**Core technologies:**
- Flutter SDK 3.41.x via FVM 4.0.5 — version-pinned per project via `.fvmrc`; FVM standalone script avoids Dart chicken-and-egg problem
- Android SDK (cmdline-tools 14742923, platform-tools 36.0.2, build-tools 36.0.0, platform API 36) — complete toolchain for `flutter build apk` and `flutter doctor`
- Android Emulator 36.4.9 + system-images;android-35;google_apis;x86_64 — API 35 image used (not 36) because API 36 system images are not yet widely available; software rendering via SwiftShader
- Android Studio Panda 1 (2025.3.1.8) — full IDE, GUI access via VNC; only viable install method is tar.gz extraction
- OpenJDK 21 — matches Android Studio Panda's bundled JBR; required minimum for AGP 8.x is JDK 17, but 21 is the recommended match
- Rust 1.93.x via rustup — independent toolchain; same pattern as existing `trixie-rust-nvm-uv-claude` variant
- xvfb + x11vnc — virtual framebuffer and VNC server; inlined from VNC variant rather than inheriting, to keep CI matrix flat

### Expected Features

**Must have (table stakes):**
- Flutter SDK via FVM — core runtime; FVM is the community standard for version management
- Android SDK (cmdline-tools, platform-tools, build-tools, platforms) — required for all Android compilation
- Android emulator + pre-created AVD (Pixel 6, API 35, google_apis, x86_64) — zero-config emulator launch
- Software rendering via SwiftShader — emulator must work without KVM
- JDK 21 — prerequisite for sdkmanager, Gradle, and Android Studio
- Rust toolchain (rustup, cargo, clippy, rustfmt, cargo-watch, cargo-nextest) — explicitly required by project
- `flutter doctor` passes clean at build time — validation gate
- Android SDK license acceptance during build — prevents interactive prompts at runtime
- CLAUDE.md tools section appended — project convention for all variants
- CI/CD matrix entry in both build.yml and check.yml — must build in GitHub Actions

**Should have (competitive):**
- Android Studio IDE accessible via VNC — major differentiator; most Flutter Docker images omit the full IDE
- Chromium for Flutter web target (`flutter run -d chrome`) — enables second build target without leaving the container
- Configurable Android API level via build ARG — avoids maintaining multiple images for different API targets
- Pre-configured AVD with devcontainer.json resource recommendations — documents KVM, memory, and swap settings

**Defer to v1.x/v2+:**
- Entrypoint script for emulator auto-start — add after manual emulator workflow is validated
- Linux desktop target support (GTK, clang, ninja) — high image size cost, niche demand
- Android NDK as build ARG — only for projects doing native C/C++ Android development
- Flutter integration test runner — requires Chromium + emulator orchestration

### Architecture Approach

The Flutter Dockerfile uses `FROM devcontainer-base:latest` and inlines the VNC packages directly rather than extending the VNC variant via a three-level image chain. This decision is deliberate: the VNC layer is only three APT packages (~10 MB), and inlining it keeps the CI matrix flat (all variants build in parallel from `devcontainer-base:latest`) without requiring workflow changes. The Dockerfile follows a strict 9-step layer order driven by build-time dependencies, and uses Docker ARG for all version-pinned components to support future version bumps without Dockerfile edits.

**Major components:**
1. VNC layer (xvfb, x11vnc, xdg-utils) — provides the virtual framebuffer and VNC server; must precede all GUI apps
2. JDK 21 + Android GUI dependencies — prerequisite for sdkmanager, Gradle, and Android Studio GUI rendering
3. Android SDK (cmdline-tools bootstrap + sdkmanager packages) — installed to `/opt/android-sdk`, owned by `dev` user
4. Android Studio IDE — extracted to `/opt/android-studio`; in its own layer to avoid cache invalidation coupling with SDK
5. Rust toolchain — independent chain installed as `user dev`; no interaction with Android stack
6. FVM + Flutter SDK — installed as `user dev`; validates the entire stack via `flutter doctor`
7. AVD creation — `avdmanager` creates a default Pixel 6 AVD during build with conservative memory settings
8. CLAUDE.md append — appended last, after all tools are installed

### Critical Pitfalls

1. **KVM unavailability breaks emulator** — Configure SwiftShader (`-gpu swiftshader_indirect`) as the default in the AVD config.ini; set `hw.gpu.enabled=no` in the AVD; document `--device=/dev/kvm` as an optional host requirement in devcontainer.json; never make KVM mandatory.

2. **Image size exceeds CI cache budget** — Use GHA cache scope `flutter` to isolate this variant; consider switching to registry-based cache (`type=registry`) which has no 10 GB cap; pin a single system image (API 35 only); combine RUN commands and clean caches in the same layer; track image size in CI.

3. **Qt xcb plugin crash silently kills emulator** — Install the full set of xcb/X11 dependencies during build: `libxcb-xinerama0`, `libxcb-cursor0`, `libxcb-randr0`, `libxcb-shape0`, `libxcb-xfixes0`, `libxcb-render-util0`, `libxkbcommon-x11-0`, `libpulse0`, `libatk1.0-0`, `libcups2`, `libdrm2`, `libgbm1`; run the emulator once during build validation.

4. **JAVA_HOME / sdkmanager version mismatch** — Pin `openjdk-21-jdk-headless` explicitly; set `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`; use `cmdline-tools;latest` (12.0+) which supports Java 21; run `yes | sdkmanager --licenses` and `flutter doctor --android-licenses` during build.

5. **DISPLAY misconfiguration makes emulator invisible in VNC** — Set `ENV DISPLAY=:99` in the Dockerfile (not just in bashrc); start Xvfb before x11vnc, and x11vnc before any GUI app; use `Xvfb :99 -screen 0 1920x1080x24` for adequate resolution; test with `xdpyinfo -display :99`.

6. **Emulator OOM boot loop** — Set `hw.ramSize=2048` in AVD config.ini; pass `-memory 2048` to the emulator; document minimum host requirements (16 GB RAM, 8 GB container memory) in devcontainer.json.

## Implications for Roadmap

Based on research, the work naturally divides into three phases driven by build-time dependencies and validation requirements.

### Phase 1: Dockerfile Construction

**Rationale:** All other work depends on a working Dockerfile. The strict layer order (VNC → JDK → Android SDK → Android Studio → Rust → Flutter/FVM → validation) must be established first. All pitfalls except CI cache strategy are addressed here.

**Delivers:** A Dockerfile that builds locally, passes `flutter doctor`, and produces a working emulator and Android Studio via VNC.

**Addresses (from FEATURES.md):** All P1 table-stakes features except CI integration — FVM + Flutter, JDK, Android SDK, emulator, pre-created AVD, SwiftShader, Rust toolchain, SDK license acceptance, CLAUDE.md append.

**Avoids (from PITFALLS.md):**
- KVM pitfall: configure SwiftShader defaults and conservative AVD memory in the Dockerfile
- Qt xcb crash: install full xcb/X11 dependency set
- Java/sdkmanager mismatch: pin OpenJDK 21 and verify against sdkmanager + flutter doctor
- DISPLAY misconfiguration: set ENV DISPLAY=:99 and establish correct Xvfb resolution
- Emulator OOM: configure AVD with hw.ramSize=2048

**Research flag:** This phase has the most complexity. The layer ordering, exact package list, AVD creation command, and flutter doctor validation are all well-documented across community sources, but the interaction between OpenJDK 21, cmdline-tools;latest, and flutter doctor requires careful ordering that should be tested incrementally. Recommend building and testing layer by layer locally before finalizing.

### Phase 2: Local Validation

**Rationale:** The Dockerfile can build successfully but produce an image with subtle runtime failures — invisible emulator, broken VNC, or flutter doctor false positives. Validation before CI integration catches failures cheaply.

**Delivers:** A confirmed working image verified locally with Docker CLI: emulator boots to home screen, Android Studio launches via VNC, `flutter doctor -v` shows correct FVM-managed Flutter, `adb devices` lists the emulator, hot reload works.

**Addresses (from FEATURES.md):** Confirms all P1 features are functional, not just installed. Identifies any P2 features (Chromium, Android Studio) that can be layered in before CI.

**Avoids (from PITFALLS.md):**
- "Looks done but isn't" checklist: all 8 validation items from PITFALLS.md must pass
- Emulator OOM: verified by watching emulator boot time and dmesg
- DISPLAY mismatch: verified by VNC connection and emulator visibility

**Research flag:** Standard validation workflow. No additional research needed. Use the "Looks Done But Isn't" checklist from PITFALLS.md verbatim.

### Phase 3: CI/CD Integration

**Rationale:** The image is large (7-10 GB) and requires specific GHA cache configuration to avoid degrading other variants' build performance. This is a distinct concern from Dockerfile correctness.

**Delivers:** Build.yml and check.yml matrix entries for the `flutter` variant; GHA cache scope `flutter` configured; build timeout adjusted for the larger variant (60 minutes); image size gate in CI; image pushed to GHCR.

**Addresses (from FEATURES.md):** CI/CD matrix integration (P1 table stakes).

**Avoids (from PITFALLS.md):**
- Image size cache explosion: isolate with `flutter` scope; evaluate registry-based cache if size exceeds 10 GB
- Other variant cache eviction: verify no cache scope collision after flutter variant builds

**Research flag:** The CI structure is well-documented in the existing project. Only new decision is cache backend strategy (GHA vs. registry). GHA cache now supports expansion beyond 10 GB (per Nov 2025 GitHub changelog), so `type=gha` may be sufficient if the `flutter` scope is isolated. Validate with a test build before committing to registry-based cache.

### Phase Ordering Rationale

- Phase 1 before Phase 2: the image must exist before it can be validated
- Phase 2 before Phase 3: CI should not be configured to push a broken image; local validation is cheaper than debugging in CI
- Android SDK before Android Studio (within Phase 1): Android Studio's first-run sync expects `ANDROID_HOME` to exist
- JDK before Android SDK (within Phase 1): sdkmanager is a Java program and fails silently without JDK
- Flutter/FVM after Android SDK (within Phase 1): `flutter doctor` validates the SDK; installing Flutter before the SDK produces a false-failing doctor
- Rust before Flutter (within Phase 1): independent chain, but placing Rust before Flutter gives better layer caching (Rust changes less frequently than Flutter)
- Android Studio as a separate Dockerfile layer from Android SDK: both are large downloads; isolating them prevents SDK version bumps from invalidating the Studio layer cache

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (Dockerfile):** The exact xcb/X11 dependency list for emulator on Debian Trixie needs verification via `ldd` on the actual emulator binary. The ARCHITECTURE.md and PITFALLS.md lists are based on community sources; some packages may be unnecessary or missing on Trixie specifically. Recommend running `QT_DEBUG_PLUGINS=1 emulator -avd flutter_emu` during development and adding any missing `.so` dependencies found.
- **Phase 1 (Android Studio):** The exact tar.gz download URL from STACK.md (`edgedl.me.gvt1.com`) should be verified; Google occasionally changes CDN URLs. Fall back to the official developer.android.com/studio page if the URL fails.

Phases with standard patterns (skip additional research):
- **Phase 2 (validation):** Well-defined checklist from PITFALLS.md. No ambiguity in what "working" means.
- **Phase 3 (CI):** Existing project CI structure is clear; adding a matrix entry is a one-line change per workflow file. Cache scope naming convention is established.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | Most component versions verified via official sources. Android Studio CDN URL and exact cmdline-tools version number are MEDIUM (Google changes these). FVM, Flutter, JDK, Rust versions are HIGH. |
| Features | MEDIUM | Table-stakes features are clear from official Flutter + Android docs. P2 features (Chromium, API build arg) are low-risk additions. Competitor analysis is MEDIUM — most competitor images are low-activity or archived. |
| Architecture | MEDIUM | Layer ordering and inline-VNC decision are well-reasoned and validated against the existing project structure. The three-level FROM chain concern is confirmed by the current CI workflow. Individual source images are mostly MEDIUM confidence. |
| Pitfalls | MEDIUM-HIGH | KVM, image size, Java/sdkmanager, and DISPLAY pitfalls are extensively documented across community projects and Google's own emulator container scripts. Qt xcb dependencies are less well-documented for Trixie specifically. |

**Overall confidence:** MEDIUM

### Gaps to Address

- **Exact xcb dependency list for Debian Trixie:** The package names in STACK.md and PITFALLS.md are based on Ubuntu/Debian community sources. Some package names may differ in Trixie (e.g., `libgl1-mesa-glx` may be `libgl1-mesa-dri` on Trixie). Resolve by running `ldd` on the emulator binary during Dockerfile development.

- **Android Studio download URL stability:** The `edgedl.me.gvt1.com` CDN URL in STACK.md may not be stable across builds. Consider adding a URL check step in the Dockerfile or using the official redirect from developer.android.com. This is a build reliability concern, not a correctness concern.

- **GHA cache capacity for this variant:** STACK.md estimates 7-8 GB total image size; PITFALLS.md warns about exceeding the historical 10 GB limit. GitHub's Nov 2025 changelog states cache can now exceed 10 GB, but pricing implications for this private repo are unknown. Validate actual image size before committing to a cache strategy.

- **JDK 21 + cmdline-tools;latest compatibility:** PITFALLS.md notes cmdline-tools version history has a moving target with Java versions. The research recommends cmdline-tools;latest (12.0+) with Java 21. This combination should be validated early in Phase 1 development — specifically that `sdkmanager --list` succeeds and `flutter doctor --android-licenses` completes.

- **System image API level (35 vs 36):** STACK.md recommends API 35 system image because API 36 images may not be widely available. This should be verified at build time; if `system-images;android-36;google_apis;x86_64` is available via sdkmanager, it is the preferred target.

## Sources

### Primary (HIGH confidence)
- [Flutter SDK archive](https://docs.flutter.dev/install/archive) — Flutter 3.41.2 stable version confirmation
- [FVM installation docs](https://fvm.app/documentation/getting-started/installation) — standalone script method, FVM 4.0.5
- [Android Studio downloads](https://developer.android.com/studio) — Panda 1 2025.3.1.8 version and URL
- [Android SDK Platform release notes](https://developer.android.com/tools/releases/platforms) — API 36 confirmation
- [Android SDK Platform-Tools release notes](https://developer.android.com/tools/releases/platform-tools) — 36.0.2
- [Android Emulator release notes](https://developer.android.com/studio/releases/emulator) — 36.4.9, Lavapipe/Swiftshader
- [Java versions in Android builds](https://developer.android.com/build/jdks) — AGP 8.x JDK 17+ minimum, JBR details
- [Flutter Android setup guide](https://docs.flutter.dev/platform-integration/android/setup) — required SDK components
- [Android emulator acceleration](https://developer.android.com/studio/run/emulator-acceleration) — KVM/HAXM requirements
- [Android SDK cmdline-tools](https://developer.android.com/tools/sdkmanager) — sdkmanager documentation
- Existing project Dockerfiles (`base/Dockerfile`, `trixie-vnc-nvm-uv-claude/Dockerfile`, `trixie-rust-nvm-uv-claude/Dockerfile`) — project conventions, base image contents

### Secondary (MEDIUM confidence)
- [google/android-emulator-container-scripts](https://github.com/google/android-emulator-container-scripts) — emulator containerization patterns, KVM documentation
- [budtmo/docker-android](https://github.com/budtmo/docker-android) — noVNC + emulator patterns, memory/VNC pitfalls
- [thyrlian/AndroidSDK](https://github.com/thyrlian/AndroidSDK) — Qt xcb plugin issues
- [cirruslabs/docker-images-android](https://github.com/cirruslabs/docker-images-android) — used by Flutter CI itself; layer ordering reference
- [Deadolus/android-studio-docker](https://github.com/Deadolus/android-studio-docker) — Android Studio in Docker pattern
- [bizz84/claude-code-flutter-devcontainer](https://github.com/bizz84/claude-code-flutter-devcontainer) — Claude Code + Flutter DevContainer
- [ReactiveCircus/android-emulator-runner](https://github.com/ReactiveCircus/android-emulator-runner) — SwiftShader flags for CI
- [Dockerizing Flutter blog (Noveo, 2025)](https://blog.noveogroup.com/2025/11/dockerizing-flutter-mastering-flutter-docker-setup-struggle) — real-world Flutter + Docker pitfalls
- [GitHub Actions cache documentation](https://docs.docker.com/build/cache/backends/gha/) — 10 GB limit and eviction policies
- [GitHub Actions cache size expansion (Nov 2025)](https://github.blog/changelog/2025-11-20-github-actions-cache-size-can-now-exceed-10-gb-per-repository/) — cache now expandable beyond 10 GB

### Tertiary (LOW confidence)
- [matsp/docker-flutter](https://github.com/matsp/docker-flutter) — archived (2023); general feature comparison only
- [amrsa1/Android-Emulator-image](https://github.com/amrsa1/Android-Emulator-image) — VNC + emulator pattern, unverified for Trixie
- [ljishen/docker-vnc-android-studio](https://github.com/ljishen/docker-vnc-android-studio) — Android Studio VNC reference, older Ubuntu base

---
*Research completed: 2026-02-24*
*Ready for roadmap: yes*
