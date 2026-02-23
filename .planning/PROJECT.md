# DevContainer: trixie-vnc-flutter-rust-nvm-uv-claude

## What This Is

A new DevContainer Docker image variant for full-stack mobile development. It extends the existing VNC variant to provide Flutter (managed via FVM) with full Android Studio, Android SDK/emulator, Rust, Node (via NVM), and Python (via UV) — all with X11VNC display forwarding so Android Studio and the emulator run with a GUI inside the container. Physical Android device forwarding via ADB is included if possible.

## Core Value

A developer can open this DevContainer and immediately build, run, and debug a Flutter app with Android Studio and emulator, alongside Rust/Node/Python backend services, without installing anything on the host.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Dockerfile extends the VNC variant and installs Flutter via FVM
- [ ] Full Android Studio IDE installed and launchable via VNC
- [ ] Android SDK with command-line tools, platform-tools, and at least one system image for the emulator
- [ ] Android emulator runs inside the container and is visible via X11VNC/xvfb
- [ ] Rust toolchain installed (rustup, cargo, rustc)
- [ ] NVM installed with a default Node.js LTS version
- [ ] UV installed for Python package management
- [ ] Physical Android device forwarding via ADB (if feasible in container context)
- [ ] `flutter doctor` passes with no critical errors
- [ ] Variant appends its tools section to `~/.claude/CLAUDE.md` (per project convention)
- [ ] Added to GitHub Actions build matrix (build.yml and check.yml)
- [ ] Image builds successfully in CI with GHA cache scope

### Out of Scope

- iOS development / Xcode — not possible in a Linux container
- Running Android Studio natively on host — this is container-only
- GPU-accelerated emulator — containers typically lack GPU passthrough; software rendering is acceptable
- Custom Android Studio plugins — user can install post-build

## Context

- The project already has a VNC variant with X11/VNC display forwarding infrastructure — this variant builds on it
- Existing variants (bun, php, rust, vnc) follow a pattern: extend `devcontainer-base:latest`, install language-specific tools, append to `~/.claude/CLAUDE.md`
- CI/CD uses a two-job structure: base image builds first, then variant matrix jobs use a local registry service container to remap `FROM devcontainer-base:latest`
- The base image is Debian Trixie with common dev tools, ends with `USER dev`
- Android Studio + emulator is heavy (~2-4GB) — image size and build time will be significant
- FVM (Flutter Version Manager) allows pinning Flutter versions per project
- UV is the fast Python package manager from Astral (replaces pip/pipx for many workflows)

## Constraints

- **Base image**: Must extend VNC variant (which itself extends devcontainer-base) — Debian Trixie
- **Shell compatibility**: RUN commands use `/bin/sh` (dash) — POSIX-compatible redirects only (`>/dev/null 2>&1`, not `&>`)
- **User convention**: Base image ends with `USER dev` / `ENV HOME=/home/dev`; switching to root requires resetting HOME
- **CI/CD**: Must integrate with existing two-job GHA workflow using registry service container and build-contexts
- **Privacy**: Repository and hosted Docker images are private (GHCR)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Extend VNC variant instead of base | Reuse existing X11/VNC display forwarding setup | — Pending |
| Use FVM for Flutter version management | Allows pinning Flutter versions per project, standard in Flutter community | — Pending |
| Use NVM for Node version management | Flexible Node version switching for different backend needs | — Pending |
| Use UV for Python tooling | Fast, modern Python package management; replaces pip workflows | — Pending |
| Software-rendered emulator | GPU passthrough in containers is unreliable; software rendering is the pragmatic choice | — Pending |

---
*Last updated: 2026-02-24 after initialization*
