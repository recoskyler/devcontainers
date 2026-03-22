---
phase: quick
plan: 260322-wyy
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/setup-claude.sh
  - base/devcontainer-claude.md
  - README.md
  - base/Dockerfile
autonomous: false
requirements: [add-gstack, update-docs, validate-build]
must_haves:
  truths:
    - "gstack is cloned and set up during Docker image build"
    - "devcontainer-claude.md lists gstack in Plugins & Skills"
    - "README.md lists gstack in What's Included > All images (base)"
    - "Base Docker image builds successfully with gstack installed"
  artifacts:
    - path: "scripts/setup-claude.sh"
      provides: "gstack clone + setup commands"
      contains: "gstack"
    - path: "base/devcontainer-claude.md"
      provides: "gstack listed in Plugins & Skills"
      contains: "gstack"
    - path: "README.md"
      provides: "gstack listed in base image tools"
      contains: "gstack"
  key_links:
    - from: "base/Dockerfile"
      to: "scripts/setup-claude.sh"
      via: "COPY + bash execution during build"
      pattern: "setup-claude.sh"
---

<objective>
Add gstack (garrytan/gstack) to the base DevContainer image, update documentation (devcontainer-claude.md and README.md), and validate the build works.

Purpose: gstack provides 28 specialized Claude Code skills as slash commands, enhancing the DevContainer's AI capabilities out of the box.
Output: Updated setup script, documentation, and a validated Docker build.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@./CLAUDE.md
@scripts/setup-claude.sh
@base/devcontainer-claude.md
@README.md
@base/Dockerfile
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add gstack installation to setup-claude.sh and install Bun in base Dockerfile</name>
  <files>scripts/setup-claude.sh, base/Dockerfile</files>
  <action>
1. **base/Dockerfile** — Add Bun installation in the USER dev section, BEFORE `setup-claude.sh` is executed (around line 209, after UV install). Use the official install script:
   ```
   # Bun
   RUN curl -fsSL https://bun.sh/install | bash
   ```
   This installs bun to `~/.bun/bin/bun`. The `.bashrc` sourced by NVM already handles PATH, but the Dockerfile RUN shell won't have it. So for subsequent RUN commands that need bun, use the full path or add to PATH explicitly.

   Also add `ENV PATH="/home/dev/.bun/bin:${PATH}"` right after the bun install RUN so subsequent layers (including setup-claude.sh) can find `bun`.

2. **scripts/setup-claude.sh** — Add a `# --- gstack ---` section AFTER the `# --- GSD ---` block (line 58) and BEFORE the `# --- MCP Servers ---` block. Content:
   ```bash
   # --- gstack ---

   git clone https://github.com/garrytan/gstack.git "$HOME/.claude/skills/gstack"
   cd "$HOME/.claude/skills/gstack" && ./setup
   cd /workspace
   ```

   The setup script likely requires bun (now available from the Dockerfile step above).
  </action>
  <verify>
    <automated>grep -q "gstack" /workspace/scripts/setup-claude.sh && grep -q "bun" /workspace/base/Dockerfile && echo "PASS" || echo "FAIL"</automated>
  </verify>
  <done>setup-claude.sh contains gstack clone+setup section; base/Dockerfile installs Bun before running setup-claude.sh</done>
</task>

<task type="auto">
  <name>Task 2: Update devcontainer-claude.md and README.md with gstack documentation</name>
  <files>base/devcontainer-claude.md, README.md</files>
  <action>
1. **base/devcontainer-claude.md** — In the `## Plugins & Skills` section (line 51-60), add a new line after the GSD entry (line 52):
   ```
   - gstack — 28 specialized engineering skills as slash commands (garrytan/gstack)
   ```

   Also in `### Languages & Runtimes` section (line 7-9), add Bun:
   ```
   - Bun — `bun`, `bunx`
   ```

2. **README.md** — In the `### All images (base)` section (around line 157-174), add after the "Agent Browser" line (line 164):
   ```
   - **gstack** — 28 specialized Claude Code engineering skills ([garrytan/gstack](https://github.com/garrytan/gstack))
   ```

   Also add Bun to the base section since it is now in the base image:
   ```
   - **Bun** runtime (`bun`, `bunx`)
   ```

   Since Bun is now in base, the Bun variant section becomes a thin wrapper. Keep the variant as-is for now but add Bun to the base section. The variant may add bun-specific extras in the future.
  </action>
  <verify>
    <automated>grep -q "gstack" /workspace/base/devcontainer-claude.md && grep -q "gstack" /workspace/README.md && echo "PASS" || echo "FAIL"</automated>
  </verify>
  <done>Both devcontainer-claude.md and README.md document gstack and Bun in the base image tooling</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3: Build base image and verify gstack installation</name>
  <files>base/Dockerfile</files>
  <action>
Build the base Docker image and verify gstack + Bun are correctly installed. Run:
1. `docker build -t devcontainer-base:test -f base/Dockerfile .`
2. `docker run --rm devcontainer-base:test ls ~/.claude/skills/gstack/`
3. `docker run --rm devcontainer-base:test bun --version`
4. `docker run --rm devcontainer-base:test ls ~/.claude/skills/gstack/skills/`
Then present results for human review.
  </action>
  <verify>
    <automated>docker build -t devcontainer-base:test -f base/Dockerfile . 2>&1 | tail -5</automated>
  </verify>
  <done>Base Docker image builds successfully; gstack directory exists at ~/.claude/skills/gstack/ with skills populated; bun --version returns 1.x+</done>
</task>

</tasks>

<verification>
- `grep -q "gstack" scripts/setup-claude.sh` returns 0
- `grep -q "gstack" base/devcontainer-claude.md` returns 0
- `grep -q "gstack" README.md` returns 0
- `grep -q "bun" base/Dockerfile` returns 0
- Docker base image builds successfully
- gstack directory exists at ~/.claude/skills/gstack/ inside the built image
</verification>

<success_criteria>
- gstack is installed in the base Docker image during build
- Bun runtime is available in the base image
- devcontainer-claude.md documents gstack in Plugins & Skills and Bun in Languages & Runtimes
- README.md documents gstack and Bun in the base image section
- Base Docker image builds without errors
</success_criteria>

<output>
After completion, create `.planning/quick/260322-wyy-add-gstack-to-claude-update-readme-valid/260322-wyy-SUMMARY.md`
</output>
