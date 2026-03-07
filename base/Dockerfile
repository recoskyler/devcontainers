FROM debian:trixie

# ── Environment ──────────────────────────────────────────────────────────────

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── System packages (apt-get) ────────────────────────────────────────────────

RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common

RUN add-apt-repository -y ppa:git-core/ppa

RUN apt-get update \
    && apt-get -y install --no-install-recommends \
    apt-transport-https \
    bash \
    bat \
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
    bzip2 \
    file \
    fonts-dejavu-core \
    g++ \
    libz-dev \
    locales \
    make \
    netbase \
    patch \
    uuid-runtime \
    tzdata

RUN localedef -i en_US -f UTF-8 en_US.UTF-8

RUN useradd -m -s /bin/bash linuxbrew

RUN echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers

ENV PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH

WORKDIR /home/linuxbrew

RUN cd /home/linuxbrew/.linuxbrew \
  && mkdir -p bin etc include lib opt sbin share var/homebrew/linked Cellar \
  && ln -s ../Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/ \
  && git -C /home/linuxbrew/.linuxbrew/Homebrew remote set-url origin https://github.com/Homebrew/brew \
  && HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_AUTO_UPDATE=1 brew tap homebrew/core \
  && brew install-bundler-gems \
  && brew install tealdeer \
  && brew cleanup \
  && rm -rf ~/.cache \
  && chown -R linuxbrew: /home/linuxbrew/.linuxbrew \
  && chmod -R g+w,o-w /home/linuxbrew/.linuxbrew

WORKDIR /workspace

# ── CLI tools (apt repos) ───────────────────────────────────────────────────

# Stripe CLI
RUN curl -s https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public | gpg --dearmor | tee /usr/share/keyrings/stripe.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] https://packages.stripe.dev/stripe-cli-debian-local stable main" | tee -a /etc/apt/sources.list.d/stripe.list

# GH CLI + Stripe CLI install
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) \
    && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get -y install --no-install-recommends gh stripe

# ── CLI tools (releases) ────────────────────────────────────────────────────

# git-delta (GitHub .deb release)
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_${ARCH}.deb" -o /tmp/git-delta.deb \
    && dpkg -i /tmp/git-delta.deb \
    && rm -f /tmp/git-delta.deb

# AWS CLI v2
RUN ARCH=$(uname -m) \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# Terraform (HashiCorp apt repo)
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
       | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get -y install --no-install-recommends terraform

# kubectl (Kubernetes apt repo v1.32)
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" \
       | tee /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update \
    && apt-get -y install --no-install-recommends kubectl

# ── User setup ───────────────────────────────────────────────────────────────

RUN id dev >/dev/null 2>&1 || useradd -m -s /bin/bash -u 1000 dev

RUN chsh -s $(which bash) dev \
    && echo 'export PS1="\e[01;32m\u\e[m:\e[01;34m\w\e[m\$ "' >> /home/dev/.bashrc

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Set debconf to run non-interactively
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Passwordless sudo
RUN echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ── NVM + Node.js ────────────────────────────────────────────────────────────

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

# ── ttyd (built from source) ────────────────────────────────────────────────

RUN cd /tmp \
    && git clone https://github.com/tsl0922/ttyd.git \
    && cd ttyd && mkdir build && cd build \
    && cmake .. && make && make install \
    && rm -rf /tmp/ttyd

# ── Cleanup ──────────────────────────────────────────────────────────────────

RUN apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN chown -R dev:dev /home/dev

# ── User-space tools (as USER dev) ──────────────────────────────────────────

USER dev
ENV HOME=/home/dev

# Claude Code CLI
RUN curl -fsSL https://claude.ai/install.sh | bash

ENV PATH=$HOME/.local/bin:$PATH

# User-level CLAUDE.md for the devcontainer
RUN mkdir -p $HOME/.claude
COPY --chown=dev:dev base/devcontainer-claude.md $HOME/.claude/CLAUDE.md

WORKDIR /workspace

# UV
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

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

RUN tldr --update

# ── Final root section ──────────────────────────────────────────────────────

USER root

RUN adduser dev sudo

RUN passwd -d dev

RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# agent-browser
WORKDIR /workspace

RUN npm install -y -g agent-browser

RUN agent-browser install --with-deps

RUN chown -R dev:dev /home/dev

USER dev
