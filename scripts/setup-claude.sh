#!/bin/bash
set -e

CLAUDE="$HOME/.local/bin/claude"

# --- Claude Plugins ---

if [ -x "$CLAUDE" ]; then
    $CLAUDE plugin marketplace add pcvelz/superpowers
    $CLAUDE plugin install superpowers-extended-cc@superpowers-extended-cc-marketplace

    $CLAUDE plugin marketplace add anthropics/claude-plugins-official
else
    echo "WARNING: Claude CLI not found at $CLAUDE — skipping plugin setup"
fi

# --- Agent Browser ---

npx -y skills add -y --global --all vercel-labs/agent-browser

# --- GSD ---

npx -y @opengsd/gsd-core@latest --claude --global

# --- Headroom ---

uv tool install "headroom-ai[all]"
