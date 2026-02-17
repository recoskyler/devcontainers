ARG VARIANT=noble

FROM ubuntu:${VARIANT}

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV HOME=/home/ubuntu

# Install system packages
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    default-mysql-client \
    git \
    gnupg \
    jq \
    less \
    libatspi2.0-0 \
    libjson-c-dev \
    libnotify4 \
    libsecret-1-0 \
    libssl-dev \
    libuv1-dev \
    libwebsockets-dev \
    lsb-release \
    nano \
    openssh-client \
    openssl \
    poppler-utils \
    postgresql-client \
    python3-pip \
    redis-tools \
    sudo \
    tmux \
    unzip \
    vim \
    wget \
    x11vnc \
    xclip \
    xdg-utils \
    netcat-openbsd \
    xvfb

# Install GH CLI
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) \
    && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get -y install --no-install-recommends gh

RUN id ubuntu &>/dev/null || useradd -m -s /bin/bash -u 1000 ubuntu

RUN chsh -s $(which bash) ubuntu \
    && echo 'export PS1="\e[01;32m\u\e[m:\e[01;34m\w\e[m\$ "' >> /home/ubuntu/.bashrc

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Set debconf to run non-interactively
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# NVM
ENV NVM_DIR=/usr/local/nvm

RUN mkdir -p $NVM_DIR \
    && curl --silent -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# Node
ARG NODE_VERSION=24.12.0

RUN source $NVM_DIR/nvm.sh \
    && nvm install ${NODE_VERSION} \
    && nvm alias default ${NODE_VERSION} \
    && nvm use default

ENV NODE_PATH=$NVM_DIR/v${NODE_VERSION}/lib/node_modules
ENV PATH=$NVM_DIR/versions/node/v${NODE_VERSION}/bin:$PATH

RUN node -v && npm -v \
    && npm install -g npm@latest

# ttyd
RUN cd /tmp \
    && git clone https://github.com/tsl0922/ttyd.git \
    && cd ttyd && mkdir build && cd build \
    && cmake .. && make && make install \
    && rm -rf /tmp/ttyd

# Cleanup
RUN apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Switch to ubuntu user
RUN chown -R ubuntu:ubuntu /home/ubuntu

USER ubuntu

WORKDIR /workspace

# Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

# UV
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && echo 'export PATH=$HOME/.local/bin:$PATH' >> $HOME/.bashrc

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

COPY --chown=ubuntu:ubuntu scripts/ntfy-hook.sh $HOME/.local/bin/ntfy-hook.sh
COPY --chown=ubuntu:ubuntu scripts/suggest-context7-hook.sh $HOME/.local/bin/suggest-context7-hook.sh
COPY --chown=ubuntu:ubuntu scripts/init-claude-mcp.sh $HOME/.local/bin/init-claude-mcp.sh
RUN chmod +x $HOME/.local/bin/ntfy-hook.sh $HOME/.local/bin/suggest-context7-hook.sh $HOME/.local/bin/init-claude-mcp.sh

COPY --chown=ubuntu:ubuntu scripts/setup-claude.sh /tmp/setup-claude.sh
RUN bash /tmp/setup-claude.sh && rm -f /tmp/setup-claude.sh

RUN echo 'source $HOME/.local/bin/init-claude-mcp.sh 2>/dev/null' >> $HOME/.bashrc

# Python (via UV)
ARG PYTHON_VERSION=3.13

RUN $HOME/.local/bin/uv python install ${PYTHON_VERSION} \
    && $HOME/.local/bin/uv python pin ${PYTHON_VERSION} \
    && $HOME/.local/bin/uv init && $HOME/.local/bin/uv venv


# Remove sudo password

USER root

RUN adduser ubuntu sudo

RUN passwd -d ubuntu

RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# agent-browser

USER ubuntu

WORKDIR /workspace

RUN npm install -y -g agent-browser npm@latest pnpm tsx

RUN agent-browser install

# Requirements
# COPY ./requirements.txt /workspace/requirements.txt
# RUN source .venv/activate && $HOME/.local/bin/uv pip install -r requirements.txt
