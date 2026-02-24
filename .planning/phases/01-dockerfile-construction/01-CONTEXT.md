# Phase 1: Dockerfile Construction - Context

**Gathered:** 2026-02-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Build a new Docker image variant (`trixie-vnc-flutter-rust-nvm-uv-claude`) that installs Flutter/FVM, Android SDK (API 35), Android emulator with pre-created AVD, Android Studio, Rust toolchain, and Chromium. The image must pass `flutter doctor` with no critical errors at build time. Runtime validation (emulator boots, Studio connects, web target works) is Phase 2. CI/CD integration is Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Base image lineage
- Extend `trixie-vnc-nvm-uv-claude` (chain: base -> VNC -> Flutter)
- Directory name: `trixie-vnc-flutter-rust-nvm-uv-claude`
- Single `USER root` block for all system-level installs, then `USER dev` for user-level tools (FVM, Rust)
- CI workflow remapping for the VNC parent image is deferred to Phase 3

### Rust inclusion
- Duplicate the install logic from `trixie-rust-nvm-uv-claude` (rustup + rustfmt, clippy, cargo-watch, cargo-edit, cargo-nextest)
- Install Rust last, after all Android/Flutter tools, as the `dev` user
- Clean up cargo registry/git cache after install (same as Rust variant)
- No FFI bridge packages (flutter_rust_bridge/rinf) -- deferred to v2 (DX-02)

### Emulator defaults
- Pixel 7 device profile for the pre-created AVD
- 2048 MB guest RAM
- 4096 MB internal storage
- AVD name: `flutter_pixel7`
- System image: x86_64, google_apis, API 35
- SwiftShader software rendering (no KVM required)

### Android Studio install
- Official tarball from dl.google.com
- Pin to a specific version in the Dockerfile (with comment noting version name, e.g. Meerkat)
- Install location: `/opt/android-studio`
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

</decisions>

<specifics>
## Specific Ideas

- Follow the pattern of existing variants: each Dockerfile is self-contained and independent
- The Rust install block should be recognizably similar to `trixie-rust-nvm-uv-claude/Dockerfile`
- CLAUDE.md append (CONV-02) should list all tools available in this variant

</specifics>

<deferred>
## Deferred Ideas

- Flutter-Rust FFI bridge packages (flutter_rust_bridge/rinf) -- v2 requirement DX-02
- Emulator auto-start entrypoint script -- v2 requirement EMUL-04
- Configurable Android API level via build arg -- v2 requirement EMUL-05
- Gradle and pub cache volume mount guidance -- v2 requirement DX-01

</deferred>

---

*Phase: 01-dockerfile-construction*
*Context gathered: 2026-02-24*
