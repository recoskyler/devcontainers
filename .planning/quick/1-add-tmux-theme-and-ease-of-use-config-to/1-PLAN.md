---
phase: quick
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - base/tmux.conf
  - base/Dockerfile
autonomous: true
must_haves:
  truths:
    - "tmux starts with mouse support enabled (scroll, click, drag, resize)"
    - "tmux has a visible, themed status bar"
    - "tmux supports intuitive copy-paste with mouse selection"
    - "tmux pane/window creation uses memorable key bindings"
  artifacts:
    - path: "base/tmux.conf"
      provides: "tmux configuration with theme, mouse, and keybindings"
      min_lines: 30
    - path: "base/Dockerfile"
      provides: "COPY of tmux.conf into image"
      contains: "tmux.conf"
  key_links:
    - from: "base/Dockerfile"
      to: "base/tmux.conf"
      via: "COPY into /home/dev/.tmux.conf"
      pattern: "COPY.*tmux\\.conf"
---

<objective>
Add a polished tmux configuration to the base DevContainer image that makes tmux behave as close to a GUI terminal as possible: mouse scrolling, click-to-select panes, drag-to-resize, mouse-based copy-paste, intuitive window/pane splitting keybindings, and a clean status bar theme.

Purpose: Make tmux immediately usable without memorizing arcane keybindings. Developers should feel like they are using a modern terminal multiplexer out of the box.
Output: base/tmux.conf file and updated Dockerfile to install it.
</objective>

<execution_context>
@/home/dev/.claude/get-shit-done/workflows/execute-plan.md
@/home/dev/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@base/Dockerfile
@CLAUDE.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create tmux.conf with theme and GUI-like settings</name>
  <files>base/tmux.conf</files>
  <action>
Create `base/tmux.conf` with the following configuration sections:

**Mouse support (critical for GUI-like feel):**
- `set -g mouse on` — enables scroll, click, drag, resize all at once
- Configure mouse scroll to work in both normal mode (scrollback) and copy-mode (page through history)

**Copy-paste integration:**
- Use vi-style copy mode (`set-window-option -g mode-keys vi`)
- Bind `v` to begin selection, `y` to yank in copy-mode-vi
- On mouse drag end, copy selection to tmux buffer and to system clipboard via `xclip -selection clipboard`
- `bind p paste-buffer` for quick paste

**Intuitive pane/window keybindings:**
- Change prefix to `C-a` (more ergonomic than `C-b`): `set -g prefix C-a` and `unbind C-b`
- Split horizontal: `bind |` (pipe) for vertical split, `bind -` for horizontal split (visual mnemonics)
- Navigate panes with Alt+arrow keys (no prefix needed): `bind -n M-Left select-pane -L`, etc.
- Resize panes with Shift+arrow keys (no prefix needed): `bind -n S-Left resize-pane -L 2`, etc.
- `bind r source-file ~/.tmux.conf` to reload config easily

**Terminal and display settings:**
- `set -g default-terminal "screen-256color"` and `set -ga terminal-overrides ",xterm-256color:Tc"` for true color
- `set -g base-index 1` and `setw -g pane-base-index 1` (1-indexed, more natural)
- `set -g renumber-windows on`
- `set -sg escape-time 0` (no delay after escape, important for vim users)
- `set -g history-limit 50000` (generous scrollback)
- `set -g display-time 4000` (status messages visible longer)

**Status bar theme (clean, informative, modern):**
- Status bar at bottom, refresh every 5 seconds
- Use a dark background with colored accents (e.g., blue/cyan highlights)
- Left side: session name in a colored block
- Right side: date and time
- Window list: current window highlighted with distinct background color, inactive windows dimmed
- Pane borders: subtle colors, active pane border highlighted
- Style example colors: status-bg colour235 (dark gray), status-fg colour248 (light gray), active window bg colour25 (blue), active pane border colour39 (cyan)

Do NOT install any tmux plugin manager (tpm) or external plugins — keep it self-contained with built-in tmux features only.
  </action>
  <verify>
    <automated>test -f /workspace/base/tmux.conf && grep -q "set -g mouse on" /workspace/base/tmux.conf && grep -q "prefix" /workspace/base/tmux.conf && grep -q "status-" /workspace/base/tmux.conf && echo "PASS" || echo "FAIL"</automated>
  </verify>
  <done>base/tmux.conf exists with mouse support, copy-paste bindings, intuitive keybindings, and a themed status bar. No external plugin dependencies.</done>
</task>

<task type="auto">
  <name>Task 2: Add tmux.conf COPY to base Dockerfile</name>
  <files>base/Dockerfile</files>
  <action>
Add a COPY instruction to the base Dockerfile to install the tmux.conf as `/home/dev/.tmux.conf`.

Insert the COPY line in the "User-space tools (as USER dev)" section (after line 202 where `mkdir -p $HOME/.claude` happens, near the other COPY for devcontainer-claude.md). The line should be:

```
COPY --chown=dev:dev base/tmux.conf $HOME/.tmux.conf
```

This must be placed AFTER the `USER dev` / `ENV HOME=/home/dev` lines (line 193-194) so that `$HOME` resolves correctly.

Follow existing Dockerfile conventions:
- Use POSIX-compatible syntax
- Use `--chown=dev:dev` consistent with other COPY instructions in that section
  </action>
  <verify>
    <automated>grep -n "tmux.conf" /workspace/base/Dockerfile && echo "PASS" || echo "FAIL"</automated>
  </verify>
  <done>Dockerfile contains COPY instruction for tmux.conf, placed in the user-space section with correct ownership.</done>
</task>

</tasks>

<verification>
- `base/tmux.conf` exists and contains mouse, keybinding, copy-paste, and theme configuration
- `base/Dockerfile` contains a COPY line for tmux.conf in the USER dev section
- No tmux plugin manager or external dependencies introduced
- Dockerfile still follows project conventions (POSIX redirects, --chown pattern)
</verification>

<success_criteria>
- tmux.conf is a self-contained config with mouse support, vi copy mode, intuitive splits (| and -), Alt+arrow pane navigation, and a themed status bar
- Dockerfile correctly copies the config to /home/dev/.tmux.conf
- No breaking changes to existing Dockerfile structure
</success_criteria>

<output>
After completion, create `.planning/quick/1-add-tmux-theme-and-ease-of-use-config-to/1-SUMMARY.md`
</output>
