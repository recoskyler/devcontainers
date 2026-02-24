# Phase 1: Dockerfile Construction - Research

**Researched:** 2026-02-24
**Domain:** Docker image construction for Flutter/Android/Rust development environment
**Confidence:** MEDIUM-HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Extend `trixie-vnc-nvm-uv-claude` (chain: base -> VNC -> Flutter)
- Directory name: `trixie-vnc-flutter-rust-nvm-uv-claude`
- Single `USER root` block for all system-level installs, then `USER dev` for user-level tools (FVM, Rust)
- CI workflow remapping for the VNC parent image is deferred to Phase 3
- Duplicate Rust install logic from `trixie-rust-nvm-uv-claude` (rustup + rustfmt, clippy, cargo-watch, cargo-edit, cargo-nextest)
- Install Rust last, after all Android/Flutter tools, as the `dev` user
- Clean up cargo registry/git cache after install (same as Rust variant)
- No FFI bridge packages (flutter_rust_bridge/rinf) -- deferred to v2 (DX-02)
- Pixel 7 device profile for the pre-created AVD
- 2048 MB guest RAM, 4096 MB internal storage
- AVD name: `flutter_pixel7`
- System image: x86_64, google_apis, API 35
- SwiftShader software rendering (no KVM required)
- Android Studio from official tarball, pinned version, install at `/opt/android-studio`
- Android SDK components installed via standalone cmdline-tools (independent of Studio)

### Claude's Discretion
- Exact Dockerfile layer ordering within the root and dev blocks
- apt-get package grouping strategy
- Environment variable naming and PATH construction
- Chromium installation method (apt vs download)
- FVM installation method and Flutter channel pinning
- ANDROID_HOME / ANDROID_SDK_ROOT path choice
- Build-tools version selection (latest compatible with API 35)
- `flutter doctor` error resolution approach

### Deferred Ideas (OUT OF SCOPE)
- Flutter-Rust FFI bridge packages (flutter_rust_bridge/rinf) -- v2 requirement DX-02
- Emulator auto-start entrypoint script -- v2 requirement EMUL-04
- Configurable Android API level via build arg -- v2 requirement EMUL-05
- Gradle and pub cache volume mount guidance -- v2 requirement DX-01
</user_constraints>

## Summary

This phase constructs a single Dockerfile that extends the existing VNC variant image and installs the Flutter/Android/Rust toolchain. The image is unique in this project because it chains from another variant (`trixie-vnc-nvm-uv-claude`) rather than directly from `devcontainer-base:latest`. For Phase 1, this means the VNC image must be pre-built locally before building the new variant. CI/CD remapping is deferred to Phase 3.

The Dockerfile follows a two-block structure: a `USER root` block installs all system packages (OpenJDK, Android SDK cmdline-tools, Android Studio, emulator dependencies, Chromium), then a `USER dev` block installs user-space tools (FVM + Flutter SDK, Android SDK components via sdkmanager, AVD creation, Rust toolchain). The critical validation is that `flutter doctor` passes with no critical errors at build time.

**Primary recommendation:** Build the Dockerfile in clear, sequential layers -- Java/system deps first, then Android SDK cmdline-tools bootstrap, then sdkmanager-based installs (platform-tools, build-tools, platform, system-image, emulator), then Android Studio tarball extraction, then FVM + Flutter, then Rust. Accept SDK licenses via `yes | sdkmanager --licenses` and run `flutter doctor` as a build verification step.

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| OpenJDK | 21 (`openjdk-21-jdk-headless`) | Java runtime for Android SDK tools | Available in Debian Trixie repos; JDK 21 is LTS; headless saves ~200MB |
| Android cmdline-tools | Latest (build 14742923) | Bootstrap sdkmanager for SDK component installs | Official standalone installer from Google |
| Android SDK platform | API 35 (Android 15) | Target platform for Flutter builds | Current Google Play requirement |
| Android build-tools | 35.0.0 | APK compilation tools | Matches API 35 target |
| Android emulator | Latest via sdkmanager | Android device emulation with SwiftShader | Bundled SwiftShader for no-KVM environments |
| Android Studio | Panda 1 (2025.3.1.8) | Full IDE for Android development | Latest stable; `flutter doctor` detects it at `/opt/android-studio` |
| FVM | 4.0.5 | Flutter version management | Latest stable; install script supports Docker containers |
| Flutter | Stable channel (via FVM) | Cross-platform UI framework | FVM manages version; stable is production default |
| Rust | Latest stable (via rustup) | Systems programming language | Matches existing `trixie-rust-nvm-uv-claude` pattern |
| Chromium | Trixie repo version | Web target browser for `flutter run -d chrome` | Available via `apt install chromium`; no external repo needed |

