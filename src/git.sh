# Detects git branch and dirty status for a given directory.
# Sets GIT_BRANCH and GIT_DIRTY variables.
# Usage: detect_git "/path/to/dir"
detect_git() {
    local dir="$1"
    GIT_BRANCH=""
    GIT_DIRTY=""

    command -v git >/dev/null 2>&1 || return 0

    git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

    GIT_BRANCH=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null)
    if [ -z "$GIT_BRANCH" ]; then
        GIT_BRANCH=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
    fi

    if [ -n "$(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
        GIT_DIRTY="1"
    fi
}
