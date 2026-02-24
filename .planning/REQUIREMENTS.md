# Requirements: trixie-vnc-flutter-rust-nvm-uv-claude

**Defined:** 2026-02-24
**Core Value:** A developer can open this DevContainer and immediately build, run, and debug a Flutter app with Android Studio and emulator, alongside Rust/Node/Python backend services, without installing anything on the host.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Flutter & FVM

- [x] **FLUT-01**: FVM installed and Flutter stable SDK available via FVM
- [x] **FLUT-02**: `flutter doctor` passes with no critical errors at build time

### Android SDK

- [x] **SDK-01**: OpenJDK installed with JAVA_HOME configured
- [x] **SDK-02**: Android SDK cmdline-tools, platform-tools, and build-tools installed
- [x] **SDK-03**: Android platform (API 35) installed
- [x] **SDK-04**: Android SDK licenses accepted at build time

### Android Emulator

- [x] **EMUL-01**: Android system image (x86_64, google_apis, API 35) installed
- [x] **EMUL-02**: Emulator runs with SwiftShader software rendering (no KVM required)
- [x] **EMUL-03**: Pre-created AVD with Pixel device profile for zero-config launch

### Android Studio IDE

- [x] **IDE-01**: Full Android Studio IDE installed and launchable via VNC
- [ ] **IDE-02**: Android Studio can connect to the running emulator

### Backend Toolchain

- [x] **TOOL-01**: Rust toolchain installed via rustup (cargo, rustc, clippy, rustfmt)
- [ ] **TOOL-02**: NVM + Node.js LTS available (inherited from base)
- [ ] **TOOL-03**: UV available for Python package management (inherited from base)

### Display & Devices

- [x] **DISP-01**: X11VNC/Xvfb display forwarding works for emulator and Studio GUI
- [ ] **DISP-02**: ADB wireless debugging documented for physical device connectivity

### Web Target

- [x] **WEB-01**: Chromium installed with CHROME_EXECUTABLE configured
- [ ] **WEB-02**: `flutter run -d chrome` works inside the container

### CI/CD

- [ ] **CICD-01**: Variant added to build.yml GitHub Actions matrix
- [ ] **CICD-02**: Variant added to check.yml GitHub Actions matrix
- [ ] **CICD-03**: GHA cache scope configured for the variant

### Conventions

- [x] **CONV-01**: Dockerfile extends the VNC variant (or inlines VNC packages from base)
- [x] **CONV-02**: Tools section appended to `~/.claude/CLAUDE.md`
- [x] **CONV-03**: POSIX-compatible shell redirects used in Dockerfile RUN commands

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Emulator Enhancements

- **EMUL-04**: Entrypoint script for emulator auto-start on container launch
- **EMUL-05**: Configurable Android API level via Dockerfile build arg

### Developer Experience

- **DX-01**: Gradle and pub cache volume mount guidance in devcontainer.json
- **DX-02**: Flutter-Rust FFI (flutter_rust_bridge/rinf) documentation in CLAUDE.md

### Multi-Target

- **MTGT-01**: Linux desktop target support (GTK libs, clang, cmake, ninja, libgtk-3-dev)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| iOS / Xcode support | Impossible on Linux containers |
| GPU passthrough for emulator | Not portable across machines; broken in most CI; adds complexity |
| KVM as a hard requirement | Must work without KVM; optional performance boost on Linux bare-metal |
| USB device passthrough | Platform-dependent, fragile, requires --privileged; use ADB wireless instead |
| Android NDK | 1.5+ GB; most Flutter projects don't need it; installable at runtime |
| Pre-installed Studio plugins | User preferences vary; plugins change frequently; install post-start |
| Multiple Android API levels | Each system image is 1-2 GB; one default, install more at runtime |
| Genymotion / third-party emulators | Licensing issues; stock emulator with SwiftShader is sufficient |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FLUT-01 | Phase 1 | Complete |
| FLUT-02 | Phase 1 | Complete |
| SDK-01 | Phase 1 | Complete |
| SDK-02 | Phase 1 | Complete |
| SDK-03 | Phase 1 | Complete |
| SDK-04 | Phase 1 | Complete |
| EMUL-01 | Phase 1 | Complete |
| EMUL-02 | Phase 1 | Complete |
| EMUL-03 | Phase 1 | Complete |
| IDE-01 | Phase 1 | Complete |
| IDE-02 | Phase 2 | Pending |
| TOOL-01 | Phase 1 | Complete |
| TOOL-02 | Phase 2 | Pending |
| TOOL-03 | Phase 2 | Pending |
| DISP-01 | Phase 1 | Complete |
| DISP-02 | Phase 2 | Pending |
| WEB-01 | Phase 1 | Complete |
| WEB-02 | Phase 2 | Pending |
| CICD-01 | Phase 3 | Pending |
| CICD-02 | Phase 3 | Pending |
| CICD-03 | Phase 3 | Pending |
| CONV-01 | Phase 1 | Complete |
| CONV-02 | Phase 1 | Complete |
| CONV-03 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 24 total
- Mapped to phases: 24
- Unmapped: 0

---
*Requirements defined: 2026-02-24*
*Last updated: 2026-02-24 after roadmap creation*
