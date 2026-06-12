FROM trixie-vnc-nvm-uv-claude:latest

USER root
ENV HOME=/root

# ── Environment ──────────────────────────────────────────────────────────────

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV ANDROID_HOME=/home/dev/android-sdk
ENV ANDROID_SDK_ROOT=$ANDROID_HOME
ENV CHROME_EXECUTABLE=/usr/bin/chromium
ENV PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH

# ── System packages ──────────────────────────────────────────────────────────

RUN apt-get update \
    && apt-get -y install --no-install-recommends \
    openjdk-21-jdk-headless \
    chromium \
    libgl1 \
    libpulse0 \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxi6 \
    libxext6 \
    libxfixes3 \
    libxdamage1 \
    libnss3 \
    libglu1-mesa \
    libxrandr2 \
    libxtst6 \
    libdbus-1-3 \
    libfontconfig1 \
    libasound2t64 \
    libstdc++6 \
    zlib1g \
    unzip \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── Android cmdline-tools bootstrap ──────────────────────────────────────────

ARG CMDLINE_TOOLS_URL=https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip

RUN mkdir -p /home/dev/android-sdk/cmdline-tools \
    && curl -fsSL "$CMDLINE_TOOLS_URL" -o /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d /tmp \
    && mv /tmp/cmdline-tools /home/dev/android-sdk/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip

# Note: the full Android Studio IDE is intentionally NOT installed. Flutter and
# Android builds rely on the SDK (cmdline-tools, platform-tools, build-tools)
# installed via sdkmanager below; the GUI IDE added ~2-3GB to this image without
# being needed for headless `flutter build`/`test`. Install it at runtime if a
# GUI IDE is required over VNC.

# ── Ownership and user switch ────────────────────────────────────────────────

RUN chown -R dev:dev /home/dev

USER dev
ENV HOME=/home/dev

# ── Android SDK Components ───────────────────────────────────────────────────
RUN yes | sdkmanager --licenses >/dev/null 2>&1 \
    && sdkmanager \
        "platform-tools" \
        "platforms;android-35" \
        "platforms;android-36" \
        "build-tools;35.0.0" \
        "build-tools;28.0.3" \
        "emulator" \
        "system-images;android-35;google_apis;x86_64"

# ── Android Emulator AVD ─────────────────────────────────────────────────────
RUN echo "no" | avdmanager create avd \
        --force \
        --name "flutter_pixel7" \
        --package "system-images;android-35;google_apis;x86_64" \
        --tag "google_apis" \
        --abi "x86_64" \
        --device "pixel_7" \
    && printf 'hw.gpu.enabled=yes\nhw.gpu.mode=swiftshader_indirect\nhw.ramSize=2048\nhw.sdCard.size=4096M\n' \
        >> $HOME/.android/avd/flutter_pixel7.avd/config.ini

# ── FVM + Flutter ─────────────────────────────────────────────────────────────
RUN curl -fsSL https://fvm.app/install.sh | bash

ENV PATH=$HOME/fvm/bin:$HOME/fvm/default/bin:$PATH

RUN fvm install stable \
    && fvm global stable

# Accept Flutter-specific Android licenses
RUN yes | flutter doctor --android-licenses >/dev/null 2>&1 || true

# ── Rust (via rustup, installed as user) ──────────────────────────────────────
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . "$HOME/.cargo/env" \
    && rustup component add rustfmt clippy \
    && cargo install cargo-watch cargo-edit \
    && cargo install --locked cargo-nextest \
    && rm -rf "$HOME/.cargo/registry" "$HOME/.cargo/git"

RUN echo 'source "$HOME/.cargo/env"' >> /home/dev/.bashrc

# ── CLAUDE.md tools append ────────────────────────────────────────────────────
RUN printf '\n### Flutter & Android\n- `flutter`, `dart` via FVM (`fvm`)\n- Android SDK: cmdline-tools, platform-tools, build-tools 28.0.3 + 35.0.0, API 35 + 36\n- Android Emulator with SwiftShader (AVD: flutter_pixel7, Pixel 7, API 35)\n- `chromium` (CHROME_EXECUTABLE set for `flutter run -d chrome`)\n\n### Rust\n- `rustc`, `cargo`, `rustup`, `rustfmt`, `clippy`\n- `cargo-watch`, `cargo-edit`, `cargo-nextest`\n\n### ADB Wireless Debugging (Physical Devices)\n\n**Method A: Wireless Pairing (Android 11+, no USB needed)**\n1. On device: Settings > Developer options > Wireless debugging > Enable\n2. Tap "Pair device with pairing code" -- note IP:PORT and 6-digit code\n3. In terminal: `adb pair <device-ip>:<pairing-port>` and enter the code\n4. Note IP:PORT on "Wireless debugging" screen header\n5. Connect: `adb connect <device-ip>:<connect-port>`\n6. Verify: `adb devices`\n\n**Method B: TCP/IP (requires USB initially)**\n1. Connect device via USB to host\n2. On host (not container): `adb tcpip 5555`\n3. Disconnect USB\n4. In terminal: `adb connect <device-ip>:5555`\n5. Verify: `adb devices`\n\n**Network note:** Container must reach device IP. Use `docker run --network host` or ensure same network.\n\n### Android Emulator Known Issues\n\n**Kernel compatibility:** The Android emulator (v36.4.9.0) uses QEMU internally and may segfault on Linux kernel >= 6.17 (e.g., Fedora 43 kernel 6.17.7). This is an upstream QEMU/kernel incompatibility, not a container defect.\n\n**Workarounds:**\n- Use a host with kernel < 6.17 (e.g., Ubuntu 24.04 LTS with kernel 6.8)\n- Wait for a newer Android emulator release with QEMU fix\n- Use CI runners (GitHub Actions Ubuntu runners use compatible kernels)\n- For local development on affected kernels, use ADB wireless debugging with a physical device instead\n\n**KVM acceleration (optional):** If the host has KVM available, pass --device /dev/kvm to docker run for 5-10x faster emulator boot. The emulator auto-detects KVM; SwiftShader software rendering is used as fallback.\n' >> $HOME/.claude/CLAUDE.md

# ── Build Verification ────────────────────────────────────────────────────────
RUN flutter doctor -v
