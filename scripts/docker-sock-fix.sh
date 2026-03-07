#!/bin/bash
# Fix Docker socket permissions so the dev user can use docker without sudo.
# When /var/run/docker.sock is bind-mounted from the host, its GID may not
# match the container's "docker" group. This script updates the container's
# docker group GID to match the socket's GID, then re-execs with the new group.

SOCKET="/var/run/docker.sock"

if [ -S "$SOCKET" ]; then
    SOCK_GID=$(stat -c '%g' "$SOCKET")
    CUR_GID=$(getent group docker | cut -d: -f3)

    if [ "$SOCK_GID" != "$CUR_GID" ]; then
        # Check if another group already uses this GID
        EXISTING=$(getent group "$SOCK_GID" | cut -d: -f1)
        if [ -n "$EXISTING" ] && [ "$EXISTING" != "docker" ]; then
            sudo groupmod -g 99999 "$EXISTING"
        fi
        sudo groupmod -g "$SOCK_GID" docker
    fi

    # Re-exec with updated docker group if not already applied
    if ! id -G | tr ' ' '\n' | grep -q "^${SOCK_GID}$"; then
        exec sg docker "$(printf '%q ' "$@")"
    fi
fi

exec "$@"
