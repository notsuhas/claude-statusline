# Fetches API usage data with 60-second caching.
# Sets USAGE_DATA to the JSON response or empty string.
# Requires: get_oauth_token (from credentials.sh), curl, jq
# Usage: fetch_usage_data
USAGE_DATA=""

fetch_usage_data() {
    USAGE_DATA=""

    command -v curl >/dev/null 2>&1 || return 0

    local cache_dir="/tmp/claude"
    local cache_file="${cache_dir}/statusline-usage-cache.json"
    local cache_max_age=60

    mkdir -p "$cache_dir"

    # Check cache freshness
    if [ -f "$cache_file" ]; then
        local cache_mtime now cache_age
        cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
        now=$(date +%s)
        cache_age=$(( now - cache_mtime ))
        if [ "$cache_age" -lt "$cache_max_age" ]; then
            USAGE_DATA=$(cat "$cache_file" 2>/dev/null)
            return 0
        fi
    fi

    # Fetch fresh data
    local token
    token=$(get_oauth_token)
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        local response
        response=$(curl -s --max-time 5 \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-statusline/1.0.0" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        if [ -n "$response" ] && printf '%s' "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
            USAGE_DATA="$response"
            printf '%s' "$response" > "$cache_file"
            return 0
        fi
    fi

    # Fall back to stale cache if fetch failed
    if [ -f "$cache_file" ]; then
        USAGE_DATA=$(cat "$cache_file" 2>/dev/null)
    fi
}
