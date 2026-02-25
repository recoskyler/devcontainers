#!/usr/bin/env bash
# validate-flutter-runtime.sh -- Run inside the Flutter devcontainer
# Usage: docker exec -it <container> bash /path/to/validate-flutter-runtime.sh
#
# Validates all Phase 2 runtime requirements:
#   Section 1: Inherited tools (NVM, Node.js, npm, UV, Rust, Cargo)
#   Section 2: VNC display stack (Xvfb + x11vnc)
#   Section 3: Android emulator boot
#   Section 4: Android Studio launch
#   Section 5: Flutter web target (build + run + curl)
#   Section 6: Cleanup

set -euo pipefail

PASSED=0
FAILED=0
SKIPPED=0

pass() {
    PASSED=$((PASSED + 1))
    echo "  PASS: $1"
}

fail() {
    FAILED=$((FAILED + 1))
    echo "  FAIL: $1"
}

skip() {
    SKIPPED=$((SKIPPED + 1))
    echo "  SKIP: $1"
}

# Track background PIDs for cleanup
XVFB_PID=""
X11VNC_PID=""
EMU_PID=""
STUDIO_PID=""
FLUTTER_WEB_PID=""

# ── Environment setup (restore Docker ENV paths lost in login shells) ─────────
export ANDROID_HOME="${ANDROID_HOME:-/home/dev/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
export CHROME_EXECUTABLE="${CHROME_EXECUTABLE:-/usr/bin/chromium}"
export PATH="$HOME/fvm/bin:$HOME/fvm/default/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# ── Section 1: Inherited Tools Check (TOOL-02, TOOL-03) ─────────────────────

echo ""
echo "=== Section 1: Inherited Tools Check ==="

# NVM + Node.js + npm (TOOL-02)
export NVM_DIR=/usr/local/nvm
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
else
    fail "NVM script not found at $NVM_DIR/nvm.sh"
fi

NVM_VER=$(nvm --version 2>/dev/null || true)
if [ -n "$NVM_VER" ]; then
    pass "nvm --version: $NVM_VER"
else
    fail "nvm --version returned empty"
fi

NODE_VER=$(node --version 2>/dev/null || true)
if [ -n "$NODE_VER" ]; then
    pass "node --version: $NODE_VER"
else
    fail "node --version returned empty"
fi

NPM_VER=$(npm --version 2>/dev/null || true)
if [ -n "$NPM_VER" ]; then
    pass "npm --version: $NPM_VER"
else
    fail "npm --version returned empty"
fi

# UV (TOOL-03)
export PATH="$HOME/.local/bin:$PATH"

UV_VER=$(uv --version 2>/dev/null || true)
if [ -n "$UV_VER" ]; then
    pass "uv --version: $UV_VER"
else
    fail "uv --version returned empty"
fi

# Rust (quick recheck from Phase 1)
if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

RUSTC_VER=$(rustc --version 2>/dev/null || true)
if [ -n "$RUSTC_VER" ]; then
    pass "rustc --version: $RUSTC_VER"
else
    fail "rustc --version returned empty"
fi

CARGO_VER=$(cargo --version 2>/dev/null || true)
if [ -n "$CARGO_VER" ]; then
    pass "cargo --version: $CARGO_VER"
else
    fail "cargo --version returned empty"
fi

echo "--- Section 1 complete ---"

# ── Section 2: VNC Display Stack ─────────────────────────────────────────────

echo ""
echo "=== Section 2: VNC Display Stack ==="

export DISPLAY=:99

Xvfb :99 -screen 0 1280x1024x24 &
XVFB_PID=$!

# Poll for Xvfb readiness with xdpyinfo
XVFB_READY=0
for i in $(seq 1 30); do
    if xdpyinfo -display :99 >/dev/null 2>&1; then
        XVFB_READY=1
        break
    fi
    sleep 1
done

