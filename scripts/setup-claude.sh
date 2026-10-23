#!/bin/bash
set -e

CLAUDE="$HOME/.local/bin/claude"

# --- Claude Plugins ---

if [ -x "$CLAUDE" ]; then
    $CLAUDE plugin marketplace add anthropics/claude-plugins-official
    $CLAUDE plugin install playground@claude-plugins-official
    $CLAUDE plugin install typescript-lsp@claude-plugins-official
    $CLAUDE plugin install pyright-lsp@claude-plugins-official
    $CLAUDE plugin install php-lsp@claude-plugins-official
    $CLAUDE plugin install mattpocock-skills@claude-plugins-official

    $CLAUDE mcp add --transport stdio -s user mnemosyne -- mnemosyne mcp
else
    echo "WARNING: Claude CLI not found at $CLAUDE — skipping plugin setup"
fi

# --- Agent Browser ---

npx -y skills add -y --global --all vercel-labs/agent-browser

# --- RTK (global Claude Code hook + RTK.md) ---

rtk init -g --auto-patch </dev/null

# --- Mnemosyne: pre-fetch embedding model so first recall works offline ---

MNEMOSYNE_DATA_DIR=/tmp/mnemosyne-warmup mnemosyne store "warmup" >/dev/null
rm -rf /tmp/mnemosyne-warmup
