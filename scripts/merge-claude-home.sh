#!/bin/bash
set -e

# Merge image-built ~/.claude tooling into a host-mounted ~/.claude directory.
# Called by the entrypoint (docker-sock-fix.sh) at container start.
#
# Three scenarios:
#   1. No backup exists (/opt/devcontainer-claude missing) -> exit 0
#   2. No mount detected (image marker matches) -> exit 0
#   3. Host mount detected -> merge image tooling additively, skip host files

BACKUP="/opt/devcontainer-claude"
LIVE="$HOME/.claude"

# If backup doesn't exist, nothing to merge (image not built with snapshot)
if [ ! -d "$BACKUP" ]; then
    exit 0
fi

# If the live directory has the same image marker as the backup, no mount happened
if [ -f "$LIVE/.image-marker" ] && [ -f "$BACKUP/.image-marker" ]; then
    if [ "$(cat "$LIVE/.image-marker")" = "$(cat "$BACKUP/.image-marker")" ]; then
        exit 0
    fi
fi

# Idempotency: if we already merged for this backup version, skip
BACKUP_HASH=""
if [ -f "$BACKUP/.image-marker" ]; then
    BACKUP_HASH=$(cat "$BACKUP/.image-marker")
fi

if [ -f "$LIVE/.merge-done" ] && [ "$(cat "$LIVE/.merge-done")" = "$BACKUP_HASH" ]; then
    exit 0
fi

# Ensure live directory exists
mkdir -p "$LIVE"

# Merge directories — cp -rn (no-clobber) so host files are never overwritten
for dir in plugins skills rules get-shit-done agents; do
    if [ -d "$BACKUP/$dir" ]; then
        if [ ! -d "$LIVE/$dir" ]; then
            cp -r "$BACKUP/$dir" "$LIVE/$dir"
        else
            cp -rn "$BACKUP/$dir/." "$LIVE/$dir/" 2>/dev/null || true
        fi
    fi
done

# Merge CLAUDE.md — special append logic
if [ -f "$BACKUP/CLAUDE.md" ]; then
    if [ ! -f "$LIVE/CLAUDE.md" ]; then
        # No host CLAUDE.md — copy from backup
        cp "$BACKUP/CLAUDE.md" "$LIVE/CLAUDE.md"
    elif ! grep -q '# DevContainer Environment' "$LIVE/CLAUDE.md" 2>/dev/null; then
        # Host CLAUDE.md exists but lacks DevContainer section — append
        printf '\n\n# --- DevContainer Image (auto-merged) ---\n\n' >>"$LIVE/CLAUDE.md"
        cat "$BACKUP/CLAUDE.md" >>"$LIVE/CLAUDE.md"
    fi
    # If already contains '# DevContainer Environment', skip (already merged or image-native)
fi

# Write idempotency marker
echo "$BACKUP_HASH" >"$LIVE/.merge-done"

exit 0
