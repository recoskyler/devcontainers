ARG VARIANT=8.3-trixie

FROM mcr.microsoft.com/devcontainers/php:${VARIANT}

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install quality-of-life packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends bash curl git vim mariadb-client libpq-dev libxml2-dev libcurl4-openssl-dev \
    libpng-dev \
    libwebp-dev \
    libxpm-dev \
    libzip-dev \
    zip \
    tmux \
    apt-transport-https \
    build-essential \
    wget \
    libmcrypt-dev \
    ca-certificates \
    curl \
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
    lsb-release \
    build-essential \
    libwebsockets-dev \
    libjson-c-dev \
    libuv1-dev \
    libssl-dev \
    python3-pip \
    poppler-utils \
    postgresql-client \
    default-mysql-client \
    redis-tools \
    ca-certificates \
    git \
    wget \
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
    postgresql-client \
    default-mysql-client \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*

# Install GH CLI
RUN  mkdir -p -m 755 /etc/apt/keyrings

RUN out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

RUN mkdir -p -m 755 /etc/apt/sources.list.d

RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# nvm environment variables
ENV NVM_DIR=/usr/local/nvm

RUN mkdir -p $NVM_DIR

# Install NVM
# https://github.com/creationix/nvm#install-script
RUN curl --silent -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# Install node and npm

ARG NODE_VERSION=24.12.0

RUN source $NVM_DIR/nvm.sh \
    && nvm install ${NODE_VERSION} \
    && nvm alias default ${NODE_VERSION} \
    && nvm use default

# Add node and npm to path so the commands are available
ENV NODE_PATH=$NVM_DIR/v${NODE_VERSION}/lib/node_modules
ENV PATH=$NVM_DIR/versions/node/v${NODE_VERSION}/bin:$PATH

# Confirm installation
RUN node -v
RUN npm -v

RUN npm install -g npm@latest

# ttyd

WORKDIR /tmp

RUN git clone https://github.com/tsl0922/ttyd.git

WORKDIR /tmp/ttyd

RUN mkdir build

WORKDIR /tmp/ttyd/build

RUN cmake ..
RUN make && make install

# GH CLI

RUN apt-get update \
    && apt-get -y install --no-install-recommends gh \
    && chsh -s $(which bash) vscode \
    && echo 'export PS1="\e[01;32m\u\e[m:\e[01;34m\w\e[m\$ "' >> /home/vscode/.bashrc

# Install Claude Code and Opencode globally
RUN npm install -g tsx pnpm

RUN npx playwright install --with-deps chrome

RUN npx playwright install --with-deps

# UV

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

RUN echo 'export PATH=$HOME/.local/bin:$PATH' >> /home/vscode/.bashrc

# Install composer for php deps.
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Composer uses its php binary, but we want it to use the container's one
RUN rm -f /usr/bin/php83
RUN ln -s /usr/local/bin/php /usr/bin/php83

# Adjust PHP memory limit
RUN echo "memory_limit=2048M" >> /usr/local/etc/php/php.ini

# Install redis driver.
RUN mkdir -p /usr/src/php/ext/redis; \
    curl -fsSL --ipv4 https://github.com/phpredis/phpredis/archive/6.0.2.tar.gz | tar xvz -C "/usr/src/php/ext/redis" --strip 1; \
    docker-php-ext-install redis pdo_mysql pcntl

# Cleanup

RUN rm -rf /tmp/ttyd
RUN rm -rf /var/lib/apt/lists/*
RUN apt-get autoremove -y
RUN apt-get clean

USER vscode

# Claude Code

RUN curl -fsSL https://claude.ai/install.sh | bash

# Hookify Fix

WORKDIR /home/vscode/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0

RUN ln -s . hookify

# ECC

WORKDIR /tmp

RUN git clone https://github.com/affaan-m/everything-claude-code.git

RUN mkdir -p $HOME/.claude/rules

RUN cp -r /tmp/everything-claude-code/rules/common/* ~/.claude/rules/

RUN cp -r /tmp/everything-claude-code/rules/typescript/* ~/.claude/rules/

RUN rm -rf /tmp/everything-claude-code

# GSD

WORKDIR /workspace

RUN npx -y get-shit-done-cc --claude --local

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

RUN $HOME/.local/bin/claude mcp add --transport stdio -s user --env="PLAYWRIGHT_CHROMIUM_ARGS=--no-sandbox --disable-setuid-sandbox" playwright -- npx -y @playwright/mcp@latest --headless

ARG CONTEXT7_API_KEY
ARG AUTOMEM_ENDPOINT
ARG AUTOMEM_API_KEY

RUN $HOME/.local/bin/claude mcp add --transport stdio -s user context7 -- npx -y @upstash/context7-mcp --api-key ${CONTEXT7_API_KEY}

RUN $HOME/.local/bin/claude mcp add --transport stdio -s user --env="AUTOMEM_ENDPOINT=${AUTOMEM_ENDPOINT}" --env="AUTOMEM_API_KEY=${AUTOMEM_API_KEY}" automem -- npx -y @verygoodplugins/mcp-automem

RUN $HOME/.local/bin/claude mcp add --transport http figma https://mcp.figma.com/mcp

# Ntfy Hook

ARG NTFY_URL
ARG NTFY_TOKEN

RUN mkdir -p ~/.claude && \
    [ -f ~/.claude.json ] || echo '{}' > ~/.claude.json && \
    HOOKS_JSON='{"Notification":[{"matcher":"*","hooks":[{"type":"command","command":"bash -c '\''D=$(cat); curl -H \"Markdown: yes\" -H \"Priority: max\" -H \"Title: Çekirge: $(echo \"$D\"|jq -r \".title // \\\"Notification\\\"\")\" -H \"Tags: cricket,warning\" -u :__NTFY_TOKEN__ -d \"$(echo \"$D\"|jq -r \"\\\"**Type:** \\(.notification_type // \\\"notification\\\")\\n\\n\\(.message // \\\"No details\\\")\\n\\n\\\"**Tool:** \\(.tool_name // \\\"unknown\\\")\\n\\n\\(.tool_input // \\\"No details\\\")\\\"\")\" __NTFY_URL__'\''"}]}],"Stop":[{"matcher":"*","hooks":[{"type":"command","command":"bash -c '\''D=$(cat); curl -H \"Markdown: yes\" -H \"Title: Çekirge: Stopped\" -H \"Tags: cricket,white_check_mark\" -u :__NTFY_TOKEN__ -d \"$(echo \"$D\"|jq -r \"\\\"**Session:** \\(.session_id // \\\"unknown\\\")\\n**Directory:** \\(.cwd // \\\"unknown\\\")\\\"\")\" __NTFY_URL__'\''"}]}]}' && \
    HOOKS_JSON="${HOOKS_JSON//__NTFY_TOKEN__/${NTFY_TOKEN}}" && \
    HOOKS_JSON="${HOOKS_JSON//__NTFY_URL__/${NTFY_URL}}" && \
    jq --argjson newhooks "$HOOKS_JSON" '. + {hooks: ((.hooks // {}) * $newhooks)}' ~/.claude.json > ~/.claude.json.tmp && \
    mv ~/.claude.json.tmp ~/.claude.json
