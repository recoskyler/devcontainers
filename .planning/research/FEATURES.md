# Feature Research

**Domain:** Flutter full-stack mobile DevContainer Docker image (Android Studio, emulator, Rust, Node, Python)
**Researched:** 2026-02-24
**Confidence:** MEDIUM -- established patterns for individual components exist, but the combined full-stack image with VNC is uncommon; most competitors focus on CI/build only or omit the IDE entirely.

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Flutter SDK via FVM | Core language runtime; FVM is the standard version manager in Flutter community | LOW | Install FVM, `fvm install stable`, set PATH. FVM allows per-project Flutter version pinning via `.fvmrc`. |
| Android SDK command-line tools | Required for `flutter build apk`, `flutter doctor`, and all Android compilation | MEDIUM | Need `cmdline-tools/latest`, `platform-tools`, `build-tools;35.0.0`, `platforms;android-35`. License acceptance via `yes \| sdkmanager --licenses`. |
| Android emulator with system image | Developers expect to run apps without a physical device | HIGH | Requires `emulator` package + `system-images;android-35;google_apis;x86_64`. Software rendering via SwiftShader (`-gpu swiftshader_indirect`). Pre-create AVD during build. Needs 2-3 GB extra. |
| X11VNC display forwarding for emulator | Emulator GUI must be visible; project already has VNC variant | LOW | Inherited from trixie-vnc variant. Xvfb + x11vnc already available. Emulator renders to virtual framebuffer, visible via VNC client. |
| `flutter doctor` passes clean | Universal Flutter sanity check; failing = broken image | MEDIUM | Requires JDK, Android SDK, cmdline-tools, accepted licenses, and correct PATH/env vars. Must pass with no critical errors at build time. |
| JDK 17 (OpenJDK) | Android build toolchain requires JDK 17; Flutter uses it via Gradle | LOW | `apt-get install openjdk-17-jdk-headless`. Set JAVA_HOME. JDK 17 is the current stable requirement for Android Gradle Plugin 8.x. |
| Rust toolchain (rustup, cargo, rustc) | Explicitly required per PROJECT.md; enables Flutter-Rust FFI (rinf, flutter_rust_bridge) | LOW | Same pattern as existing trixie-rust variant. Install via rustup as user, add clippy/rustfmt, cargo-watch, cargo-edit, cargo-nextest. |
| NVM + Node.js LTS | Explicitly required per PROJECT.md; backend services, tooling | LOW | Already in base image. Inherited via devcontainer-base. Node 24.x + npm + pnpm + tsx. |
| UV for Python | Explicitly required per PROJECT.md; Python package management | LOW | Already in base image. Inherited via devcontainer-base. Fast pip replacement from Astral. |
| Android SDK license acceptance | Build-time requirement; `flutter doctor` fails without it; CI blocks on interactive prompts | LOW | `yes \| sdkmanager --licenses` in Dockerfile. Must run after all SDK packages installed. |
| Append tools to `~/.claude/CLAUDE.md` | Project convention -- all variants do this so Claude Code knows available tools | LOW | `printf` append with Flutter, FVM, Android SDK, Rust, emulator info. Follow existing pattern from rust/vnc variants. |
| CI/CD integration (build.yml + check.yml) | New variant must build in GitHub Actions matrix | MEDIUM | Add `flutter` to matrix in both workflows. New GHA cache scope `flutter`. Image will be large (10-16 GB); may need extended build timeout. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Full Android Studio IDE via VNC | Most Flutter Docker images omit the IDE; having it lets developers use the full GUI (layout inspector, profiler, device manager) over VNC | HIGH | ~1 GB download. Silent install from tarball. Launchable via VNC. Most competitors only provide cmdline-tools. Adds significant image size but huge DX value. |
| Pre-created AVD device profile | Zero-config emulator start -- `emulator -avd dev_device` works immediately | LOW | `avdmanager create avd -n dev_device -k "system-images;android-35;google_apis;x86_64" -d pixel_7` during build. Saves developers 5-10 min of first-time setup. |
| Flutter + Rust FFI ready (cargo + Dart FFI) | Combined stack enables flutter_rust_bridge / rinf workflows out of the box; rare in DevContainer images | LOW | Both Rust and Flutter installed. No extra tooling needed beyond what's already table stakes. Documenting the capability in CLAUDE.md is the differentiator. |
| Claude Code + MCP servers pre-configured | AI-assisted development with semantic code analysis, context7 docs, memory -- unique to this project | LOW | Inherited from base image. Already configured with serena, context7, memory MCPs. No competitors have this. |
| Chromium for Flutter web development | Enables `flutter run -d chrome` and `flutter test --platform chrome` inside the container | MEDIUM | `apt-get install chromium`. Set `CHROME_EXECUTABLE=/usr/bin/chromium`. Enables web target alongside Android without leaving the container. |
| Configurable Android API level via build arg | Different projects target different Android versions; build arg makes image flexible | LOW | `ARG ANDROID_API=35` controlling which platform/system-image/build-tools to install. Avoids maintaining multiple images. |
| Gradle + pub cache volume mount guidance | Dramatically faster rebuilds; avoids re-downloading 500+ MB of dependencies per project | LOW | Not baked into image, but documented in devcontainer.json examples. Mount `~/.gradle` and `~/.pub-cache` as named volumes. |
| ADB wireless debugging support | Physical device testing without USB passthrough (which is platform-dependent and fragile) | LOW | ADB is included via platform-tools. `adb pair` / `adb connect` over network. Document the workflow; no extra image work needed. Avoids the USB passthrough anti-feature. |
| Multi-target ready (Android + Web + Linux desktop) | One image serves all three Linux-buildable Flutter targets | HIGH | Android (emulator), Web (Chromium), Linux desktop (GTK libs + clang + cmake + ninja-build + pkg-config + libgtk-3-dev). Significant extra deps for Linux desktop target. |
| Entrypoint script for emulator auto-start | Container starts with emulator already running and VNC ready -- developer just connects | MEDIUM | Script that starts Xvfb, x11vnc, and emulator on container start. Requires careful process management (supervisor or simple shell script). |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| USB device passthrough for ADB | Physical device testing feels native | Platform-dependent (works on Linux, broken on macOS/Windows Docker); requires `--privileged` mode; fragile with device connect/disconnect; security risk | Use ADB wireless debugging (`adb pair`/`adb connect`). Works cross-platform, no privileged mode needed. Document the workflow. |
| GPU passthrough for emulator acceleration | Faster emulator rendering | Requires host GPU drivers, NVIDIA container toolkit, `--gpus` flag; not portable across machines; broken on most CI; adds huge complexity | Use SwiftShader software rendering (`-gpu swiftshader_indirect`). Slower but works everywhere. Acceptable for development. |
| KVM hardware acceleration for emulator | Faster emulator boot and execution | Requires `/dev/kvm` access on host; not available in most cloud VMs, CI runners, or nested virtualization scenarios; Docker Desktop on macOS/Windows lacks KVM | Document KVM as optional performance boost for Linux bare-metal hosts. Default to `-no-accel` or auto-detect. Image must work without KVM. |
| iOS/Xcode support | Full cross-platform Flutter development | Impossible on Linux containers. macOS only. Fundamentally cannot work. | Explicitly document as out of scope. iOS builds require a separate macOS machine or CI service (Codemagic, GitHub Actions macOS runners). |
| Pre-installed Android Studio plugins | Customized IDE experience | Plugins change frequently; increases image size; user preferences vary widely; plugins may conflict | Let users install plugins post-container-start. Android Studio syncs plugin state. Document recommended plugins in CLAUDE.md. |
| Multiple Android API levels pre-installed | Support testing across many Android versions | Each system image is 1-2 GB. Installing multiple doubles/triples image size. Most developers target 1-2 API levels. | Install one default API level (latest stable). Provide build arg to customize. Document how to install additional via sdkmanager at runtime. |
| Genymotion or third-party emulators | Potentially faster/lighter than stock emulator | Licensing issues (Genymotion is commercial for non-personal use); adds vendor dependency; stock emulator with SwiftShader is sufficient | Use stock Android emulator with SwiftShader. Free, well-maintained, official Google support. |
| Full Android NDK | Native C/C++ development for Android | 1.5+ GB download; most Flutter projects don't need NDK directly; Rust FFI uses its own cross-compilation | Omit NDK by default. Document how to install via `sdkmanager "ndk;28.0.12674087"` at runtime if needed for specific projects. |