### Supporting

| Package | Purpose | When to Use |
|---------|---------|-------------|
| `libgl1` | OpenGL library for emulator SwiftShader | Required for software rendering |
| `libpulse0` | PulseAudio client library | Emulator audio (prevents missing lib errors) |
| `libx11-6`, `libxcb1` | X11 client libraries | Emulator display via Xvfb/VNC |
| `libxcomposite1`, `libxcursor1`, `libxi6`, `libxext6`, `libxfixes3`, `libxdamage1` | X11 extension libraries | Emulator and Android Studio GUI dependencies |
| `libnss3` | Network Security Services | Required by Chromium and Android Studio |
| `libglu1-mesa` | OpenGL Utility library | Emulator 3D rendering support |
| `libxrandr2`, `libxtst6` | X11 extensions | Android Studio GUI rendering |
| `libdbus-1-3` | D-Bus IPC library | Emulator inter-process communication |
| `libfontconfig1` | Font configuration | Emulator and Studio text rendering |
| `libasound2t64` | ALSA sound library | Emulator audio support on Trixie |
| `libstdc++6` | C++ standard library | Emulator native code |
| `zlib1g` | Compression library | Emulator and SDK tools |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Chromium (apt) | Google Chrome (deb download) | Chrome requires adding Google repo; Chromium is in Trixie repos, simpler, smaller |
| FVM | Direct Flutter SDK install | FVM adds version management; the install script now supports Docker containers since v4.0.5 |
| `openjdk-21-jdk-headless` | `openjdk-21-jdk` (full) | Full JDK adds ~200MB for GUI tools (javaws, etc.) not needed in a headless SDK context |
| `ANDROID_HOME` | `ANDROID_SDK_ROOT` | `ANDROID_SDK_ROOT` is the newer name but both work; use `ANDROID_HOME` for broadest compatibility as Flutter still references it |

## Architecture Patterns

### Recommended Dockerfile Structure

```
trixie-vnc-flutter-rust-nvm-uv-claude/
└── Dockerfile
```

The Dockerfile is self-contained and extends the VNC variant. No additional files or scripts are needed in the directory.

### Pattern 1: Two-Block USER Structure

**What:** All root-level installs in one `USER root` block, all user-level installs in one `USER dev` block.
**When to use:** Always -- this is a project convention from CLAUDE.md.
**Example:**
```dockerfile
FROM trixie-vnc-nvm-uv-claude:latest

USER root
ENV HOME=/root

# ... all apt-get installs, Android Studio tarball, cmdline-tools bootstrap ...

RUN chown -R dev:dev /home/dev

USER dev
ENV HOME=/home/dev

# ... FVM, Flutter SDK, sdkmanager installs, AVD creation, Rust ...
```

**Key detail:** When switching to `USER root`, must also set `ENV HOME=/root`. When switching back to `USER dev`, must reset `ENV HOME=/home/dev`. This is a project convention.

### Pattern 2: Android SDK Directory Layout

**What:** Standard Android SDK directory structure at a chosen root.
**When to use:** For all Android SDK component installs.
**Example:**
```
/home/dev/android-sdk/          # ANDROID_HOME
├── cmdline-tools/
│   └── latest/
│       └── bin/
│           ├── sdkmanager
│           └── avdmanager
├── platform-tools/
│   └── adb
├── build-tools/
│   └── 35.0.0/
├── platforms/
│   └── android-35/
├── emulator/
│   └── emulator
├── system-images/
│   └── android-35/
│       └── google_apis/
│           └── x86_64/
└── licenses/
```

