# DevContainer Environment

This is a DevContainer running Debian Trixie. You are the `dev` user with passwordless sudo.

## Available tools

### Languages & Runtimes
- Node.js via NVM — `nvm`, `node`, `npm`, `tsx`, `pnpm`
- Python 3 — `python3`, `pip`, `uv`
- Bun — `bun`, `bunx`

### CLI Tools
- `git`, `gh` (GitHub CLI), `delta` (git-delta)
- `docker`, `docker compose` (Docker CLI + Compose plugin)
- `aws` (AWS CLI v2), `terraform`, `kubectl`, `stripe`
- `claude` (Claude Code CLI)
- `brew` (Homebrew — used for select packages, on `$PATH` via `/home/linuxbrew/.linuxbrew/bin`)

### Search & Productivity
- `rg` (ripgrep), `fdfind` (fd-find), `fzf`, `batcat` (bat), `tldr` (tealdeer)
- `jq`, `tree`, `duf`, `http`/`https` (httpie)

### Database Clients
- `psql` (PostgreSQL), `mysql` (MariaDB), `redis-cli`

### Build Tools
- `gcc`, `g++`, `make`, `cmake`, `pkg-config`

### Editors
- `vim`, `nano`

### Networking
- `curl`, `wget`, `nc` (netcat), `ssh`

### PDF & Document Tools
- `pdftotext`, `pdftoppm`, `pdfinfo` (poppler-utils)

### Other
- `tmux`, `ttyd` (web terminal on port 7681), `agent-browser`, `xclip`, `unzip`

## Working directory
Default: `/workspace`

## MCP Servers

MCP servers are configured on first shell login via `init-claude-mcp.sh`. Optional servers are only added when their env vars are set.

- `serena` — semantic code analysis (symbols, references, overview)
- `context7` — library documentation lookup (if CONTEXT7_API_KEY is set)

## Plugins & Skills
- GSD (`/gsd:*`) — project management and execution workflow
- gstack — 28 specialized engineering skills as slash commands (garrytan/gstack)
- superpowers — brainstorming, TDD, debugging, code review skills
- everything-claude-code (ECC) — rules installed at `~/.claude/rules/`
- feature-dev, frontend-design, code-review, commit-commands, pr-review-toolkit
- hookify, playground, claude-md-management, claude-code-setup
- ralph-loop, security-guidance
- explanatory-output-style, learning-output-style
- typescript-lsp, pyright-lsp, php-lsp, laravel-boost
- agent-browser skill at `~/.claude/skills/agent-browser/SKILL.md`

## Hooks
- Context7 suggestion hook — suggests context7 when WebSearch is used (if configured)
- Ntfy notification hook — sends push notifications on task completion (if configured)

## Browser Automation

Use `agent-browser` for web automation. Run `agent-browser --help` for all commands.

Core workflow:
1. `agent-browser open <url>` - Navigate to page
2. `agent-browser snapshot -i` - Get interactive elements with refs (@e1, @e2)
3. `agent-browser click @e1` / `fill @e2 "text"` - Interact using refs
4. Re-snapshot after page changes

## Notes
- Shell is bash. `/bin/sh` is symlinked to `/bin/bash`.
- Passwordless sudo is available via `sudo`.
- When host `~/.claude` is bind-mounted, the entrypoint auto-merges image tooling (plugins, skills, rules, GSD) into the mounted directory. Host files (credentials, settings) are never overwritten.
