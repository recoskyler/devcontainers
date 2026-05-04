# Dev Containers

Docker-based dev containers with Claude Code, MCP servers, and common tooling pre-installed. Each image targets a different stack/project type.

## Usage

1. Create a Dockerfile

    `PROJECT_ROOT/.devcontainer/Dockerfile`

    ```Dockerfile
    FROM ghcr.io/recoskyler/trixie-bun-nvm-uv-claude:latest
    ```

2. Create a Docker Compose file

    `PROJECT_ROOT/.devcontainer/compose.yml`

    ```yaml
    services:
        app:
            build:
                context: .
                dockerfile: Dockerfile
                args:
                    NODE_VERSION: '24.12.0'

            ports:
                - "0.0.0.0:7681:7681" # TTYD
                - '6901:6901' # VNC

            networks:
                - default

            environment:
                - CONTEXT7_API_KEY=your-key
                - NTFY_URL=https://ntfy.sh/your-topic
                - NTFY_TOKEN=your-token
                - ENABLE_TOOL_SEARCH=true
                - ENABLE_EXPERIMENTAL_MCP_CLI=false
                - CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="1"
                - DISPLAY=":0"

            logging:
                options:
                    max-size: 10m
                    max-file: 3

            volumes:
                - ..:/workspace:cached
                - home:/home
                - /var/run/docker.sock:/var/run/docker.sock
                # Host credentials (see "Host Credentials" section below)
                - ~/.claude:/home/dev/.claude
                - ~/.ssh:/home/dev/.ssh:ro
                - ~/.gitconfig:/home/dev/.gitconfig:ro
                - ~/.config/gh:/home/dev/.config/gh:ro
                - ~/.config/github-copilot:/home/dev/.config/github-copilot:ro

            # Overrides default command so things don't
            # shut down after the process ends
            command: sleep infinity

            # Chrome/VNC might need the following options:

            security_opt:
                - seccomp:unconfined

            cap_add:
                - SYS_ADMIN
                - CAP_SYS_ADMIN
                - SYS_PTRACE
                - CAP_SYS_PTRACE
                - IPC_LOCK
                - SYS_NICE
                - CAP_SYS_NICE

            ipc: host
            init: true

    volumes:
        home:

    networks:
        default:
            driver: bridge
    ```

3. Create a `devcontainer.json` file:

    `PROJECT_ROOT/.devcontainer/devcontainer.json`

    ```json
    {
        "$schema": "https://raw.githubusercontent.com/devcontainers/spec/refs/heads/main/schemas/devContainer.base.schema.json",
        "name": "DevContainer",
        "dockerComposeFile": "compose.yml",
        "service": "app",
        "workspaceFolder": "/workspace",

        "mounts": [
            "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
        ],

        "forwardPorts": [3000, 4983, 5173, 5174],

        "portsAttributes": {
            "5174": {
                "label": "Vite Preview Server",
                "onAutoForward": "openBrowserOnce"
            },
            "5173": {
                "label": "Vite Dev Server",
                "onAutoForward": "openBrowserOnce"
            },
            "3000": {
                "label": "Node.js Server",
                "onAutoForward": "openBrowserOnce"
            },
            "4983": {
                "label": "Drizzle Studio",
                "onAutoForward": "silent"
            }
        },

        "customizations": {
            "vscode": {
                "extensions": [
                    "EditorConfig.EditorConfig",
                    "ms-python.python",
                    "dbaeumer.vscode-eslint",
                    "esbenp.prettier-vscode",
                    "ms-azuretools.vscode-docker",
                    "Orta.vscode-jest",
                    "42Crunch.vscode-openapi",
                    "yzhang.markdown-all-in-one",
                    "YoavBls.pretty-ts-errors"
                ]
            }
        }
        // Uncomment to connect as root instead. More info: https://aka.ms/dev-containers-non-root.
        // "remoteUser": "root"
    }
    ```

## Images

All images extend a shared base (`base/Dockerfile` — `debian:trixie`) and run as user `dev` (UID 1000, home `/home/dev`).