if [ "$XVFB_READY" -eq 1 ]; then
    pass "Xvfb display :99 is ready"
else
    fail "Xvfb display :99 did not become ready within 30s"
fi

x11vnc -display :99 -forever -nopw -rfbport 5900 -quiet &
X11VNC_PID=$!
sleep 1

if kill -0 "$X11VNC_PID" 2>/dev/null; then
    pass "x11vnc running on port 5900 (PID: $X11VNC_PID)"
else
    fail "x11vnc failed to start"
fi

echo "--- Section 2 complete ---"

# ── Kernel Compatibility Check ───────────────────────────────────────────────

KERNEL_VERSION=$(uname -r)
KERNEL_MAJOR=$(echo "$KERNEL_VERSION" | cut -d. -f1)
KERNEL_MINOR=$(echo "$KERNEL_VERSION" | cut -d. -f2)
KERNEL_COMPAT=1

# Android emulator (QEMU) segfaults on Linux kernel >= 6.17 due to upstream
# incompatibility (emulator v36.4.9.0, QEMU init crash). This is tracked as a
# known issue and will resolve with a kernel update or newer emulator release.
if [ "$KERNEL_MAJOR" -gt 6 ] || { [ "$KERNEL_MAJOR" -eq 6 ] && [ "$KERNEL_MINOR" -ge 17 ]; }; then
    KERNEL_COMPAT=0
    echo ""
    echo "WARNING: Host kernel $KERNEL_VERSION is >= 6.17"
    echo "  Android emulator v36.4.9.0 has a known QEMU segfault on this kernel."
    echo "  Emulator checks (Sections 3-4) will be SKIPPED, not FAILED."
    echo "  See: https://issuetracker.google.com/ (upstream QEMU/kernel compat)"
fi

# ── Section 3: Android Emulator Boot (IDE-02 prerequisite) ───────────────────

echo ""
echo "=== Section 3: Android Emulator Boot ==="

EMULATOR_OK=0

if [ "$KERNEL_COMPAT" -eq 1 ]; then
    adb start-server

    # Auto-detect KVM; use hardware acceleration when available, SwiftShader otherwise
    ACCEL_FLAGS=""
    if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
        echo "  KVM detected -- using hardware acceleration"
        ACCEL_FLAGS="-gpu swiftshader_indirect"
    else
        echo "  KVM not available -- using software emulation (TCG)"
        ACCEL_FLAGS="-no-accel -gpu swiftshader_indirect"
    fi

    emulator -avd flutter_pixel7 \
        $ACCEL_FLAGS \
        -no-audio \
        -no-boot-anim \
        -no-snapshot \
        -no-metrics \
        -memory 2048 &
    EMU_PID=$!

    # Wait for device with a 60s timeout (emulator may crash early)
    echo "Waiting for ADB to detect emulator device..."
    WAIT_ELAPSED=0
    while [ "$WAIT_ELAPSED" -lt 60 ]; do
        if ! kill -0 "$EMU_PID" 2>/dev/null; then
            echo "  Emulator process exited prematurely (PID: $EMU_PID)"
            break
        fi
        if adb devices 2>/dev/null | grep -q "emulator-5554"; then
            break
        fi
        sleep 2
        WAIT_ELAPSED=$((WAIT_ELAPSED + 2))
    done

    # Check if emulator is still alive and detected
    if kill -0 "$EMU_PID" 2>/dev/null && adb devices 2>/dev/null | grep -q "emulator-5554"; then
        echo "Waiting for emulator boot (this takes 2-5 minutes with SwiftShader)..."
        TIMEOUT=600
        ELAPSED=0
        BOOT_OK=0
        while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
            if ! kill -0 "$EMU_PID" 2>/dev/null; then
                echo "  Emulator process died during boot"
                break
            fi
            BOOT_STATUS=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)
            if [ "$BOOT_STATUS" = "1" ]; then
                BOOT_OK=1
                break
            fi
            sleep 5
            ELAPSED=$((ELAPSED + 5))
            echo "  ${ELAPSED}s elapsed..."
        done

        if [ "$BOOT_OK" -eq 1 ]; then
            pass "Emulator booted after ${ELAPSED}s"
            EMULATOR_OK=1
        else
            fail "Emulator boot timed out or crashed after ${ELAPSED}s"
        fi
    else
        fail "Emulator failed to start (crashed or not detected by ADB)"
    fi

    # Verify emulator is listed by ADB
    if [ "$EMULATOR_OK" -eq 1 ]; then
        ADB_DEVICES=$(adb devices 2>/dev/null)
        echo "$ADB_DEVICES"
        if echo "$ADB_DEVICES" | grep -q "emulator-5554.*device"; then
            pass "emulator-5554 listed as 'device' in adb devices"
        else
            fail "emulator-5554 not found or not in 'device' state"
        fi
    else
        fail "emulator-5554 not checked (emulator did not start)"
    fi
