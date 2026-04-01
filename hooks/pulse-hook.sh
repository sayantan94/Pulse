#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/tmp/pulse"
mkdir -p "$STATE_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATTERNS_FILE="$SCRIPT_DIR/risky-patterns.json"

INPUT=$(cat)

# Single jq parse for all needed fields
IFS=$'\t' read -r EVENT TOOL RAW_SESSION_ID CWD <<< "$(jq -r '[.hook_event_name // "", .tool_name // "", .session_id // "unknown", .cwd // ""] | @tsv' <<< "$INPUT")"

# Sanitize session ID to be filename-safe (replace / with _)
SESSION_ID="${RAW_SESSION_ID//\//_}"

SESSION_NAME="${CLAUDE_SESSION_NAME:-}"
[ -z "$SESSION_NAME" ] && [ -n "$CWD" ] && SESSION_NAME="$CWD"
SESSION_NAME="${SESSION_NAME:-unnamed}"

STATE_FILE="$STATE_DIR/${SESSION_ID}.json"
TIMESTAMP_FILE="$STATE_DIR/${SESSION_ID}.ts"
PID_CACHE="$STATE_DIR/${SESSION_ID}.pid"

# Read cached terminal PID (set at SessionStart)
TERMINAL_PID=""
[ -f "$PID_CACHE" ] && TERMINAL_PID=$(cat "$PID_CACHE")

write_state() {
    local state="$1" label="$2" ttl="${3:-}"
    jq -n --arg s "$state" --arg l "$label" --arg n "$SESSION_NAME" \
        --arg ttl "$ttl" --arg pid "${TERMINAL_PID:-}" '
        {state: $s, label: $l, session_name: $n}
        | if $ttl != "" then . + {ttl: ($ttl | tonumber)} else . end
        | if $pid != "" then . + {terminal_pid: ($pid | tonumber)} else . end
    ' > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"
    date +%s > "$TIMESTAMP_FILE"
}

# Read current state to avoid overwriting warnings
current_state() {
    jq -r '.state // "gray"' "$STATE_FILE" 2>/dev/null || echo "gray"
}

case "$EVENT" in
    PreToolUse)
        case "$TOOL" in
            Bash)
                COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")
                if [ -f "$PATTERNS_FILE" ]; then
                    MATCH_MODE=$(jq -r --arg cmd "$COMMAND" '
                        (.blockByDefault // false) as $def |
                        [.patterns[] | .pattern as $p | select($cmd | test($p; "i")) |
                         if $def then "block"
                         elif .mode == "block" then "block"
                         else "warn" end
                        ] | first // empty
                    ' "$PATTERNS_FILE" 2>/dev/null)
                    if [ -n "$MATCH_MODE" ]; then
                        SHORT_CMD=$(echo "$COMMAND" | head -c 50)
                        if [ "$MATCH_MODE" = "block" ]; then
                            write_state "red" "Blocked: $SHORT_CMD"
                            echo "Pulse blocked this command. Edit ~/.pulse/hooks/risky-patterns.json to change." >&2
                            exit 2
                        else
                            write_state "orange" "Risky: $SHORT_CMD"
                        fi
                    fi
                fi
                ;;
            AskUserQuestion)
                QUESTION=$(jq -r '.tool_input.questions[0].question // "Input needed"' <<< "$INPUT" | head -c 60)
                write_state "yellow" "Input: $QUESTION"
                ;;
        esac
        ;;
    PostToolUse)
        echo 0 > "$STATE_DIR/${SESSION_ID}.failures" 2>/dev/null || true
        # Keep orange/red visible -- only Stop event clears them
        CUR=$(current_state)
        if [ "$CUR" != "orange" ] && [ "$CUR" != "red" ]; then
            write_state "green" "Running"
        fi
        ;;
    PostToolUseFailure)
        FAIL_FILE="$STATE_DIR/${SESSION_ID}.failures"
        COUNT=$(cat "$FAIL_FILE" 2>/dev/null || echo 0)
        COUNT=$((COUNT + 1))
        echo "$COUNT" > "$FAIL_FILE"
        if [ "$COUNT" -ge 3 ]; then
            write_state "red" "Stuck: $COUNT consecutive failures"
        fi
        ;;
    Notification)
        NTYPE=$(jq -r '.notification_type // empty' <<< "$INPUT")
        case "$NTYPE" in
            permission_prompt) write_state "yellow" "Permission: $TOOL" ;;
            idle_prompt) write_state "yellow" "Idle prompt" ;;
        esac
        ;;
    StopFailure)
        ERROR_TYPE=$(jq -r '.error_type // "unknown"' <<< "$INPUT")
        write_state "red" "Error: $ERROR_TYPE"
        ;;
    Stop)
        echo 0 > "$STATE_DIR/${SESSION_ID}.failures" 2>/dev/null || true
        write_state "yellow" "Response ready" 5
        ;;
    SessionStart)
        # Detect and cache terminal PID (only once per session)
        _CPID=$PPID
        for _ in 1 2 3; do
            _PARENT=$(ps -o ppid= -p "$_CPID" 2>/dev/null | tr -d ' ') || break
            [ -z "$_PARENT" ] && break
            _PNAME=$(ps -o comm= -p "$_PARENT" 2>/dev/null || true)
            case "$_PNAME" in
                *Terminal*|*iTerm*|*Alacritty*|*kitty*|*WezTerm*|*Ghostty*) TERMINAL_PID="$_PARENT"; break ;;
            esac
            _CPID="$_PARENT"
        done
        [ -n "$TERMINAL_PID" ] && echo "$TERMINAL_PID" > "$PID_CACHE"

        write_state "green" "Session started"
        WATCHER_PID_FILE="$STATE_DIR/.watcher.pid"
        if ! { [ -f "$WATCHER_PID_FILE" ] && kill -0 "$(cat "$WATCHER_PID_FILE")" 2>/dev/null; }; then
            nohup "$SCRIPT_DIR/pulse-watcher.sh" > /dev/null 2>&1 &
            echo $! > "$WATCHER_PID_FILE"
        fi
        ;;
    SessionEnd)
        write_state "gray" "Session ended"
        rm -f "$STATE_DIR/${SESSION_ID}.ts" "$STATE_DIR/${SESSION_ID}.failures" "$STATE_DIR/${SESSION_ID}.pid"
        ;;
esac

echo '{"async":true}'
exit 0
