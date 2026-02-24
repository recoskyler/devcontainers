# Roadmap: trixie-vnc-flutter-rust-nvm-uv-claude

## Overview

This roadmap delivers a new DevContainer Docker image variant for full-stack Flutter mobile development. The work proceeds in three phases driven by build-time dependencies: first construct the Dockerfile with all tools installed and passing validation gates, then verify the image works end-to-end at runtime (emulator boots, Studio connects, web target runs), and finally integrate into the existing GitHub Actions CI/CD pipeline with proper cache configuration.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Dockerfile Construction** - Build the Dockerfile with all tools (Flutter/FVM, Android SDK, emulator, Studio, Rust, Chromium) installed and `flutter doctor` passing
- [ ] **Phase 2: Runtime Validation** - Verify the built image works end-to-end: emulator boots via VNC, Studio connects to emulator, web target runs, inherited tools confirmed
- [ ] **Phase 3: CI/CD Integration** - Add variant to GitHub Actions build and check workflows with isolated cache scope

## Phase Details

### Phase 1: Dockerfile Construction
**Goal**: A developer can build the Docker image locally and all tools are installed correctly, with `flutter doctor` reporting no critical errors
**Depends on**: Nothing (first phase)
**Requirements**: FLUT-01, FLUT-02, SDK-01, SDK-02, SDK-03, SDK-04, EMUL-01, EMUL-02, EMUL-03, IDE-01, TOOL-01, DISP-01, WEB-01, CONV-01, CONV-02, CONV-03
**Success Criteria** (what must be TRUE):
  1. `docker build` completes successfully for the new variant Dockerfile
  2. `flutter doctor` passes with no critical errors when run inside the built image
  3. Android SDK components (cmdline-tools, platform-tools, build-tools, platform API 35) are present at expected paths with correct environment variables
  4. Android emulator binary, system image, and pre-created AVD exist in the image
  5. Android Studio is installed and the Dockerfile follows all project conventions (extends VNC variant, POSIX shell, USER/HOME handling, CLAUDE.md append)
**Plans**: 2 plans

Plans:
- [ ] 01-01-PLAN.md — System-level installs (Java, cmdline-tools, Android Studio, Chromium, GUI libs)
- [ ] 01-02-PLAN.md — User-level installs + validation (FVM/Flutter, SDK components, AVD, Rust, CLAUDE.md, flutter doctor)

### Phase 2: Runtime Validation
**Goal**: The built image works end-to-end at runtime -- emulator boots visibly via VNC, Android Studio connects to it, Flutter web target runs, and inherited backend tools are confirmed functional
**Depends on**: Phase 1
**Requirements**: IDE-02, TOOL-02, TOOL-03, DISP-02, WEB-02
**Success Criteria** (what must be TRUE):
  1. Android emulator boots to home screen and is visible in a VNC client connected to the container
  2. Android Studio launches via VNC and can connect to the running emulator instance
  3. `flutter run -d chrome` successfully launches a Flutter app in Chromium inside the container
  4. NVM, Node.js LTS, UV, and Rust toolchain are all functional for the `dev` user (commands resolve, versions print)
  5. ADB wireless debugging instructions are documented for physical device connectivity
**Plans**: TBD

Plans:
- [ ] 02-01: TBD

### Phase 3: CI/CD Integration
**Goal**: The variant builds automatically in GitHub Actions alongside existing variants, with isolated caching that does not degrade other variants' build performance
**Depends on**: Phase 2
**Requirements**: CICD-01, CICD-02, CICD-03
**Success Criteria** (what must be TRUE):
  1. `build.yml` matrix includes the flutter variant and the image pushes to GHCR on merge to main
  2. `check.yml` matrix includes the flutter variant and blocks PR merge on build failure
  3. GHA cache scope `flutter` is configured and does not collide with existing variant cache scopes
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Dockerfile Construction | 0/2 | Not started | - |
| 2. Runtime Validation | 0/? | Not started | - |
| 3. CI/CD Integration | 0/? | Not started | - |
