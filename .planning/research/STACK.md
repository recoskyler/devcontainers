# Stack Research

**Domain:** Docker-based DevContainer for Flutter full-stack mobile development
**Researched:** 2026-02-24
**Confidence:** MEDIUM (Android SDK tooling versions move fast; some version numbers verified via official docs, others inferred from multiple sources)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended | Confidence |
|------------|---------|---------|-----------------|------------|
| Flutter SDK | 3.41.x (via FVM) | Cross-platform mobile framework | Latest stable (Feb 2026). Installed via FVM, not directly — allows per-project pinning. FVM pulls the SDK so no manual Flutter download in Dockerfile. | HIGH |
| FVM | 4.0.5 | Flutter version manager | Standalone install script (`curl -fsSL https://fvm.app/install.sh \| bash`), no Dart prereq. Installs to `$HOME/fvm`, adds `$HOME/fvm/bin` to PATH. Standard in Flutter community for multi-version workflows. | HIGH |
| Android Studio | Panda 1 (2025.3.1 Patch 1) | Full IDE for Android/Flutter dev | Latest stable. Required for flutter doctor, bundled JDK (JBR/JDK 21), Gradle daemon, and visual emulator management. 1.4 GB tarball for Linux. Launchable via VNC. | HIGH |
| Android SDK Command-Line Tools | latest (via `sdkmanager`) | SDK package management | Bootstrapped from `commandlinetools-linux-14742923_latest.zip` (172.8 MB). Then `sdkmanager` installs remaining components. Use `cmdline-tools;latest` channel. | MEDIUM |
| Android SDK Platform | API 36 (Android 16) | Compile/target SDK | Flutter 3.41 targets API 36. Revision 1 released March 2025. This is the compile SDK version Flutter expects. | HIGH |
| Android SDK Build-Tools | 36.0.x | APK/AAB building | Matches API 36 platform. Installed via `sdkmanager "build-tools;36.0.0"`. | MEDIUM |
| Android SDK Platform-Tools | 36.0.2 | ADB, fastboot | Latest stable (Sept 2025). Required for device communication and emulator management. | HIGH |
| Android Emulator | 36.4.9 | Android device emulation | Latest stable (Feb 2026). Supports software rendering via Lavapipe (new default) and Swiftshader (proven fallback). Headless mode available. | HIGH |
| System Image | `system-images;android-35;google_apis;x86_64` | Emulator OS image | API 35 (not 36) — API 36 system images may not be widely available yet. Google APIs variant includes Google services needed for most Flutter apps. x86_64 for performance with KVM. | MEDIUM |
| OpenJDK | 21 | Java runtime for Gradle/Android builds | Android Studio Panda bundles JBR (JetBrains Runtime based on JDK 21). AGP 8.x requires minimum JDK 17. Installing OpenJDK 21 in the container ensures Gradle compatibility outside the IDE too. | HIGH |
| Rust | 1.93.x (via rustup) | Systems language for backend | Latest stable (Feb 2026). Installed via `rustup` as user dev, same pattern as existing `trixie-rust-nvm-uv-claude` variant. | HIGH |
| NVM | 0.40.4 | Node.js version manager | Latest stable (Jan 2025). Already in the base image at v0.40.3 — bump to 0.40.4 if building from scratch, but the base image provides this already. | HIGH |
| Node.js | 24.13.x LTS | JavaScript runtime | Current LTS "Krypton" (Feb 2026). Already provided by base image. | HIGH |
| UV | 0.10.4 | Python package manager | Latest (Feb 2026). Installed via `curl -LsSf https://astral.sh/uv/install.sh \| sh`. Already in base image. | HIGH |

### Display & VNC Stack

