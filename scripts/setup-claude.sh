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

echo '{ "type": "commonjs" }' > /workspace/.claude/get-shit-done/bin/package.json

# --- MCP Servers ---

$CLAUDE mcp add --transport stdio -s user serena -- \
    uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context=claude-code --project-from-cwd

$CLAUDE mcp add --transport stdio -s user \
    playwright -- npx -y @playwright/mcp@latest ${PLAYWRIGHT_MCP_ARGS:-}

if [ -n "$CONTEXT7_API_KEY" ]; then
    $CLAUDE mcp add --transport stdio -s user context7 -- \
        npx -y @upstash/context7-mcp --api-key "$CONTEXT7_API_KEY"
fi

if [ -n "$AUTOMEM_ENDPOINT" ] && [ -n "$AUTOMEM_API_KEY" ]; then
    $CLAUDE mcp add --transport stdio -s user \
        --env="AUTOMEM_ENDPOINT=$AUTOMEM_ENDPOINT" \
        --env="AUTOMEM_API_KEY=$AUTOMEM_API_KEY" \
        memory -- npx -y @verygoodplugins/mcp-automem
fi

$CLAUDE mcp add --transport http figma https://mcp.figma.com/mcp

# --- Ntfy Hook ---

if [ -n "$NTFY_URL" ] && [ -n "$NTFY_TOKEN" ]; then
    mkdir -p ~/.claude ~/.local/bin
    [ -f ~/.claude.json ] || echo '{}' > ~/.claude.json

    cp /tmp/ntfy-hook.sh "$HOME/.local/bin/ntfy-hook.sh"
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