**Recommendation:** Use `/home/dev/android-sdk` as `ANDROID_HOME` so all SDK content is user-owned. This avoids permission issues when `sdkmanager` writes to the SDK directory as the `dev` user.

### Pattern 3: cmdline-tools Bootstrap

**What:** Download and extract cmdline-tools ZIP, then use sdkmanager to install remaining components.
**When to use:** For setting up the Android SDK from scratch without Android Studio.
**Example:**
```dockerfile
# As root: download and set up cmdline-tools
ARG CMDLINE_TOOLS_URL=https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip
RUN mkdir -p /home/dev/android-sdk/cmdline-tools \
    && curl -fsSL "$CMDLINE_TOOLS_URL" -o /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d /tmp \
    && mv /tmp/cmdline-tools /home/dev/android-sdk/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip

# As dev: use sdkmanager to install components
RUN yes | sdkmanager --licenses \
    && sdkmanager \
        "platform-tools" \
        "platforms;android-35" \
        "build-tools;35.0.0" \
        "emulator" \
        "system-images;android-35;google_apis;x86_64"
```

### Pattern 4: AVD Pre-Creation

**What:** Create an AVD at build time so it is ready for immediate use.
**When to use:** For EMUL-03 (zero-config launch).
**Example:**
```dockerfile
RUN echo "no" | avdmanager create avd \
    --force \
    --name "flutter_pixel7" \
    --package "system-images;android-35;google_apis;x86_64" \
    --tag "google_apis" \
    --abi "x86_64" \
    --device "pixel_7"
```

The `echo "no"` answers the "Do you wish to create a custom hardware profile?" prompt. The `--force` flag overwrites any existing AVD with the same name.

After creation, configure SwiftShader rendering and hardware specs in the AVD config:

```dockerfile
RUN printf 'hw.gpu.enabled=yes\nhw.gpu.mode=swiftshader_indirect\nhw.ramSize=2048\nhw.sdCard.size=4096M\n' \
    >> $HOME/.android/avd/flutter_pixel7.avd/config.ini
```

### Pattern 5: Rust Install (Duplicated from Existing Variant)

**What:** Copy the exact Rust install block from `trixie-rust-nvm-uv-claude/Dockerfile`.
**When to use:** For TOOL-01.
**Example:**
```dockerfile
# As USER dev, after all Flutter/Android installs
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . "$HOME/.cargo/env" \
    && rustup component add rustfmt clippy \
    && cargo install cargo-watch cargo-edit \
    && cargo install --locked cargo-nextest \
    && rm -rf "$HOME/.cargo/registry" "$HOME/.cargo/git"

RUN echo 'source "$HOME/.cargo/env"' >> /home/dev/.bashrc
```

### Anti-Patterns to Avoid

- **Installing Android SDK as root in a system directory:** Causes permission issues when `sdkmanager` tries to write updates. Keep SDK under `/home/dev/` where the `dev` user has full ownership.
- **Using `&>` for redirects in RUN commands:** Docker uses `/bin/sh` (dash), which does not support `&>`. Use `>/dev/null 2>&1` instead. (Project convention from CLAUDE.md.)
- **Running FVM install.sh as root:** FVM v4.0.5 has smart container detection, but the script is designed for non-root users. Install as `USER dev`.
- **Forgetting `ENV HOME=` when switching USER:** Project convention requires setting `ENV HOME=/root` with `USER root` and `ENV HOME=/home/dev` with `USER dev`.
- **Installing Android Studio via apt or snap:** Neither is available in Debian Trixie. Use the official tarball from `dl.google.com`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Flutter version management | Manual git clone + channel switching | FVM (`curl -fsSL https://fvm.app/install.sh \| bash`) | FVM handles caching, switching, and per-project pinning |
| Android SDK management | Manual ZIP downloads for each component | `sdkmanager` from cmdline-tools | sdkmanager handles dependencies, updates, and license tracking |
| SDK license acceptance | Manual file creation in licenses/ dir | `yes \| sdkmanager --licenses` | Ensures all current licenses are accepted correctly |
| AVD creation | Manual config.ini file writing | `avdmanager create avd` | avdmanager generates correct hardware profile and paths |
| Rust toolchain | Manual binary downloads | `rustup` | rustup manages components, targets, and updates |
| Chromium path detection | Hardcoded binary path | `CHROME_EXECUTABLE` env var + `which chromium` | Path may vary by Debian version; env var is Flutter's standard |

