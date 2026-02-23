FROM devcontainer-base:latest

USER root

# ── Bun ───────────────────────────────────────────────────────────────────────

RUN curl -fsSL https://bun.sh/install | bash \
    && mv /root/.bun/bin/bun /usr/local/bin/bun \
    && ln -s /usr/local/bin/bun /usr/local/bin/bunx \
    && rm -rf /root/.bun

RUN chown -R dev:dev /home/dev

USER dev
