---
phase: quick
plan: 260329-lnd
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/merge-claude-home.sh
  - scripts/docker-sock-fix.sh
  - base/Dockerfile
  - base/devcontainer-claude.md
autonomous: true
requirements: [QUICK-260329-LND]

must_haves:
  truths:
    - "Full ~/.claude dir mount results in image tooling (plugins, skills, rules, GSD) present alongside host auth files"
    - "Individual file mounts (credentials.json, settings.json only) work without merge logic triggering"
    - "Host CLAUDE.md content is preserved and image CLAUDE.md content is appended"
    - "Merge is idempotent — running the entrypoint multiple times (container restart) does not duplicate content"
    - "Existing docker-sock-fix.sh behavior is unchanged"
  artifacts:
    - path: "scripts/merge-claude-home.sh"
      provides: "Merge logic for ~/.claude host mount"
    - path: "scripts/docker-sock-fix.sh"
      provides: "Entrypoint that calls merge script before exec"
    - path: "base/Dockerfile"
      provides: "Build-time snapshot of ~/.claude to /opt/devcontainer-claude"
  key_links:
    - from: "base/Dockerfile"
      to: "/opt/devcontainer-claude/"
      via: "cp -a at build time after setup-claude.sh"
      pattern: "cp -a.*\\.claude.*devcontainer-claude"
    - from: "scripts/docker-sock-fix.sh"
      to: "scripts/merge-claude-home.sh"
      via: "source or call before exec"
      pattern: "merge-claude-home"
    - from: "scripts/merge-claude-home.sh"
      to: "/opt/devcontainer-claude/"
      via: "rsync/cp from backup into live ~/.claude"
      pattern: "devcontainer-claude"
---

<objective>
Create an entrypoint merge mechanism so that when a developer bind-mounts their host ~/.claude directory (or individual files from it) into the devcontainer, image-built tooling (plugins, skills, rules, GSD, CLAUDE.md) is merged in without overwriting host auth/settings files.

Purpose: Developers need host credentials (credentials.json, settings.json) in the container, but mounting ~/.claude shadows all build-time tooling. This merge script restores image tooling additively at container start.

Output: New merge script, updated entrypoint, updated Dockerfile with build-time snapshot.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@scripts/docker-sock-fix.sh
@scripts/setup-claude.sh
@base/Dockerfile
@base/devcontainer-claude.md
@scripts/init-claude-mcp.sh
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create merge-claude-home.sh and snapshot in Dockerfile</name>
  <files>scripts/merge-claude-home.sh, base/Dockerfile</files>
  <action>
**Create `scripts/merge-claude-home.sh`** — a POSIX-compatible bash script that:

1. **Detect mount**: Check if `~/.claude` was volume-mounted by comparing device IDs:
   ```
   BACKUP="/opt/devcontainer-claude"
   LIVE="$HOME/.claude"
   # If backup doesn't exist, nothing to merge (image not built with snapshot)
   [ -d "$BACKUP" ] || exit 0
   # Use a marker file approach: at build time we create $BACKUP/.image-marker
   # If $LIVE/.image-marker exists and matches, no mount happened — skip
   if [ -f "$LIVE/.image-marker" ] && [ "$(cat "$LIVE/.image-marker")" = "$(cat "$BACKUP/.image-marker")" ]; then
       exit 0
   fi
   ```

2. **Idempotency marker**: Create `$LIVE/.merge-done` with a hash of the backup marker. If this file exists and matches, skip merge (handles container restart without re-merging).

3. **Merge directories** — for each of these subdirectories, use `cp -rn` (no-clobber) from backup to live:
   - `plugins/`
   - `skills/`
   - `rules/`
   - `get-shit-done/`
   - `agents/` (if exists in backup)

   The `-n` flag ensures host files are never overwritten. Only missing files/dirs are filled in.

4. **Merge CLAUDE.md** — special handling:
   - If `$LIVE/CLAUDE.md` does not exist, copy from backup
   - If `$LIVE/CLAUDE.md` exists but does NOT contain the marker `# DevContainer Environment` (the heading from devcontainer-claude.md), append the backup CLAUDE.md content with a separator:
     ```
     printf '\n\n# --- DevContainer Image (auto-merged) ---\n\n' >> "$LIVE/CLAUDE.md"
     cat "$BACKUP/CLAUDE.md" >> "$LIVE/CLAUDE.md"
     ```
   - If it already contains `# DevContainer Environment`, skip (already merged or image-native)

5. **Preserve host files**: Never touch `credentials.json`, `settings.json`, `projects/`, `.claude.json`, or any file that already exists in the live directory (cp -n handles this).

6. Write the idempotency marker at the end.

7. The script must be `set -e`, use POSIX-compatible redirects (`>/dev/null 2>&1`), and exit 0 on all paths (entrypoint must not fail).

**Update `base/Dockerfile`** — add two steps after the `setup-claude.sh` RUN (line ~234):

1. Create the image marker:
   ```dockerfile
   RUN echo "devcontainer-$(date +%s)" > $HOME/.claude/.image-marker
   ```

2. Snapshot the entire `~/.claude/` to `/opt/devcontainer-claude/`:
   ```dockerfile
   USER root
   RUN cp -a /home/dev/.claude /opt/devcontainer-claude \
       && chown -R dev:dev /opt/devcontainer-claude
   USER dev
   ```
   Place this BEFORE the `USER root` final section (before line ~240). Since the Dockerfile already switches to `USER root` at line ~240, fold the snapshot into that section to avoid extra USER switches. Specifically:
   - Insert `RUN cp -a /home/dev/.claude /opt/devcontainer-claude` right after switching to USER root in the final section (after line 243 area)

