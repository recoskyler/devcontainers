# DevContainer: trixie-vnc-flutter-rust-nvm-uv-claude

## What This Is

A DevContainer Docker image variant for full-stack Flutter mobile development. Extends the VNC variant to provide Flutter (managed via FVM) with Android Studio, Android SDK/emulator (SwiftShader software rendering), Rust, Node (via NVM), and Python (via UV) — all with X11VNC display forwarding. Includes a 13-check runtime validation script and automated CI/CD via GitHub Actions.

## Core Value

A developer can open this DevContainer and immediately build, run, and debug a Flutter app with Android Studio and emulator, alongside Rust/Node/Python backend services, without installing anything on the host.

## Requirements

### Validated

- ✓ Dockerfile extends VNC variant and installs Flutter via FVM — v1.0
- ✓ Full Android Studio IDE installed and launchable via VNC — v1.0
- ✓ Android SDK with cmdline-tools, platform-tools, build-tools, emulator, and system image (API 35) — v1.0
- ✓ Android emulator runs with SwiftShader software rendering (no KVM required) — v1.0
- ✓ Pre-created AVD (Pixel 7) for zero-config emulator launch — v1.0
- ✓ Rust toolchain installed (rustup, cargo, rustc, clippy, rustfmt, cargo-watch, cargo-edit, cargo-nextest) — v1.0
- ✓ NVM + Node.js LTS available (inherited from base) — v1.0
- ✓ UV available for Python package management (inherited from base) — v1.0
- ✓ ADB wireless debugging documented for physical device connectivity — v1.0
- ✓ `flutter doctor` passes with no critical errors — v1.0
- ✓ Variant appends tools section to `~/.claude/CLAUDE.md` — v1.0
- ✓ Added to GitHub Actions build and check workflows with isolated `flutter` cache scope — v1.0
- ✓ Chromium installed with CHROME_EXECUTABLE for Flutter web target — v1.0
- ✓ Kernel compatibility detection for emulator (graceful SKIP on kernel 6.17+) — v1.0

### Active

(None — next milestone not yet planned)

### Out of Scope

- iOS development / Xcode — not possible in a Linux container
- GPU-accelerated emulator — containers lack GPU passthrough; SwiftShader software rendering works
- Custom Android Studio plugins — user installs post-build; preferences vary
- Android NDK — 1.5+ GB; most Flutter projects don't need it; installable at runtime
- Multiple Android API levels — each system image is 1-2 GB; one default, install more at runtime
- KVM as hard requirement — must work without KVM; optional performance boost on bare-metal Linux
- Emulator auto-start on container launch — deferred to v2 (EMUL-04)
- Configurable Android API level via build arg — deferred to v2 (EMUL-05)

## Context

Shipped v1.0 with 935 LOC across Dockerfile, GHA workflows, and scripts.
Tech stack: Debian Trixie, Docker, GitHub Actions, Bash.
5 DevContainer variants now in the matrix: bun, php, rust, vnc, flutter.
Flutter variant uses three-tier chain (base → VNC → flutter) with `matrix.build_contexts` pattern.
Known issue: Android emulator segfaults on host kernel 6.17+ (upstream QEMU bug); validation script handles gracefully.

## Constraints

- **Base image**: Must extend VNC variant (which itself extends devcontainer-base) — Debian Trixie
- **Shell compatibility**: RUN commands use `/bin/sh` (dash) — POSIX-compatible redirects only (`>/dev/null 2>&1`, not `&>`)
- **User convention**: Base image ends with `USER dev` / `ENV HOME=/home/dev`; switching to root requires resetting HOME
- **CI/CD**: Three-tier chain requires conditional VNC rebuild step (`if: matrix.needs_vnc`) in both workflows
- **Privacy**: Repository and hosted Docker images are private (GHCR)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Extend VNC variant instead of base | Reuse existing X11/VNC display forwarding setup | ✓ Good — avoids duplicating VNC packages, clean three-tier chain |
| Use FVM for Flutter version management | Allows pinning Flutter versions per project, standard in Flutter community | ✓ Good — FVM installs to ~/fvm/bin, Flutter SDK managed cleanly |
| Use NVM for Node version management | Flexible Node version switching for different backend needs | ✓ Good — inherited from base, works out of the box |
| Use UV for Python tooling | Fast, modern Python package management; replaces pip workflows | ✓ Good — inherited from base, no extra config |
| Software-rendered emulator (SwiftShader) | GPU passthrough in containers is unreliable; software rendering is pragmatic | ✓ Good — works on all hosts; KVM optional boost |
| Android Studio via dl.google.com direct URL | Redirector URLs unreliable, direct CDN URL more stable | ⚠️ Revisit — Google CDN URLs may change over time |
| API 35 + 36 SDK (dual platform) | Flutter 3.41.2 requires API 36 for compile, API 35 for emulator system image | ✓ Good — satisfies both flutter doctor and emulator |
| matrix.build_contexts over ternary expression | Cleaner per-variant FROM image remapping in GHA workflows | ✓ Good — each matrix entry declares its own build context |
| Kernel SKIP instead of FAIL for emulator | Upstream QEMU bug on kernel 6.17+; CI shouldn't block on host kernel issue | ✓ Good — CI passes cleanly, emulator works on compatible kernels |

---
*Last updated: 2026-02-24 after v1.0 milestone*
