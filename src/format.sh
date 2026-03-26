# ── Colors ──────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
DIM='\033[2m'
WHITE='\033[38;2;220;220;220m'
RESET='\033[0m'

# ── Helpers ─────────────────────────────────────────────

# Returns the color escape code for a given percentage.
# Usage: color=$(color_for_pct 75)
color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 80 ]; then
        printf '%s' "$RED"
    elif [ "$pct" -ge 50 ]; then
        printf '%s' "$YELLOW"
    else
        printf '%s' "$GREEN"
    fi
}

# Builds a 10-circle progress bar: ◉◉◉◉◉◎◎◎◎◎
# Usage: bar=$(build_bar 45 10)
build_bar() {
    local pct=$1
    local width=${2:-10}
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100

    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar_color
    bar_color=$(color_for_pct "$pct")

    local filled_str="" empty_str=""
    local i
    for ((i=0; i<filled; i++)); do filled_str+="◉"; done
    for ((i=0; i<empty; i++)); do empty_str+="◎"; done

    printf '%b%s%b%s%b' "$bar_color" "$filled_str" "$DIM" "$empty_str" "$RESET"
}

# Formats elapsed seconds into human-readable duration: 1h23m, 5m, 30s
# Usage: dur=$(format_duration 3723)
format_duration() {
    local elapsed=$1
    if [ "$elapsed" -ge 3600 ]; then
        printf '%dh%dm' "$(( elapsed / 3600 ))" "$(( (elapsed % 3600) / 60 ))"
    elif [ "$elapsed" -ge 60 ]; then
        printf '%dm' "$(( elapsed / 60 ))"
    else
        printf '%ds' "$elapsed"
    fi
}
