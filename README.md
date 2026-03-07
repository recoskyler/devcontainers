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
                - AUTOMEM_ENDPOINT=your-endpoint
                - AUTOMEM_API_KEY=your-key
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
| `ghcr.io/recoskyler/trixie-bun-nvm-uv-claude:latest` | Bun |
| `ghcr.io/recoskyler/trixie-php-nvm-uv-claude:latest` | PHP 8.4, Composer |
| `ghcr.io/recoskyler/trixie-rust-nvm-uv-claude:latest` | Rust toolchain |
| `ghcr.io/recoskyler/trixie-vnc-nvm-uv-claude:latest` | x11vnc, Xvfb |

## What's Included

### All images (base)

- **Node.js** via NVM (default: 24.12.0)
- **UV** (Python package manager)
- **Claude Code** CLI + plugins (ECC, Superpowers, official plugin suite)
- **MCP servers**: Serena, Context7, Automem
- **GSD** (Get Shit Done for Claude Code)
- **Agent Browser** + Chrome
- **CLI tools**: git, curl, wget, vim, nano, jq, tmux, xclip, openssh-client, gnupg, cmake, less, unzip, gh, pnpm, tsx
- **Search & file tools**: ripgrep, fd-find, fzf, bat, tree
- **Networking & HTTP**: httpie, netcat
- **Cloud & infra**: AWS CLI v2, Terraform, kubectl, Stripe CLI
- **Utilities**: duf, git-delta, tldr
- **ttyd** (web terminal)
- **Database clients**: postgresql-client, default-mysql-client, redis-tools
- **ntfy** notification hooks (Notification + Stop events)

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

## Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `NODE_VERSION` | `24.12.0` | Node.js version installed via NVM |

## Runtime Environment Variables

Secret-dependent MCP servers and ntfy hooks are configured at **runtime** (first shell login) via environment variables. Pass these in your compose `environment` section or via `docker run -e`.

| Variable | Description |
|----------|-------------|
| `CONTEXT7_API_KEY` | [Context7](https://context7.com) MCP server API key (skipped if empty) |
| `AUTOMEM_ENDPOINT` | [Automem](https://github.com/verygoodplugins/mcp-automem) MCP server endpoint URL (skipped if empty) |
| `AUTOMEM_API_KEY` | [Automem](https://github.com/verygoodplugins/mcp-automem) MCP server API key (skipped if empty) |
| `NTFY_URL` | [ntfy](https://ntfy.sh) server/topic URL for notification hooks (skipped if empty) |
| `NTFY_TOKEN` | [ntfy](https://ntfy.sh) authentication token for notification hooks (skipped if empty) |

> Optional MCP servers and ntfy hooks are only configured when their corresponding environment variables are set.

## CI/CD

Two GitHub Actions workflows build and verify images:

- **`build.yml`** — Runs on push to `latest` or version tags. Builds the base image with GHA cache, then builds and pushes all 4 variants to GHCR in parallel (matrix strategy).
- **`check.yml`** — Runs on PRs to `latest`. Same structure but read-only cache (no `cache-to`) and no push to GHCR.

Both workflows use a local `registry:2` service container and `build-contexts` to remap `FROM devcontainer-base:latest` at build time, requiring zero Dockerfile changes.

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
# Build base first
docker build -t devcontainer-base:latest -f base/Dockerfile .

# Then build a variant
docker build \
  -f trixie-bun-nvm-uv-claude/Dockerfile \
  --build-arg NODE_VERSION=24.12.0 \
  -t trixie-bun-nvm-uv-claude .
```

Then run with your API keys as environment variables:

```bash
docker run -it \
  -e CONTEXT7_API_KEY=your-key \
  -e AUTOMEM_ENDPOINT=your-endpoint \
  -e AUTOMEM_API_KEY=your-key \
  -e NTFY_URL=https://ntfy.sh/your-topic \
  -e NTFY_TOKEN=your-token \
  trixie-bun-nvm-uv-claude
```

## Agent Browser

The skill is already installed. You may want to add the following to `AGENTS.md`/`CLAUDE.md`:

```md
## Browser Automation

Use `agent-browser` for web automation. Run `agent-browser --help` for all commands.

Core workflow:
1. `agent-browser open <url>` - Navigate to page
2. `agent-browser snapshot -i` - Get interactive elements with refs (@e1, @e2)
3. `agent-browser click @e1` / `fill @e2 "text"` - Interact using refs
4. Re-snapshot after page changes
```
