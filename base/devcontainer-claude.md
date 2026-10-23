# DevContainer Environment

This is a DevContainer running Debian Trixie. You are the `dev` user with passwordless sudo.

## Available tools

### Languages & Runtimes
- Node.js via NVM — `nvm`, `node`, `npm`, `tsx`, `pnpm`
- Python 3 — `python3`, `pip`, `uv`
- Bun — `bun`, `bunx`
- Go — `go`, `gofmt` (`GOPATH=~/go`, `~/go/bin` on `$PATH`)

### CLI Tools
- `git`, `gh` (GitHub CLI), `delta` (git-delta)
- `docker`, `docker compose` (Docker CLI + Compose plugin — omitted when built with `INSTALL_DOCKER=false`)
- `aws` (AWS CLI v2), `terraform`, `kubectl`, `stripe`
- `claude` (Claude Code CLI)
- `rtk` — token-saving CLI proxy; a PreToolUse hook rewrites Bash commands to `rtk <cmd>` automatically. `rtk gain` shows savings, `rtk proxy <cmd>` bypasses filtering
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
- `mnemosyne` — local persistent memory (`mnemosyne_remember`, `mnemosyne_recall`, `mnemosyne_forget`); SQLite data in `~/.claude/mnemosyne`

## Plugins & Skills
- mattpocock-skills — grilling, spec/ticket flows, TDD, code review, domain modelling
- playground, typescript-lsp, pyright-lsp, php-lsp
- agent-browser skill

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
