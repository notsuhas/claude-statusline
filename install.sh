#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
RESET='\033[0m'

success() { printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
warn()    { printf "  ${YELLOW}!${RESET} %s\n" "$1"; }
fail()    { printf "  ${RED}✗${RESET} %s\n" "$1" >&2; }
info()    { printf "  %s\n" "$1"; }

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
STATUSLINE_DEST="$CLAUDE_DIR/statusline.sh"
REPO_URL="https://github.com/notsuhas/claude-statusline"

install_jq() {
    command -v jq >/dev/null 2>&1 && return 0

    info "jq not found — attempting to install..."
    local platform
    platform=$(uname -s)

    if [ "$platform" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
        brew install jq && success "Installed jq via Homebrew" && return 0
    fi

    if [ "$platform" = "Linux" ]; then
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get install -y jq && success "Installed jq via apt" && return 0
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y jq && success "Installed jq via dnf" && return 0
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm jq && success "Installed jq via pacman" && return 0
        fi
    fi

    # Static binary fallback
    local arch os_name
    arch=$(uname -m)
    case "$arch" in
        aarch64|arm64) arch="arm64" ;;
        *) arch="amd64" ;;
    esac
    case "$platform" in
        Darwin) os_name="macos" ;;
        *) os_name="linux" ;;
    esac

    local dest="$HOME/.local/bin/jq"
    mkdir -p "$(dirname "$dest")"
    if curl -fsSL -o "$dest" "https://github.com/jqlang/jq/releases/latest/download/jq-${os_name}-${arch}" && chmod +x "$dest"; then
        success "Installed jq static binary to ~/.local/bin/jq"
        info "  Ensure ~/.local/bin is in your PATH"
        return 0
    fi

    fail "Could not install jq automatically"
    info "  Install jq manually: https://jqlang.github.io/jq/download/"
    return 1
}

uninstall() {
    printf "\n"
    info "${CYAN}Claude Statusline Uninstaller${RESET}"
    info "${DIM}─────────────────────────────${RESET}"
    printf "\n"

    local backup="${STATUSLINE_DEST}.bak"
    if [ -f "$backup" ]; then
        cp "$backup" "$STATUSLINE_DEST"
        rm "$backup"
        success "Restored previous statusline from statusline.sh.bak"
    elif [ -f "$STATUSLINE_DEST" ]; then
        rm "$STATUSLINE_DEST"
        success "Removed statusline.sh"
    else
        warn "No statusline found — nothing to remove"
    fi

    if [ -f "$SETTINGS_FILE" ]; then
        if command -v jq >/dev/null 2>&1; then
            local tmp="${SETTINGS_FILE}.tmp"
            jq 'del(.statusLine)' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
            success "Removed statusLine from settings.json"
        else
            warn "jq not available — remove statusLine from settings.json manually"
        fi
    fi

    printf "\n"
    info "${GREEN}Done!${RESET} Restart Claude Code to apply changes."
    printf "\n"
}

install() {
    printf "\n"
    info "${CYAN}Claude Statusline Installer${RESET}"
    info "${DIM}───────────────────────────${RESET}"
    printf "\n"

    install_jq || exit 1

    # Download the built statusline.sh from latest release
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" EXIT

    info "Downloading latest release..."
    if curl -fsSL "${REPO_URL}/releases/latest/download/statusline.sh" -o "${tmp_dir}/statusline.sh"; then
        success "Downloaded statusline.sh"
    else
        # Fallback: clone and build
        info "Release not found — cloning and building..."
        git clone --depth 1 "$REPO_URL" "${tmp_dir}/repo" 2>/dev/null
        bash "${tmp_dir}/repo/bin/build.sh"
        cp "${tmp_dir}/repo/dist/statusline.sh" "${tmp_dir}/statusline.sh"
        success "Built statusline.sh from source"
    fi

    mkdir -p "$CLAUDE_DIR"

    if [ -f "$STATUSLINE_DEST" ]; then
        cp "$STATUSLINE_DEST" "${STATUSLINE_DEST}.bak"
        warn "Backed up existing statusline to statusline.sh.bak"
    fi

    cp "${tmp_dir}/statusline.sh" "$STATUSLINE_DEST"
    chmod +x "$STATUSLINE_DEST"
    success "Installed statusline to ${STATUSLINE_DEST}"

    # Update settings.json
    local target_cmd='bash "$HOME/.claude/statusline.sh"'
    if [ -f "$SETTINGS_FILE" ]; then
        local current_cmd
        current_cmd=$(jq -r '.statusLine.command // ""' "$SETTINGS_FILE" 2>/dev/null)
        if [ "$current_cmd" = "$target_cmd" ]; then
            success "Settings already configured"
        else
            local tmp="${SETTINGS_FILE}.tmp"
            jq --arg cmd "$target_cmd" '.statusLine = {"type": "command", "command": $cmd}' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
            success "Updated settings.json with statusLine config"
        fi
    else
        printf '{"statusLine":{"type":"command","command":"bash \\"$HOME/.claude/statusline.sh\\""}}\n' | jq '.' > "$SETTINGS_FILE"
        success "Created settings.json with statusLine config"
    fi

    printf "\n"
    info "${GREEN}Done!${RESET} Restart Claude Code to see your new status line."
    printf "\n"
}

if [ "${1:-}" = "--uninstall" ]; then
    uninstall
else
    install
fi
