# Pitfalls Research

**Domain:** Flutter full-stack mobile DevContainer (Android Studio + emulator in Docker with X11VNC)
**Researched:** 2026-02-24
**Confidence:** MEDIUM-HIGH (well-documented domain with many community post-mortems; some areas depend on hardware/host specifics)

## Critical Pitfalls

### Pitfall 1: Emulator requires KVM but DevContainers typically lack /dev/kvm access

**What goes wrong:**
The Android x86/x86_64 emulator requires hardware-assisted virtualization (KVM on Linux) for acceptable performance. Without KVM, the emulator either refuses to start entirely, falls back to extremely slow ARM emulation, or crashes with QEMU panic errors. Most DevContainer hosts (especially cloud-based Codespaces, CI runners, or VMs without nested virtualization) do not expose `/dev/kvm` to containers.

**Why it happens:**
Developers assume the emulator "just works" in Docker like it does on bare metal. They install x86 system images expecting hardware acceleration, but Docker containers are isolated from host KVM by default. Even when the host supports KVM, the container needs explicit `--device /dev/kvm` access, and the user inside the container needs membership in the `kvm` group.

**How to avoid:**
- Document the KVM requirement explicitly in `devcontainer.json` with `"runArgs": ["--device=/dev/kvm"]` and note it only works on Linux hosts with KVM enabled.
- Install ARM64 system images as a fallback (e.g., `system-images;android-35;google_apis;arm64-v8a`) that work without KVM, though slowly.
- Default the emulator to software rendering with `-gpu swiftshader_indirect` and `-no-window` or `-no-boot-anim` flags.
- Set `hw.gpu.enabled=no` and `hw.gpu.mode=swiftshader_indirect` in the AVD config.ini.
- Test the container on a host without KVM to verify graceful degradation.

**Warning signs:**
- `flutter doctor` reports "No hardware acceleration" or "KVM not available"
- Emulator exits immediately with "Could not initialize emulation"
- QEMU panic: "CPU acceleration status: KVM requires a CPU that supports vmx or svm"
- Emulator starts but is unusable (5+ minutes to boot, constant ANR dialogs)

**Phase to address:**
Phase 1 (Dockerfile construction) -- the emulator flags and AVD config must be baked into the image, and `devcontainer.json` must document the host requirement.

---

### Pitfall 2: Image size explodes beyond 10-15GB, breaking CI cache and pull times

**What goes wrong:**
Combining Android Studio (~1.5GB), Android SDK command-line tools, platform-tools, build-tools, at least one system image (~1-2GB), the emulator binary, Flutter SDK (~1-2GB), Rust toolchain (~1GB), Node via NVM, Python via UV, plus the existing base image (already ~2GB) creates an image that easily exceeds 10-15GB. This exceeds GitHub Actions' default 10GB GHA cache limit, causes cache eviction (breaking all variant cache scopes in the shared repository), slows CI to 30+ minute builds, and makes developer pull times unacceptable.

**Why it happens:**
Each tool seems reasonable in isolation. Android SDK alone is manageable until you add a system image and emulator. Flutter SDK downloads its own copies of Dart and internal tools. The base image already includes NVM, Node, build-essential, and many CLI tools. Layers accumulate fast when `apt-get install` runs across multiple RUN commands without cleanup.

**How to avoid:**
- Install Android SDK command-line tools only (no full Android Studio IDE) -- developers can install the full IDE themselves if needed via VNC. The cmdline-tools + platform-tools + build-tools are sufficient for `flutter build` and `flutter doctor`.
- Pin a single Android API level and a single system image (not multiple).
- Aggressively clean SDK caches in the same RUN layer: `rm -rf $ANDROID_HOME/.android $ANDROID_HOME/.cache /tmp/*`.
- Combine RUN commands to minimize layers.
- Consider switching CI caching from GHA cache to registry-based cache (`type=registry`) since registry cache has no 10GB limit.
- Track image size in CI with a `docker images --format` step that fails if size exceeds a threshold.

**Warning signs:**
- `docker images` shows 12GB+ for the variant
- GHA cache starts showing "Cache entry evicted" in workflow logs
- Other variant builds (bun, php, rust) start rebuilding from scratch because their cache scopes got evicted
- Pull times exceed 5 minutes on a fast connection

**Phase to address:**
Phase 1 (Dockerfile) for layer optimization. Phase 3 (CI integration) for cache strategy switch and size gates.

---

### Pitfall 3: Qt xcb plugin crash kills emulator before it renders in VNC

