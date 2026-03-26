#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$ROOT_DIR/src"
DIST_DIR="$ROOT_DIR/dist"
OUT_FILE="$DIST_DIR/statusline.sh"

VERSION=$(node -p "require('$ROOT_DIR/package.json').version" 2>/dev/null || echo "dev")

mkdir -p "$DIST_DIR"

{
    cat <<HEADER
#!/usr/bin/env bash
# claude-statusline v${VERSION}
# https://github.com/notsuhas/claude-statusline
# Generated — do not edit. Modify src/ files instead.
HEADER

    echo ""
    echo "# ── format.sh ───────────────────────────────────────"
    cat "$SRC_DIR/format.sh"
    echo ""
    echo "# ── credentials.sh ──────────────────────────────────"
    cat "$SRC_DIR/credentials.sh"
    echo ""
    echo "# ── api.sh ──────────────────────────────────────────"
    cat "$SRC_DIR/api.sh"
    echo ""
    echo "# ── git.sh ──────────────────────────────────────────"
    cat "$SRC_DIR/git.sh"
    echo ""
    echo "# ── themes/robbyrussell.sh ──────────────────────────"
    cat "$SRC_DIR/themes/robbyrussell.sh"
    echo ""
    echo "# ── main.sh ─────────────────────────────────────────"
    cat "$SRC_DIR/main.sh"
} > "$OUT_FILE"

chmod +x "$OUT_FILE"
echo "Built $OUT_FILE (v${VERSION})"