| Technology | Purpose | Why Recommended | Confidence |
|------------|---------|-----------------|------------|
| xvfb | Virtual framebuffer X server | Provides a virtual display (`:99`) for headless rendering. Android Studio and emulator render to this. Already in VNC variant. | HIGH |
| x11vnc | VNC server | Exports the xvfb display over VNC. Already in VNC variant. Combined with `DISPLAY=:99` gives full GUI access. | HIGH |
| xdg-utils | Desktop integration | Already in VNC variant. Provides `xdg-open` for launching apps. | HIGH |
| dbus-x11 | D-Bus for X11 apps | Android Studio requires D-Bus session bus. Install `dbus-x11` and start `dbus-daemon` or use `dbus-launch`. | MEDIUM |
| libgl1-mesa-dri + libgl1-mesa-glx | OpenGL libraries | Required for emulator software rendering. Mesa provides the GL implementation for Lavapipe/Swiftshader. | MEDIUM |
| libpulse0 | Audio stub | Emulator expects PulseAudio libraries even if audio is unused. Prevents startup errors. | LOW |
| libxcomposite1, libxrandr2, libxtst6, libxi6 | X11 extension libraries | Android Studio Swing/AWT GUI requires these X11 extensions to render properly in xvfb. | MEDIUM |

### Emulator Configuration

| Setting | Value | Why | Confidence |
|---------|-------|-----|------------|
| GPU mode | `-gpu swiftshader_indirect` | Proven software renderer for containers. Lavapipe is newer default but Swiftshader is more battle-tested in Docker/CI. Falls back gracefully. | MEDIUM |
| No-window | `-no-window` | Headless — rendering goes to xvfb DISPLAY, not a native window. | HIGH |
| No-audio | `-noaudio` | No audio device in container. Prevents hangs. | HIGH |
| No-boot-anim | `-no-boot-anim` | Faster boot time. | HIGH |
| No-snapshot | `-no-snapshot` | Clean boot each time. Snapshot save/load unreliable in containers. | MEDIUM |
| KVM | `--device /dev/kvm` (Docker run flag) | x86_64 emulator needs KVM for acceptable performance. Host must support nested virtualization or bare-metal KVM. Without KVM, emulator is unusably slow. | HIGH |
| Memory | `-memory 2048` | 2 GB RAM for emulator. Default may be too low for API 35. | MEDIUM |

### Supporting Libraries (Debian Trixie APT)

| Package | Purpose | When Needed |
|---------|---------|-------------|
| `openjdk-21-jdk-headless` | JDK for Gradle and Android builds | Always — required for `flutter build apk` and Android Studio |
| `lib32stdc++6` | 32-bit C++ runtime | Android SDK tools have 32-bit dependencies on 64-bit hosts |
| `lib32z1` | 32-bit zlib | Same — Android SDK 32-bit binary compatibility |
| `libgl1-mesa-dri` | Mesa DRI drivers | Emulator software rendering (Lavapipe/Swiftshader backend) |
| `mesa-vulkan-drivers` | Vulkan drivers | Lavapipe Vulkan software renderer (emulator default in 36.4.9+) |
| `qemu-kvm` | KVM support check | Not installed in image — but host must provide `/dev/kvm` |
| `unzip`, `wget`, `curl` | Download tools | Already in base image |
| `fonts-noto` | Unicode font support | Android Studio UI and emulator need fonts for rendering |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `adb` (via platform-tools) | Android Debug Bridge | USB device forwarding requires `--device /dev/bus/usb` Docker flag on host. Container sees devices via adb. |
| `sdkmanager` | SDK component management | Bootstrap tool. Install from cmdline-tools zip, then use to install everything else. |
| `avdmanager` | AVD creation/management | Create emulator AVD: `avdmanager create avd -n flutter_emu --abi google_apis/x86_64 -k "system-images;android-35;google_apis;x86_64"` |
| `flutter doctor` | Environment validation | Must pass with no critical errors. Key checks: Android SDK, Android Studio, connected devices. |
| `cargo-watch`, `cargo-edit`, `cargo-nextest` | Rust dev tools | Same as existing rust variant. Installed via `cargo install`. |

## Installation