**What goes wrong:**
The Android emulator binary bundles its own Qt libraries and tries to load the `xcb` platform plugin for display rendering. In a minimal Docker container, the required system libraries (`libxcb`, `libxkbcommon`, `libxrender`, `libxi`, etc.) are missing or version-incompatible. The emulator crashes at startup with: `qt.qpa.plugin: Could not load the Qt platform plugin "xcb"` -- and this happens silently if not running with `-verbose`.

**Why it happens:**
The emulator's Qt dependency is not documented as a requirement in most Docker guides. Developers install `xvfb` and `x11vnc` (which the VNC variant already has) and assume that covers X11 needs. But the emulator uses Qt's xcb platform plugin, which requires additional shared libraries beyond what Xvfb provides.

**How to avoid:**
- Install the full set of xcb dependencies in the Dockerfile: `libxcb-xinerama0 libxcb-cursor0 libxcb-randr0 libxcb-shape0 libxcb-xfixes0 libxcb-render-util0 libxkbcommon-x11-0 libpulse0 libnss3 libxcomposite1 libxdamage1 libxrandr2 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libgbm1 libpango-1.0-0 libgtk-3-0`.
- As an alternative, set `QT_QPA_PLATFORM=offscreen` if running headless (but this disables VNC rendering).
- Run the emulator once during `docker build` (or in a test step) to verify it starts without Qt errors.
- Enable `QT_DEBUG_PLUGINS=1` in the test step to get verbose error output about missing libraries.

**Warning signs:**
- Emulator exits immediately with no error in normal output (exit code 1)
- VNC session shows a blank screen with no emulator window
- Setting `QT_DEBUG_PLUGINS=1` reveals missing `.so` files
- `ldd` on the emulator binary shows "not found" entries

**Phase to address:**
Phase 1 (Dockerfile) -- these dependencies must be installed alongside the emulator. Phase 2 (validation) -- `flutter doctor` and emulator smoke test.

---

### Pitfall 4: JAVA_HOME and sdkmanager version mismatch breaks license acceptance and flutter doctor

**What goes wrong:**
`sdkmanager` and `flutter doctor --android-licenses` fail with cryptic Java errors. Older cmdline-tools versions are incompatible with Java 17+. Newer cmdline-tools (12.0+) require Java 17+ but may not work with Java 21+. Debian Trixie ships OpenJDK 21 as default, which can conflict with Android tooling expectations. The error messages are misleading -- they say "sdkmanager not found" when the real issue is Java version incompatibility.

**Why it happens:**
Android's Java version requirements are a moving target. The SDK command-line tools historically required Java 8 or 11, then updated to require Java 17, and the latest versions are catching up to Java 21. Debian Trixie's default JDK is OpenJDK 21, and developers typically install `default-jdk` without checking which version that provides. Flutter's `flutter doctor` follows its own logic to find Java, which may not match `JAVA_HOME`.

**How to avoid:**
- Pin a specific Java version explicitly (OpenJDK 21 from Trixie repos, which is what `default-jdk` provides).
- Use the latest `cmdline-tools;latest` version (12.0+) which supports Java 17 and 21.
- Set `JAVA_HOME` explicitly in the Dockerfile and verify it matches what `sdkmanager` and Flutter expect.
- Run `yes | sdkmanager --licenses` and `flutter doctor --android-licenses` during the Docker build to catch failures early (not at runtime).
- Consider using Android Studio's bundled JBR (JetBrains Runtime) if installing the full IDE -- but this conflicts with system Java for other tools.

**Warning signs:**
- `sdkmanager --list` fails with `UnsupportedClassVersionError`
- `flutter doctor` reports "Android license status unknown"
- `flutter doctor --android-licenses` hangs or crashes
- `java -version` output does not match what Android tools expect

**Phase to address:**
Phase 1 (Dockerfile) -- Java installation must be tested against sdkmanager and flutter doctor in the build.

---

### Pitfall 5: Xvfb DISPLAY misconfiguration makes emulator invisible in VNC

**What goes wrong:**
The Android emulator starts and runs but is invisible in the VNC session. Or the VNC session shows the desktop but the emulator renders to a different virtual display. Or the emulator and Android Studio render on different displays and cannot interact. The DISPLAY variable mismatch between Xvfb, x11vnc, the emulator process, and Android Studio is the most common cause of "it runs but I can't see it."

**Why it happens:**
Xvfb creates a virtual framebuffer on a numbered display (e.g., `:99`). x11vnc connects to that display and exposes it over VNC. But if the emulator or Android Studio is launched with a different `DISPLAY` value (or inherits none), it renders to a display that x11vnc is not serving. This is especially tricky when processes are started by different users (root vs dev), via systemd, or via shell scripts that reset the environment.

