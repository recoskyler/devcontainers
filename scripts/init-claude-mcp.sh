#!/bin/bash
# Runtime MCP/hook initializer - runs from .bashrc on first login per container lifecycle.
# Uses /tmp/.claude-mcp-init as marker (cleared on container restart).

[ -f /tmp/.claude-mcp-init ] && return 0 2>/dev/null || [ -f /tmp/.claude-mcp-init ] && exit 0

CLAUDE="$HOME/.local/bin/claude"
CLAUDE_JSON="$HOME/.claude.json"

[ -f "$CLAUDE_JSON" ] || echo '{}' > "$CLAUDE_JSON"

# --- Automem MCP ---
if [ -n "$AUTOMEM_ENDPOINT" ] && [ -n "$AUTOMEM_API_KEY" ]; then
    if ! grep -q '"memory"' "$CLAUDE_JSON" 2>/dev/null; then
        $CLAUDE mcp add --transport stdio -s user \
            --env="AUTOMEM_ENDPOINT=$AUTOMEM_ENDPOINT" \
            --env="AUTOMEM_API_KEY=$AUTOMEM_API_KEY" \
            memory -- npx -y @verygoodplugins/mcp-automem
    fi
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