```bash
# ---- As root ----

# System dependencies for Android Studio, emulator, and Java
apt-get update && apt-get install -y --no-install-recommends \
    openjdk-21-jdk-headless \
    lib32stdc++6 \
    lib32z1 \
    libgl1-mesa-dri \
    mesa-vulkan-drivers \
    dbus-x11 \
    libpulse0 \
    libxcomposite1 \
    libxrandr2 \
    libxtst6 \
    libxi6 \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libgbm1 \
    fonts-noto \
    fonts-noto-color-emoji

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

# ---- Android SDK (as root, in /opt/android-sdk) ----

# Download and extract command-line tools
mkdir -p /opt/android-sdk/cmdline-tools
curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip \
    -o /tmp/cmdline-tools.zip
unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-tmp
mv /tmp/cmdline-tools-tmp/cmdline-tools /opt/android-sdk/cmdline-tools/latest
rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools-tmp

export ANDROID_HOME=/opt/android-sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH

# Accept licenses and install SDK components
yes | sdkmanager --licenses >/dev/null 2>&1
sdkmanager \
    "platform-tools" \
    "platforms;android-36" \
    "platforms;android-35" \
    "build-tools;36.0.0" \
    "system-images;android-35;google_apis;x86_64" \
    "emulator" \
    "ndk;27.0.12077973" \
    "cmake;3.22.1"

# ---- Android Studio (as root, in /opt/android-studio) ----

curl -fsSL https://edgedl.me.gvt1.com/android/studio/ide-zips/2025.3.1.8/android-studio-panda1-patch1-linux.tar.gz \
    -o /tmp/android-studio.tar.gz
tar -xzf /tmp/android-studio.tar.gz -C /opt/
rm /tmp/android-studio.tar.gz

# Symlink studio.sh for PATH
ln -s /opt/android-studio/bin/studio.sh /usr/local/bin/android-studio

# Set ownership
chown -R dev:dev /opt/android-sdk /opt/android-studio

# ---- As user dev ----

# FVM (standalone, no Dart required)
curl -fsSL https://fvm.app/install.sh | bash
# Adds $HOME/fvm/bin to PATH
echo 'export PATH="$HOME/fvm/bin:$PATH"' >> ~/.bashrc

# Install Flutter stable via FVM
fvm install stable
fvm global stable

# Add FVM Flutter to PATH
echo 'export PATH="$HOME/fvm/default/bin:$PATH"' >> ~/.bashrc

# Rust (same pattern as existing variant)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
echo 'source "$HOME/.cargo/env"' >> ~/.bashrc

# Create default AVD
avdmanager create avd -n flutter_emu \
    --abi google_apis/x86_64 \
    -k "system-images;android-35;google_apis;x86_64" \
    --device "pixel_6" \
    --force
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| FVM (standalone script) | `dart pub global activate fvm` | Only if Dart is already installed for other reasons. Standalone avoids the Dart prereq chicken-and-egg problem. |
| FVM | Direct Flutter SDK install via `git clone` | Only for single-version setups that never change. FVM adds trivial overhead but massive flexibility. |
| Android Studio (full IDE) | Android SDK CLI only (no IDE) | Only if VNC/GUI is not needed and builds are CLI-only. PROJECT.md explicitly requires Android Studio launchable via VNC. |
| `system-images;android-35;google_apis;x86_64` | `system-images;android-36;google_apis;x86_64` | When API 36 system images are confirmed stable and widely available. API 35 is proven and sufficient. |
| `system-images;...;google_apis;x86_64` | `system-images;...;default;x86_64` | Only if Google services are not needed. Most Flutter apps use Firebase/Google APIs, so `google_apis` variant is safer default. |
| Swiftshader (`-gpu swiftshader_indirect`) | Lavapipe (new emulator default) | Lavapipe is the new default in emulator 36.4.9+ and may work better. But Swiftshader has years of Docker/CI battle-testing. Try Lavapipe first, fall back to Swiftshader if issues arise. |
| OpenJDK 21 | OpenJDK 17 | If Gradle/AGP issues arise with JDK 21. AGP 8.x requires minimum JDK 17. JDK 21 is what Android Studio Panda bundles (JBR), so 21 is the correct match. |
| x86_64 system image + KVM | ARM64 system image (no KVM) | Only if KVM is absolutely unavailable. ARM emulation on x86 is 10-50x slower. Not viable for development. |
| API 35 system image | API 34 system image | If API 35 image has stability issues. API 34 is well-proven. But API 35 should be preferred for current Flutter targeting. |
| NVM (in base image) | fnm, volta | No reason to switch. NVM is already installed in the base image. Adding another version manager creates confusion. |
| UV (in base image) | pip, pipx, pyenv | No reason to switch. UV is already in the base image and is the modern standard. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Installing Flutter directly (no FVM) | Cannot pin versions per project. Upgrading breaks other projects. FVM is the standard approach. | FVM with `fvm install stable` and `fvm global stable` |
| `snap` packages in Docker | Snap requires `snapd` daemon, doesn't work reliably in containers, adds bloat. Android Studio snap is broken in Docker. | Direct tarball extraction to `/opt/android-studio` |
| `flatpak` packages in Docker | Same problems as snap — runtime daemon, heavy, not container-friendly. | Direct tarball or apt packages |
| Alpine base image | Flutter/Dart binaries link against glibc. Alpine uses musl. Incompatible without heroic workarounds. | Debian Trixie (project standard) |
| Android emulator without KVM | x86_64 emulator without KVM is unusably slow (10-50x performance penalty). Effectively broken for dev workflows. | Require `--device /dev/kvm` at container runtime. Document as hard requirement. |
| `sdkmanager --channel=3` (canary) | Canary SDK components are unstable. Breakage risk in a DevContainer that should "just work". | Stable channel only (`--channel=0`, the default) |
| Multiple Java versions (JDK 17 + 21) | Causes PATH confusion, JAVA_HOME conflicts, Gradle resolution issues. Pick one. | OpenJDK 21 only. Matches Android Studio Panda JBR. |
| `emulator -no-window` without xvfb | Without a DISPLAY, Android Studio also can't run. The VNC variant already provides xvfb — use it. | `DISPLAY=:99` with xvfb-run, then x11vnc exports it |
| `google_apis_playstore` system image | Play Store images require Google sign-in, add unnecessary weight, and can't be rooted. Overkill for development. | `google_apis` variant |

## Stack Patterns by Variant

**If KVM is available (bare-metal host or nested virt):**
- Use `system-images;android-35;google_apis;x86_64`
- Emulator with `-gpu swiftshader_indirect` (or try `-gpu auto` for Lavapipe)
- Performance is near-native for UI interactions
- This is the expected/recommended path

**If KVM is NOT available:**
- Emulator will not work at acceptable speed
- Use `flutter build apk` for build-only workflows
- Connect physical device via USB forwarding (`--device /dev/bus/usb`)
- Document this limitation clearly in CLAUDE.md and image README

**If host has GPU passthrough (e.g., NVIDIA with `--gpus all`):**
- Use `-gpu host` for hardware-accelerated emulator rendering
- Significantly faster than software rendering
- Rare in practice — don't design around this

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| Flutter 3.41.x | API 36 (compile), API 35 (system image) | Flutter targets API 36 for compilation but API 35 system image is used for emulator |
| AGP 8.x | JDK 17+ (minimum), JDK 21 (recommended) | Android Gradle Plugin requires JDK 17 minimum. JDK 21 matches Android Studio Panda bundled JBR |
| OpenJDK 21 | Gradle 8.5+ | Gradle 8.5 added JDK 21 support. Flutter's bundled Gradle wrapper handles this. |
| FVM 4.0.5 | Flutter 1.x through 3.41.x | FVM manages any Flutter version. No compatibility constraints. |
| Android Emulator 36.4.9 | API 28-36 system images | Backwards compatible. Using API 35 is well within support range. |
| Rust 1.93.x | Independent | No interaction with Flutter/Android stack. Isolated toolchain. |
| NVM 0.40.4 / Node 24.x | Independent | No interaction with Flutter/Android stack. Isolated runtime. |
| UV 0.10.4 / Python 3.x | Independent | No interaction with Flutter/Android stack. Isolated runtime. |

## Image Size Considerations

| Component | Estimated Size | Notes |
|-----------|---------------|-------|
| Android Studio tarball | ~1.4 GB | Extracted to `/opt/android-studio` |
| Android SDK (platforms, build-tools, tools) | ~500 MB | After sdkmanager installs |
| System image (API 35 google_apis x86_64) | ~1.2 GB | Single system image |
| Android Emulator | ~300 MB | Installed via sdkmanager |
| Flutter SDK (via FVM) | ~1.5 GB | Full SDK with framework, engine, tools |
| OpenJDK 21 | ~300 MB | Headless variant |
| Rust toolchain | ~500 MB | rustc + cargo + stdlib |
| **Total image overhead** | **~5.7 GB** | On top of VNC variant base (~2 GB) |
| **Expected total image** | **~7-8 GB** | Large but acceptable for full-stack mobile DevContainer |

## Environment Variables

```bash
# Android
ANDROID_HOME=/opt/android-sdk
ANDROID_SDK_ROOT=/opt/android-sdk       # deprecated alias, but some tools still check it
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