**How to avoid:**
- Set `ENV DISPLAY=:99` globally in the Dockerfile (not just in bashrc or a startup script).
- Ensure the Xvfb startup, x11vnc startup, and all GUI application launches use the same display number.
- Use a single entrypoint script that starts Xvfb, waits for the display to be ready, starts x11vnc, and then launches GUI applications -- all in sequence with the same DISPLAY.
- Set the Xvfb resolution to something reasonable: `Xvfb :99 -screen 0 1920x1080x24` -- too-small resolutions cause Android Studio to be unusable.
- Test by connecting to VNC and verifying `xdpyinfo -display :99` works.

**Warning signs:**
- VNC session shows a blank or gray screen
- `echo $DISPLAY` in the VNC terminal shows empty or a different number than Xvfb uses
- `xdpyinfo` fails with "unable to open display"
- Emulator log shows "Emulator started" but nothing appears in VNC

**Phase to address:**
Phase 1 (Dockerfile/entrypoint) for DISPLAY setup. Phase 2 (validation) for end-to-end VNC verification.

---

### Pitfall 6: Emulator OOM crash or infinite boot loop from insufficient memory allocation

**What goes wrong:**
The Android emulator boots to the logo, then either crashes, reboots in a loop, or gets stuck at "BOOTING" indefinitely. The container appears healthy but the emulator process inside is constantly restarting. This is caused by the emulator's default RAM allocation (typically 1536-2048MB) conflicting with Docker's container memory limits. The emulator also uses a writable qcow2 disk image that can exhaust container disk space.

**Why it happens:**
Docker containers often have memory limits (2GB default in Docker Desktop, explicit limits in Kubernetes/DevContainers). The Android emulator needs 2-4GB of RAM for itself, plus the host OS overhead, plus Flutter tooling, Rust compilation, and Node processes running simultaneously in the same container. The emulator does not fail gracefully when it runs out of memory -- it just crashes or hangs.

**How to avoid:**
- Set explicit memory recommendations in `devcontainer.json`: `"runArgs": ["--memory=8g", "--memory-swap=12g"]`.
- Configure the AVD with reduced RAM: `hw.ramSize=2048` in config.ini (not the default 4096).
- Document minimum host requirements: 16GB RAM recommended for this multi-tool image.
- Add a health check in the entrypoint that waits for the emulator to boot and kills+restarts it if it takes more than 120 seconds.
- Use `-memory 2048` emulator flag to cap memory usage.

**Warning signs:**
- Emulator shows "BOOTING" for more than 2 minutes
- `dmesg` shows OOM killer activity
- `adb devices` shows the emulator alternating between "device" and "offline"
- Container restarts unexpectedly
- Host machine becomes sluggish when container is running

