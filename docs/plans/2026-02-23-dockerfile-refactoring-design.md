# Dockerfile Refactoring Design

## Problem

The 4 Dockerfiles share ~80% identical content: apt packages, GH CLI, NVM+Node, ttyd, Claude Code, UV, scripts, and Agent Browser. Stripe CLI is only in the bun image but should be in all. Additional developer and cloud CLI tools are needed.

## Solution

Two-phase build with a shared base Dockerfile on `debian:trixie`.

## Architecture

```
base/Dockerfile (debian:trixie)
├── Merged apt packages (existing + new developer tools)
├── GH CLI, Stripe CLI
├── NVM + Node.js 24.12.0 + npm packages (npm@latest, tsx, pnpm)
├── ttyd (from source)
├── Developer tools (ripgrep, fd-find, fzf, bat, httpie, tree, git-delta, duf)
├── Cloud CLIs (AWS CLI v2, Terraform, kubectl)
├── UV (Python package manager)
├── Claude Code CLI
├── Scripts (ntfy, context7, init-mcp, setup-claude)
└── Agent Browser

trixie-bun-nvm-uv-claude/Dockerfile      → FROM devcontainer-base + Bun runtime
trixie-php-nvm-uv-claude/Dockerfile      → FROM devcontainer-base + PHP 8.3 + extensions + Composer
trixie-rust-nvm-uv-claude/Dockerfile     → FROM devcontainer-base + Rust toolchain + cargo tools
trixie-vnc-nvm-uv-claude/Dockerfile      → FROM devcontainer-base + x11vnc + xvfb
```

## Key Decisions

- **Common base**: `debian:trixie` (3 of 4 images already Trixie-based; noble drops in favor of Trixie)
- **Standardized username**: `dev` (UID 1000) across all images, replacing the current mix of `ubuntu`, `bun`, `vscode`, `rust`
- **Base not published**: Built as a local intermediate image in CI, never pushed to GHCR
- **Rename**: `noble-uv-vnc-claude` → `trixie-vnc-nvm-uv-claude`

## Merged apt-get Packages (base)

### Existing (union of all 4 images)

```
build-essential, ca-certificates, cmake, curl, default-mysql-client,
git, gnupg, jq, less, libjson-c-dev, libssl-dev, libuv1-dev,
libwebsockets-dev, lsb-release, nano, openssh-client, openssl,
poppler-utils, postgresql-client, python3-pip, redis-tools, sudo,
tmux, unzip, vim, wget, netcat-openbsd, xclip, pkg-config
```

### New developer tools (apt)

```
ripgrep, fd-find, fzf, bat, httpie, tree, duf
```

### Installed from releases/repos (not apt)

- **git-delta** — from GitHub releases
- **GH CLI** — from GitHub apt repo
- **Stripe CLI** — from Stripe apt repo
- **AWS CLI v2** — from Amazon official installer
- **Terraform** — from HashiCorp apt repo
- **kubectl** — from Kubernetes apt repo

## Per-Image Additions

| Image | Additions |
|-------|-----------|
| `trixie-bun-nvm-uv-claude` | Bun runtime via `curl -fsSL https://bun.sh/install` |
| `trixie-php-nvm-uv-claude` | PHP 8.3, php-redis, php-mysql, php-pcntl, Composer |
| `trixie-rust-nvm-uv-claude` | Rust via rustup, cargo-watch, cargo-edit, cargo-nextest, rustfmt, clippy |
| `trixie-vnc-nvm-uv-claude` | x11vnc, xvfb |

## CI Changes (build.yml)

Single job, sequential then parallel:
1. Build `base/Dockerfile` → tag `devcontainer-base:latest` (local)
2. Matrix build all 4 language images in parallel (each `FROM devcontainer-base:latest`)

## File Layout

```
devcontainers/
├── base/
│   └── Dockerfile
├── trixie-bun-nvm-uv-claude/
│   └── Dockerfile
├── trixie-php-nvm-uv-claude/
│   └── Dockerfile
├── trixie-rust-nvm-uv-claude/
│   └── Dockerfile
├── trixie-vnc-nvm-uv-claude/
│   └── Dockerfile
├── scripts/
│   ├── setup-claude.sh
│   ├── ntfy-hook.sh
│   ├── suggest-context7-hook.sh
│   └── init-claude-mcp.sh
└── .github/workflows/
    └── build.yml
```
