# Robbyrussell theme for claude-statusline
# Assembles and prints the final status line output.
#
# Expected variables (set by main.sh before calling):
#   MODEL_NAME, CURRENT_DIR, CTX_PCT
#   GIT_BRANCH, GIT_DIRTY (from detect_git)
#   SESSION_DURATION (formatted string or empty)
#   USAGE_DATA (JSON string or empty, from fetch_usage_data)
#
# Expected functions (from format.sh):
#   color_for_pct, build_bar, format_duration

theme_robbyrussell() {
    # ── Line 1: ➜  dir git:(branch) ✗  Model  ctx: N%  ⏱ Nm ──

    local line1=""

    # Green arrow
    line1+="\033[1;32m➜\033[0m"

    # Cyan directory
    line1+="  \033[0;36m${CURRENT_DIR}\033[0m"

    # Git info
    if [ -n "$GIT_BRANCH" ]; then
        if [ -n "$GIT_DIRTY" ]; then
            line1+=" \033[1;34mgit:(\033[0;31m${GIT_BRANCH}\033[1;34m)\033[0m"
            line1+=" \033[0;33m✗\033[0m"
        else
            line1+=" \033[1;34mgit:(\033[0;31m${GIT_BRANCH}\033[1;34m)\033[0m"
        fi
    fi

    # Model name (magenta)
    line1+="  \033[0;35m${MODEL_NAME}\033[0m"

    # Context percentage
    if [ -n "$CTX_PCT" ]; then
        local ctx_int ctx_color
        ctx_int=$(printf '%.0f' "$CTX_PCT")
        ctx_color=$(color_for_pct "$ctx_int")
        line1+="  ${ctx_color}ctx: ${ctx_int}%\033[0m"
    fi

    # Session duration
    if [ -n "$SESSION_DURATION" ]; then
        line1+="  \033[2m⏱ \033[0m\033[38;2;220;220;220m${SESSION_DURATION}\033[0m"
    fi

    printf '%b' "$line1"

    # ── Line 2: rate limits (only if usage data available) ──

    if [ -n "$USAGE_DATA" ] && printf '%s' "$USAGE_DATA" | jq -e . >/dev/null 2>&1; then
        local bar_width=10

        # 5-hour usage
        local five_pct five_bar five_color five_fmt
        five_pct=$(printf '%s' "$USAGE_DATA" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
        five_bar=$(build_bar "$five_pct" "$bar_width")
        five_color=$(color_for_pct "$five_pct")
        five_fmt=$(printf '%3d' "$five_pct")

        # 7-day usage
        local seven_pct seven_bar seven_color seven_fmt
        seven_pct=$(printf '%s' "$USAGE_DATA" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
        seven_bar=$(build_bar "$seven_pct" "$bar_width")
        seven_color=$(color_for_pct "$seven_pct")
        seven_fmt=$(printf '%3d' "$seven_pct")

        printf '\n  %b %b%s%%%b (5h)  %b %b%s%%%b (7d)' \
            "$five_bar" "$five_color" "$five_fmt" "$RESET" \
            "$seven_bar" "$seven_color" "$seven_fmt" "$RESET"
    fi
}
