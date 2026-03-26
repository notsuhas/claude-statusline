# Resolves Claude Code OAuth token from available sources.
# Prints the token to stdout or empty string if not found.
# Usage: token=$(get_oauth_token)
get_oauth_token() {
    local token=""

    # 1. Environment variable
    if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
        printf '%s' "$CLAUDE_CODE_OAUTH_TOKEN"
        return 0
    fi

    # 2. macOS Keychain
    if command -v security >/dev/null 2>&1; then
        local blob
        blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [ -n "$blob" ]; then
            token=$(printf '%s' "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                printf '%s' "$token"
                return 0
            fi
        fi
    fi

    # 3. Linux secret-tool (before credentials file per spec priority)
    if command -v secret-tool >/dev/null 2>&1; then
        local blob
        blob=$(secret-tool lookup service "Claude Code-credentials" 2>/dev/null || true)
        if [ -n "$blob" ]; then
            token=$(printf '%s' "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                printf '%s' "$token"
                return 0
            fi
        fi
    fi

    # 4. Credentials file
    local creds_file="${HOME}/.claude/.credentials.json"
    if [ -f "$creds_file" ]; then
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            printf '%s' "$token"
            return 0
        fi
    fi

    printf ''
}