## Feature Dependencies

```
[Base image (devcontainer-base)]
    |
    +--extends--> [VNC variant (trixie-vnc)]
                      |
                      +--extends--> [Flutter variant] (this image)
                                        |
                                        +--requires--> [JDK 17]
                                        |                  |
                                        |                  +--required-by--> [Android SDK]
                                        |                                        |
                                        |                                        +--required-by--> [Android emulator + system image]
                                        |                                        |
                                        |                                        +--required-by--> [Android Studio IDE]
                                        |                                        |
                                        |                                        +--required-by--> [flutter doctor passes]
                                        |                                        |
                                        |                                        +--required-by--> [Pre-created AVD]
                                        |
                                        +--requires--> [FVM + Flutter SDK]
                                        |                  |
                                        |                  +--required-by--> [flutter doctor passes]
                                        |                  |
                                        |                  +--enhances--> [Rust toolchain] (Flutter-Rust FFI)
                                        |
                                        +--requires--> [Xvfb + x11vnc] (inherited from VNC variant)
                                        |                  |
                                        |                  +--required-by--> [Android emulator display]
                                        |                  |
                                        |                  +--required-by--> [Android Studio GUI]
                                        |
                                        +--independent--> [Rust toolchain]
                                        |
                                        +--independent--> [NVM + Node.js] (inherited from base)
                                        |
                                        +--independent--> [UV + Python] (inherited from base)
                                        |
                                        +--optional--> [Chromium] --enhances--> [Flutter web target]
                                        |
                                        +--optional--> [Linux desktop libs] --enhances--> [Flutter Linux target]

[CI/CD integration] --requires--> [Dockerfile builds successfully]
                     --requires--> [GHA cache scope configured]

[flutter doctor passes] --requires--> [JDK 17]
                        --requires--> [Android SDK + licenses]
                        --requires--> [FVM + Flutter SDK]
                        --optional--> [Chromium] (for web target check)
                        --optional--> [Android Studio] (for IDE check, non-critical)
```