**Phase to address:**
Phase 1 (AVD configuration in Dockerfile). Phase 2 (devcontainer.json resource configuration).

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Installing full Android Studio IDE instead of cmdline-tools only | Developers get the full IDE experience via VNC | +1.5GB image size, slower builds, IDE update management | Only if Android Studio GUI is a hard requirement (PROJECT.md says it is) |
| Using `cmdline-tools;latest` instead of pinning a version | Always get newest tools | Build breaks when Google releases an incompatible version | Never in CI; pin in Dockerfile, update intentionally |
| Downloading multiple system images | Developers can test on different API levels | +1-2GB per image; CI cache explosion | Never in the base image; document how to install additional images post-container-start |
| Skipping `flutter doctor` in Docker build | Faster build | Runtime failures that should have been caught at build time | Never -- always run `flutter doctor` as a build validation step |
| Single-layer Dockerfile (fewer RUN commands) | Simpler Dockerfile | Lost caching granularity; one change rebuilds everything | Only for the final apt-get cleanup step |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| FVM + Flutter SDK + Android SDK | FVM installs Flutter SDK in `~/.fvm/` but `ANDROID_HOME` and `PATH` are not updated to find it; `flutter doctor` uses system Flutter, not FVM Flutter | Set `FVM_HOME`, add FVM's default Flutter to PATH via symlink, ensure `FLUTTER_ROOT` points to FVM's active version |
| ADB (physical device) | Forwarding host USB to container via `--device /dev/bus/usb` does not work on macOS/Windows DevContainer hosts | Document as Linux-only; provide wireless ADB (`adb tcpip 5555`) as cross-platform alternative |
| Rust + Flutter | `cargo` and `flutter pub get` both download large dependency trees; running them in parallel causes I/O contention and OOM in CI | Serialize these operations in CI; in the Dockerfile, install Rust before Flutter to get better layer caching |
| NVM + Flutter + Android Studio | Android Studio ignores NVM-managed Node and uses system Node (or none); Gradle plugins that invoke Node fail | Set `NODE_PATH` and ensure NVM's Node is on the global PATH (not just bashrc-sourced) |
| x11vnc + emulator | x11vnc started before Xvfb is ready crashes silently; emulator started before x11vnc renders to an unshared buffer | Use a startup script with `wait-for-display` logic: start Xvfb, sleep 1, verify display, start x11vnc, then start emulator |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Software-rendered emulator with full resolution | Emulator shows 1-3 FPS; UI interactions take 5-10 seconds to register | Use a low-resolution AVD (720p or smaller); disable boot animation; use `-gpu swiftshader_indirect` | Immediately visible on first use |
| Running `flutter pub get` + `cargo build` + `npm install` concurrently | Container freezes; OOM kills one process; builds fail with I/O errors | Serialize heavy operations; allocate sufficient memory (8GB+) | When any project has non-trivial dependencies |
| Emulator disk I/O on overlayfs (Docker default) | Emulator writes heavily to its writable qcow2 layer; overlayfs is slow for random I/O | Mount `/home/dev/.android/avd/` as a named volume or tmpfs | Noticeable on large apps; critical during instrumented tests |
| GHA cache with this image size | Cache save/restore takes 5-10 minutes; exceeds 10GB limit; evicts other variant caches | Switch from `type=gha` to `type=registry` caching for this variant; or use inline cache | When the variant image exceeds ~4GB (likely from the start) |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Using `--privileged` instead of `--device /dev/kvm` | Grants full host access; any container escape = root on host | Use specific device mapping: `--device=/dev/kvm`; never `--privileged` in devcontainer.json |
| Baking Android license acceptance keys into the image | Licenses are per-user/per-org; sharing images shares the acceptance | Accept licenses during build with `yes \| sdkmanager --licenses` which is stateless and acceptable |
| Storing GHCR credentials in Dockerfile ARGs | Build args are visible in image history | Use Docker secrets or pass credentials only at runtime via environment variables |
| Running the emulator as root | Emulator with root has unrestricted host device access if --device is passed | Always run as `USER dev`; emulator does not need root |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No startup guidance after VNC connect | Developer connects to VNC and sees a blank desktop; doesn't know how to start emulator or Android Studio | Provide a desktop shortcut or auto-start script; add a README to the desktop wallpaper or terminal motd |
| Emulator takes 3+ minutes to boot | Developer thinks container is broken; kills and restarts it | Show boot progress; add a terminal status indicator; document expected boot time in devcontainer-claude.md |
| `flutter doctor` warnings about Chrome | Developer sees warnings and thinks setup is broken | Suppress irrelevant warnings in CLAUDE.md documentation; or install Chrome/Chromium for web dev support |
| VNC resolution too small for Android Studio | Android Studio is nearly unusable; menus cut off; dialogs overflow | Default Xvfb to 1920x1080x24 minimum; document how to change resolution |

## "Looks Done But Isn't" Checklist

