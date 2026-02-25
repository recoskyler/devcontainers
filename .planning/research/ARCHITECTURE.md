# Architecture Research

**Domain:** Flutter + Android Studio DevContainer Docker Image
**Researched:** 2026-02-24
**Confidence:** MEDIUM

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Docker Image Layer Stack                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Layer 5 — Flutter + FVM + CLAUDE.md append        (USER dev)       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  FVM → Flutter SDK  │  flutter doctor  │  CLAUDE.md patch   │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  Layer 4 — Android Studio IDE                      (USER root)      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  android-studio tar.gz → /opt/android-studio               │    │
│  │  Desktop entry / symlink for VNC launch                     │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  Layer 3 — Android SDK + Emulator                  (USER root)      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  cmdline-tools → sdkmanager                                │    │
│  │  platform-tools (adb, fastboot)                            │    │
│  │  build-tools;36.0.0                                        │    │
│  │  platforms;android-36                                       │    │
│  │  emulator + system-images;android-34;google_apis;x86_64    │    │
│  │  License acceptance (yes | sdkmanager --licenses)           │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  Layer 2 — JDK + Android GUI dependencies          (USER root)      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  openjdk-17-jdk  │  lib32z1  │  X11/GL libs for emulator   │    │
│  │  libgl1 libglu1 libpulse0 libnss3 libxcomposite1 ...      │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  Layer 1 — Rust toolchain                          (USER dev)       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  rustup → rustc, cargo, rustfmt, clippy                    │    │
│  │  cargo-watch, cargo-edit, cargo-nextest                     │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  Layer 0 — VNC variant (FROM devcontainer-base:latest)              │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  x11vnc  │  xvfb  │  xdg-utils                            │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  Base — devcontainer-base:latest (Debian Trixie)                    │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  NVM + Node.js  │  UV  │  Claude Code  │  git, curl, etc.  │    │
│  │  ttyd  │  GH CLI  │  AWS CLI  │  kubectl  │  Terraform     │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Architectural Decision: Inline VNC vs. Extend VNC Variant

There are two options for how the Flutter image relates to the existing VNC variant:

**Option A — FROM the VNC variant image (three-level chain: base -> VNC -> flutter)**
- Pros: Maximum reuse, VNC variant stays a single source of truth
- Cons: CI/CD three-level dependency chain requires building VNC first, then flutter; the current two-job workflow (base + variants in parallel) would need a third sequential phase or special handling
- CI impact: The `build-contexts` remap only maps `devcontainer-base:latest` today; a second remap for `devcontainer-vnc:latest` is needed, or VNC must be pushed to the local registry first

**Option B — Inline VNC packages into the Flutter Dockerfile (two-level: base -> flutter)**
- Pros: Fits existing CI perfectly (two-phase: base, then variants in parallel); no workflow changes needed; the VNC layer is only 3 lines of apt-get
- Cons: Duplicates VNC apt-get from the VNC Dockerfile (3 packages: x11vnc, xvfb, xdg-utils); must stay in sync manually

**Recommendation: Option B (inline VNC).** The VNC layer is trivially small (3 packages, ~10MB). Duplicating it avoids all CI/CD complexity. The Flutter Dockerfile does `FROM devcontainer-base:latest` and installs VNC packages itself, exactly like the existing VNC variant does. This keeps the CI matrix flat and parallel. If VNC grows substantially in the future, reconsider Option A.

### Component Responsibilities

| Component | Responsibility | Communicates With |
|-----------|----------------|-------------------|
| devcontainer-base (Debian Trixie) | OS, NVM/Node, UV/Python, Claude Code, common CLI tools | All downstream variants |
| VNC layer (inlined) | Virtual framebuffer (xvfb) + VNC server (x11vnc) for headless GUI | Android Studio, Android Emulator, any X11 app |
| JDK 17 | Java runtime required by Android toolchain and Gradle | Android SDK, Android Studio, Flutter build system |
| Android SDK (cmdline-tools) | sdkmanager, avdmanager, platform-tools, build-tools | Flutter SDK (flutter doctor), Android Studio, Emulator |
| Android Emulator + system image | Virtual Android device for testing | VNC/xvfb for display, ADB for communication |
| Android Studio IDE | Full IDE for Flutter/Android development | VNC/xvfb for display, Android SDK, Flutter SDK |
| Rust toolchain (rustup) | Rust compiler, cargo, dev tools | Independent; for backend/FFI work |
| FVM + Flutter SDK | Flutter framework and CLI, version-managed | Android SDK, JDK, Chrome (for web) |
| CLAUDE.md append | Declares available tools for Claude Code agent | Claude Code CLI |