**Key insight:** The Android SDK ecosystem is designed around `sdkmanager` and `avdmanager` CLI tools. These handle internal version dependencies, directory structure, and license files correctly. Manual file manipulation leads to subtle breakage with `flutter doctor`.

## Common Pitfalls

### Pitfall 1: cmdline-tools Directory Structure

**What goes wrong:** `sdkmanager` fails with "Could not determine SDK root" errors.
**Why it happens:** The cmdline-tools ZIP extracts to a `cmdline-tools/` directory, but sdkmanager expects to find itself at `$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager`. If you unzip directly into `$ANDROID_HOME/cmdline-tools/`, you get a nested `cmdline-tools/cmdline-tools/` structure.
**How to avoid:** Unzip to `/tmp`, then move `/tmp/cmdline-tools` to `$ANDROID_HOME/cmdline-tools/latest`.
**Warning signs:** "Error: Could not determine SDK root" when running sdkmanager.

### Pitfall 2: flutter doctor Android License Detection

**What goes wrong:** `flutter doctor` reports "Android license status unknown" even after accepting licenses with sdkmanager.
**Why it happens:** Flutter looks for licenses in `$ANDROID_HOME/licenses/` using its own license check. Sometimes `flutter doctor --android-licenses` uses a different Java version or classpath than standalone sdkmanager.
**How to avoid:** Accept licenses with both `yes | sdkmanager --licenses` and `yes | flutter doctor --android-licenses`. Ensure `JAVA_HOME` is set consistently.
**Warning signs:** `flutter doctor` shows a yellow/red warning about licenses after sdkmanager reports all accepted.

### Pitfall 3: Android Studio Detection by flutter doctor

**What goes wrong:** `flutter doctor` reports "Android Studio not found" despite installation at `/opt/android-studio`.
**Why it happens:** Flutter searches specific paths on Linux: `/opt/android-studio`, `$HOME/android-studio`, and paths from the JetBrains Toolbox. The path must be exactly `/opt/android-studio` with no additional hierarchy levels (not `/opt/android-studio/2025.3.1/`).
**How to avoid:** Extract the Android Studio tarball so that `/opt/android-studio/bin/studio.sh` exists. Optionally run `flutter config --android-studio-dir=/opt/android-studio` as a fallback.
**Warning signs:** `flutter doctor` shows "Android Studio not installed" section.

### Pitfall 4: Emulator Shared Library Dependencies

**What goes wrong:** The emulator binary crashes at launch with missing `.so` errors.
**Why it happens:** The Android emulator dynamically links against system libraries (libX11, libGL, libpulse, etc.) that are not installed in a minimal Debian image.
**How to avoid:** Install all required X11, GL, and audio libraries in the `USER root` apt-get block. The exact list is documented in the Standard Stack / Supporting section above.
**Warning signs:** `ldd` on the emulator binary shows "not found" entries.

### Pitfall 5: Large Image Size from Uncleaned Downloads

**What goes wrong:** Docker image balloons to 15+ GB.
**Why it happens:** Each RUN command creates a new layer. If you download a ZIP in one RUN and delete it in the next, the ZIP still exists in the previous layer.
**How to avoid:** Download, extract, and delete temporary files in the same RUN command. Clean `apt-get` caches, cargo registry, and SDK download caches.
**Warning signs:** `docker images` shows unexpectedly large image size.

### Pitfall 6: FVM PATH Not Available in Subsequent RUN Commands

