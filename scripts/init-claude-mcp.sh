#!/bin/bash
# Runtime MCP/hook initializer - runs from .bashrc on first login per container lifecycle.
# Uses /tmp/.claude-mcp-init as marker (cleared on container restart).

[ -f /tmp/.claude-mcp-init ] && return 0 2>/dev/null || [ -f /tmp/.claude-mcp-init ] && exit 0

CLAUDE="$HOME/.local/bin/claude"
CLAUDE_JSON="$HOME/.claude.json"

[ -f "$CLAUDE_JSON" ] || echo '{}' > "$CLAUDE_JSON"

# --- Mnemosyne MCP ---
if ! grep -q '"mnemosyne"' "$CLAUDE_JSON" 2>/dev/null; then
    $CLAUDE mcp add --transport stdio -s user mnemosyne -- mnemosyne mcp >/dev/null
fi

# --- RTK hook (re-applied when a host ~/.claude mount lacks it) ---
if command -v rtk >/dev/null 2>&1 && ! rtk init --show 2>/dev/null | grep -q '\[ok\] Hook'; then
    rtk init -g --auto-patch </dev/null >/dev/null
fi

# --- Ntfy Hooks ---
if [ -n "$NTFY_URL" ] && [ -n "$NTFY_TOKEN" ]; then
    if ! grep -q 'ntfy-hook' "$CLAUDE_JSON" 2>/dev/null; then
        HOOK_CMD="$HOME/.local/bin/ntfy-hook.sh"
        chmod +x "$HOOK_CMD" 2>/dev/null

        HOOKS_JSON=$(jq -n \
            --arg ncmd "$HOOK_CMD notification" \
            --arg scmd "$HOOK_CMD stop" \
            '{
                Notification: [{matcher: "*", hooks: [{type: "command", command: $ncmd}]}],
                Stop: [{matcher: "*", hooks: [{type: "command", command: $scmd}]}]
            }')

        jq --argjson newhooks "$HOOKS_JSON" '. + {hooks: ((.hooks // {}) * $newhooks)}' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp"
        mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
    fi
fi

touch /tmp/.claude-mcp-init
