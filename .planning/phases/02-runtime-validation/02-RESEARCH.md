# Phase 2: Runtime Validation - Research

**Researched:** 2026-02-24
**Domain:** Docker container runtime validation -- Android emulator, Android Studio, Flutter web, VNC display, ADB wireless debugging
**Confidence:** MEDIUM-HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| IDE-02 | Android Studio can connect to the running emulator | Start emulator first, then launch Android Studio via VNC; Studio auto-detects emulator via ADB on localhost:5554. See Architecture Pattern 3. |
| TOOL-02 | NVM + Node.js LTS available (inherited from base) | Verify with `nvm --version`, `node --version`, `npm --version` inside running container as `dev` user. NVM_DIR=/usr/local/nvm per base Dockerfile. |
| TOOL-03 | UV available for Python package management (inherited from base) | Verify with `uv --version` inside running container. UV installed at `$HOME/.local/bin/uv` per base Dockerfile. |
| DISP-02 | ADB wireless debugging documented for physical device connectivity | Document both Android 11+ wireless pairing (`adb pair`) and legacy TCP/IP (`adb tcpip 5555`) methods. See Architecture Pattern 5. |
| WEB-02 | `flutter run -d chrome` works inside the container | Requires Xvfb running with DISPLAY set; use `flutter create` for a test project, then `flutter run -d chrome --no-resident-compiler`. See Architecture Pattern 4. |
</phase_requirements>

## Summary

Phase 2 validates that the Docker image built in Phase 1 works correctly at runtime. Unlike Phase 1 (which was purely build-time), this phase requires actually running the container interactively and verifying that graphical applications (Android emulator, Android Studio, Chromium via Flutter web) render through the VNC display pipeline, that inherited tools (NVM, Node.js, UV) are functional, and that ADB wireless debugging instructions are documented.

The core technical challenge is orchestrating the X11 display stack inside the container: Xvfb provides a virtual framebuffer, x11vnc exposes it over VNC, and all GUI applications (emulator, Android Studio, Chromium) must target the same DISPLAY. The emulator needs specific flags for software rendering (`-gpu swiftshader_indirect`) and Docker compatibility (`-no-audio`, `-no-boot-anim`). Boot completion must be verified via `adb shell getprop sys.boot_completed` polling. Flutter web validation requires the same Xvfb display for Chromium to render.

This phase produces no Dockerfile changes. Its outputs are: (1) runtime validation evidence (commands run, output captured), (2) ADB wireless debugging documentation appended to the devcontainer CLAUDE.md or added as a separate reference, and (3) confirmation that all Phase 2 requirements are satisfied.

**Primary recommendation:** Write a validation script that starts Xvfb + x11vnc, boots the emulator, waits for boot completion, launches Android Studio, runs `flutter run -d chrome`, and verifies inherited tools -- all inside a single `docker run` session. Document ADB wireless debugging in the CLAUDE.md tools section.

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Xvfb | System (Debian Trixie) | Virtual X11 framebuffer for headless display | Inherited from VNC parent image; standard approach for headless GUI in Docker |
| x11vnc | System (Debian Trixie) | VNC server exposing Xvfb display | Inherited from VNC parent image; lightweight VNC server |
| Android emulator | Via sdkmanager (installed in Phase 1) | Boots Android virtual device | Pre-installed; runs with SwiftShader in software mode |
| ADB (platform-tools) | Via sdkmanager (installed in Phase 1) | Communicates with emulator and physical devices | Pre-installed at `$ANDROID_HOME/platform-tools/adb` |
| Android Studio | 2025.3.1.5 Panda 1 (installed in Phase 1) | IDE launched via VNC | Pre-installed at `/opt/android-studio/bin/studio.sh` |
| Flutter | 3.41.2 stable via FVM (installed in Phase 1) | Web target build and run | Pre-installed via FVM at `$HOME/fvm/default/bin/flutter` |
| Chromium | Debian Trixie package (installed in Phase 1) | Browser for `flutter run -d chrome` | Pre-installed; CHROME_EXECUTABLE already set |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `xdpyinfo` | Verify Xvfb display is ready | Before starting GUI applications; poll until display responds |
| `adb wait-for-device` | Block until emulator device appears | After starting emulator, before boot polling |
| `adb shell getprop sys.boot_completed` | Poll emulator boot status | After `adb wait-for-device`; loop until returns "1" |
| `flutter create` | Generate minimal test project | For WEB-02 validation; creates a runnable Flutter app |
| `nvm`, `node`, `npm` | Node.js version manager and runtime | For TOOL-02 validation |
| `uv` | Python package manager | For TOOL-03 validation |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| x11vnc | TigerVNC | x11vnc is already installed in the VNC parent image; no reason to switch |
| Manual VNC client verification | noVNC (web-based) | noVNC would require installing additional packages; manual VNC client or scripted checks are simpler |
| Interactive validation | Automated script | Script is more reproducible; interactive is backup if script has issues |