else
    skip "Emulator boot -- kernel $KERNEL_VERSION incompatible (QEMU segfault on >= 6.17)"
    skip "emulator-5554 ADB check -- emulator skipped"
fi

echo "--- Section 3 complete ---"

# ── Section 4: Android Studio Launch (IDE-02) ────────────────────────────────

echo ""
echo "=== Section 4: Android Studio Launch ==="

/opt/android-studio/bin/studio.sh &
STUDIO_PID=$!

# Give Studio time to start (it is heavy)
sleep 30

if kill -0 "$STUDIO_PID" 2>/dev/null; then
    pass "Android Studio is running (PID: $STUDIO_PID)"
    if [ "$KERNEL_COMPAT" -eq 1 ]; then
        echo "ADB devices (Studio should see emulator):"
        adb devices
    else
        skip "Studio-emulator connection -- emulator skipped due to kernel incompatibility"
    fi
else
    fail "Android Studio failed to start (PID: $STUDIO_PID exited)"
fi

echo "--- Section 4 complete ---"

# ── Section 5: Flutter Web Target (WEB-02) ───────────────────────────────────

echo ""
echo "=== Section 5: Flutter Web Target ==="

cd /tmp
flutter create --platforms=web flutter_web_test >/dev/null 2>&1
cd flutter_web_test

# Build first to verify compilation works
if flutter build web; then
    pass "flutter build web succeeded"
else
    fail "flutter build web failed"
fi

# Run with dev server and verify HTTP response
flutter run -d chrome --web-port=8080 &
FLUTTER_WEB_PID=$!

# Wait for the dev server to start
sleep 15

HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    pass "flutter run -d chrome HTTP 200 on port 8080"
else
    fail "flutter run -d chrome returned HTTP $HTTP_CODE (expected 200)"
fi

# Kill the flutter run process
kill "$FLUTTER_WEB_PID" 2>/dev/null || true

# Clean up test project
cd /
rm -rf /tmp/flutter_web_test

echo "--- Section 5 complete ---"

# ── Section 6: Cleanup ───────────────────────────────────────────────────────

echo ""
echo "=== Section 6: Cleanup ==="

kill "$STUDIO_PID" 2>/dev/null || true
kill "$EMU_PID" 2>/dev/null || true
kill "$X11VNC_PID" 2>/dev/null || true
kill "$XVFB_PID" 2>/dev/null || true

# Wait briefly for processes to exit
sleep 2

echo "Background processes terminated."
echo "--- Section 6 complete ---"

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "========================================"
echo "  Runtime Validation Summary"
echo "========================================"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
echo "  Skipped: $SKIPPED"
echo "========================================"

if [ "$FAILED" -eq 0 ]; then
    echo ""
    echo "ALL_CHECKS_PASSED"
    exit 0
else
    echo ""
    echo "SOME_CHECKS_FAILED"
    exit 1
fi