**What goes wrong:** `fvm` command not found in RUN commands after installation.
**Why it happens:** FVM installs to `$HOME/.fvm/bin` or `$HOME/.local/bin` and adds to PATH via `.bashrc`, but Docker RUN commands don't source `.bashrc`.
**How to avoid:** Add FVM to PATH explicitly with `ENV PATH=$HOME/.fvm/bin:$PATH` (or wherever FVM installs) after the FVM installation RUN.
**Warning signs:** "fvm: command not found" in subsequent RUN layers.

### Pitfall 7: POSIX Shell Compatibility

**What goes wrong:** RUN commands fail with syntax errors.
**Why it happens:** Docker uses `/bin/sh` (dash on Debian) by default, which doesn't support bashisms like `&>`, `[[ ]]`, or `source`.
**How to avoid:** Use POSIX redirects (`>/dev/null 2>&1`), `[ ]` tests, and `. file` instead of `source file`. Note: the base image symlinks `/bin/sh` to `/bin/bash`, but relying on this is fragile and violates project convention.
**Warning signs:** "Syntax error" in RUN commands during build.

## Code Examples

### Complete Environment Variable Block

```dockerfile
# Android SDK
ENV ANDROID_HOME=/home/dev/android-sdk
ENV ANDROID_SDK_ROOT=$ANDROID_HOME
ENV PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH

# Java
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

# Chromium for Flutter web
ENV CHROME_EXECUTABLE=/usr/bin/chromium
```

### Android Studio Installation

```dockerfile
# Android Studio Panda 1 | 2025.3.1.8
ARG ANDROID_STUDIO_URL=https://edgedl.me.gvt1.com/android/studio/ide-zips/2025.3.1.8/android-studio-panda1-patch1-linux.tar.gz
RUN curl -fsSL "$ANDROID_STUDIO_URL" -o /tmp/android-studio.tar.gz \
    && tar -xzf /tmp/android-studio.tar.gz -C /opt/ \
    && rm /tmp/android-studio.tar.gz
```

### FVM + Flutter Installation (as USER dev)

```dockerfile
# Install FVM
RUN curl -fsSL https://fvm.app/install.sh | bash

ENV PATH=$HOME/.fvmrc/bin:$HOME/fvm/default/bin:$PATH

# Install Flutter stable via FVM
RUN fvm install stable \
    && fvm global stable
```

**Note:** The exact FVM binary path and Flutter symlink path need validation during implementation. FVM v4.0.5 may install to `$HOME/.fvm/bin/` or `$HOME/.local/bin/` depending on the install script version. Check `which fvm` after install.

### Build Verification Step

```dockerfile
# Verify the build
RUN flutter doctor -v \
    && flutter doctor --android-licenses 2>/dev/null || true
```

### CLAUDE.md Append (CONV-02)

```dockerfile
RUN printf '\n### Flutter & Android\n- `flutter`, `dart` via FVM (`fvm`)\n- Android SDK: cmdline-tools, platform-tools, build-tools 35.0.0, API 35\n- Android Emulator with SwiftShader (AVD: flutter_pixel7, Pixel 7)\n- Android Studio Panda 1 at /opt/android-studio\n- `chromium` (CHROME_EXECUTABLE set for `flutter run -d chrome`)\n\n### Rust\n- `rustc`, `cargo`, `rustup`, `rustfmt`, `clippy`\n- `cargo-watch`, `cargo-edit`, `cargo-nextest`\n' >> $HOME/.claude/CLAUDE.md
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ANDROID_SDK_ROOT` env var | Both `ANDROID_HOME` and `ANDROID_SDK_ROOT` accepted | 2023+ | Use `ANDROID_HOME` for broadest compatibility; set both for safety |
| Manual Flutter SDK git clone | FVM for version management | FVM 3.0+ (2023) | FVM handles switching, caching, and per-project pinning |
| `sdkmanager` from `tools` package | `sdkmanager` from `cmdline-tools` package | 2020 | Old `tools` package is deprecated; use `cmdline-tools/latest` |
| FVM install.sh blocks root | FVM v4.0.5 detects containers | Dec 2025 | Docker builds work without workarounds |
| Android Studio Meerkat | Android Studio Panda 1 (2025.3.1.8) | 2025 | Latest stable; pin version in Dockerfile |