3. Copy the merge script into the image:
   ```dockerfile
   COPY --chown=dev:dev scripts/merge-claude-home.sh $HOME/.local/bin/merge-claude-home.sh
   ```
   Place this near the other script COPY lines (around line 228-231). Ensure chmod +x includes it.

Important: The image marker RUN must come AFTER `setup-claude.sh` runs but BEFORE the snapshot copy. The snapshot must capture the full post-setup state.
  </action>
  <verify>
    <automated>bash -n /workspace/scripts/merge-claude-home.sh && grep -q 'devcontainer-claude' /workspace/scripts/merge-claude-home.sh && grep -q 'merge-claude-home' /workspace/base/Dockerfile && grep -q 'opt/devcontainer-claude' /workspace/base/Dockerfile && echo "PASS"</automated>
  </verify>
  <done>
  - merge-claude-home.sh exists, passes bash syntax check, handles detect/merge/idempotency
  - Dockerfile creates image marker, snapshots ~/.claude to /opt/devcontainer-claude, copies merge script
  </done>
</task>

<task type="auto">
  <name>Task 2: Wire merge into entrypoint and update devcontainer-claude.md</name>
  <files>scripts/docker-sock-fix.sh, base/devcontainer-claude.md</files>
  <action>
**Update `scripts/docker-sock-fix.sh`** — call the merge script early in the entrypoint, BEFORE the docker socket logic:

Insert after the shebang/comment block (after line 6), before the `SOCKET=` line:

```bash
# Merge image-built ~/.claude tooling if host directory was mounted
if [ -x "$HOME/.local/bin/merge-claude-home.sh" ]; then
    "$HOME/.local/bin/merge-claude-home.sh" || true
fi
```

The `|| true` ensures the entrypoint never fails even if merge has issues. Keep all existing docker socket logic unchanged.

**Update `base/devcontainer-claude.md`** — add a short section documenting the merge mechanism under `## Notes`:

Add after the existing notes bullet about shell:

```
- When host `~/.claude` is bind-mounted, the entrypoint auto-merges image tooling (plugins, skills, rules, GSD) into the mounted directory. Host files (credentials, settings) are never overwritten.
```

This keeps the in-image documentation accurate for developers.
  </action>
  <verify>
    <automated>grep -q 'merge-claude-home' /workspace/scripts/docker-sock-fix.sh && grep -q 'auto-merges' /workspace/base/devcontainer-claude.md && echo "PASS"</automated>
  </verify>
  <done>
  - docker-sock-fix.sh calls merge script before docker socket logic
  - devcontainer-claude.md documents the merge behavior
  - Existing entrypoint behavior (docker socket fix, exec "$@") is preserved
  </done>
</task>

<task type="auto">
  <name>Task 3: Validate with Docker build dry-run</name>
  <files></files>
  <action>
Run a Docker build of the base image to verify the Dockerfile changes are syntactically valid and the snapshot step succeeds. Use:

```bash
docker build -f base/Dockerfile -t devcontainer-base:merge-test --target= . 2>&1 | tail -50
```

If the full build is too slow or fails due to network (build args, Claude CLI download), at minimum validate:
1. `docker build --check` or parse the Dockerfile for syntax
2. Run `bash -n scripts/merge-claude-home.sh` (syntax check)
3. Run `bash -n scripts/docker-sock-fix.sh` (syntax check)
4. Verify the merge script handles all three scenarios by tracing logic:
   - No backup dir exists -> exits 0
   - Backup exists, marker matches -> exits 0 (no mount)
   - Backup exists, marker differs -> runs merge

If Docker build succeeds, verify `/opt/devcontainer-claude` exists in the image:
```bash
docker run --rm devcontainer-base:merge-test ls /opt/devcontainer-claude/
```

Note: A full Docker build may take a long time. If it exceeds 5 minutes, skip and rely on syntax validation + manual CI check on PR.
  </action>
  <verify>
    <automated>bash -n /workspace/scripts/merge-claude-home.sh && bash -n /workspace/scripts/docker-sock-fix.sh && echo "PASS"</automated>
  </verify>
  <done>
  - Both scripts pass bash syntax validation
  - Dockerfile is buildable (or syntax-valid if full build skipped)
  - Merge script logic covers: no-op when no mount, idempotent on restart, additive merge on mount
  </done>
</task>

</tasks>

<verification>
1. `bash -n scripts/merge-claude-home.sh` — syntax valid
2. `bash -n scripts/docker-sock-fix.sh` — syntax valid
3. `grep -c 'devcontainer-claude' base/Dockerfile` — returns 2+ (snapshot + copy)
4. `grep -c 'merge-claude-home' scripts/docker-sock-fix.sh` — returns 1+
5. Dockerfile builds successfully (or passes syntax check)
</verification>

<success_criteria>
- New merge-claude-home.sh script handles three scenarios: no mount, individual file mount, full directory mount
- Merge is additive (cp -n) and idempotent (marker file)
- CLAUDE.md gets special append-merge treatment
- Entrypoint calls merge before existing logic
- Dockerfile snapshots build-time ~/.claude to /opt/devcontainer-claude
- All scripts pass bash syntax validation
- devcontainer-claude.md documents the merge behavior
</success_criteria>

<output>
After completion, create `.planning/quick/260329-lnd-create-entrypoint-merge-mechanism-for-cl/260329-lnd-SUMMARY.md`
</output>
