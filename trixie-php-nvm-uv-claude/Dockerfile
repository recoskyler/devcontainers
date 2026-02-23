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
