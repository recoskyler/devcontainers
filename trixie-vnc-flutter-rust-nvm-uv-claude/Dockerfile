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

# ── Android Studio Panda 1 | 2025.3.1.5 ─────────────────────────────────────

ARG ANDROID_STUDIO_URL=https://dl.google.com/dl/android/studio/ide-zips/2025.3.1.5/android-studio-2025.3.1.5-linux.tar.gz

RUN curl -fsSL "$ANDROID_STUDIO_URL" -o /tmp/android-studio.tar.gz \
    && tar -xzf /tmp/android-studio.tar.gz -C /opt/ \
    && rm /tmp/android-studio.tar.gz

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

# Configure Android Studio path for flutter doctor detection
RUN flutter config --android-studio-dir=/opt/android-studio 2>/dev/null || true

# ── Rust (via rustup, installed as user) ──────────────────────────────────────
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . "$HOME/.cargo/env" \
    && rustup component add rustfmt clippy \
    && cargo install cargo-watch cargo-edit \
    && cargo install --locked cargo-nextest \
    && rm -rf "$HOME/.cargo/registry" "$HOME/.cargo/git"

RUN echo 'source "$HOME/.cargo/env"' >> /home/dev/.bashrc

# ── CLAUDE.md tools append ────────────────────────────────────────────────────
RUN printf '\n### Flutter & Android\n- `flutter`, `dart` via FVM (`fvm`)\n- Android SDK: cmdline-tools, platform-tools, build-tools 28.0.3 + 35.0.0, API 35 + 36\n- Android Emulator with SwiftShader (AVD: flutter_pixel7, Pixel 7, API 35)\n- Android Studio Panda 1 at /opt/android-studio\n- `chromium` (CHROME_EXECUTABLE set for `flutter run -d chrome`)\n\n### Rust\n- `rustc`, `cargo`, `rustup`, `rustfmt`, `clippy`\n- `cargo-watch`, `cargo-edit`, `cargo-nextest`\n\n### ADB Wireless Debugging (Physical Devices)\n\n**Method A: Wireless Pairing (Android 11+, no USB needed)**\n1. On device: Settings > Developer options > Wireless debugging > Enable\n2. Tap "Pair device with pairing code" -- note IP:PORT and 6-digit code\n3. In terminal: `adb pair <device-ip>:<pairing-port>` and enter the code\n4. Note IP:PORT on "Wireless debugging" screen header\n5. Connect: `adb connect <device-ip>:<connect-port>`\n6. Verify: `adb devices`\n\n**Method B: TCP/IP (requires USB initially)**\n1. Connect device via USB to host\n2. On host (not container): `adb tcpip 5555`\n3. Disconnect USB\n4. In terminal: `adb connect <device-ip>:5555`\n5. Verify: `adb devices`\n\n**Network note:** Container must reach device IP. Use `docker run --network host` or ensure same network.\n' >> $HOME/.claude/CLAUDE.md

# ── Build Verification ────────────────────────────────────────────────────────
RUN flutter doctor -v