## Architecture Patterns

### Pattern 1: VNC Display Stack Startup Sequence

**What:** Start Xvfb, verify it is ready, then start x11vnc, all sharing the same DISPLAY.
**When to use:** Every time the container needs GUI display for validation.
**Example:**
```bash
# Start Xvfb on display :99 with 1280x1024 resolution, 24-bit color
Xvfb :99 -screen 0 1280x1024x24 &
XVFB_PID=$!

# Export DISPLAY for all subsequent GUI processes
export DISPLAY=:99

# Wait for Xvfb to be ready (poll with xdpyinfo)
for i in $(seq 1 30); do
    xdpyinfo -display :99 >/dev/null 2>&1 && break
    sleep 1
done

# Start x11vnc on the same display, port 5900, no password, run forever
x11vnc -display :99 -forever -nopw -rfbport 5900 -quiet &
X11VNC_PID=$!
```

**Key details:**
- Use display `:99` to avoid conflicts (`:0` or `:1` might clash with other X servers).
- Resolution `1280x1024x24` is a good balance for emulator + Studio visibility.
- The `xdpyinfo` poll loop is critical -- starting GUI apps before Xvfb is ready causes crashes.
- x11vnc `-forever` keeps the server running after client disconnects.

### Pattern 2: Android Emulator Launch and Boot Wait

**What:** Start the emulator with Docker-compatible flags, then poll for boot completion.
**When to use:** For IDE-02 and visual verification of emulator.
**Example:**
```bash
# Start emulator in background with software rendering, no audio, no boot animation
emulator -avd flutter_pixel7 \
    -gpu swiftshader_indirect \
    -no-audio \
    -no-boot-anim \
    -no-snapshot \
    -memory 2048 &
EMU_PID=$!

# Wait for ADB to detect the device
adb wait-for-device

# Poll for boot completion (typically 2-5 minutes with SwiftShader)
echo "Waiting for emulator to boot..."
while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
    sleep 5
    echo "Still booting..."
done
echo "Emulator booted successfully"
```

**Key flags explained:**
- `-gpu swiftshader_indirect`: Software GPU rendering, no KVM/GPU needed
- `-no-audio`: Prevents PulseAudio errors in containers
- `-no-boot-anim`: Faster boot (skip animation)
- `-no-snapshot`: Clean boot every time (no quickboot state)
- `-memory 2048`: Matches AVD config from Phase 1

**Important:** The emulator is very slow without KVM. Boot time with SwiftShader is 2-5 minutes. The `docker run` command should NOT use `--device /dev/kvm` since the requirement is to work without KVM (EMUL-02). If KVM is available, adding `--device /dev/kvm` is an optional performance boost.

### Pattern 3: Android Studio Launch and Emulator Connection