## Recommended Dockerfile Structure

```
trixie-vnc-flutter-rust-nvm-uv-claude/
└── Dockerfile           # Single Dockerfile, extends devcontainer-base:latest
```

### Dockerfile Layer Ordering (Detailed)

```dockerfile
# ── FROM ─────────────────────────────────────────────────────────────
FROM devcontainer-base:latest

# ── Layer 0: VNC (inlined from vnc variant) ──────────────────────────
USER root
ENV HOME=/root

RUN apt-get update \
    && apt-get -y install --no-install-recommends \
    x11vnc xvfb xdg-utils \
    ...cleanup...

# ── Layer 1: JDK + Android GUI dependencies ─────────────────────────
#    These MUST come before Android SDK because sdkmanager needs java
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
    openjdk-17-jdk \
    lib32z1 libgl1 libglu1-mesa libpulse0 libnss3 \
    libxcomposite1 libxcursor1 libxdamage1 libxi6 \
    libxrandr2 libxrender1 libxtst6 libfreetype6 \
    fontconfig fonts-dejavu ...
    ...cleanup...

# ── Layer 2: Android SDK (cmdline-tools + sdkmanager) ───────────────
#    Install cmdline-tools, then use sdkmanager for everything else
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator

ARG ANDROID_SDK_TOOLS_VERSION=13114758

RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_TOOLS_VERSION}_latest.zip \
    && unzip ... \
    && yes | sdkmanager --licenses \
    && sdkmanager \
        "platform-tools" \
        "build-tools;36.0.0" \
        "platforms;android-36" \
        "emulator" \
        "system-images;android-34;google_apis;x86_64"

# ── Layer 3: Android Studio IDE ─────────────────────────────────────
#    Separate layer — large download (~1GB), changes less frequently
ARG ANDROID_STUDIO_VERSION=2025.3.1.8

RUN wget -q https://dl.google.com/dl/android/studio/ide-zips/${ANDROID_STUDIO_VERSION}/android-studio-...-linux.tar.gz \
    && tar xzf ... -C /opt/ \
    && rm ...tar.gz

ENV PATH=${PATH}:/opt/android-studio/bin

# ── Layer 4: Rust (as user dev) ──────────────────────────────────────
RUN chown -R dev:dev /home/dev

USER dev
ENV HOME=/home/dev

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . "$HOME/.cargo/env" \
    && rustup component add rustfmt clippy \
    && cargo install cargo-watch cargo-edit \
    && cargo install --locked cargo-nextest

# ── Layer 5: FVM + Flutter ───────────────────────────────────────────
#    FVM must come AFTER Android SDK is installed so flutter doctor sees it
RUN curl -fsSL https://fvm.app/install.sh | bash \
    && export PATH="$HOME/.local/bin:$PATH" \
    && fvm install stable \
    && fvm global stable

ENV PATH=${HOME}/fvm/default/bin:${HOME}/.pub-cache/bin:${PATH}

# ── Layer 6: Validation + CLAUDE.md ──────────────────────────────────
RUN flutter doctor --android-licenses \
    && flutter doctor

RUN printf '\n### Flutter + Android\n...\n### Rust\n...\n' >> $HOME/.claude/CLAUDE.md
```

### Structure Rationale

- **VNC first (Layer 0):** Must be present before any GUI app is installed so DISPLAY is configurable; trivially small, almost never changes
- **JDK before Android SDK (Layer 1 before 2):** sdkmanager requires java on PATH; without JDK, cmdline-tools fail to run
- **Android SDK before Android Studio (Layer 2 before 3):** Studio expects ANDROID_HOME to exist and may attempt first-run SDK sync; pre-installing SDK avoids interactive prompts
- **Android Studio as separate layer (Layer 3):** ~1GB download; keeping it in its own RUN means SDK changes do not re-download Studio and vice versa
- **Rust as user dev (Layer 4):** rustup installs per-user by design; does not need root; independent of Android toolchain
- **FVM/Flutter last (Layer 5):** flutter doctor validates the entire stack; FVM needs the Android SDK and JDK already on PATH to report a clean bill of health
- **CLAUDE.md append last (Layer 6):** Must come after all tools are installed so the list is accurate

## Data Flow

### Component Dependency Graph

