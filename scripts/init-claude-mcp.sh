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

# --- Automem MCP ---
if [ -n "$AUTOMEM_ENDPOINT" ] && [ -n "$AUTOMEM_API_KEY" ]; then
    if ! grep -q '"memory"' "$CLAUDE_JSON" 2>/dev/null; then
        $CLAUDE mcp add --transport stdio -s user \
            --env="AUTOMEM_ENDPOINT=$AUTOMEM_ENDPOINT" \
            --env="AUTOMEM_API_KEY=$AUTOMEM_API_KEY" \
            memory -- npx -y @verygoodplugins/mcp-automem
    fi

    # Disable Serena's built-in memory tools in favor of Automem
    SERENA_CONFIG="$HOME/.serena/serena_config.yml"
    if [ ! -f "$SERENA_CONFIG" ] || ! grep -q 'excluded_tools' "$SERENA_CONFIG" 2>/dev/null; then
        mkdir -p "$HOME/.serena"
        cat > "$SERENA_CONFIG" <<'YAML'
excluded_tools:
  - "write_memory"
  - "read_memory"
  - "edit_memory"
  - "delete_memory"
  - "list_memories"
  - "check_onboarding_performed"
  - "onboarding"
YAML
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