**What:** Launch Android Studio via VNC, verify it can see the running emulator.
**When to use:** For IDE-02 validation.
**Example:**
```bash
# Ensure DISPLAY is set and Xvfb + x11vnc are running (Pattern 1)
# Ensure emulator is booted (Pattern 2)

# Launch Android Studio in background
/opt/android-studio/bin/studio.sh &
STUDIO_PID=$!

# Verify ADB lists the emulator device (Studio uses ADB to discover devices)
adb devices
# Expected output should include "emulator-5554 device"
```

**Key details:**
- Android Studio auto-discovers emulators via ADB. No manual configuration needed.
- Studio connects to the running emulator through `adb` which lists it as `emulator-5554`.
- The first Studio launch triggers license acceptance and setup wizard. For automated testing, this can be skipped with `-Didea.config.path` flags, but for runtime validation, the manual VNC walkthrough is acceptable.
- Studio needs significant memory. The container should be run with at least `--memory 4g` to accommodate both Studio and the emulator.

### Pattern 4: Flutter Web Target Validation

**What:** Create a test Flutter project and run it targeting Chrome inside the container.
**When to use:** For WEB-02 validation.
**Example:**
```bash
# Ensure DISPLAY is set and Xvfb is running (Pattern 1)

# Create a minimal Flutter test project
cd /tmp
flutter create flutter_web_test
cd flutter_web_test

# Run on Chrome (Chromium) -- this opens a browser window via DISPLAY
# Use --web-port to specify the port
flutter run -d chrome --web-port=8080 &
FLUTTER_WEB_PID=$!

# Give it time to compile and launch (first run is slow)
sleep 60

# Verify the web server is running
curl -s http://localhost:8080 | head -5

# Clean up
kill $FLUTTER_WEB_PID 2>/dev/null
rm -rf /tmp/flutter_web_test
```

**Key details:**
- `flutter run -d chrome` requires DISPLAY to be set because Chromium needs an X11 display even when rendering in headful mode.
- The `CHROME_EXECUTABLE=/usr/bin/chromium` env var is already set in the Dockerfile.
- First compilation is slow (~60-90 seconds). Subsequent hot-reloads are fast.
- Alternative: Use `flutter build web` to just verify the build works, then manually open in Chromium via VNC.

### Pattern 5: ADB Wireless Debugging Documentation

**What:** Instructions for connecting a physical Android device to the devcontainer via ADB wireless debugging.
**When to use:** For DISP-02 documentation requirement.

**Two methods to document:**

**Method A: Android 11+ Wireless Debugging (Recommended)**
```
1. On your Android device: Settings > Developer options > Wireless debugging > Enable
2. Tap "Pair device with pairing code" -- note the IP:PORT and pairing code
3. In the devcontainer terminal:
   adb pair <device-ip>:<pairing-port>
   # Enter the pairing code when prompted
4. After pairing, note the IP:PORT shown on the "Wireless debugging" screen
5. Connect:
   adb connect <device-ip>:<connect-port>
6. Verify:
   adb devices
```

**Method B: Legacy TCP/IP (Android 10 and below, or when USB is available initially)**
```
1. Connect device via USB to the host machine
2. On host: adb tcpip 5555
3. Disconnect USB
4. In the devcontainer terminal:
   adb connect <device-ip>:5555
5. Verify:
   adb devices
```

**Docker networking note:** The container must be on the same network as the physical device. Use `--network host` or ensure the container's network can reach the device's IP address.

### Anti-Patterns to Avoid

