FROM devcontainer-base:latest

USER dev

# ── Rust (via rustup, installed as user) ──────────────────────────────────────

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . "$HOME/.cargo/env" \
    && rustup component add rustfmt clippy \
    && cargo install cargo-watch cargo-edit cargo-nextest \
    && rm -rf "$HOME/.cargo/registry" "$HOME/.cargo/git"

RUN echo 'source "$HOME/.cargo/env"' >> /home/dev/.bashrc
