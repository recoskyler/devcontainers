#!/bin/bash
set -e

CLAUDE="$HOME/.local/bin/claude"

# --- Claude Plugins ---

$CLAUDE plugin marketplace add affaan-m/everything-claude-code
$CLAUDE plugin install everything-claude-code@everything-claude-code

$CLAUDE plugin marketplace add obra/superpowers
$CLAUDE plugin install superpowers@superpowers-dev

$CLAUDE plugin marketplace add anthropics/claude-code
$CLAUDE plugin install code-review@claude-code-plugins
$CLAUDE plugin install commit-commands@claude-code-plugins
$CLAUDE plugin install explanatory-output-style@claude-code-plugins
$CLAUDE plugin install hookify@claude-code-plugins
$CLAUDE plugin install feature-dev@claude-code-plugins
$CLAUDE plugin install frontend-design@claude-code-plugins
$CLAUDE plugin install learning-output-style@claude-code-plugins
$CLAUDE plugin install ralph-wiggum@claude-code-plugins
$CLAUDE plugin install pr-review-toolkit@claude-code-plugins
$CLAUDE plugin install security-guidance@claude-code-plugins

# --- Hookify Fix ---

HOOKIFY_DIR="$HOME/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0"
[ -d "$HOOKIFY_DIR" ] && ln -sf . "$HOOKIFY_DIR/hookify"

# --- ECC Rules ---

git clone https://github.com/affaan-m/everything-claude-code.git /tmp/everything-claude-code
mkdir -p "$HOME/.claude/rules"
cp -r /tmp/everything-claude-code/rules/common/* "$HOME/.claude/rules/"
cp -r /tmp/everything-claude-code/rules/typescript/* "$HOME/.claude/rules/"
rm -rf /tmp/everything-claude-code

# --- GSD ---

cd /workspace
npx -y get-shit-done-cc --claude --local

# --- MCP Servers ---

$CLAUDE mcp add --transport stdio -s user serena -- \
    uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context=claude-code --project-from-cwd

$CLAUDE mcp add --transport stdio -s user \
    playwright -- npx -y @playwright/mcp@latest ${PLAYWRIGHT_MCP_ARGS:-}

$CLAUDE mcp add --transport stdio -s user context7 -- \
    npx -y @upstash/context7-mcp --api-key "$CONTEXT7_API_KEY"

$CLAUDE mcp add --transport stdio -s user \
    --env="AUTOMEM_ENDPOINT=$AUTOMEM_ENDPOINT" \
    --env="AUTOMEM_API_KEY=$AUTOMEM_API_KEY" \
    automem -- npx -y @verygoodplugins/mcp-automem

$CLAUDE mcp add --transport http figma https://mcp.figma.com/mcp

# --- Ntfy Hook ---

if [ -n "$NTFY_URL" ] && [ -n "$NTFY_TOKEN" ]; then
    mkdir -p ~/.claude ~/.local/bin
    [ -f ~/.claude.json ] || echo '{}' > ~/.claude.json

    cat > "$HOME/.local/bin/ntfy-hook.sh" << 'HOOKSCRIPT'
#!/bin/bash
EVENT_TYPE="${1:-notification}"
INPUT=$(cat)
NTFY_URL="__NTFY_URL__"
NTFY_TOKEN="__NTFY_TOKEN__"

case "$EVENT_TYPE" in
    notification)
        TITLE=$(echo "$INPUT" | jq -r '.title // "Notification"')
        TYPE=$(echo "$INPUT" | jq -r '.notification_type // "notification"')
        MESSAGE=$(echo "$INPUT" | jq -r '.message // "No details"')
        TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
        TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // "No details"')
        BODY=$(printf "**Type:** %s\n\n%s\n\n**Tool:** %s\n\n%s" "$TYPE" "$MESSAGE" "$TOOL" "$TOOL_INPUT")
        curl -s -H "Markdown: yes" -H "Priority: max" \
            -H "Title: Çekirge: ${TITLE}" \
            -H "Tags: cricket,warning" \
            -u ":${NTFY_TOKEN}" \
            -d "$BODY" "$NTFY_URL"
        ;;
    stop)
        SESSION=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
        CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"')
        BODY=$(printf "**Session:** %s\n**Directory:** %s" "$SESSION" "$CWD")
        curl -s -H "Markdown: yes" \
            -H "Title: Çekirge: Stopped" \
            -H "Tags: cricket,white_check_mark" \
            -u ":${NTFY_TOKEN}" \
            -d "$BODY" "$NTFY_URL"
        ;;
esac
HOOKSCRIPT

    sed -i "s|__NTFY_URL__|${NTFY_URL}|g" "$HOME/.local/bin/ntfy-hook.sh"
    sed -i "s|__NTFY_TOKEN__|${NTFY_TOKEN}|g" "$HOME/.local/bin/ntfy-hook.sh"
    chmod +x "$HOME/.local/bin/ntfy-hook.sh"

    HOOK_CMD="$HOME/.local/bin/ntfy-hook.sh"
    HOOKS_JSON=$(jq -n \
        --arg ncmd "$HOOK_CMD notification" \
        --arg scmd "$HOOK_CMD stop" \
        '{
            Notification: [{matcher: "*", hooks: [{type: "command", command: $ncmd}]}],
            Stop: [{matcher: "*", hooks: [{type: "command", command: $scmd}]}]
        }')

    jq --argjson newhooks "$HOOKS_JSON" '. + {hooks: ((.hooks // {}) * $newhooks)}' ~/.claude.json > ~/.claude.json.tmp
    mv ~/.claude.json.tmp ~/.claude.json
fi