- **Starting GUI apps before Xvfb is ready:** Always poll with `xdpyinfo` before launching emulator or Studio. Launching too early causes silent failures or crashes.
- **Using `-no-window` for VNC validation:** The `-no-window` flag makes the emulator headless (no GUI window). For VNC validation, OMIT `-no-window` so the emulator renders its window on the Xvfb display.
- **Expecting fast emulator boot without KVM:** SwiftShader software rendering is 5-10x slower than hardware-accelerated emulation. Boot takes 2-5 minutes. Do not set short timeouts.
- **Running emulator as root:** The AVD and SDK are under `/home/dev`. Run the emulator as the `dev` user.
- **Forgetting `tr -d '\r'` on adb shell output:** ADB shell returns lines with `\r\n`. Comparing without stripping `\r` causes the boot polling loop to never match.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Emulator boot detection | Custom PID/port checking | `adb wait-for-device` + `getprop sys.boot_completed` | Standard pattern used by Google's own container scripts and CI systems |
| Display readiness check | `sleep 5` fixed delay | `xdpyinfo` polling loop | Fixed delays are fragile; xdpyinfo confirms X server is actually accepting connections |
| VNC password management | Custom auth scripts | `x11vnc -nopw` for dev or `-rfbauth` for password | x11vnc has built-in auth support |
| Flutter device discovery | Manual device ID lookup | `flutter devices` | Flutter CLI auto-discovers Chrome and emulator devices |
| ADB key management | Custom SSH-based auth | ADB's built-in RSA key pairing | ADB handles key generation and authorization automatically |

**Key insight:** This phase is purely validation -- it confirms that what Phase 1 built actually works at runtime. No new software needs to be installed. The work is in orchestrating startup sequences and verifying outputs.

## Common Pitfalls

### Pitfall 1: Emulator Fails to Start Without KVM

**What goes wrong:** `emulator: ERROR: x86_64 emulation currently requires hardware acceleration!`
**Why it happens:** The emulator defaults to requiring KVM hardware acceleration for x86_64 system images.
**How to avoid:** Use `-gpu swiftshader_indirect` flag AND ensure the AVD config has `hw.gpu.mode=swiftshader_indirect` (already set in Phase 1). On newer emulator versions, also try adding `-no-accel` if the error persists.
**Warning signs:** Error messages mentioning "KVM", "hardware acceleration", or "HAXM" at emulator startup.

### Pitfall 2: DISPLAY Not Set or Xvfb Not Running

**What goes wrong:** GUI applications fail with "Error: unable to open display" or "Cannot open display: :99"
**Why it happens:** DISPLAY environment variable not exported, or Xvfb process crashed/not started.
**How to avoid:** Always start Xvfb first, verify with `xdpyinfo`, then export DISPLAY before any GUI app.
**Warning signs:** "cannot open display" errors from emulator, Android Studio, or Chromium.

### Pitfall 3: Emulator Boot Timeout

**What goes wrong:** `sys.boot_completed` never returns "1" and the polling loop runs forever.
**Why it happens:** SwiftShader rendering is very slow. The emulator may need 5+ minutes to boot on a slow machine.
**How to avoid:** Set a generous timeout (10 minutes). Monitor emulator log output for crash messages. Ensure sufficient memory (`--memory 4g` on docker run).
**Warning signs:** Boot polling exceeds 5 minutes; emulator process exits unexpectedly.

### Pitfall 4: Flutter Web Fails to Find Chrome

**What goes wrong:** `flutter run -d chrome` fails with "Cannot find Chrome" or similar.
**Why it happens:** The `CHROME_EXECUTABLE` env var is set in the Dockerfile but may not be visible in interactive shells if the shell session doesn't inherit Docker ENV.
**How to avoid:** Verify `echo $CHROME_EXECUTABLE` shows `/usr/bin/chromium`. If not, export it manually or check that the Dockerfile ENV is correctly set.
**Warning signs:** `flutter devices` doesn't list "Chrome" as an available device.

### Pitfall 5: ADB Not Detecting Emulator

**What goes wrong:** `adb devices` shows empty list even though emulator is running.
**Why it happens:** ADB server not started, or emulator started on a different port, or ADB_SERVER_SOCKET mismatch.
**How to avoid:** Run `adb start-server` before starting the emulator. The emulator auto-registers with the ADB server on `localhost:5554`/`localhost:5555`.
**Warning signs:** `adb devices` returns empty or "offline" status.

### Pitfall 6: Inherited Tools Not in PATH