### Dependency Notes

- **Flutter variant requires VNC variant:** Emulator and Android Studio both need display forwarding. The VNC variant already provides Xvfb + x11vnc.
- **Android SDK requires JDK 17:** Gradle and sdkmanager both need JDK. JDK 17 is the minimum for AGP 8.x. Must be installed before any sdkmanager commands.
- **flutter doctor requires Android SDK + Flutter SDK + JDK:** All three must be correctly configured (PATH, ANDROID_HOME, JAVA_HOME, licenses accepted) for a clean pass.
- **Pre-created AVD requires system image:** The system image must be installed via sdkmanager before `avdmanager create avd` can run.
- **Rust enhances Flutter:** Not a hard dependency, but having both enables flutter_rust_bridge and rinf. This is a unique value proposition.
- **Chromium enhances Flutter web:** Optional but valuable; enables a second target platform without extra machines.
- **Linux desktop libs conflict with image size goals:** GTK/clang/ninja add significant size; should be a separate concern or build arg.

## MVP Definition

### Launch With (v1)

Minimum viable product -- what's needed to validate the concept.

- [ ] Dockerfile extending VNC variant -- establishes the build chain
- [ ] JDK 17 installed -- prerequisite for everything Android
- [ ] Android SDK (cmdline-tools, platform-tools, build-tools, platform) -- core Android toolchain
- [ ] FVM + Flutter stable installed -- core Flutter runtime
- [ ] Android emulator + system image (x86_64, google_apis, API 35) -- run apps without physical device
- [ ] Pre-created AVD with Pixel 7 profile -- zero-config emulator launch
- [ ] Software rendering via SwiftShader -- works without GPU/KVM
- [ ] Rust toolchain (rustup, cargo, clippy, rustfmt) -- per requirements
- [ ] `flutter doctor` passes clean -- validation gate
- [ ] Android SDK licenses accepted -- build-time requirement
- [ ] CLAUDE.md tools section appended -- project convention
- [ ] CI/CD matrix entry added -- must build in GitHub Actions

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] Android Studio IDE via VNC -- add once emulator+SDK proves stable in container; significant image size increase
- [ ] Chromium for Flutter web target -- add when developers request multi-target
- [ ] Configurable Android API level build arg -- add when different teams need different API levels
- [ ] Entrypoint script for emulator auto-start -- add once manual emulator start is validated
- [ ] Gradle/pub cache volume mount documentation -- add as devcontainer.json examples

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Linux desktop target support (GTK libs, clang, ninja) -- high image size cost, niche demand
- [ ] Multi-target entrypoint (Android + Web + Linux) -- complexity of managing multiple targets simultaneously
- [ ] Android NDK as optional build arg -- only for projects doing native C/C++ Android dev
- [ ] Pre-configured Flutter integration test runner -- needs Chromium + emulator orchestration

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| FVM + Flutter SDK | HIGH | LOW | P1 |
| JDK 17 | HIGH | LOW | P1 |
| Android SDK (cmdline-tools, platform-tools, build-tools) | HIGH | MEDIUM | P1 |
| Android emulator + system image + AVD | HIGH | HIGH | P1 |
| Software rendering (SwiftShader) | HIGH | LOW | P1 |
| Rust toolchain | HIGH | LOW | P1 |
| `flutter doctor` clean pass | HIGH | MEDIUM | P1 |
| SDK license acceptance | HIGH | LOW | P1 |
| CLAUDE.md append | MEDIUM | LOW | P1 |
| CI/CD matrix integration | HIGH | MEDIUM | P1 |
| Android Studio IDE via VNC | MEDIUM | HIGH | P2 |
| Chromium (Flutter web) | MEDIUM | MEDIUM | P2 |
| Configurable API level build arg | LOW | LOW | P2 |
| Pre-created AVD | MEDIUM | LOW | P1 |
| ADB wireless debugging docs | LOW | LOW | P2 |
| Emulator auto-start entrypoint | MEDIUM | MEDIUM | P2 |
| Gradle/pub cache mount guidance | MEDIUM | LOW | P2 |
| Flutter-Rust FFI documentation | LOW | LOW | P3 |
| Linux desktop target | LOW | HIGH | P3 |
| Android NDK (optional) | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | matsp/docker-flutter (archived) | Deadolus/android-studio-docker | budtmo/docker-android | bizz84/claude-code-flutter | mingc/android-build-box | Our Approach |
|---------|--------------------------------|-------------------------------|----------------------|---------------------------|------------------------|--------------|
| Flutter SDK | Yes (direct install) | Yes (with Android Studio) | No (Android only) | Yes (git clone stable) | Yes (3.32.4) | FVM-managed (version pinning per project) |
| Android Studio IDE | No | Yes (full GUI) | No | No | No | Yes, via VNC (P2, differentiator) |
| Android emulator | Yes (Pixel, Android 9) | Yes (with display) | Yes (API 28-34, noVNC) | No | Yes (basic) | Yes, pre-created AVD, SwiftShader |
| Display forwarding | X11 forwarding | SSH + display | noVNC web UI | None | None | x11vnc (inherited from VNC variant) |
| KVM required | Yes | Yes | Yes | N/A | No | No (works without, optional boost) |
| Rust toolchain | No | No | No | No | No | Yes (unique combination) |
| Node.js | No | No | No | No | Yes (v22) | Yes, via NVM (inherited from base) |
| Python | No | No | No | No | Yes (3.8) | Yes, via UV (inherited from base) |
| Claude Code / AI tools | No | No | No | Yes (Claude Code) | No | Yes + MCP servers + hooks (strongest) |
| Web target (Chrome) | Yes (port 8090) | No | No | No | No | Chromium (P2) |
| CI/CD optimized | No | No | No | No | Yes (primary purpose) | Yes, GHA matrix with cache |
| Image size | ~8 GB | ~6 GB | ~10 GB | ~3 GB (no SDK) | ~16 GB | Est. 12-18 GB (full stack) |
| Active maintenance | Archived (2023) | Low activity | Active | Active | Active | Active (this project) |

