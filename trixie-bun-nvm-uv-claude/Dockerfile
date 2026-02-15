ARG VARIANT=debian

FROM oven/bun:${VARIANT}

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install system packages
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    default-mysql-client \
    git \
    gnupg \
    jq \
    less \
    libjson-c-dev \
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
    xclip

# Stripe CLI
RUN curl -s https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public | gpg --dearmor | tee /usr/share/keyrings/stripe.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] https://packages.stripe.dev/stripe-cli-debian-local stable main" | tee -a /etc/apt/sources.list.d/stripe.list

# Install GH CLI and Stripe CLI
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) \
    && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get -y install --no-install-recommends gh stripe

RUN chsh -s $(which bash) bun \
    && echo 'export PS1="\e[01;32m\u\e[m:\e[01;34m\w\e[m\$ "' >> /home/bun/.bashrc

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Remove sudo password
RUN echo "bun ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

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
    && npm install -g npm@latest tsx pnpm

# ttyd
RUN cd /tmp \
    && git clone https://github.com/tsl0922/ttyd.git \
    && cd ttyd && mkdir build && cd build \
    && cmake .. && make && make install \
    && rm -rf /tmp/ttyd

# Playwright
RUN npx playwright install --with-deps firefox chrome

# Cleanup
RUN apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN chown -R bun:bun /home/bun

USER bun

# Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

WORKDIR /workspace

# UV
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && echo 'export PATH=$HOME/.local/bin:$PATH' >> /home/bun/.bashrc

# Claude Plugins, MCP, Hooks
ARG CONTEXT7_API_KEY=""
ARG AUTOMEM_ENDPOINT=""
ARG AUTOMEM_API_KEY=""
ARG NTFY_URL=""
ARG NTFY_TOKEN=""
ARG PLAYWRIGHT_MCP_ARGS="--headless --no-sandbox"

ENV CONTEXT7_API_KEY=${CONTEXT7_API_KEY}
ENV AUTOMEM_ENDPOINT=${AUTOMEM_ENDPOINT}
ENV AUTOMEM_API_KEY=${AUTOMEM_API_KEY}
ENV NTFY_URL=${NTFY_URL}
ENV NTFY_TOKEN=${NTFY_TOKEN}

COPY --chown=bun:bun scripts/ntfy-hook.sh $HOME/.local/bin/ntfy-hook.sh
COPY --chown=bun:bun scripts/suggest-context7-hook.sh $HOME/.local/bin/suggest-context7-hook.sh
COPY --chown=bun:bun scripts/init-claude-mcp.sh $HOME/.local/bin/init-claude-mcp.sh
RUN chmod +x $HOME/.local/bin/ntfy-hook.sh $HOME/.local/bin/suggest-context7-hook.sh $HOME/.local/bin/init-claude-mcp.sh

COPY --chown=bun:bun scripts/setup-claude.sh /tmp/setup-claude.sh
RUN bash /tmp/setup-claude.sh && rm -f /tmp/setup-claude.sh

RUN echo 'source $HOME/.local/bin/init-claude-mcp.sh 2>/dev/null' >> /home/bun/.bashrc

# agent-browser

USER root

RUN npm install -y -g agent-browser

RUN agent-browser install --with-deps

# Remove sudo password

RUN adduser bun sudo

RUN passwd -d bun

RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER bun
