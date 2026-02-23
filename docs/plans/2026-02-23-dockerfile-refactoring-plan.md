# Dockerfile Refactoring Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract repeated Dockerfile sections into a shared base, add Stripe CLI + developer/cloud tools to all images, and slim each language Dockerfile to only its unique additions.

**Architecture:** A `base/Dockerfile` on `debian:trixie` installs all shared tooling. Each language image does `FROM devcontainer-base:latest` and adds only its runtime. CI builds base first as a local image, then builds all language images in parallel.

**Tech Stack:** Docker, Docker Buildx, GitHub Actions, debian:trixie

---

### Task 1: Create the shared base Dockerfile

**Files:**
- Create: `base/Dockerfile`

**Step 1: Create `base/Dockerfile`**

```dockerfile
FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── System packages ───────────────────────────────────────────────────────────

RUN apt-get update \
    && apt-get -y install --no-install-recommends \
    apt-transport-https \
    bash \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    default-mysql-client \
    duf \
    fd-find \
    fzf \
    git \
    gnupg \
    httpie \
    jq \
    less \
    libjson-c-dev \
    libssl-dev \
    libuv1-dev \
    libwebsockets-dev \
    lsb-release \
    nano \
    netcat-openbsd \
    openssh-client \
    openssl \
    pkg-config \
    poppler-utils \
    postgresql-client \
    python3-pip \
    redis-tools \
    ripgrep \
    sudo \
    tmux \
    tree \
    unzip \
    vim \
    wget \
    xclip \
    bat

# ── GH CLI ────────────────────────────────────────────────────────────────────

RUN mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) \
    && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get -y install --no-install-recommends gh

# ── Stripe CLI ────────────────────────────────────────────────────────────────

RUN curl -s https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public | gpg --dearmor | tee /usr/share/keyrings/stripe.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] https://packages.stripe.dev/stripe-cli-debian-local stable main" | tee -a /etc/apt/sources.list.d/stripe.list \
    && apt-get update \
    && apt-get -y install --no-install-recommends stripe

# ── git-delta (from GitHub releases) ─────────────────────────────────────────

RUN ARCH=$(dpkg --print-architecture) \
    && DELTA_VERSION=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest | jq -r '.tag_name') \
    && curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_${ARCH}.deb" -o /tmp/delta.deb \
    && dpkg -i /tmp/delta.deb \
    && rm /tmp/delta.deb

# ── AWS CLI v2 ────────────────────────────────────────────────────────────────

RUN ARCH=$(uname -m) \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# ── Terraform ─────────────────────────────────────────────────────────────────

RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
       | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get -y install --no-install-recommends terraform

# ── kubectl ───────────────────────────────────────────────────────────────────

RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" \
       | tee /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update \
    && apt-get -y install --no-install-recommends kubectl

# ── User setup ────────────────────────────────────────────────────────────────

RUN id dev &>/dev/null || useradd -m -s /bin/bash -u 1000 dev

RUN chsh -s $(which bash) dev \
    && echo 'export PS1="\e[01;32m\u\e[m:\e[01;34m\w\e[m\$ "' >> /home/dev/.bashrc

RUN rm -f /bin/sh && ln -s /bin/bash /bin/sh

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# ── NVM + Node.js ─────────────────────────────────────────────────────────────

ENV NVM_DIR=/usr/local/nvm

RUN mkdir -p $NVM_DIR \
    && curl --silent -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

ARG NODE_VERSION=24.12.0

RUN source $NVM_DIR/nvm.sh \
    && nvm install ${NODE_VERSION} \
    && nvm alias default ${NODE_VERSION} \
    && nvm use default

ENV NODE_PATH=$NVM_DIR/v${NODE_VERSION}/lib/node_modules
ENV PATH=$NVM_DIR/versions/node/v${NODE_VERSION}/bin:$PATH

RUN node -v && npm -v \
    && npm install -g npm@latest tsx pnpm

# ── ttyd (from source) ───────────────────────────────────────────────────────

RUN cd /tmp \
    && git clone https://github.com/tsl0922/ttyd.git \
    && cd ttyd && mkdir build && cd build \
    && cmake .. && make && make install \
    && rm -rf /tmp/ttyd

# ── Cleanup ───────────────────────────────────────────────────────────────────

RUN apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN chown -R dev:dev /home/dev

# ── User-space tools ─────────────────────────────────────────────────────────

USER dev
ENV HOME=/home/dev

WORKDIR /workspace

# Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

# UV
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && echo 'export PATH=$HOME/.local/bin:$PATH' >> /home/dev/.bashrc

# Claude Plugins, MCP, Hooks
ARG CONTEXT7_API_KEY=""
ARG AUTOMEM_ENDPOINT=""
ARG AUTOMEM_API_KEY=""
ARG NTFY_URL=""
ARG NTFY_TOKEN=""

ENV CONTEXT7_API_KEY=${CONTEXT7_API_KEY}
ENV AUTOMEM_ENDPOINT=${AUTOMEM_ENDPOINT}
ENV AUTOMEM_API_KEY=${AUTOMEM_API_KEY}
ENV NTFY_URL=${NTFY_URL}
ENV NTFY_TOKEN=${NTFY_TOKEN}

COPY --chown=dev:dev scripts/ntfy-hook.sh $HOME/.local/bin/ntfy-hook.sh
COPY --chown=dev:dev scripts/suggest-context7-hook.sh $HOME/.local/bin/suggest-context7-hook.sh
COPY --chown=dev:dev scripts/init-claude-mcp.sh $HOME/.local/bin/init-claude-mcp.sh
RUN chmod +x $HOME/.local/bin/ntfy-hook.sh $HOME/.local/bin/suggest-context7-hook.sh $HOME/.local/bin/init-claude-mcp.sh

COPY --chown=dev:dev scripts/setup-claude.sh /tmp/setup-claude.sh
RUN bash /tmp/setup-claude.sh && rm -f /tmp/setup-claude.sh

RUN echo 'source $HOME/.local/bin/init-claude-mcp.sh 2>/dev/null' >> /home/dev/.bashrc

# ── Sudo + Agent Browser (requires root) ─────────────────────────────────────

USER root

RUN adduser dev sudo \
    && passwd -d dev \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

WORKDIR /workspace

RUN npm install -y -g agent-browser \
    && agent-browser install --with-deps

RUN chown -R dev:dev /home/dev

USER dev
```