```
                devcontainer-base:latest
                         │
                         ▼
              ┌──────────────────────┐
              │  VNC: xvfb + x11vnc  │
              └──────────┬───────────┘
                         │
              ┌──────────┴───────────┐
              │     JDK 17           │
              └──────────┬───────────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
    ┌───────────┐  ┌──────────┐  ┌──────────┐
    │ Android   │  │ Android  │  │ Gradle   │
    │ cmdline-  │  │ Emulator │  │ (bundled │
    │ tools +   │  │ + system │  │ w/Studio)│
    │ SDK pkgs  │  │ image    │  │          │
    └─────┬─────┘  └────┬─────┘  └────┬─────┘
          │              │             │
          ▼              ▼             ▼
    ┌──────────────────────────────────────┐
    │         Android Studio IDE            │
    └──────────────────┬───────────────────┘
                       │
                       ▼
    ┌──────────────────────────────────────┐
    │     FVM → Flutter SDK                 │
    │  (validates with flutter doctor)      │
    └──────────────────────────────────────┘

    ┌──────────────────────────────────────┐
    │  Rust (rustup) — independent chain   │
    └──────────────────────────────────────┘
```

### Runtime Display Flow

```
[Android Studio / Emulator]
    │
    │  X11 protocol (DISPLAY=:99)
    ▼
[Xvfb — virtual framebuffer]
    │
    │  Shares X11 display
    ▼
[x11vnc — VNC server]
    │
    │  VNC protocol (port 5900)
    ▼
[Host VNC client or noVNC in browser]
```

### Build & Run Flow (Flutter App)

```
[Developer via VNC or terminal]
    │
    ├─→ flutter run (via FVM)
    │       │
    │       ├─→ Gradle build (uses JDK 17)
    │       │       │
    │       │       └─→ Android SDK build-tools + platform-tools
    │       │
    │       └─→ ADB → Emulator (or physical device)
    │               │
    │               └─→ Display via Xvfb → x11vnc → VNC client
    │
    └─→ Android Studio (via VNC display)
            │
            ├─→ Flutter plugin → flutter commands
            ├─→ Gradle integration → JDK
            └─→ AVD Manager → Emulator → Display
```

### ADB Device Forwarding

```
[Host physical Android device]
    │
    │  USB → host ADB server (port 5037)
    │
    ├─→ Option A: --device=/dev/bus/usb in docker run
    │       └─→ Container ADB detects device directly
    │
    └─→ Option B: adb forward / adb connect
            └─→ Container connects to host ADB server via network
```

### Key Data Flows

1. **Build flow:** Flutter CLI → Gradle → Android SDK build-tools → APK/AAB output
2. **Emulator flow:** avdmanager creates AVD → emulator launches on DISPLAY=:99 → Xvfb renders → x11vnc serves
3. **IDE flow:** Android Studio renders on DISPLAY=:99 → Xvfb → x11vnc → VNC client on host
4. **Hot reload:** Flutter CLI → ADB → running emulator instance → instant UI update

## Architectural Patterns

### Pattern 1: Parameterized Versions via ARG

**What:** Use Docker ARG for all version-pinned components so they can be overridden at build time without modifying the Dockerfile.
**When to use:** Every versioned component (Android SDK tools version, Android Studio version, API level, system image, JDK version).
**Trade-offs:** Adds ARG lines but makes CI matrix expansion trivial; default values serve as "known-good" pins.

```dockerfile
ARG JDK_VERSION=17
ARG ANDROID_SDK_TOOLS_VERSION=13114758
ARG ANDROID_STUDIO_VERSION=2025.3.1.8
ARG ANDROID_API_LEVEL=36
ARG ANDROID_BUILD_TOOLS_VERSION=36.0.0
ARG ANDROID_SYSTEM_IMAGE="system-images;android-34;google_apis;x86_64"
```

### Pattern 2: License Acceptance in Build

**What:** Accept all Android SDK licenses non-interactively during build so there are no interactive prompts.
**When to use:** Always, in every Android SDK Docker image.
**Trade-offs:** None; this is mandatory.

```dockerfile
RUN yes | sdkmanager --licenses >/dev/null 2>&1
```

### Pattern 3: Emulator System Image Selection

**What:** Use x86_64 Google APIs system image (not Google Play) for the emulator.
**When to use:** DevContainer environments where KVM may or may not be available.
**Trade-offs:** Google APIs image is smaller than Google Play; x86_64 requires KVM on x86 hosts but is far faster than ARM emulation. Software rendering (`-gpu swiftshader_indirect`) works without GPU passthrough but is slow.

