# Dev Containers

Docker-based dev containers with Claude Code, MCP servers, and common tooling pre-installed. Each image targets a different stack/project type.

## Usage

1. Log into ghcr.io:

    ```bash
    docker login ghcr.io
    ```

2. Use the image:
   - In Dockerfile

        ```Dockerfile
        FROM ghcr.io/recoskyler/trixie-bun-nvm-uv-claude:latest
        ```

        ```Dockerfile
        FROM ghcr.io/recoskyler/noble-uv-vnc-claude:latest
        ```

        ```Dockerfile
        FROM ghcr.io/recoskyler/trixie-php-nvm-uv-claude:latest
        ```

    - In Docker Compose

        ```yaml
        services:
            app:
                image: ghcr.io/recoskyler/trixie-bun-nvm-uv-claude:latest

                ports:
                - "0.0.0.0:7681:7681" # TTYD

                networks:
                - default

                environment:
                - ENABLE_TOOL_SEARCH=true
                - ENABLE_EXPERIMENTAL_MCP_CLI=false
                - CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="1"

                logging:
                    options:
                        max-size: 10m
                        max-file: 3

                volumes:
                - ..:/workspace:cached

                # Overrides default command so things don't shut down after the process ends.
                command: sleep infinity

                # Use "forwardPorts" in **devcontainer.json** to forward an app port locally.
                # (Adding the "ports" property to this file will not forward from a Codespace.)

        networks:
            default:
                driver: bridge
        ```

## Images

Each image has its own Dockerfile in a folder named after the image.

| Image | Base | `VARIANT` |
|-------|------|-----------|
| `ghcr.io/recoskyler/noble-uv-vnc-claude:latest` | `ubuntu:noble` | `noble` |
| `ghcr.io/recoskyler/trixie-bun-nvm-uv-claude:latest` | `oven/bun:debian` | `debian` |
| `ghcr.io/recoskyler/trixie-php-nvm-uv-claude:latest` | `mcr.microsoft.com/devcontainers/php:8.3-trixie` | `8.3-trixie` |

## What's Included

### All images

- **Node.js** via NVM (default: 24.12.0)
- **UV** (Python package manager)
- **Claude Code** CLI + plugins (ECC, Superpowers, official plugin suite)
- **MCP servers**: Serena, Playwright, Context7, Automem, Figma
- **GSD** (Get Shit Done for Claude Code)
- **Playwright** + Chrome
- **CLI tools**: git, curl, wget, vim, nano, jq, tmux, xclip, openssh-client, gnupg, cmake, less, unzip, gh, pnpm, tsx
- **ttyd** (web terminal)
- **Database clients**: postgresql-client, default-mysql-client, redis-tools
- **ntfy** notification hooks (Notification + Stop events)

### Bun images (`trixie-bun-nvm-uv-claude`)

- **Bun** runtime
- **Stripe CLI**

### PHP images (`trixie-php-nvm-uv-claude`)

- **PHP** (from MS devcontainers base)
- **Composer**
- PHP Redis extension, pdo_mysql, pcntl

### Noble image (`noble-uv-vnc-claude`)

- **Ubuntu Noble** base
- **Python venv** setup via UV (default: 3.13)
- x11vnc, xvfb

## Environment Variables

### Build-time variables (GitHub repository variables)

Set these in **Settings > Secrets and variables > Actions > Variables**. They are passed as `--build-arg` during CI builds:

| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_VERSION` | `24.12.0` | Node.js version installed via NVM |
| `PYTHON_VERSION` | `3` / `3.13` (noble) | Python version |
| `NTFY_URL` | All images | [ntfy](https://ntfy.sh) server/topic URL for notification hooks |
| `AUTOMEM_ENDPOINT` | All images | [Automem](https://github.com/verygoodplugins/mcp-automem) MCP server endpoint URL |

> `VARIANT` is defined per image in the workflow matrix (see Images table above).

### Build-time secrets (GitHub repository secrets)

Set these in **Settings > Secrets and variables > Actions > Secrets**. They are expanded during `docker build` by MCP server configuration commands and baked into Claude Code's MCP config inside the image:

| Variable | Required by | Description |
|----------|-------------|-------------|
| `CONTEXT7_API_KEY` | All images | [Context7](https://context7.com) MCP server API key |
| `AUTOMEM_API_KEY` | All images | [Automem](https://github.com/verygoodplugins/mcp-automem) MCP server API key |
| `NTFY_TOKEN` | All images | [ntfy](https://ntfy.sh) authentication token for notification hooks |

## CI/CD

The GitHub Actions workflow (`.github/workflows/build.yml`) builds and pushes all images on every push to `latest` branch or when a version tag is created.

Images are published to GHCR at `ghcr.io/<owner>/<image-name>`.

### Tags

| Trigger | Tag(s) |
|---------|--------|
| Push to `latest` | `latest` |
| Git tag `v1.2.3` | `1.2.3`, `1.2` |

> `GITHUB_TOKEN` is provided automatically by GitHub Actions for GHCR authentication.

## Local Build

```bash
# Build a specific image
docker build \
  -f trixie-bun-nvm-uv-claude/Dockerfile \
  --build-arg VARIANT=debian \
  --build-arg NODE_VERSION=24.12.0 \
  --build-arg CONTEXT7_API_KEY=your-key \
  --build-arg AUTOMEM_ENDPOINT=your-endpoint \
  --build-arg AUTOMEM_API_KEY=your-key \
  -t trixie-bun-nvm-uv-claude .

# Run with runtime env vars
docker run -it \
  -e NTFY_TOKEN=your-token \
  -e NTFY_URL=https://ntfy.sh/your-topic \
  trixie-bun-nvm-uv-claude
```
