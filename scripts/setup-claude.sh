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
else
    echo "WARNING: Claude CLI not found at $CLAUDE — skipping plugin setup"
fi

# --- Agent Browser ---

mkdir -p /home/dev/.claude/skills/agent-browser

curl -o /home/dev/.claude/skills/agent-browser/SKILL.md https://raw.githubusercontent.com/vercel-labs/agent-browser/main/skills/agent-browser/SKILL.md

# --- MCP Servers ---

if [ -x "$CLAUDE" ]; then
    $CLAUDE mcp add --transport stdio -s user mnemosyne -- mnemosyne mcp
else
    echo "WARNING: Claude CLI not found — skipping MCP server setup"
fi

# --- RTK (global Claude Code hook + RTK.md) ---

rtk init -g --auto-patch </dev/null

# --- Mnemosyne: pre-fetch embedding model so first recall works offline ---

MNEMOSYNE_DATA_DIR=/tmp/mnemosyne-warmup mnemosyne store "warmup" >/dev/null
rm -rf /tmp/mnemosyne-warmup

# --- Enable Remote Control for all sessions ---

# CLAUDE_JSON="$HOME/.claude.json"
# if [ -f "$CLAUDE_JSON" ] && command -v jq >/dev/null 2>&1; then
#     jq '. + {"remoteControlAtStartup": true}' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" \
#         && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
# else
#     printf '{"remoteControlAtStartup":true}\n' > "$CLAUDE_JSON"
# fi
