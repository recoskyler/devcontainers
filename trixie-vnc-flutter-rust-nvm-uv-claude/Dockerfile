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