- [ ] **Emulator boots:** Emulator shows home screen -- verify it also responds to touch events via VNC (not just a frozen frame)
- [ ] **flutter doctor passes:** All checks green -- verify `flutter doctor -v` shows the correct Flutter version (FVM-managed, not system)
- [ ] **Android licenses accepted:** `sdkmanager --licenses` accepted -- verify `flutter doctor --android-licenses` also passes (they use different license stores)
- [ ] **ADB sees emulator:** `adb devices` shows the emulator -- verify `flutter devices` also lists it (Flutter sometimes loses the connection)
- [ ] **VNC is accessible:** Can connect to VNC -- verify the emulator is *visible* in VNC (not rendering to a different display)
- [ ] **CI builds pass:** Image builds in CI -- verify the image size is tracked and hasn't exceeded the cache budget
- [ ] **Rust works alongside Flutter:** `cargo build` works -- verify it works *while the emulator is running* (memory contention)
- [ ] **Hot reload works:** `flutter run` starts -- verify hot reload (`r` key) actually works through the VNC emulator connection

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Image too large for GHA cache | MEDIUM | Switch to registry-based cache (`type=registry`); split Android SDK installation into a separate intermediate image that gets cached independently |
| Qt xcb crash on emulator start | LOW | Install missing libraries; re-run `ldd` on emulator binary to find remaining gaps; set `QT_DEBUG_PLUGINS=1` for diagnostics |
| Java version mismatch | LOW | Pin `openjdk-21-jdk` explicitly; set `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`; re-run `sdkmanager --licenses` and `flutter doctor` |
| Emulator OOM loop | MEDIUM | Reduce AVD RAM to 2048MB; add swap; increase container memory limit; consider removing unused tools from the image |
| DISPLAY mismatch in VNC | LOW | Set `ENV DISPLAY=:99` in Dockerfile; verify all startup scripts use same display; restart Xvfb + x11vnc + emulator in sequence |
| KVM not available on host | HIGH (architectural) | Fall back to ARM emulator (very slow); or document KVM as hard requirement; no Docker-level fix exists |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| KVM dependency | Phase 1: Dockerfile + devcontainer.json | `flutter doctor` reports acceleration status; emulator starts without crash |
| Image size explosion | Phase 1: Dockerfile layer optimization; Phase 3: CI cache strategy | `docker images --format` check in CI; GHA cache not evicting other scopes |
| Qt xcb crash | Phase 1: Dockerfile apt-get dependencies | Emulator launches and appears in VNC; no Qt errors in logs |
| Java/sdkmanager mismatch | Phase 1: Dockerfile pinned Java + cmdline-tools version | `sdkmanager --list` works; `flutter doctor --android-licenses` passes |
| DISPLAY misconfiguration | Phase 1: Dockerfile ENV + entrypoint script | VNC connection shows emulator; `xdpyinfo` succeeds inside container |
| Emulator OOM/boot loop | Phase 1: AVD config; Phase 2: devcontainer.json resources | Emulator reaches home screen in < 120s; no OOM in `dmesg` |
| FVM PATH conflicts | Phase 1: Dockerfile PATH setup | `which flutter` points to FVM-managed binary; `flutter --version` matches FVM config |
| CI cache exceeded | Phase 3: CI workflow changes | All variant caches remain valid after flutter variant build |

## Sources

- [budtmo/docker-android](https://github.com/budtmo/docker-android) -- most popular Docker Android project; documented memory, KVM, and VNC issues
- [google/android-emulator-container-scripts](https://github.com/google/android-emulator-container-scripts) -- Google's official emulator containerization; documents KVM requirement and NVIDIA-only GPU support
- [thyrlian/AndroidSDK](https://github.com/thyrlian/AndroidSDK) -- full-fledged Android SDK Docker image; Qt xcb plugin issues documented
- [Android Developer: Configure hardware acceleration](https://developer.android.com/studio/run/emulator-acceleration) -- official KVM/HAXM requirements
- [Android Developer: Java versions in builds](https://developer.android.com/build/jdks) -- official Java compatibility guidance
- [Android Developer: sdkmanager](https://developer.android.com/tools/sdkmanager) -- SDK command-line tool documentation
- [GitHub Actions cache documentation](https://docs.docker.com/build/cache/backends/gha/) -- 10GB limit, eviction policies
- [GitHub Actions cache size can now exceed 10GB](https://github.blog/changelog/2025-11-20-github-actions-cache-size-can-now-exceed-10-gb-per-repository/) -- pay-as-you-go cache expansion
- [Docker cache management with GitHub Actions](https://docs.docker.com/build/ci/github-actions/cache/) -- registry-based cache alternative
- [Dockerizing Flutter: The Setup Struggle (Noveo, 2025)](https://blog.noveogroup.com/2025/11/dockerizing-flutter-mastering-flutter-docker-setup-struggle) -- real-world Docker+Flutter pitfalls
- [Codemagic: How to dockerize Flutter apps](https://blog.codemagic.io/how-to-dockerize-flutter-apps/) -- license acceptance and environment setup
- [flutter/flutter#137022](https://github.com/flutter/flutter/issues/137022) -- sdkmanager Java version incompatibility issue
- [flutter/flutter#57372](https://github.com/flutter/flutter/issues/57372) -- flutter doctor JAVA_HOME selection issue
- [ReactiveCircus/android-emulator-runner](https://github.com/ReactiveCircus/android-emulator-runner) -- SwiftShader and emulator flags for CI
- [ljishen/docker-vnc-android-studio](https://github.com/ljishen/docker-vnc-android-studio) -- Android Studio VNC Docker reference
- [GHCR slow download speeds discussion](https://lowendspirit.com/discussion/7390/extremely-slow-download-speeds-from-github-container-registry-ghcr-io) -- large image pull performance on GHCR

---
*Pitfalls research for: Flutter full-stack mobile DevContainer (Android Studio + emulator in Docker with X11VNC)*
*Researched: 2026-02-24*
