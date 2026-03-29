---
phase: quick
plan: 260329-lnd
subsystem: devcontainer-base
tags: [entrypoint, merge, claude-tooling, bind-mount]
dependency_graph:
  requires: [setup-claude.sh, docker-sock-fix.sh]
  provides: [merge-claude-home.sh, /opt/devcontainer-claude snapshot]
  affects: [base/Dockerfile, docker-sock-fix.sh, devcontainer-claude.md]
tech_stack:
  added: []
  patterns: [build-time-snapshot, entrypoint-merge, idempotent-marker]
key_files:
  created:
    - scripts/merge-claude-home.sh
  modified:
    - base/Dockerfile
    - scripts/docker-sock-fix.sh
    - base/devcontainer-claude.md
decisions:
  - Used cp -rn (no-clobber) for directory merge to avoid overwriting host files
  - Used image marker file comparison for mount detection instead of device ID comparison
  - Snapshot placed in final root section to avoid extra USER switches
metrics:
  duration: 2m
  completed: 2026-03-29
---

# Quick Task 260329-lnd: Create Entrypoint Merge Mechanism for ~/.claude Summary

POSIX-compatible entrypoint merge script that detects host ~/.claude bind-mounts and additively restores image-built tooling (plugins, skills, rules, GSD, CLAUDE.md) without overwriting host auth/settings files, using build-time snapshot and idempotent marker files.

## What Was Done

### Task 1: Create merge-claude-home.sh and snapshot in Dockerfile
- Created `scripts/merge-claude-home.sh` with three-scenario detection: no backup, no mount, host mount
- Mount detection via image marker file comparison
- Idempotent merge via `.merge-done` marker (handles container restarts)
- Directory merge uses `cp -rn` (no-clobber) for plugins, skills, rules, get-shit-done, agents
- CLAUDE.md gets special append-merge: host content preserved, image content appended with separator
- Updated Dockerfile: image marker after setup-claude.sh, snapshot to `/opt/devcontainer-claude` in root section, merge script COPY with chmod +x
- Commit: 700cdfe

### Task 2: Wire merge into entrypoint and update devcontainer-claude.md
- Added merge-claude-home.sh call early in docker-sock-fix.sh (before socket logic)
- Protected with `|| true` so entrypoint never fails on merge issues
- Documented merge behavior in devcontainer-claude.md Notes section
- Commit: a22725d

### Task 3: Validate with Docker build dry-run
- Both scripts pass `bash -n` syntax validation
- Dockerfile passes instruction-level validation
- Merge script logic traced through all three scenarios
- Dockerfile contains 4 references to devcontainer-claude (snapshot, copy, marker)
- Entrypoint contains 2 references to merge-claude-home (comment + call)

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Commits

| # | Hash | Message |
|---|------|---------|
| 1 | 700cdfe | feat(quick-260329-lnd): create merge-claude-home.sh and Dockerfile snapshot |
| 2 | a22725d | feat(quick-260329-lnd): wire merge into entrypoint and document in devcontainer-claude.md |