**Step 2: Verify base builds**

Run: `docker build -t devcontainer-base:latest -f base/Dockerfile .`
Expected: Successful build (may take several minutes on first run)

**Step 3: Commit**

```bash
git add base/Dockerfile
git commit --no-gpg-sign -m "feat: add shared base Dockerfile with merged dependencies"
```

---

### Task 2: Rewrite trixie-bun-nvm-uv-claude Dockerfile

**Files:**
- Modify: `trixie-bun-nvm-uv-claude/Dockerfile` (replace entire contents)

**Step 1: Replace Dockerfile contents**

```dockerfile
FROM devcontainer-base:latest

USER root

# ── Bun ───────────────────────────────────────────────────────────────────────

RUN curl -fsSL https://bun.sh/install | bash \
    && mv /root/.bun/bin/bun /usr/local/bin/bun \
    && ln -s /usr/local/bin/bun /usr/local/bin/bunx \
    && rm -rf /root/.bun

RUN chown -R dev:dev /home/dev

USER dev
```

**Step 2: Verify build**

Run: `docker build -t trixie-bun-nvm-uv-claude:test -f trixie-bun-nvm-uv-claude/Dockerfile .`
Expected: Successful build. Test with `docker run --rm trixie-bun-nvm-uv-claude:test bun --version`

**Step 3: Commit**

```bash
git add trixie-bun-nvm-uv-claude/Dockerfile
git commit --no-gpg-sign -m "refactor: slim bun Dockerfile to extend shared base"
```

---

### Task 3: Rewrite trixie-php-nvm-uv-claude Dockerfile

**Files:**
- Modify: `trixie-php-nvm-uv-claude/Dockerfile` (replace entire contents)

**Step 1: Replace Dockerfile contents**

```dockerfile
FROM devcontainer-base:latest

USER root

# ── PHP 8.3 ───────────────────────────────────────────────────────────────────

RUN apt-get update \
    && apt-get -y install --no-install-recommends \
    libcurl4-openssl-dev \
    libmcrypt-dev \
    libpng-dev \
    libpq-dev \
    libwebp-dev \
    libxml2-dev \
    libxpm-dev \
    libzip-dev \
    mariadb-client \
    php8.3 \
    php8.3-cli \
    php8.3-common \
    php8.3-curl \
    php8.3-mbstring \
    php8.3-mysql \
    php8.3-pcntl \
    php8.3-redis \
    php8.3-xml \
    php8.3-zip \
    zip \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN chown -R dev:dev /home/dev

USER dev
```