| Image | Extra stack |
|-------|-------------|
| `ghcr.io/recoskyler/devcontainer-base:latest` | — (base only) |
| `ghcr.io/recoskyler/trixie-bun-nvm-uv-claude:latest` | Bun |
| `ghcr.io/recoskyler/trixie-php-nvm-uv-claude:latest` | PHP 8.4, Composer |
| `ghcr.io/recoskyler/trixie-rust-nvm-uv-claude:latest` | Rust toolchain |
| `ghcr.io/recoskyler/trixie-vnc-nvm-uv-claude:latest` | x11vnc, Xvfb |
| `ghcr.io/recoskyler/trixie-vnc-flutter-rust-nvm-uv-claude:latest` | Flutter, Rust, Android SDK, VNC |

## What's Included

### All images (base)

- **Node.js** via NVM (default: 24.12.0)
- **UV** (Python package manager)
- **Claude Code** CLI + plugins (ECC, Superpowers, official plugin suite)
- **MCP servers**: Serena, Context7
- **GSD** — Get Shit Done coding workflow (Claude Code via [get-shit-done-cc](https://github.com/gsd-build/get-shit-done-cc), Pi via [gsd-pi](https://github.com/gsd-build/gsd-2))
- **MemPalace** — local AI memory; mines projects and conversations into a searchable palace, no API key required ([MemPalace/mempalace](https://github.com/MemPalace/mempalace))
- **Graphify** — knowledge-graph skill; turns any folder of code, docs, papers, images, or videos into a queryable graph ([safishamsi/graphify](https://github.com/safishamsi/graphify))
- **Agent Browser** + Chrome
- **gstack** — 28 specialized Claude Code engineering skills ([garrytan/gstack](https://github.com/garrytan/gstack))
- **Bun** runtime (`bun`, `bunx`)
- **Docker** CLI + Compose plugin (`docker`, `docker compose`) — mount the host socket to use; works without `sudo` (the entrypoint automatically matches the socket's GID)
- **CLI tools**: git, curl, wget, vim, nano, jq, tmux, xclip, openssh-client, gnupg, cmake, less, unzip, gh, pnpm, tsx
- **Search & file tools**: ripgrep, fd-find, fzf, bat, tree
- **PDF tools**: poppler-utils (pdftotext, pdfinfo, etc.)
- **Networking & HTTP**: httpie, netcat
- **Cloud & infra**: AWS CLI v2, Terraform, kubectl, Stripe CLI
- **Utilities**: duf, git-delta, tldr
- **ttyd** (web terminal)
- **Database clients**: postgresql-client, default-mysql-client, redis-tools
- **ntfy** notification hooks (Notification + Stop events)
- **pi** — minimal terminal coding harness, with `pi-agent-browser` for browser automation
- **CliDeck** — one dashboard for all your AI coding agents

### Bun (`trixie-bun-nvm-uv-claude`)

- **Bun** runtime (`bun`, `bunx`)

### PHP (`trixie-php-nvm-uv-claude`)

- **PHP 8.4** (cli, curl, mbstring, mysql, redis, xml, zip)
- **Composer**

### Rust (`trixie-rust-nvm-uv-claude`)

- **Rust** toolchain (via rustup)
- **rustfmt** + **clippy**
- **cargo-watch** (file watcher / auto-rebuild)
- **cargo-edit** (`cargo add`/`cargo rm`)
- **cargo-nextest** (modern test runner)

### VNC (`trixie-vnc-nvm-uv-claude`)

- **x11vnc**, **Xvfb**, xdg-utils

### Flutter (`trixie-vnc-flutter-rust-nvm-uv-claude`)

Extends the VNC image with Flutter, Rust, and Android tooling.

- **Flutter** via FVM (`flutter`, `dart`, `fvm`)
- **Rust** toolchain (rustup, rustfmt, clippy, cargo-watch, cargo-edit, cargo-nextest)
- **Android SDK**: cmdline-tools, platform-tools, build-tools (28.0.3 + 35.0.0), API 35 + 36
- **Android Emulator** with SwiftShader (AVD: `flutter_pixel7`, Pixel 7, API 35)
- **Android Studio** Panda 1 (at `/opt/android-studio`)
- **Chromium** (`CHROME_EXECUTABLE` set for `flutter run -d chrome`)
- **OpenJDK 21** (headless)

## Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `NODE_VERSION` | `24.12.0` | Node.js version installed via NVM |

## Runtime Environment Variables

Secret-dependent MCP servers and ntfy hooks are configured at **runtime** (first shell login) via environment variables. Pass these in your compose `environment` section or via `docker run -e`.

| Variable | Description |
|----------|-------------|
| `CONTEXT7_API_KEY` | [Context7](https://context7.com) MCP server API key (skipped if empty) |
| `NTFY_URL` | [ntfy](https://ntfy.sh) server/topic URL for notification hooks (skipped if empty) |
| `NTFY_TOKEN` | [ntfy](https://ntfy.sh) authentication token for notification hooks (skipped if empty) |

> Optional MCP servers and ntfy hooks are only configured when their corresponding environment variables are set.

## Host Credentials

Mount host directories to forward credentials and settings into the container. The entrypoint automatically merges image-built tooling (plugins, skills, rules, GSD) with your host files — nothing is lost.

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| `~/.claude` | `/home/dev/.claude` | Claude Code auth, settings, memory, and projects |
| `~/.ssh` | `/home/dev/.ssh:ro` | SSH keys for git and remote access |
| `~/.gitconfig` | `/home/dev/.gitconfig:ro` | Git identity and config |
| `~/.config/gh` | `/home/dev/.config/gh:ro` | GitHub CLI auth tokens |
| `~/.config/github-copilot` | `/home/dev/.config/github-copilot:ro` | GitHub Copilot OAuth tokens |
| `~/.gnupg` | `/home/dev/.gnupg:ro` | GPG keys for signed commits |

> **How the `~/.claude` merge works:** At build time, the image snapshots all tooling to `/opt/devcontainer-claude/`. When a host `~/.claude` bind-mount is detected at container start, the entrypoint copies missing tooling (plugins, skills, rules, GSD) into the mounted directory without overwriting host files. The image's `CLAUDE.md` is appended if the host version lacks the DevContainer section. The merge is idempotent — container restarts won't duplicate content.

> **Note:** Use `:ro` (read-only) for credentials you don't want the container to modify. `~/.claude` is mounted read-write because Claude Code writes memory, session state, and settings at runtime.

> **Important:** Ensure host files exist before first launch. If a mounted path doesn't exist on the host, Docker creates it as an empty directory, which may cause unexpected behavior.

## CI/CD

Two GitHub Actions workflows build and verify images:

- **`build.yml`** — Runs on push to `latest` or version tags. Builds the base image with GHA cache, then builds and pushes all 5 variants to GHCR in parallel (matrix strategy).
- **`check.yml`** — Runs on PRs to `latest`. Same structure but read-only cache (no `cache-to`) and no push to GHCR. Each variant runs tool verification and posts results as PR comments.

Both workflows use a local `registry:2` service container and `build-contexts` to remap `FROM` images at build time, requiring zero Dockerfile changes. The flutter variant has a three-tier chain (base → VNC → flutter) with a conditional VNC rebuild step.

Images are published to GHCR at `ghcr.io/<owner>/<image-name>`.

### Tags

| Trigger | Tag(s) |
|---------|--------|
| Push to `latest` | `latest` |
| Git tag `v1.2.3` | `1.2.3`, `1.2` |

> `GITHUB_TOKEN` is provided automatically by GitHub Actions for GHCR authentication.

## Local Build

Build locally:

```bash
# Build base first (NODE_VERSION is a base ARG)
docker build -t devcontainer-base:latest \
  --build-arg NODE_VERSION=24.12.0 \
  -f base/Dockerfile .

# Then build a variant
docker build \
  -f trixie-bun-nvm-uv-claude/Dockerfile \
  -t trixie-bun-nvm-uv-claude .

# Flutter requires VNC as an intermediate layer
docker build -t trixie-vnc-nvm-uv-claude:latest \
  -f trixie-vnc-nvm-uv-claude/Dockerfile .
docker build \
  -f trixie-vnc-flutter-rust-nvm-uv-claude/Dockerfile \
  -t trixie-vnc-flutter-rust-nvm-uv-claude .
```

Then run with your API keys as environment variables:

```bash
docker run -it \
  -e CONTEXT7_API_KEY=your-key \
  -e NTFY_URL=https://ntfy.sh/your-topic \
  -e NTFY_TOKEN=your-token \
  trixie-bun-nvm-uv-claude
```

## Agent Browser

The skill is already installed, and the following section is already included in all images `~/.claude/CLAUDE.md`.

```md
## Browser Automation

Use `agent-browser` for web automation. Run `agent-browser --help` for all commands.

Core workflow:
1. `agent-browser open <url>` - Navigate to page
2. `agent-browser snapshot -i` - Get interactive elements with refs (@e1, @e2)
3. `agent-browser click @e1` / `fill @e2 "text"` - Interact using refs
4. Re-snapshot after page changes
```
