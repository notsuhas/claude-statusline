# ── Main entry point ────────────────────────────────────
set -f

input=$(cat)

if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# ── Parse stdin JSON ────────────────────────────────────
MODEL_NAME=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')

cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // ""')
[ -z "$cwd" ] || [ "$cwd" = "null" ] && cwd=$(pwd)
CURRENT_DIR=$(basename "$cwd")

CTX_PCT=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')

# ── Session duration ────────────────────────────────────
SESSION_DURATION=""
session_start=$(printf '%s' "$input" | jq -r '.session.start_time // empty')
if [ -n "$session_start" ] && [ "$session_start" != "null" ]; then
    # Try GNU date first, then BSD date
    start_epoch=$(date -d "$session_start" +%s 2>/dev/null)
    if [ -z "$start_epoch" ]; then
        # BSD: strip fractional seconds and timezone for parsing
        stripped="${session_start%%.*}"
        stripped="${stripped%%Z}"
        stripped="${stripped%%+*}"
        start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    fi
    if [ -n "$start_epoch" ]; then
        now_epoch=$(date +%s)
        elapsed=$(( now_epoch - start_epoch ))
        SESSION_DURATION=$(format_duration "$elapsed")
    fi
else
    # Fallback: track session via temp file keyed to parent PID
    session_file="/tmp/claude-statusline-session-$PPID"
    if [ ! -f "$session_file" ]; then
        date +%s > "$session_file"
    fi
    start_epoch=$(cat "$session_file")
    now_epoch=$(date +%s)
    elapsed=$(( now_epoch - start_epoch ))
    SESSION_DURATION=$(format_duration "$elapsed")
fi

# ── Git detection ───────────────────────────────────────
detect_git "$cwd"

# ── API rate limits ─────────────────────────────────────
fetch_usage_data

# ── Render theme ────────────────────────────────────────
theme_robbyrussell

exit 0
