#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/tmp/pulse"
mkdir -p "$STATE_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATTERNS_FILE="$SCRIPT_DIR/risky-patterns.json"

INPUT=$(cat)

# Parse common fields
EVENT=$(jq -r '.hook_event_name // ""' <<< "$INPUT")
TOOL=$(jq -r '.tool_name // ""' <<< "$INPUT")
_SID=$(jq -r '.session_id // ""' <<< "$INPUT")
CWD=$(jq -r '.cwd // ""' <<< "$INPUT")
PERM_MODE=$(jq -r '.permission_mode // ""' <<< "$INPUT")

# If CWD is missing, look up from cached mapping
CWD_CACHE="$STATE_DIR/.cwd-${_SID}"
if [ -z "$CWD" ] && [ -f "$CWD_CACHE" ]; then
    CWD=$(cat "$CWD_CACHE")
elif [ -n "$CWD" ] && [ -n "$_SID" ]; then
    echo "$CWD" > "$CWD_CACHE"
fi

# Use CWD as session key
SESSION_ID="${CWD//\//_}"
SESSION_ID="${SESSION_ID:-${_SID//\//_}}"
SESSION_ID="${SESSION_ID:-unknown}"
SESSION_NAME="${CLAUDE_SESSION_NAME:-$CWD}"
SESSION_NAME="${SESSION_NAME:-unnamed}"

STATE_FILE="$STATE_DIR/${SESSION_ID}.json"
TIMESTAMP_FILE="$STATE_DIR/${SESSION_ID}.ts"
PID_CACHE="$STATE_DIR/${SESSION_ID}.pid"
STATS_FILE="$STATE_DIR/${SESSION_ID}.stats"
LOG_FILE="$STATE_DIR/${SESSION_ID}.log"
START_FILE="$STATE_DIR/${SESSION_ID}.start"
META_FILE="$STATE_DIR/${SESSION_ID}.meta"
PROMPT_FILE="$STATE_DIR/${SESSION_ID}.prompt"
TASKS_FILE="$STATE_DIR/${SESSION_ID}.tasks"

# Read cached terminal PID (set at SessionStart)
TERMINAL_PID=""
[ -f "$PID_CACHE" ] && TERMINAL_PID=$(cat "$PID_CACHE")

# Persist permission mode if provided
if [ -n "$PERM_MODE" ]; then
    if [ -f "$META_FILE" ]; then
        jq --arg pm "$PERM_MODE" '.permission_mode = $pm' "$META_FILE" > "$META_FILE.tmp" 2>/dev/null && mv "$META_FILE.tmp" "$META_FILE" || true
    else
        jq -n --arg pm "$PERM_MODE" '{permission_mode: $pm}' > "$META_FILE"
    fi
fi

write_state() {
    local state="$1" label="$2" ttl="${3:-}"
    # Auto-create start time and stats if missing
    [ ! -s "$START_FILE" ] && date +%s > "$START_FILE"
    [ ! -s "$STATS_FILE" ] && echo '{}' > "$STATS_FILE"
    jq -n --arg s "$state" --arg l "$label" --arg n "$SESSION_NAME" \
        --arg ttl "$ttl" --arg pid "${TERMINAL_PID:-}" '
        {state: $s, label: $l, session_name: $n}
        | if $ttl != "" then . + {ttl: ($ttl | tonumber)} else . end
        | if $pid != "" then . + {terminal_pid: ($pid | tonumber)} else . end
    ' > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"
    date +%s > "$TIMESTAMP_FILE"
}

# Append to activity log (keep last 20 entries)
log_event() {
    local event_type="$1" detail="${2:-}"
    local ts
    ts=$(date +%s)
    echo "{\"ts\":$ts,\"event\":\"$event_type\",\"detail\":\"$detail\"}" >> "$LOG_FILE"
    # Rotate: keep last 20 lines
    if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 20 ]; then
        tail -20 "$LOG_FILE" > "$LOG_FILE.tmp"
        mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