```dockerfile
# Prefer API 34 for emulator stability; API 36 for build target
RUN sdkmanager "system-images;android-34;google_apis;x86_64"
```

## CI/CD Integration

### Current CI Structure (Two-Phase)

```
Phase 1: Build base image → push to local registry:2
Phase 2: Build variant matrix (bun, php, rust, vnc) in parallel
         Each variant: FROM devcontainer-base:latest
         Remapped via: build-contexts devcontainer-base:latest=docker-image://localhost:5000/...
```

### Flutter Variant Integration

Because the Flutter Dockerfile uses `FROM devcontainer-base:latest` (with VNC inlined), it fits directly into the existing Phase 2 matrix as another parallel job:

```yaml
matrix:
  include:
    - name: trixie-bun-nvm-uv-claude
      scope: bun
    - name: trixie-php-nvm-uv-claude
      scope: php
    - name: trixie-rust-nvm-uv-claude
      scope: rust
    - name: trixie-vnc-nvm-uv-claude
      scope: vnc
    - name: trixie-vnc-flutter-rust-nvm-uv-claude    # NEW
      scope: flutter                                   # NEW
```

**No workflow structural changes needed.** Only a matrix entry addition in both `build.yml` and `check.yml`.

### Build Time & Cache Considerations

| Layer | Estimated Size | Cache Stability |
|-------|---------------|-----------------|
| VNC packages | ~10 MB | Very stable (rarely changes) |
| JDK 17 + GUI libs | ~300 MB | Stable (version-pinned) |
| Android SDK cmdline-tools + packages | ~1.5 GB | Moderate (API level bumps) |
| Android Studio IDE | ~1 GB | Moderate (quarterly releases) |
| Emulator system image | ~1 GB | Stable (pinned API level) |
| Rust toolchain | ~500 MB | Stable (infrequent updates) |
| FVM + Flutter SDK | ~800 MB | Moderate (Flutter releases) |
| **Total estimated** | **~5+ GB** | |

**GHA cache scope:** `flutter` — keeps cache independent of other variants.

**Build time warning:** This variant will take significantly longer than others (20-40 minutes vs. 5-10 minutes for simpler variants). The `timeout-minutes: 30` in the current workflow may need to be increased to 60 for this variant, or the timeout can be set per-matrix-entry.

## Scaling Considerations

| Concern | Approach |
|---------|----------|
| Image size (~5+ GB) | Accept it; Android SDK + Studio is inherently large. Use GHA layer caching aggressively. Do not attempt to slim below functional minimum. |
| Build time (~30+ min) | GHA cache handles repeat builds well; first build is slow. Consider splitting into a multi-stage build where SDK layers are cached separately if build times become problematic. |
| Emulator performance | Requires KVM for acceptable speed; document `--device=/dev/kvm` in docker run. Software rendering works but is slow. |
| Disk in container | Android builds produce large intermediate artifacts (~2-4 GB Gradle cache). Mount workspace as volume; do not embed project files in the image. |

## Anti-Patterns

### Anti-Pattern 1: Installing Android Studio via apt/snap

**What people do:** Attempt to install Android Studio through package managers inside Docker.
**Why it's wrong:** apt has no official Android Studio package; snap requires snapd/systemd which does not work in Docker. The only reliable method is the tar.gz archive.
**Do this instead:** Download the tar.gz from Google's CDN and extract to `/opt/android-studio`.

### Anti-Pattern 2: Running sdkmanager Before JDK Is Installed

**What people do:** Install cmdline-tools and immediately try to use sdkmanager.
**Why it's wrong:** sdkmanager is a Java program; without JDK on PATH, it silently fails or produces cryptic errors.
**Do this instead:** Always install JDK first, verify `java -version`, then proceed with sdkmanager.

### Anti-Pattern 3: Using a Three-Level FROM Chain in CI Without Registry Support

**What people do:** `FROM vnc-variant:latest` in the Flutter Dockerfile, then struggle with CI not being able to resolve the intermediate image.
**Why it's wrong:** The current CI remap only handles `devcontainer-base:latest`. A second remap adds complexity and creates a sequential dependency (base -> vnc -> flutter) that breaks the parallel matrix.
**Do this instead:** Inline the VNC packages (3 packages, trivially small) and keep `FROM devcontainer-base:latest`.

### Anti-Pattern 4: Embedding System Images for Multiple API Levels

**What people do:** Install 3-4 system images to "cover all bases."
**Why it's wrong:** Each system image is ~1 GB. The image bloats to 8+ GB with no benefit since developers only run one emulator at a time.
**Do this instead:** Ship one system image (API 34 with Google APIs); let users install additional images at runtime via `sdkmanager`.

