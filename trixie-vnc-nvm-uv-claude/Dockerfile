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
ENV HOME=/home/dev

RUN printf '\n### VNC\n- `x11vnc`, `xvfb-run`, `xdg-open`\n' >> $HOME/.claude/CLAUDE.md