**What goes wrong:** `nvm`, `uv`, or `cargo` commands not found in the shell session.
**Why it happens:** These tools are configured via `.bashrc` which is only sourced in interactive bash sessions. Docker `exec` with `/bin/sh` or non-interactive bash won't source it.
**How to avoid:** For validation, use `docker exec -it <container> bash -l` (login shell) or explicitly source the relevant files: `source $NVM_DIR/nvm.sh`, `source $HOME/.cargo/env`, `export PATH=$HOME/.local/bin:$PATH`.
**Warning signs:** "command not found" for tools that should be inherited from base image.

### Pitfall 7: Container Memory Insufficient

**What goes wrong:** Emulator crashes, OOM kills, or Android Studio hangs.
**Why it happens:** Default Docker memory limits may be too low for running emulator (2GB RAM allocated to guest) + Android Studio + Flutter compilation simultaneously.
**How to avoid:** Run the container with `--memory 6g` or higher. If running emulator and Studio together, 8GB is safer.
**Warning signs:** Processes dying unexpectedly; `dmesg` showing OOM killer activity.

## Code Examples

### Complete Validation Script

```bash
#!/usr/bin/env bash
# validate-runtime.sh -- Run inside the Flutter devcontainer
# Usage: docker exec -it <container> bash /path/to/validate-runtime.sh

set -euo pipefail

echo "=== Phase 2: Runtime Validation ==="

# ── 1. Inherited Tools Check (TOOL-02, TOOL-03) ────────────────────────────

echo ""
echo "--- Checking inherited tools ---"

# NVM + Node.js (TOOL-02)
export NVM_DIR=/usr/local/nvm
. "$NVM_DIR/nvm.sh"
echo "NVM: $(nvm --version)"
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"

# UV (TOOL-03)
export PATH="$HOME/.local/bin:$PATH"
echo "UV: $(uv --version)"

# Rust (already validated in Phase 1, quick recheck)
. "$HOME/.cargo/env"
echo "Rust: $(rustc --version)"
echo "Cargo: $(cargo --version)"

echo "--- Inherited tools: PASS ---"

# ── 2. VNC Display Stack ────────────────────────────────────────────────────

echo ""
echo "--- Starting VNC display stack ---"

export DISPLAY=:99

Xvfb :99 -screen 0 1280x1024x24 &
XVFB_PID=$!

# Wait for Xvfb
for i in $(seq 1 30); do
    xdpyinfo -display :99 >/dev/null 2>&1 && break
    sleep 1
done

x11vnc -display :99 -forever -nopw -rfbport 5900 -quiet &
X11VNC_PID=$!

echo "VNC display stack running on :99 (VNC port 5900)"

# ── 3. Emulator Boot (IDE-02 prerequisite) ──────────────────────────────────

echo ""
echo "--- Starting Android emulator ---"

adb start-server

emulator -avd flutter_pixel7 \
    -gpu swiftshader_indirect \
    -no-audio \
    -no-boot-anim \
    -no-snapshot \
    -memory 2048 &
EMU_PID=$!

adb wait-for-device

echo "Waiting for emulator boot (this takes 2-5 minutes)..."
TIMEOUT=600
ELAPSED=0
while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "ERROR: Emulator boot timed out after ${TIMEOUT}s"
        exit 1
    fi
    echo "  ${ELAPSED}s elapsed..."
done

echo "Emulator booted! Checking ADB devices..."
adb devices
echo "--- Emulator: PASS ---"

# ── 4. Android Studio Launch (IDE-02) ───────────────────────────────────────

echo ""
echo "--- Launching Android Studio ---"

/opt/android-studio/bin/studio.sh &
STUDIO_PID=$!

# Give Studio time to start (it's heavy)
sleep 30

# Verify Studio process is running
if kill -0 $STUDIO_PID 2>/dev/null; then
    echo "Android Studio is running (PID: $STUDIO_PID)"
    echo "ADB devices (Studio should see emulator):"
    adb devices
    echo "--- Android Studio: PASS ---"
else
    echo "ERROR: Android Studio failed to start"
    exit 1
fi

# ── 5. Flutter Web (WEB-02) ────────────────────────────────────────────────

echo ""
echo "--- Testing Flutter web target ---"

cd /tmp
flutter create --platforms=web flutter_web_test >/dev/null 2>&1
cd flutter_web_test

# Build first to verify compilation works
flutter build web
echo "Flutter web build: PASS"

# Clean up
cd /
rm -rf /tmp/flutter_web_test

echo ""
echo "=== All Phase 2 checks PASSED ==="

# Cleanup
kill $STUDIO_PID 2>/dev/null || true
kill $EMU_PID 2>/dev/null || true
kill $X11VNC_PID 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true
```