### Anti-Pattern 5: Skipping flutter doctor in Build

**What people do:** Install Flutter and assume the toolchain is complete.
**Why it's wrong:** Flutter has strict requirements on exactly which SDK components are present. Missing one component means a broken developer experience at container startup.
**Do this instead:** Run `flutter doctor` as the final build step. If it reports errors, the build should fail.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| GHCR (GitHub Container Registry) | Push final image; same as other variants | Private registry; auth via GITHUB_TOKEN |
| Google CDN (dl.google.com) | Download Android Studio + SDK cmdline-tools during build | May rate-limit in CI; consider caching the zip in GHA cache |
| FVM install script (fvm.app) | Curl-pipe-bash installation | Standard pattern; version-pinnable |
| Rustup (sh.rustup.rs) | Curl-pipe-bash installation | Same as existing rust variant |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Flutter SDK ↔ Android SDK | Via `ANDROID_HOME` env var + PATH | flutter doctor validates this link |
| Android Studio ↔ Android SDK | Via `ANDROID_HOME` env var | Studio reads SDK location from env or `~/.android` |
| Emulator ↔ VNC display | Via `DISPLAY` env var + Xvfb | Must start Xvfb before emulator; typically via entrypoint script |
| ADB ↔ Emulator | Via localhost:5554/5555 | Emulator listens; ADB connects automatically |
| ADB ↔ Physical device | Via USB passthrough or network ADB | Requires `--device=/dev/bus/usb` or `adb connect host.docker.internal` |
| Gradle ↔ JDK | Via `JAVA_HOME` env var | Must be JDK 17+ for AGP 8.x compatibility |

## Build Order Summary

The strict build order (each step depends on the previous):

1. **devcontainer-base:latest** (already built by CI Phase 1)
2. **VNC packages** (xvfb, x11vnc — needed for any GUI display)
3. **JDK 17** (required by sdkmanager, Gradle, Android Studio)
4. **Android SDK cmdline-tools** (requires JDK; provides sdkmanager)
5. **Android SDK packages via sdkmanager** (platform-tools, build-tools, platforms, emulator, system-image)
6. **Android Studio IDE** (requires SDK; large standalone download)
7. **Rust toolchain** (independent; placed here to keep root/dev user switching clean)
8. **FVM + Flutter SDK** (requires Android SDK + JDK for flutter doctor validation)
9. **flutter doctor + CLAUDE.md append** (validates entire stack; must be last)

## Sources

- [Flutter Android setup documentation](https://docs.flutter.dev/platform-integration/android/setup) — MEDIUM confidence (official docs, verified)
- [Google android-emulator-container-scripts](https://github.com/google/android-emulator-container-scripts) — MEDIUM confidence (official Google project)
- [thyrlian/AndroidSDK Dockerfile](https://hub.docker.com/r/thyrlian/android-sdk) — MEDIUM confidence (widely-used community image, verified layer ordering)
- [cirruslabs/docker-images-android](https://github.com/cirruslabs/docker-images-android/blob/master/sdk/tools/Dockerfile) — MEDIUM confidence (used by Flutter CI itself)
- [Deadolus/android-studio-docker](https://github.com/Deadolus/android-studio-docker) — LOW confidence (older project, Ubuntu 18.04, but validated architecture pattern)
- [FVM official site](https://fvm.app/documentation/getting-started/installation) — HIGH confidence (official documentation)
- [Android SDK cmdline-tools](https://developer.android.com/tools/sdkmanager) — HIGH confidence (official Google documentation)
- [Docker multi-stage builds and build-contexts](https://www.docker.com/blog/dockerfiles-now-support-multiple-build-contexts/) — HIGH confidence (official Docker documentation)
- [amrsa1/Android-Emulator-image](https://github.com/amrsa1/Android-Emulator-image) — LOW confidence (community project, but validated VNC+emulator pattern)
- [budtmo/docker-android](https://github.com/budtmo/docker-android) — MEDIUM confidence (active project, noVNC + emulator patterns)
- Existing project Dockerfiles (`base/Dockerfile`, `trixie-vnc-nvm-uv-claude/Dockerfile`, `trixie-rust-nvm-uv-claude/Dockerfile`) — HIGH confidence (primary source of truth for project conventions)

---
*Architecture research for: Flutter + Android Studio DevContainer Docker Image*
*Researched: 2026-02-24*