**Deprecated/outdated:**
- `android-sdk-tools` (old `tools/` directory): Replaced by `cmdline-tools`. Do not download or reference.
- `ANDROID_SDK_ROOT`: Still works but `ANDROID_HOME` is the primary variable Flutter checks.

## Open Questions

1. **Exact FVM binary and Flutter SDK paths after install**
   - What we know: FVM installs via `curl -fsSL https://fvm.app/install.sh | bash` and manages Flutter SDKs in `$HOME/fvm/versions/`
   - What's unclear: The exact binary location (`$HOME/.fvm/bin/fvm` vs `$HOME/.local/bin/fvm`) and the symlink path for the global Flutter SDK (`$HOME/fvm/default/bin/flutter` vs something else)
   - Recommendation: Install FVM in a RUN, then immediately run `which fvm` and `fvm doctor` in the same layer to discover paths. Set ENV PATH accordingly.

2. **Android Studio tarball download URL stability**
   - What we know: Current URL is `https://edgedl.me.gvt1.com/android/studio/ide-zips/2025.3.1.8/android-studio-panda1-patch1-linux.tar.gz`
   - What's unclear: Google CDN URLs sometimes change or expire. The URL domain (`edgedl.me.gvt1.com`) is a Google CDN edge server.
   - Recommendation: Use the URL as an ARG so it can be updated without modifying the Dockerfile body. Add a comment with the version name.

3. **Complete list of emulator shared library dependencies on Trixie**
   - What we know: Core dependencies (libgl1, libpulse0, libx11-6, libxcb1, etc.) from community Dockerfiles
   - What's unclear: Exact package names may differ on Debian Trixie (e.g., `libasound2` vs `libasound2t64` on Trixie)
   - Recommendation: Install the known list, build, then run `ldd` on the emulator binary inside the image to find any remaining missing libraries.

4. **Docker image final size**
   - What we know: Android SDK + system image is ~3-4GB, Android Studio is ~1.4GB, Flutter SDK is ~1-2GB, Rust toolchain is ~1GB, plus base+VNC image
   - What's unclear: Final compressed and uncompressed size; whether GHA cache can handle it
   - Recommendation: Build locally, check `docker images` size. GHA cache concern is deferred to Phase 3.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FLUT-01 | FVM installed and Flutter stable SDK available via FVM | FVM v4.0.5 install script supports Docker containers; install as `USER dev`; use `fvm install stable && fvm global stable` |
| FLUT-02 | `flutter doctor` passes with no critical errors at build time | Run `flutter doctor -v` as final RUN; requires JAVA_HOME, ANDROID_HOME, CHROME_EXECUTABLE, Android Studio at `/opt/android-studio` |
| SDK-01 | OpenJDK installed with JAVA_HOME configured | `openjdk-21-jdk-headless` from Trixie repos; `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64` |
| SDK-02 | Android SDK cmdline-tools, platform-tools, and build-tools installed | cmdline-tools ZIP bootstrap + `sdkmanager "platform-tools" "build-tools;35.0.0"` |
| SDK-03 | Android platform (API 35) installed | `sdkmanager "platforms;android-35"` |
| SDK-04 | Android SDK licenses accepted at build time | `yes \| sdkmanager --licenses` + `yes \| flutter doctor --android-licenses` |
| EMUL-01 | Android system image (x86_64, google_apis, API 35) installed | `sdkmanager "system-images;android-35;google_apis;x86_64"` |
| EMUL-02 | Emulator runs with SwiftShader software rendering (no KVM required) | AVD config.ini with `hw.gpu.mode=swiftshader_indirect`; runtime validation in Phase 2 |
| EMUL-03 | Pre-created AVD with Pixel device profile for zero-config launch | `avdmanager create avd --name flutter_pixel7 --device pixel_7 --package "system-images;android-35;google_apis;x86_64"` + config.ini overrides for RAM/storage |
| IDE-01 | Full Android Studio IDE installed and launchable via VNC | Tarball from `dl.google.com`, extracted to `/opt/android-studio`; `flutter doctor` detects it there |
| TOOL-01 | Rust toolchain installed via rustup (cargo, rustc, clippy, rustfmt) | Duplicated from `trixie-rust-nvm-uv-claude/Dockerfile`; install as last `USER dev` step |
| DISP-01 | X11VNC/Xvfb display forwarding works for emulator and Studio GUI | Inherited from VNC parent image; Phase 1 ensures GUI library dependencies are installed |
| WEB-01 | Chromium installed with CHROME_EXECUTABLE configured | `apt install chromium`; `ENV CHROME_EXECUTABLE=/usr/bin/chromium` |
| CONV-01 | Dockerfile extends the VNC variant | `FROM trixie-vnc-nvm-uv-claude:latest` as first line |
| CONV-02 | Tools section appended to `~/.claude/CLAUDE.md` | `printf` append listing Flutter, Android SDK, Emulator, Android Studio, Chromium, Rust tools |
| CONV-03 | POSIX-compatible shell redirects used in Dockerfile RUN commands | Use `>/dev/null 2>&1`, not `&>`; use `. file` not `source file` in RUN (though base symlinks sh->bash) |
</phase_requirements>

