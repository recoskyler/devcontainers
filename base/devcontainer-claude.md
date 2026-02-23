# DevContainer Environment

This is a DevContainer running Debian Trixie. You are the `dev` user with passwordless sudo.

## Available tools

### Languages & Runtimes
- Node.js via NVM — `nvm`, `node`, `npm`, `tsx`, `pnpm`
- Python 3 — `python3`, `pip`, `uv`

### CLI Tools
- `git`, `gh` (GitHub CLI), `delta` (git-delta)
- `aws` (AWS CLI v2), `terraform`, `kubectl`, `stripe`
- `claude` (Claude Code CLI)

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

### Other
- `tmux`, `ttyd`, `agent-browser`, `xclip`, `unzip`

## Working directory
Default: `/workspace`

## MCP Servers
- `serena` — semantic code analysis (symbols, references, overview)
- `context7` — library documentation lookup (if CONTEXT7_API_KEY is set)
- `memory` — persistent memory via Automem (if AUTOMEM_ENDPOINT is set)

## Plugins & Skills
- GSD (`/gsd:*`) — project management and execution workflow
- superpowers — brainstorming, TDD, debugging, code review skills
- feature-dev, frontend-design, code-review, commit-commands, pr-review-toolkit
- hookify, playground, claude-md-management

## Hooks
- Context7 suggestion hook — suggests context7 when WebSearch is used (if configured)
- Ntfy notification hook — sends push notifications on task completion (if configured)

## Notes
- Shell is bash. `/bin/sh` is symlinked to `/bin/bash`.
- Passwordless sudo is available via `sudo`.
