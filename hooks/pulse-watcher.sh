#!/usr/bin/env bash
# Monitors per-session timestamps for idle/stuck detection.
# Auto-exits after 5 minutes with no active sessions.
set -euo pipefail

STATE_DIR="/tmp/pulse"
EMPTY_CHECKS=0

fmt_duration() {
    local secs=$1
    if [ "$secs" -ge 60 ]; then
        echo "$((secs / 60))m"
    else
        echo "${secs}s"
    fi
}

write_state() {
    local session="$1" state="$2" label="$3"
    local state_file="$STATE_DIR/${session}.json"
    local json
    json=$(jq --arg s "$state" --arg l "$label" \
        '. + {state: $s, label: $l}' "$state_file" 2>/dev/null) || return
    local tmp
    tmp=$(mktemp "$STATE_DIR/.tmp.XXXXXX")
    echo "$json" > "$tmp"
    mv "$tmp" "$state_file"
}

while true; do
    sleep 10
    [ -d "$STATE_DIR" ] || continue

    found_active=false
    for ts_file in "$STATE_DIR"/*.ts; do
        [ -f "$ts_file" ] || continue
        found_active=true

        session=$(basename "$ts_file" .ts)
        state_file="$STATE_DIR/${session}.json"
        [ -f "$state_file" ] || continue

        LAST_ACTIVITY=$(cat "$ts_file" 2>/dev/null || echo "0")
        NOW=$(date +%s)
        ELAPSED=$((NOW - LAST_ACTIVITY))

        CURRENT_STATE=$(jq -r '.state // "gray"' "$state_file" 2>/dev/null || echo "gray")

        [ "$CURRENT_STATE" = "red" ] && continue
        [ "$CURRENT_STATE" = "gray" ] && continue

        DUR=$(fmt_duration "$ELAPSED")

        case "$CURRENT_STATE" in
            yellow)
                # Waiting for input — nudge after 60s
                if [ "$ELAPSED" -ge 60 ]; then
                    write_state "$session" "orange" "Idle: waiting for input ($DUR)"
                fi
                ;;
            green)
                # Working but no activity — nudge after 120s
                if [ "$ELAPSED" -ge 120 ]; then
                    write_state "$session" "orange" "Idle: no activity ($DUR)"
                fi
                ;;
            blue)
                # Response ready — fade to gray after 60s
                if [ "$ELAPSED" -ge 60 ]; then
                    write_state "$session" "gray" "Session idle"
                fi
                ;;
            orange)
                # Already idle — keep updating the duration
                write_state "$session" "orange" "Idle ($DUR)"
                ;;
        esac
    done

    if [ "$found_active" = false ]; then
        EMPTY_CHECKS=$((EMPTY_CHECKS + 1))
        [ "$EMPTY_CHECKS" -ge 30 ] && exit 0
    else
        EMPTY_CHECKS=0
    fi
done
