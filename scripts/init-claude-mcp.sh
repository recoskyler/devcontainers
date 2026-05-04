#!/bin/bash
# Runtime MCP/hook initializer - runs from .bashrc on first login per container lifecycle.
# Uses /tmp/.claude-mcp-init as marker (cleared on container restart).

[ -f /tmp/.claude-mcp-init ] && return 0 2>/dev/null || [ -f /tmp/.claude-mcp-init ] && exit 0

CLAUDE="$HOME/.local/bin/claude"
CLAUDE_JSON="$HOME/.claude.json"

[ -f "$CLAUDE_JSON" ] || echo '{}' > "$CLAUDE_JSON"

# --- Context7 MCP ---
if [ -n "$CONTEXT7_API_KEY" ]; then
    if ! grep -q '"context7"' "$CLAUDE_JSON" 2>/dev/null; then
        $CLAUDE mcp add --transport stdio -s user context7 -- \
            npx -y @upstash/context7-mcp --api-key "$CONTEXT7_API_KEY"
    fi

    # Register WebSearch suggestion hook
    if ! grep -q 'suggest-context7-hook' "$CLAUDE_JSON" 2>/dev/null; then
        HOOK_CMD="$HOME/.local/bin/suggest-context7-hook.sh"
        chmod +x "$HOOK_CMD" 2>/dev/null

        HOOKS_JSON=$(jq -n \
            --arg cmd "$HOOK_CMD" \
            '{
                PreToolUse: [{matcher: "WebSearch", hooks: [{type: "command", command: $cmd}]}]
            }')

        jq --argjson newhooks "$HOOKS_JSON" '. + {hooks: ((.hooks // {}) * $newhooks)}' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp"
        mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
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

# --- Serena user-scope config ---
# Disable Serena memory mutation tools via user config
SERENA_USER="$HOME/.serena/user.yml"
mkdir -p "$HOME/.serena"
if [ ! -f "$SERENA_USER" ] || grep -q '^excluded_tools: \[\]' "$SERENA_USER"; then
    TOOLS=(write_memory delete_memory read_memory)

    YAML="excluded_tools:"
    for t in "${TOOLS[@]}"; do
        YAML="${YAML}
- ${t}"
    done

    if [ -f "$SERENA_USER" ]; then
        awk -v new="$YAML" '/^excluded_tools: \[\]/ { print new; next } 1' "$SERENA_USER" > "$SERENA_USER.tmp"
        mv "$SERENA_USER.tmp" "$SERENA_USER"
    else
        printf '%s\n' "$YAML" > "$SERENA_USER"
    fi
fi

touch /tmp/.claude-mcp-init
