#!/usr/bin/env bash
# verify-tools.sh -- Verify expected tools are installed in a devcontainer image
# Usage: bash verify-tools.sh <variant>
#   variant: base, trixie-bun-*, trixie-php-*, trixie-rust-*,
#            trixie-vnc-flutter-*, trixie-vnc-*

set -uo pipefail  # NO set -e — must run all checks even if some fail

# ── Counters ─────────────────────────────────────────────────────────────────

PASSED=0
FAILED=0

# ── Environment sourcing ────────────────────────────────────────────────────

export PATH="$HOME/.local/bin:$PATH"

# NVM
export NVM_DIR="${NVM_DIR:-/usr/local/nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Cargo/Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# FVM/Flutter
[ -d "$HOME/fvm/bin" ] && export PATH="$HOME/fvm/bin:$HOME/fvm/default/bin:$PATH"

# Android SDK
[ -d "${ANDROID_HOME:-}/cmdline-tools" ] && \
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# ── Helper functions ─────────────────────────────────────────────────────────

pass() {
    PASSED=$((PASSED + 1))
    echo "  PASS: $1"
}

fail() {
    FAILED=$((FAILED + 1))
    echo "  FAIL: $1"
}

check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        pass "$1"
    else
        fail "$1 not found"
    fi
}

check_any() {
    local label="$1"
    shift
    for cmd in "$@"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            pass "$label ($cmd)"
            return
        fi
    done
    fail "$label (tried: $*)"
}

check_file() {
    local label="$1"
    local path="$2"
    if [ -e "$path" ]; then
        pass "$label"
    else
        fail "$label not found at $path"
    fi
}

# ── Verification sections ───────────────────────────────────────────────────

verify_base() {
    echo ""
    echo "=== Base tools ==="

    # System
    for cmd in git curl wget jq less sudo unzip tmux tree vim nano xclip; do
        check_cmd "$cmd"
    done

    # Search / modern CLI
    check_cmd rg
    check_cmd fzf
    check_any "bat" bat batcat
    check_any "fd" fd fdfind
    check_cmd tldr
    check_cmd duf

    # DevOps
    for cmd in gh aws terraform kubectl stripe; do
        check_cmd "$cmd"
    done

    # Node.js ecosystem
    if type nvm >/dev/null 2>&1; then
        pass "nvm"
    else
        fail "nvm not found (shell function)"
    fi
    for cmd in node npm npx pnpm tsx; do
        check_cmd "$cmd"
    done

    # Python
    check_cmd uv

    # Build tools
    for cmd in gcc g++ make cmake pkg-config; do
        check_cmd "$cmd"
    done

    # DB clients
    for cmd in psql mysql redis-cli; do
        check_cmd "$cmd"
    done

    # Network
    for cmd in ssh nc http; do
        check_cmd "$cmd"
    done

    # Other
    for cmd in ttyd delta agent-browser claude pi clideck; do
        check_cmd "$cmd"
    done
}

verify_bun() {
    echo ""
    echo "=== Bun tools ==="
    for cmd in bun bunx; do
        check_cmd "$cmd"
    done
}

verify_php() {
    echo ""
    echo "=== PHP tools ==="
    for cmd in php composer; do
        check_cmd "$cmd"
    done
}

verify_rust() {
    echo ""
    echo "=== Rust tools ==="
    for cmd in rustc cargo rustup rustfmt cargo-clippy cargo-watch cargo-set-version cargo-nextest; do
        check_cmd "$cmd"
    done
}

verify_vnc() {
    echo ""
    echo "=== VNC tools ==="
    for cmd in x11vnc xvfb-run xdg-open; do
        check_cmd "$cmd"
    done
}

verify_flutter() {
    echo ""
    echo "=== Flutter tools ==="
    for cmd in flutter dart fvm java chromium adb sdkmanager avdmanager; do
        check_cmd "$cmd"
    done
}

# ── Main dispatch ────────────────────────────────────────────────────────────

VARIANT="${1:-}"

if [ -z "$VARIANT" ]; then
    echo "Usage: verify-tools.sh <variant>"
    echo "Variants: base, trixie-bun-*, trixie-php-*, trixie-rust-*, trixie-vnc-flutter-*, trixie-vnc-*"
    exit 1
fi

echo "========================================"
echo "  Tool Verification: $VARIANT"
echo "========================================"

verify_base

case "$VARIANT" in
    *flutter*)
        verify_rust
        verify_vnc
        verify_flutter
        ;;
    *vnc*)
        verify_vnc
        ;;
    *bun*)
        verify_bun
        ;;
    *php*)
        verify_php
        ;;
    *rust*)
        verify_rust
        ;;
    base)
        # base only — no extra sections
        ;;
    *)
        echo "WARNING: Unknown variant '$VARIANT' — only base tools checked"
        ;;
esac

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "========================================"
echo "  Verification Summary"
echo "========================================"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
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