## Sources

### Primary (HIGH confidence)
- [Android Studio Download Page](https://developer.android.com/studio) -- Current version: Panda 1 (2025.3.1.8); cmdline-tools download URL
- [Android sdkmanager docs](https://developer.android.com/tools/sdkmanager) -- Package install commands, license acceptance
- [Debian Trixie packages: openjdk-21-jdk](https://packages.debian.org/trixie/openjdk-21-jdk) -- Version 21.0.10+7-1~deb13u1
- [Debian Trixie packages: chromium](https://packages.debian.org/trixie/chromium) -- Available in default repos
- [FVM Installation docs](https://fvm.app/documentation/getting-started/installation) -- Install script, custom paths
- [FVM GitHub releases](https://github.com/leoafarias/fvm/releases) -- v4.0.5 (Dec 2025), Docker root fix
- Existing project Dockerfiles: `base/Dockerfile`, `trixie-vnc-nvm-uv-claude/Dockerfile`, `trixie-rust-nvm-uv-claude/Dockerfile`

### Secondary (MEDIUM confidence)
- [Google android-emulator-container-scripts Dockerfile](https://github.com/google/android-emulator-container-scripts/blob/master/emu/templates/Dockerfile) -- Emulator library dependencies
- [LionZXY/google-android-emulator Dockerfile](https://github.com/LionZXY/google-android-emulator/blob/master/Dockerfile) -- Emulator dependency list, env vars
- [Flutter website issue #12348](https://github.com/flutter/website/issues/12348) -- Android Studio detection path constraints
- [Flutter PR #75612](https://github.com/flutter/flutter/pull/75612) -- Android Studio detection fix for Linux
- [AVD management gist](https://gist.github.com/mrk-han/66ac1a724456cadf1c93f4218c6060ae) -- avdmanager commands, device profiles
- [FVM Docker root issue #864](https://github.com/leoafarias/fvm/issues/864) -- Container detection fix in v4.0.5

### Tertiary (LOW confidence)
- Emulator shared library list: Aggregated from multiple community Dockerfiles; exact Trixie package names need runtime validation
- FVM install paths: Need validation during build; may differ between v4.0.x minor versions
- Android Studio URL longevity: Google CDN URLs are not guaranteed stable

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- Versions confirmed from official download pages and package repos
- Architecture: MEDIUM-HIGH -- Patterns from existing project Dockerfiles + community Android Docker examples
- Pitfalls: MEDIUM -- Aggregated from multiple sources; Trixie-specific package names need validation
- Emulator dependencies: MEDIUM -- Library list from community Dockerfiles; exact Trixie names unverified

**Research date:** 2026-02-24
**Valid until:** 2026-03-24 (30 days; Android Studio and FVM versions may update)