Note: PHP 8.3 packages come from Debian Trixie repos natively. The `docker-php-ext-install` command from the old mcr.microsoft.com base is replaced by direct apt packages. If Trixie doesn't have php8.3-redis or php8.3-pcntl, we'll need the sury.org repo — verify during build.

**Step 2: Verify build**

Run: `docker build -t trixie-php-nvm-uv-claude:test -f trixie-php-nvm-uv-claude/Dockerfile .`
Expected: Successful build. Test with `docker run --rm trixie-php-nvm-uv-claude:test php -v`

**Step 3: Commit**

```bash
git add trixie-php-nvm-uv-claude/Dockerfile
git commit --no-gpg-sign -m "refactor: slim PHP Dockerfile to extend shared base"
```

---

### Task 4: Rewrite trixie-rust-nvm-uv-claude Dockerfile

**Files:**
- Modify: `trixie-rust-nvm-uv-claude/Dockerfile` (replace entire contents)

**Step 1: Replace Dockerfile contents**

```dockerfile
FROM devcontainer-base:latest

USER dev

# ── Rust (via rustup, installed as user) ──────────────────────────────────────

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . "$HOME/.cargo/env" \
    && rustup component add rustfmt clippy \
    && cargo install cargo-watch cargo-edit cargo-nextest \
    && rm -rf "$HOME/.cargo/registry" "$HOME/.cargo/git"

RUN echo 'source "$HOME/.cargo/env"' >> /home/dev/.bashrc
```

**Step 2: Verify build**

Run: `docker build -t trixie-rust-nvm-uv-claude:test -f trixie-rust-nvm-uv-claude/Dockerfile .`
Expected: Successful build. Test with `docker run --rm trixie-rust-nvm-uv-claude:test bash -c 'source ~/.cargo/env && rustc --version'`

**Step 3: Commit**

```bash
git add trixie-rust-nvm-uv-claude/Dockerfile
git commit --no-gpg-sign -m "refactor: slim Rust Dockerfile to extend shared base"
```

---

### Task 5: Rename noble-uv-vnc-claude to trixie-vnc-nvm-uv-claude

**Files:**
- Delete: `noble-uv-vnc-claude/Dockerfile`
- Create: `trixie-vnc-nvm-uv-claude/Dockerfile`

**Step 1: Rename directory and rewrite Dockerfile**

```bash
git mv noble-uv-vnc-claude trixie-vnc-nvm-uv-claude
```

**Step 2: Replace Dockerfile contents**

```dockerfile
FROM devcontainer-base:latest

USER root

# ── VNC ───────────────────────────────────────────────────────────────────────

RUN apt-get update \
    && apt-get -y install --no-install-recommends \
    x11vnc \
    xvfb \
    xdg-utils \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN chown -R dev:dev /home/dev

USER dev
```

**Step 3: Verify build**

Run: `docker build -t trixie-vnc-nvm-uv-claude:test -f trixie-vnc-nvm-uv-claude/Dockerfile .`
Expected: Successful build. Test with `docker run --rm trixie-vnc-nvm-uv-claude:test which x11vnc`

**Step 4: Commit**

```bash
git add noble-uv-vnc-claude trixie-vnc-nvm-uv-claude
git commit --no-gpg-sign -m "refactor: rename noble-vnc to trixie-vnc, extend shared base"
```

---

### Task 6: Update CI workflow (build.yml)

**Files:**
- Modify: `.github/workflows/build.yml`

**Step 1: Rewrite build.yml for two-phase build**

The key change: build the base image first, then build all language images.
Since GitHub Actions matrix jobs run on separate runners, we need either:
- (a) A single job that builds base then each image sequentially, OR
- (b) Two jobs: `build-base` pushes base to GHCR as a private intermediate image, then `build-images` matrix pulls it

Option (a) is simplest — single job, sequential builds, base cached via GHA cache:

```yaml
name: Build and Push Docker Images

on:
  push:
    branches: [latest]
    tags: ["v*"]

env:
  REGISTRY: ghcr.io

jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 45
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build base image
        uses: docker/build-push-action@v6
        with:
          context: .
          file: base/Dockerfile
          push: false
          load: true
          tags: devcontainer-base:latest
          cache-from: type=gha,scope=base
          cache-to: type=gha,mode=max,scope=base

      - name: Build and push trixie-bun-nvm-uv-claude
        uses: docker/build-push-action@v6
        with:
          context: .
          file: trixie-bun-nvm-uv-claude/Dockerfile
          push: true
          tags: ${{ env.REGISTRY }}/${{ github.repository_owner }}/trixie-bun-nvm-uv-claude:latest
          cache-from: type=gha,scope=trixie-bun-nvm-uv-claude
          cache-to: type=gha,mode=max,scope=trixie-bun-nvm-uv-claude

      - name: Build and push trixie-php-nvm-uv-claude
        uses: docker/build-push-action@v6
        with:
          context: .
          file: trixie-php-nvm-uv-claude/Dockerfile
          push: true
          tags: ${{ env.REGISTRY }}/${{ github.repository_owner }}/trixie-php-nvm-uv-claude:latest
          cache-from: type=gha,scope=trixie-php-nvm-uv-claude
          cache-to: type=gha,mode=max,scope=trixie-php-nvm-uv-claude

      - name: Build and push trixie-rust-nvm-uv-claude
        uses: docker/build-push-action@v6
        with:
          context: .
          file: trixie-rust-nvm-uv-claude/Dockerfile
          push: true
          tags: ${{ env.REGISTRY }}/${{ github.repository_owner }}/trixie-rust-nvm-uv-claude:latest
          cache-from: type=gha,scope=trixie-rust-nvm-uv-claude
          cache-to: type=gha,mode=max,scope=trixie-rust-nvm-uv-claude

      - name: Build and push trixie-vnc-nvm-uv-claude
        uses: docker/build-push-action@v6
        with:
          context: .
          file: trixie-vnc-nvm-uv-claude/Dockerfile
          push: true
          tags: ${{ env.REGISTRY }}/${{ github.repository_owner }}/trixie-vnc-nvm-uv-claude:latest
          cache-from: type=gha,scope=trixie-vnc-nvm-uv-claude
          cache-to: type=gha,mode=max,scope=trixie-vnc-nvm-uv-claude
```

Note: Semver tagging and metadata extraction should be added back for release tags. The above is simplified for clarity — the full version should include the `docker/metadata-action` steps per image for proper tag handling. This is left as an implementation detail.

**Step 2: Verify CI syntax**

Run: `gh act push --dryrun` (if act is installed)

**Step 3: Commit**

```bash
git add .github/workflows/build.yml
git commit --no-gpg-sign -m "ci: update workflow for two-phase base + language image builds"
```

---

### Task 7: Validate full build chain locally

**Step 1: Build base**

Run: `docker build -t devcontainer-base:latest -f base/Dockerfile .`

**Step 2: Build each image**

Run all four in sequence:
```bash
docker build -t trixie-bun-nvm-uv-claude:test -f trixie-bun-nvm-uv-claude/Dockerfile .
docker build -t trixie-php-nvm-uv-claude:test -f trixie-php-nvm-uv-claude/Dockerfile .
docker build -t trixie-rust-nvm-uv-claude:test -f trixie-rust-nvm-uv-claude/Dockerfile .
docker build -t trixie-vnc-nvm-uv-claude:test -f trixie-vnc-nvm-uv-claude/Dockerfile .
```

**Step 3: Smoke test each image**

```bash
docker run --rm trixie-bun-nvm-uv-claude:test bash -c 'bun --version && node -v && gh --version && stripe --version && rg --version && aws --version && terraform --version && kubectl version --client'
docker run --rm trixie-php-nvm-uv-claude:test bash -c 'php -v && composer --version && node -v'
docker run --rm trixie-rust-nvm-uv-claude:test bash -c 'source ~/.cargo/env && rustc --version && cargo --version && node -v'
docker run --rm trixie-vnc-nvm-uv-claude:test bash -c 'which x11vnc && node -v && claude --version'
```

**Step 4: Fix any issues and commit fixes**

---

### Task 8: Update CLAUDE.md project structure

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update the project structure section to reflect new layout**

Replace the project structure section with:
```markdown
## Project structure

- ROOT
  - base
    - Dockerfile (shared base image — debian:trixie with all common tools)
  - [DOCKER_IMAGE_NAME]
    - Dockerfile (extends devcontainer-base with language-specific tools)
  - scripts
    - setup-claude.sh
    - ntfy-hook.sh
    - suggest-context7-hook.sh
    - init-claude-mcp.sh
  - .github
    - workflows
      - build.yml
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit --no-gpg-sign -m "docs: update CLAUDE.md project structure for base image refactor"
```
