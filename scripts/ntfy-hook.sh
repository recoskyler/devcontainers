#!/bin/bash
EVENT_TYPE="${1:-notification}"
INPUT=$(timeout 5 cat 2>/dev/null || true)
NTFY_URL="${NTFY_URL:-}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

[ -z "$INPUT" ] && exit 0
[ -z "$NTFY_URL" ] && exit 0
[ -z "$NTFY_TOKEN" ] && exit 0

case "$EVENT_TYPE" in
    (notification)
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
    (stop)
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
