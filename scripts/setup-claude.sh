#!/bin/bash
set -e

CLAUDE="$HOME/.local/bin/claude"

# --- Claude Plugins ---

if [ -x "$CLAUDE" ]; then
    # ECC — low-context / no-hooks install (rules + agents + commands + core skills, no hooks-runtime)
    npx -y ecc-install --profile minimal --target claude

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
else
    echo "WARNING: Claude CLI not found at $CLAUDE — skipping plugin setup"
fi

# --- Agent Browser ---

mkdir -p /home/dev/.claude/skills/agent-browser

curl -o /home/dev/.claude/skills/agent-browser/SKILL.md https://raw.githubusercontent.com/vercel-labs/agent-browser/main/skills/agent-browser/SKILL.md

# --- Hookify Fix ---

HOOKIFY_DIR="$HOME/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0"
[ -d "$HOOKIFY_DIR" ] && ln -sf . "$HOOKIFY_DIR/hookify"

# --- ECC Rules ---



# --- GSD ---

npx -y get-shit-done-cc --claude --global

# --- gstack ---
# Manual setup (skips Chromium launch check — agent-browser already provides Playwright)

git clone https://github.com/garrytan/gstack.git "$HOME/.claude/skills/gstack"
cd "$HOME/.claude/skills/gstack"
bun install
bun run build
mkdir -p "$HOME/.gstack/projects"

# Register skills — symlink each skill subdir into the skills parent
for skill_dir in "$HOME/.claude/skills/gstack"/*/; do
    if [ -f "$skill_dir/SKILL.md" ]; then
        skill_name="$(basename "$skill_dir")"
        [ "$skill_name" = "node_modules" ] && continue
        ln -snf "gstack/$skill_name" "$HOME/.claude/skills/$skill_name"
    fi
done

cd /workspace

# --- MCP Servers ---

if [ -x "$CLAUDE" ]; then
    $CLAUDE mcp add --transport stdio -s user serena -- \
        uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context=claude-code --project-from-cwd
else
    echo "WARNING: Claude CLI not found — skipping MCP server setup"
fi

# --- Enable Remote Control for all sessions ---

# CLAUDE_JSON="$HOME/.claude.json"
# if [ -f "$CLAUDE_JSON" ] && command -v jq >/dev/null 2>&1; then
#     jq '. + {"remoteControlAtStartup": true}' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" \
#         && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
# else
#     printf '{"remoteControlAtStartup":true}\n' > "$CLAUDE_JSON"
# fi
