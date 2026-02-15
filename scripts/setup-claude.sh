#!/bin/bash
set -e

CLAUDE="$HOME/.local/bin/claude"

# --- Claude Plugins ---

$CLAUDE plugin marketplace add affaan-m/everything-claude-code
$CLAUDE plugin install everything-claude-code@everything-claude-code

$CLAUDE plugin marketplace add obra/superpowers
$CLAUDE plugin install superpowers@superpowers-dev

$CLAUDE plugin marketplace add anthropics/claude-plugins-official
$CLAUDE plugin install code-review@claude-plugins-official
$CLAUDE plugin install commit-commands@claude-plugins-official
$CLAUDE plugin install explanatory-output-style@claude-plugins-official
$CLAUDE plugin install hookify@claude-plugins-official
$CLAUDE plugin install feature-dev@claude-plugins-official
$CLAUDE plugin install frontend-design@claude-plugins-official
$CLAUDE plugin install learning-output-style@claude-plugins-official
$CLAUDE plugin install ralph-loop@claude-plugins-official
$CLAUDE plugin install pr-review-toolkit@claude-plugins-official
$CLAUDE plugin install security-guidance@claude-plugins-official
$CLAUDE plugin install claude-md-management@claude-plugins-official
$CLAUDE plugin install claude-code-setup@claude-plugins-official
$CLAUDE plugin install playground@claude-plugins-official
$CLAUDE plugin install typescript-lsp@claude-plugins-official
$CLAUDE plugin install pyright-lsp@claude-plugins-official
$CLAUDE plugin install php-lsp@claude-plugins-official
$CLAUDE plugin install laravel-boost@claude-plugins-official

# --- Agent Browser ---

mkdir -p /workspace/.claude/skills/agent-browser

curl -o /workspace/.claude/skills/agent-browser/SKILL.md https://raw.githubusercontent.com/vercel-labs/agent-browser/main/skills/agent-browser/SKILL.md

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

$CLAUDE mcp add --transport http figma https://mcp.figma.com/mcp