# Increment tool usage count
inc_tool() {
    local tool_name="$1"
    local stats="{}"
    [ -f "$STATS_FILE" ] && stats=$(cat "$STATS_FILE")
    echo "$stats" | jq --arg t "$tool_name" '
        .[$t] = ((.[$t] // 0) + 1)
    ' > "$STATS_FILE.tmp"
    mv "$STATS_FILE.tmp" "$STATS_FILE"
}

# Read current state to avoid overwriting warnings
current_state() {
    jq -r '.state // "gray"' "$STATE_FILE" 2>/dev/null || echo "gray"
}

case "$EVENT" in
    PreToolUse)
        log_event "pre_tool" "$TOOL"
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
                            log_event "blocked" "$SHORT_CMD"
                            echo "Pulse blocked this command. Edit ~/.pulse/hooks/risky-patterns.json to change." >&2
                            exit 2
                        else
                            write_state "orange" "Risky: $SHORT_CMD"
                            log_event "risky" "$SHORT_CMD"
                        fi
                    fi
                fi
                ;;
            AskUserQuestion)
                QUESTION=$(jq -r '.tool_input.questions[0].question // "Input needed"' <<< "$INPUT" | head -c 60)
                write_state "yellow" "Input: $QUESTION"
                log_event "ask_user" "$QUESTION"
                ;;
        esac
        ;;
    PostToolUse)
        inc_tool "$TOOL"
        log_event "tool_done" "$TOOL"
        echo 0 > "$STATE_DIR/${SESSION_ID}.failures" 2>/dev/null || true
        CUR=$(current_state)
        if [ "$CUR" != "orange" ] && [ "$CUR" != "red" ]; then
            write_state "green" "Running"
        fi
        ;;
    PostToolUseFailure)
        log_event "tool_fail" "$TOOL"
        FAIL_FILE="$STATE_DIR/${SESSION_ID}.failures"
        COUNT=$(cat "$FAIL_FILE" 2>/dev/null || echo 0)
        COUNT=$((COUNT + 1))
        echo "$COUNT" > "$FAIL_FILE"
        if [ "$COUNT" -ge 3 ]; then
            write_state "red" "Stuck: $COUNT consecutive failures"
        fi
        ;;
    UserPromptSubmit)
        PROMPT=$(jq -r '.prompt // ""' <<< "$INPUT" | head -c 200)
        if [ -n "$PROMPT" ]; then
            echo "$PROMPT" > "$PROMPT_FILE"
        fi
        log_event "prompt" "User prompt"
        write_state "green" "Prompt received"
        ;;
    PermissionRequest)
        log_event "permission_req" "$TOOL"
        write_state "yellow" "Permission: $TOOL"
        ;;
    PermissionDenied)
        REASON=$(jq -r '.reason // "denied"' <<< "$INPUT" | head -c 50)
        log_event "denied" "$TOOL"
        write_state "orange" "Denied: $TOOL"
        ;;
    SubagentStart)
        AGENT_TYPE=$(jq -r '.agent_type // "agent"' <<< "$INPUT")
        log_event "subagent_start" "$AGENT_TYPE"
        write_state "green" "Subagent: $AGENT_TYPE"
        ;;
    SubagentStop)
        log_event "subagent_stop" ""
        CUR=$(current_state)
        if [ "$CUR" != "orange" ] && [ "$CUR" != "red" ] && [ "$CUR" != "yellow" ]; then
            write_state "green" "Running"
        fi
        ;;
    Notification)
        NTYPE=$(jq -r '.notification_type // empty' <<< "$INPUT")
        log_event "notification" "$NTYPE"
        case "$NTYPE" in
            permission_prompt) write_state "yellow" "Permission: $TOOL" ;;
            idle_prompt) write_state "yellow" "Idle prompt" ;;
            auth_success) write_state "green" "Authenticated" ;;
            elicitation_dialog) write_state "yellow" "MCP input needed" ;;
        esac
        ;;
    PreCompact)
        log_event "compact_start" ""
        write_state "green" "Compacting context..."
        ;;
    PostCompact)
        log_event "compact_done" ""
        write_state "green" "Running"
        ;;
    StopFailure)
        ERROR_TYPE=$(jq -r '.error_type // "unknown"' <<< "$INPUT")
        ERROR_MSG=$(jq -r '.error_message // ""' <<< "$INPUT" | head -c 80)
        log_event "error" "$ERROR_TYPE: $ERROR_MSG"
        write_state "red" "Error: $ERROR_TYPE"
        ;;
    Stop)
        STOP_REASON=$(jq -r '.stop_reason // "end_turn"' <<< "$INPUT")
        log_event "stop" "$STOP_REASON"
        echo 0 > "$STATE_DIR/${SESSION_ID}.failures" 2>/dev/null || true
        if [ "$STOP_REASON" = "tool_limit" ]; then
            write_state "orange" "Hit tool limit"
        else
            write_state "blue" "Response ready"
        fi
        ;;
    SessionStart)
        # Capture model info
        MODEL=$(jq -r '.model // ""' <<< "$INPUT")
        SOURCE=$(jq -r '.source // "startup"' <<< "$INPUT")
        if [ -n "$MODEL" ] || [ -n "$PERM_MODE" ]; then
            jq -n --arg m "$MODEL" --arg pm "$PERM_MODE" --arg src "$SOURCE" '
                {}
                | if $m != "" then . + {model: $m} else . end
                | if $pm != "" then . + {permission_mode: $pm} else . end
                | if $src != "" then . + {source: $src} else . end
            ' > "$META_FILE"
        fi

        # Record session start time
        date +%s > "$START_FILE"
        # Reset stats for new session
        echo '{}' > "$STATS_FILE"
        # Clear log and tasks
        : > "$LOG_FILE"
        echo '{"created":0,"completed":0,"active":[]}' > "$TASKS_FILE"

        # Detect and cache terminal PID
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

        log_event "session_start" "$SESSION_NAME"
        write_state "green" "Session started"
        WATCHER_PID_FILE="$STATE_DIR/.watcher.pid"
        if ! { [ -f "$WATCHER_PID_FILE" ] && kill -0 "$(cat "$WATCHER_PID_FILE")" 2>/dev/null; }; then
            nohup "$SCRIPT_DIR/pulse-watcher.sh" > /dev/null 2>&1 &
            echo $! > "$WATCHER_PID_FILE"
        fi
        ;;
    SessionEnd)
        SOURCE=$(jq -r '.source // "other"' <<< "$INPUT")
        log_event "session_end" "$SOURCE"
        write_state "gray" "Session ended: $SOURCE"
        ;;
    CwdChanged)
        NEW_CWD=$(jq -r '.new_cwd // ""' <<< "$INPUT")
        if [ -n "$NEW_CWD" ]; then
            SESSION_NAME="${CLAUDE_SESSION_NAME:-$NEW_CWD}"
            echo "$NEW_CWD" > "$CWD_CACHE"
            log_event "cwd_changed" "$NEW_CWD"
            CUR=$(current_state)
            write_state "${CUR:-green}" "Running"
        fi
        ;;
    TaskCreated)
        TASK_SUBJECT=$(jq -r '.task_subject // "Task"' <<< "$INPUT" | head -c 60)
        TASK_ID=$(jq -r '.task_id // ""' <<< "$INPUT")
        log_event "task_created" "$TASK_SUBJECT"
        # Update task tracking
        if [ -f "$TASKS_FILE" ]; then
            jq --arg subj "$TASK_SUBJECT" --arg id "$TASK_ID" '
                .created = (.created + 1)
                | .active += [{id: $id, subject: $subj}]
            ' "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"
        else
            jq -n --arg subj "$TASK_SUBJECT" --arg id "$TASK_ID" '
                {created: 1, completed: 0, active: [{id: $id, subject: $subj}]}
            ' > "$TASKS_FILE"
        fi
        ;;
    TaskCompleted)
        TASK_SUBJECT=$(jq -r '.task_subject // "Task"' <<< "$INPUT" | head -c 60)
        TASK_ID=$(jq -r '.task_id // ""' <<< "$INPUT")
        log_event "task_done" "$TASK_SUBJECT"
        if [ -f "$TASKS_FILE" ]; then
            jq --arg id "$TASK_ID" '
                .completed = (.completed + 1)
                | .active = [.active[] | select(.id != $id)]
            ' "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"
        fi
        ;;
    TeammateIdle)
        TEAMMATE=$(jq -r '.teammate_name // "teammate"' <<< "$INPUT")
        log_event "teammate_idle" "$TEAMMATE"
        write_state "yellow" "Teammate idle: $TEAMMATE"
        ;;
    InstructionsLoaded)
        FILE_PATH=$(jq -r '.file_path // ""' <<< "$INPUT")
        FNAME=$(basename "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
        log_event "instructions" "$FNAME"
        ;;
    FileChanged)
        FILE_NAME=$(jq -r '.file_name // ""' <<< "$INPUT")
        log_event "file_changed" "$FILE_NAME"
        ;;
    ConfigChange)
        CONFIG_SRC=$(jq -r '.config_source // ""' <<< "$INPUT")
        log_event "config_change" "$CONFIG_SRC"
        ;;
    Elicitation)
        MCP_SERVER=$(jq -r '.mcp_server_name // "MCP"' <<< "$INPUT")
        log_event "elicitation" "$MCP_SERVER"
        write_state "yellow" "MCP input: $MCP_SERVER"
        ;;
    ElicitationResult)
        MCP_SERVER=$(jq -r '.mcp_server_name // "MCP"' <<< "$INPUT")
        log_event "elicitation_result" "$MCP_SERVER"
        CUR=$(current_state)
        if [ "$CUR" = "yellow" ]; then
            write_state "green" "Running"
        fi
        ;;
    WorktreeCreate)
        WT_PATH=$(jq -r '.worktree_path // ""' <<< "$INPUT")
        log_event "worktree_create" "$WT_PATH"
        ;;
    WorktreeRemove)
        WT_PATH=$(jq -r '.worktree_path // ""' <<< "$INPUT")
        log_event "worktree_remove" "$WT_PATH"
        ;;
esac

echo '{"async":true}'
exit 0