### Docker Run Command for Validation

```bash
# Build the image first (Phase 1 output)
docker build -f trixie-vnc-flutter-rust-nvm-uv-claude/Dockerfile \
    -t flutter-devcontainer .

# Run interactively with enough memory, expose VNC port
docker run -it --rm \
    --memory 6g \
    -p 5900:5900 \
    -p 8080:8080 \
    flutter-devcontainer \
    bash
```

### ADB Wireless Debugging Documentation Block

```markdown
### ADB Wireless Debugging (Physical Devices)

#### Method A: Wireless Pairing (Android 11+, no USB needed)

1. On your Android device: **Settings > Developer options > Wireless debugging** > Enable
2. Tap **"Pair device with pairing code"** -- note the IP:PORT and 6-digit code
3. In the devcontainer:
   ```bash
   adb pair <device-ip>:<pairing-port>
   # Enter the 6-digit pairing code when prompted
   ```
4. After pairing, note the IP:PORT on the **"Wireless debugging"** screen header
5. Connect:
   ```bash
   adb connect <device-ip>:<connect-port>
   ```
6. Verify: `adb devices` should show the device

#### Method B: TCP/IP (requires USB initially)

1. Connect your device via USB to the host machine
2. On the **host** (not the container): `adb tcpip 5555`
3. Disconnect USB cable
4. In the devcontainer:
   ```bash
   adb connect <device-ip>:5555
   ```
5. Verify: `adb devices` should show the device

**Network note:** The container must reach the device's IP. Use `docker run --network host` or ensure both are on the same network.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `-no-window` for all headless | Keep window for VNC, `-no-window` only for true headless | 2020+ | VNC validation needs the emulator window visible |
| `emulator -gpu off` | `-gpu swiftshader_indirect` | 2019+ | SwiftShader provides actual GLES rendering without GPU hardware |
| `adb tcpip 5555` (USB required first) | `adb pair` wireless debugging (Android 11+) | Android 11 (2020) | No USB cable needed at all for wireless debugging |
| Manual ADB key setup for Docker | ADB auto-generates keys on first run | Ongoing | Keys at `~/.android/adbkey` are auto-created |
| VNC with password required | Development containers use `-nopw` | Common practice | Password not needed for local development containers |

**Deprecated/outdated:**
- `emulator -gpu off`: Disables all GPU emulation; many modern apps crash. Use `swiftshader_indirect` instead.
- Old KVM-only Docker emulator images: The SwiftShader approach works without KVM, making it portable.

## Open Questions

1. **First-launch Android Studio setup wizard**
   - What we know: Android Studio shows a setup wizard on first launch. It wants to download SDK components and accept licenses.
   - What's unclear: Whether the wizard can be skipped or pre-configured when all SDK components are already installed via cmdline-tools. Some JetBrains IDEs support `-Didea.is.internal=true` or config directory seeding.
   - Recommendation: Accept that the first Studio launch via VNC may require manual wizard interaction. This is acceptable for a devcontainer -- it only happens once per container instance. The planner should note this as a manual step.

2. **Emulator `-no-accel` flag availability**
   - What we know: Recent emulator versions have a `-no-accel` flag to explicitly disable hardware acceleration. Older versions only had `-gpu swiftshader_indirect`.
   - What's unclear: Whether the emulator version installed via sdkmanager in Phase 1 supports `-no-accel` and whether it's needed in addition to `-gpu swiftshader_indirect`.
   - Recommendation: Try without `-no-accel` first. If the emulator complains about KVM, add `-no-accel`.

3. **`flutter run -d chrome` vs `flutter build web` for validation**
   - What we know: `flutter run -d chrome` opens a browser window and starts a dev server. `flutter build web` just compiles to static files.
   - What's unclear: Whether `flutter run -d chrome` actually needs a visible Chromium window or can work headlessly. In a VNC environment, it should work since DISPLAY is set.
   - Recommendation: Use `flutter build web` as the primary validation (it proves compilation works), and `flutter run -d chrome` as a secondary interactive verification via VNC. The planner should treat `flutter build web` as the automated check and `flutter run -d chrome` as a manual VNC verification.

4. **Container memory requirements for simultaneous emulator + Studio**
   - What we know: Emulator allocates 2GB guest RAM. Android Studio typically needs 2-4GB. Flutter compilation needs 1-2GB.
   - What's unclear: The actual Docker container memory needed to run all three simultaneously.
   - Recommendation: Start with `--memory 6g`. If OOM occurs, increase to 8g. Document the minimum in the validation results.

## Sources

### Primary (HIGH confidence)
- Existing project Dockerfiles: `trixie-vnc-flutter-rust-nvm-uv-claude/Dockerfile`, `trixie-vnc-nvm-uv-claude/Dockerfile`, `base/Dockerfile` -- actual installed tools and configuration
- Phase 1 Research, Plans, and Summaries -- confirmed installed versions, paths, and patterns
- [Android developer docs - emulator acceleration](https://developer.android.com/studio/run/emulator-acceleration) -- SwiftShader flags, GPU rendering options
- [Android developer docs - ADB](https://developer.android.com/tools/adb) -- Wireless debugging, `adb pair`, `adb connect` commands

### Secondary (MEDIUM confidence)
- [Google android-emulator-container-scripts](https://github.com/google/android-emulator-container-scripts) -- Docker emulator patterns, ADB wait scripts
- [amrsa1/Android-Emulator-image start_vnc.sh](https://github.com/amrsa1/Android-Emulator-image/blob/main/start_vnc.sh) -- Xvfb + x11vnc startup sequence, display polling
- [J2V8 wait-for-emulator.sh](https://github.com/eclipsesource/J2V8/blob/master/docker/android/wait-for-emulator.sh) -- Boot completion polling pattern
- [ljishen/docker-vnc-android-studio](https://github.com/ljishen/docker-vnc-android-studio) -- Android Studio in Docker with VNC
- [budtmo/docker-android](https://github.com/budtmo/docker-android) -- Docker-based Android emulation with noVNC
- [Flutter issue #79072](https://github.com/flutter/flutter/issues/79072) -- Flutter Chrome driver display requirements

### Tertiary (LOW confidence)
- Exact memory requirements for simultaneous emulator + Studio + Flutter: Estimated from component requirements, needs runtime validation
- Android Studio setup wizard skip methods: Based on general JetBrains IDE knowledge, may not apply to current Studio version
- `-no-accel` flag: Mentioned in community forums but not verified against current emulator version installed by sdkmanager

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All tools already installed in Phase 1; versions and paths confirmed from Dockerfile and summaries
- Architecture (VNC + emulator startup): MEDIUM-HIGH -- Patterns confirmed from multiple Docker Android projects and Google's own scripts
- Architecture (Flutter web): MEDIUM -- `flutter build web` is straightforward; `flutter run -d chrome` with Xvfb less documented
- Pitfalls: HIGH -- Well-known issues documented across multiple sources (KVM errors, DISPLAY missing, boot timeout, \r stripping)
- ADB wireless debugging docs: HIGH -- Official Android developer documentation covers both methods thoroughly

**Research date:** 2026-02-24
**Valid until:** 2026-03-24 (30 days; no version-sensitive components since Phase 1 locked the versions)