## Sources

- [matsp/docker-flutter](https://github.com/matsp/docker-flutter) -- archived Flutter Docker image with emulator support (MEDIUM confidence)
- [Deadolus/android-studio-docker](https://github.com/Deadolus/android-studio-docker) -- Android Studio + Flutter in Docker with display forwarding (MEDIUM confidence)
- [budtmo/docker-android](https://github.com/budtmo/docker-android) -- Android emulator in Docker with noVNC, device profiles (MEDIUM confidence)
- [bizz84/claude-code-flutter-devcontainer](https://github.com/bizz84/claude-code-flutter-devcontainer) -- Claude Code + Flutter DevContainer without Android SDK (HIGH confidence)
- [mingchen/docker-android-build-box](https://github.com/mingchen/docker-android-build-box) -- optimized Android/Flutter CI build image (MEDIUM confidence)
- [google/android-emulator-container-scripts](https://github.com/google/android-emulator-container-scripts) -- official Google Android emulator containerization (HIGH confidence)
- [sambyeol/flutter-devcontainer](https://github.com/sambyeol/flutter-devcontainer) -- archived Flutter DevContainer with SDK (LOW confidence, archived)
- [FVM installation docs](https://fvm.app/documentation/getting-started/installation) -- official FVM documentation (HIGH confidence)
- [Flutter troubleshooting](https://docs.flutter.dev/install/troubleshoot) -- official Flutter doctor requirements (HIGH confidence)
- [Android developer tools](https://developer.android.com/tools) -- official Android SDK command-line tools documentation (HIGH confidence)
- [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup) -- official Flutter Android setup guide (HIGH confidence)
- [Android emulator acceleration](https://developer.android.com/studio/run/emulator-acceleration) -- official docs on KVM/GPU requirements (HIGH confidence)
- [Dockerizing Flutter blog (Noveo, 2025)](https://blog.noveogroup.com/2025/11/dockerizing-flutter-mastering-flutter-docker-setup-struggle) -- recent Docker+Flutter practices (MEDIUM confidence)
- [BrightCoding Docker Android guide (2025)](https://www.blog.brightcoding.dev/2025/09/03/how-to-run-a-full-android-device-inside-a-docker-container/) -- 2025 guide on Android in Docker (MEDIUM confidence)

---
*Feature research for: Flutter full-stack mobile DevContainer*
*Researched: 2026-02-24*
