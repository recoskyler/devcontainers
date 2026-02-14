ARG VARIANT=noble

FROM ubuntu:${VARIANT}

ARG NODE_VERSION=24.12.0
ARG PYTHON_VERSION=3.13

###############################################################################

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV HOME=/home/ubuntu

RUN apt-get update \
    && apt-get -y install --no-install-recommends \
    ca-certificates \
    git \
    curl \
    wget \
    vim \
    openssh-client \
    openssl \
    gnupg \
    nano \
    sudo \
    vim-tiny \
    jq \
    unzip \
    cmake \
    less \
    tmux \
    xclip \
    lsb-release \
    build-essential \
    libwebsockets-dev \
    x11vnc \
    libjson-c-dev \
    libuv1-dev \
    libssl-dev \
    python3-pip \
    poppler-utils \
    xvfb \
    libnotify4 \
    xdg-utils \
    libatspi2.0-0 \
    libsecret-1-0 \
    xdg-utils \
    libatspi2.0-0 \
    libsecret-1-0 \
    postgresql-client \
    default-mysql-client \
    redis-tools

# nvm environment variables
ENV NVM_DIR /usr/local/nvm

RUN mkdir -p $NVM_DIR

# Install NVM
# https://github.com/creationix/nvm#install-script
RUN curl --silent -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# Replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Set debconf to run non-interactively
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Install node and npm
RUN source $NVM_DIR/nvm.sh \
    && nvm install ${NODE_VERSION} \
    && nvm alias default ${NODE_VERSION} \
    && nvm use default

# Add node and npm to path so the commands are available
ENV NODE_PATH $NVM_DIR/v${NODE_VERSION}/lib/node_modules
ENV PATH $NVM_DIR/versions/node/v${NODE_VERSION}/bin:$PATH

# Confirm installation
RUN node -v
RUN npm -v

RUN npm install -g npm@latest

# Playwright

RUN npx playwright install --with-deps
RUN npx playwright install --with-deps chrome

# Claude Code

RUN chown -R ubuntu:ubuntu /home/ubuntu

USER ubuntu

WORKDIR /workspace

RUN curl -fsSL https://claude.ai/install.sh | bash

# UV

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

RUN echo 'export PATH=$HOME/.local/bin:$PATH' >> $HOME/.bashrc

# Claude Plugins

RUN $HOME/.local/bin/claude plugin marketplace add affaan-m/everything-claude-code
RUN $HOME/.local/bin/claude plugin install everything-claude-code@everything-claude-code

RUN $HOME/.local/bin/claude plugin marketplace add obra/superpowers
RUN $HOME/.local/bin/claude plugin install superpowers@superpowers-dev

RUN $HOME/.local/bin/claude plugin marketplace add anthropics/claude-code
RUN $HOME/.local/bin/claude plugin install code-review@claude-code-plugins
RUN $HOME/.local/bin/claude plugin install commit-commands@claude-code-plugins
RUN $HOME/.local/bin/claude plugin install explanatory-output-style@claude-code-plugins
RUN $HOME/.local/bin/claude plugin install hookify@claude-code-plugins
RUN $HOME/.local/bin/claude plugin install feature-dev@claude-code-plugins
RUN $HOME/.local/bin/claude plugin install frontend-design@claude-code-plugins
RUN $HOME/.local/bin/claude plugin install learning-output-style@claude-code-plugins
RUN $HOME/.local/bin/claude plugin install ralph-wiggum@claude-code-plugins
RUN $HOME/.local/bin/claude plugin install pr-review-toolkit@claude-code-plugins
RUN $HOME/.local/bin/claude plugin install security-guidance@claude-code-plugins

# MCP

RUN $HOME/.local/bin/claude mcp add --transport stdio -s user serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context=claude-code --project-from-cwd

RUN $HOME/.local/bin/claude mcp add --transport stdio -s user --env="PLAYWRIGHT_CHROMIUM_ARGS=--no-sandbox --disable-setuid-sandbox" playwright -- npx -y @playwright/mcp@latest

RUN $HOME/.local/bin/claude mcp add --transport stdio -s user context7 -- npx -y @upstash/context7-mcp --api-key ${CONTEXT7_API_KEY}

RUN $HOME/.local/bin/claude mcp add --transport stdio -s user --env="AUTOMEM_ENDPOINT=${AUTOMEM_ENDPOINT}" --env="AUTOMEM_API_KEY=${AUTOMEM_API_KEY}" automem -- npx -y @verygoodplugins/mcp-automem

RUN $HOME/.local/bin/claude mcp add --transport http figma https://mcp.figma.com/mcp

# Ntfy Hook

RUN mkdir -p ~/.claude && \
    [ -f ~/.claude.json ] || echo '{}' > ~/.claude.json && \
    HOOKS_JSON='{"Notification":[{"matcher":"*","hooks":[{"type":"command","command":"bash -c '\''D=$(cat); curl -H \"Markdown: yes\" -H \"Priority: max\" -H \"Title: Çekirge: $(echo \"$D\"|jq -r \".title // \\\"Notification\\\"\")\" -H \"Tags: cricket,warning\" -u :${NTFY_TOKEN} -d \"$(echo \"$D\"|jq -r \"\\\"**Type:** \\(.notification_type // \\\"notification\\\")\\n\\n\\(.message // \\\"No details\\\")\\n\\n\\\"**Tool:** \\(.tool_name // \\\"unknown\\\")\\n\\n\\(.tool_input // \\\"No details\\\")\\\"\")\" ${NTFY_URL}'\''"}]}],"Stop":[{"matcher":"*","hooks":[{"type":"command","command":"bash -c '\''D=$(cat); curl -H \"Markdown: yes\" -H \"Title: Çekirge: Stopped\" -H \"Tags: cricket,white_check_mark\" -u :${NTFY_TOKEN} -d \"$(echo \"$D\"|jq -r \"\\\"**Session:** \\(.session_id // \\\"unknown\\\")\\n**Directory:** \\(.cwd // \\\"unknown\\\")\\\"\")\" ${NTFY_URL}'\''"}]}]}' && \
    jq --argjson newhooks "$HOOKS_JSON" '. + {hooks: ((.hooks // {}) * $newhooks)}' ~/.claude.json > ~/.claude.json.tmp && \
    mv ~/.claude.json.tmp ~/.claude.json

# Hookify Fix

WORKDIR /home/ubuntu/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0

RUN ln -s . hookify

# ECC

WORKDIR /tmp

RUN git clone https://github.com/affaan-m/everything-claude-code.git

RUN mkdir -p $HOME/.claude/rules

RUN cp -r /tmp/everything-claude-code/rules/common/* ~/.claude/rules/

RUN cp -r /tmp/everything-claude-code/rules/typescript/* ~/.claude/rules/

RUN rm -rf /tmp/everything-claude-code

# GCD

WORKDIR /workspace

RUN npx -y get-shit-done-cc --claude --local

# VENV

RUN $HOME/.local/bin/uv python install ${PYTHON_VERSION}

RUN $HOME/.local/bin/uv python pin ${PYTHON_VERSION}

RUN $HOME/.local/bin/uv init && $HOME/.local/bin/uv venv

# Requirements

# COPY ./requirements.txt /workspace/requirements.txt

# RUN source .venv/bin/activate && $HOME/.local/bin/uv pip install -r requirements.txt

# Cleanup

USER root

RUN rm -rf /var/lib/apt/lists/*
RUN apt-get autoremove -y
RUN apt-get clean

USER ubuntu