# Flutter/FVM
FVM_HOME=$HOME/fvm
PATH=$HOME/fvm/default/bin:$HOME/fvm/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH

# Display (VNC variant provides these)
DISPLAY=:99
```

## Dockerfile Layer Strategy

The recommended Dockerfile structure (extending VNC variant):

1. **Root: System packages** (apt-get) — OpenJDK, 32-bit libs, X11 libs, fonts
2. **Root: Android SDK** — cmdline-tools bootstrap, sdkmanager installs
3. **Root: Android Studio** — tarball extraction to `/opt`
4. **Root: Ownership** — `chown -R dev:dev` on SDK and Studio dirs
5. **User dev: FVM + Flutter** — standalone script, install stable, set global
6. **User dev: Rust** — rustup + cargo tools (same as rust variant)
7. **User dev: AVD creation** — pre-create a default emulator AVD
8. **User dev: CLAUDE.md** — append tools section
9. **User dev: flutter doctor** — validation step (may need to accept licenses)

## Sources

- [Flutter SDK archive](https://docs.flutter.dev/install/archive) -- Flutter 3.41.2 stable (Feb 2026). HIGH confidence.
- [Flutter release notes 3.41](https://docs.flutter.dev/release/release-notes/release-notes-3.38.0) -- Feature details. HIGH confidence.
- [FVM GitHub releases](https://github.com/leoafarias/fvm/releases) -- FVM 4.0.5 (Dec 2025). HIGH confidence.
- [FVM installation docs](https://fvm.app/documentation/getting-started/installation) -- Standalone script method. HIGH confidence.
- [Android Studio downloads](https://developer.android.com/studio) -- Panda 1 2025.3.1 Patch 1, exact download URL and checksum. HIGH confidence.
- [Android SDK Platform release notes](https://developer.android.com/tools/releases/platforms) -- API 36 (Android 16). HIGH confidence.
- [Android SDK Platform-Tools release notes](https://developer.android.com/tools/releases/platform-tools) -- 36.0.2. HIGH confidence.
- [Android Emulator release notes](https://developer.android.com/studio/releases/emulator) -- 36.4.9 (Feb 2026), Lavapipe/Swiftshader details. HIGH confidence.
- [Java versions in Android builds](https://developer.android.com/build/jdks) -- AGP 8.x requires JDK 17+, JBR details. HIGH confidence.
- [Android SDK CLI tools release notes](https://developer.android.com/tools/releases/cmdline-tools) -- Version info. MEDIUM confidence (exact "latest" number unclear).
- [Flutter Android setup guide](https://docs.flutter.dev/platform-integration/android/setup) -- Required SDK components. HIGH confidence.
- [Rust releases](https://blog.rust-lang.org/releases/latest/) -- Rust 1.93.1 (Feb 2026). HIGH confidence.
- [NVM releases](https://github.com/nvm-sh/nvm/releases) -- NVM 0.40.4 (Jan 2025). HIGH confidence.
- [UV on PyPI](https://pypi.org/project/uv/) -- UV 0.10.4 (Feb 2026). HIGH confidence.
- [Node.js releases](https://nodejs.org/en/blog/release/v24.13.1) -- Node 24.13.1 LTS (Feb 2026). HIGH confidence.
- [docker-android by HQarroum](https://github.com/HQarroum/docker-android) -- Docker emulator patterns. MEDIUM confidence.
- [budtmo/docker-android](https://github.com/budtmo/docker-android) -- noVNC + emulator Docker patterns. MEDIUM confidence.
- [Deadolus/android-studio-docker](https://github.com/Deadolus/android-studio-docker) -- Android Studio in Docker reference. MEDIUM confidence.
- [Flutter Android Java/Gradle migration guide](https://docs.flutter.dev/release/breaking-changes/android-java-gradle-migration-guide) -- JDK/Gradle compatibility. HIGH confidence.

---
*Stack research for: Flutter full-stack mobile DevContainer (Debian Trixie VNC variant)*
*Researched: 2026-02-24*
