# Claude Statusline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform, robbyrussell-themed Claude Code statusline with API rate limit monitoring, distributed as both npm package and standalone installer.

**Architecture:** Modular shell source files concatenated into a single `dist/statusline.sh` at build time. npm lifecycle handles build + install. Standalone `install.sh` for non-Node environments. Auto-installs `jq` if missing.

**Tech Stack:** Bash (3.2+ compatible), jq, curl, git, Node.js (installer only)

---

### Task 1: Project Scaffolding

**Files:**
- Create: `package.json`
- Create: `.gitignore`
- Create: `LICENSE`

- [ ] **Step 1: Initialize git repo**

```bash
cd /Users/notsuhas/Work/Personal/claude-statusline
git init
```

- [ ] **Step 2: Create package.json**

Create `package.json`:

```json
{
  "name": "@notsuhas/claude-statusline",
  "version": "1.0.0",
  "description": "Robbyrussell-themed status line for Claude Code with rate limits, session time, and git info",
  "bin": {
    "claude-statusline": "./bin/install.js"
  },
  "scripts": {
    "prepare": "bash bin/build.sh"
  },
  "keywords": [
    "claude",
    "claude-code",
    "statusline",
    "robbyrussell",
    "cli"
  ],
  "license": "MIT",
  "author": "Suhas"
}
```

- [ ] **Step 3: Create .gitignore**

Create `.gitignore`:

```
node_modules/
dist/
firebase-debug.log
```

- [ ] **Step 4: Create LICENSE**

Create `LICENSE` with MIT license text, copyright 2026 Suhas.

- [ ] **Step 5: Create directory structure**

```bash
mkdir -p src/themes bin dist
```

- [ ] **Step 6: Remove stale file**

```bash
rm -f firebase-debug.log
```

- [ ] **Step 7: Commit**

```bash
git add package.json .gitignore LICENSE
git commit -m "chore: initial project scaffolding"
```

---

### Task 2: src/format.sh — Color Utilities and Progress Bars

**Files:**
- Create: `src/format.sh`

This module defines color variables, the `color_for_pct` function, and the `build_bar` function used by both context percentage and rate limit display.

- [ ] **Step 1: Create src/format.sh**

Create `src/format.sh`:

```bash
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
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n src/format.sh
```

Expected: no output (no syntax errors).

- [ ] **Step 3: Commit**

```bash
git add src/format.sh
git commit -m "feat: add format.sh with colors, progress bars, and duration formatting"
```

---

### Task 3: src/git.sh — Git Branch and Dirty Detection

**Files:**
- Create: `src/git.sh`

- [ ] **Step 1: Create src/git.sh**

Create `src/git.sh`:

```bash
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
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n src/git.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add src/git.sh
git commit -m "feat: add git.sh for branch and dirty detection"
```

---

### Task 4: src/credentials.sh — Cross-Platform OAuth Token Resolution

**Files:**
- Create: `src/credentials.sh`

Note: The upstream uses OAuth tokens (not API keys). The resolution order is: `CLAUDE_CODE_OAUTH_TOKEN` env var → macOS Keychain → `~/.claude/.credentials.json` → Linux `secret-tool`. The credential is an OAuth access token used with `Authorization: Bearer`.

- [ ] **Step 1: Create src/credentials.sh**

Create `src/credentials.sh`:

```bash
# Resolves Claude Code OAuth token from available sources.
# Prints the token to stdout or empty string if not found.
# Usage: token=$(get_oauth_token)
get_oauth_token() {
    local token=""

    # 1. Environment variable
    if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
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

    # 3. Credentials file
    local creds_file="${HOME}/.claude/.credentials.json"
    if [ -f "$creds_file" ]; then
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            printf '%s' "$token"
            return 0
        fi
    fi

    # 4. Linux secret-tool
    if command -v secret-tool >/dev/null 2>&1; then
        local blob
        blob=$(timeout 2 secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
        if [ -n "$blob" ]; then
            token=$(printf '%s' "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                printf '%s' "$token"
                return 0
            fi
        fi
    fi

    printf ''
}
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n src/credentials.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add src/credentials.sh
git commit -m "feat: add credentials.sh for cross-platform OAuth token resolution"
```

---

### Task 5: src/api.sh — Rate Limit Fetching with Cache

**Files:**
- Create: `src/api.sh`

- [ ] **Step 1: Create src/api.sh**

Create `src/api.sh`:

```bash
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
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n src/api.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add src/api.sh
git commit -m "feat: add api.sh for rate limit fetching with 60s cache"
```

---

### Task 6: src/themes/robbyrussell.sh — Theme Output Assembly

**Files:**
- Create: `src/themes/robbyrussell.sh`

This is the core visual assembly. It takes all the data gathered by other modules and prints the two-line robbyrussell-styled output.

- [ ] **Step 1: Create src/themes/robbyrussell.sh**

Create `src/themes/robbyrussell.sh`:

```bash
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
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n src/themes/robbyrussell.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add src/themes/robbyrussell.sh
git commit -m "feat: add robbyrussell theme with two-line status output"
```

---

### Task 7: src/main.sh — Entry Point and Orchestration

**Files:**
- Create: `src/main.sh`

- [ ] **Step 1: Create src/main.sh**

Create `src/main.sh`:

```bash
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
        local stripped="${session_start%%.*}"
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
    local session_file="/tmp/claude-statusline-session-$$"
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
```

- [ ] **Step 2: Fix bash 3.2 compatibility issue**

The `local` keyword cannot be used outside functions at the top level. The session fallback uses `local` outside a function. Fix by removing the `local` keyword from the fallback block:

In `src/main.sh`, replace:

```bash
    # Fallback: track session via temp file keyed to parent PID
    local session_file="/tmp/claude-statusline-session-$$"
```

with:

```bash
    # Fallback: track session via temp file keyed to parent PID
    session_file="/tmp/claude-statusline-session-$$"
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n src/main.sh
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add src/main.sh
git commit -m "feat: add main.sh entry point with JSON parsing and orchestration"
```

---

### Task 8: bin/build.sh — Build Script

**Files:**
- Create: `bin/build.sh`

- [ ] **Step 1: Create bin/build.sh**

Create `bin/build.sh`:

```bash
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
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x bin/build.sh
```

- [ ] **Step 3: Test the build**

```bash
cd /Users/notsuhas/Work/Personal/claude-statusline && bash bin/build.sh
```

Expected: `Built dist/statusline.sh (v1.0.0)` and the file exists.

- [ ] **Step 4: Verify built script syntax**

```bash
bash -n dist/statusline.sh
```

Expected: no output.

- [ ] **Step 5: Smoke test with mock JSON**

```bash
echo '{"workspace":{"current_dir":"/tmp/test-project"},"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":42.5}}' | bash dist/statusline.sh
```

Expected: A robbyrussell-styled line showing `➜  test-project  Opus 4.6  ctx: 42%` with colors. No errors.

- [ ] **Step 6: Commit**

```bash
git add bin/build.sh
git commit -m "feat: add build.sh to concatenate src/ modules into dist/statusline.sh"
```

---

### Task 9: bin/install.js — NPM Installer

**Files:**
- Create: `bin/install.js`

- [ ] **Step 1: Create bin/install.js**

Create `bin/install.js`:

```javascript
#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const os = require("os");
const { execSync } = require("child_process");

const CLAUDE_DIR = path.join(os.homedir(), ".claude");
const SETTINGS_FILE = path.join(CLAUDE_DIR, "settings.json");
const STATUSLINE_DEST = path.join(CLAUDE_DIR, "statusline.sh");
const STATUSLINE_SRC = path.resolve(__dirname, "..", "dist", "statusline.sh");

const green = "\x1b[0;32m";
const red = "\x1b[0;31m";
const yellow = "\x1b[0;33m";
const cyan = "\x1b[0;36m";
const dim = "\x1b[2m";
const reset = "\x1b[0m";

function success(msg) { console.log(`  ${green}✓${reset} ${msg}`); }
function warn(msg) { console.log(`  ${yellow}!${reset} ${msg}`); }
function fail(msg) { console.error(`  ${red}✗${reset} ${msg}`); }
function info(msg) { console.log(`  ${msg}`); }

function hasCommand(cmd) {
    try { execSync(`which ${cmd}`, { stdio: "ignore" }); return true; } catch { return false; }
}

function installJq() {
    if (hasCommand("jq")) return true;

    info(`${cyan}jq${reset} not found — attempting to install...`);
    const platform = os.platform();

    try {
        if (platform === "darwin" && hasCommand("brew")) {
            execSync("brew install jq", { stdio: "inherit" });
            success("Installed jq via Homebrew");
            return true;
        }

        if (platform === "linux") {
            if (hasCommand("apt-get")) {
                execSync("sudo apt-get install -y jq", { stdio: "inherit" });
                success("Installed jq via apt");
                return true;
            }
            if (hasCommand("dnf")) {
                execSync("sudo dnf install -y jq", { stdio: "inherit" });
                success("Installed jq via dnf");
                return true;
            }
            if (hasCommand("pacman")) {
                execSync("sudo pacman -S --noconfirm jq", { stdio: "inherit" });
                success("Installed jq via pacman");
                return true;
            }
        }
    } catch {
        // Package manager install failed, try static binary fallback
    }

    // Static binary fallback
    try {
        const arch = os.arch() === "arm64" ? "arm64" : "amd64";
        const os_name = platform === "darwin" ? "macos" : "linux";
        const url = `https://github.com/jqlang/jq/releases/latest/download/jq-${os_name}-${arch}`;
        const dest = path.join(os.homedir(), ".local", "bin", "jq");
        fs.mkdirSync(path.dirname(dest), { recursive: true });
        execSync(`curl -fsSL -o "${dest}" "${url}" && chmod +x "${dest}"`, { stdio: "inherit" });
        success(`Installed jq static binary to ${dim}${dest}${reset}`);
        info(`  Ensure ${dim}~/.local/bin${reset} is in your PATH`);
        return true;
    } catch {
        fail("Could not install jq automatically");
        info("  Install jq manually: https://jqlang.github.io/jq/download/");
        return false;
    }
}

function uninstall() {
    console.log();
    info(`${cyan}Claude Statusline Uninstaller${reset}`);
    info(`${dim}─────────────────────────────${reset}`);
    console.log();

    const backup = STATUSLINE_DEST + ".bak";

    if (fs.existsSync(backup)) {
        fs.copyFileSync(backup, STATUSLINE_DEST);
        fs.unlinkSync(backup);
        success(`Restored previous statusline from ${dim}statusline.sh.bak${reset}`);
    } else if (fs.existsSync(STATUSLINE_DEST)) {
        fs.unlinkSync(STATUSLINE_DEST);
        success(`Removed ${dim}statusline.sh${reset}`);
    } else {
        warn("No statusline found — nothing to remove");
    }

    if (fs.existsSync(SETTINGS_FILE)) {
        try {
            const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, "utf-8"));
            if (settings.statusLine) {
                delete settings.statusLine;
                fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + "\n");
                success(`Removed statusLine from ${dim}settings.json${reset}`);
            } else {
                success("Settings already clean");
            }
        } catch {
            fail(`Could not parse ${SETTINGS_FILE} — fix it manually`);
            process.exit(1);
        }
    }

    console.log();
    info(`${green}Done!${reset} Restart Claude Code to apply changes.`);
    console.log();
}

function install() {
    console.log();
    info(`${cyan}Claude Statusline Installer${reset}`);
    info(`${dim}───────────────────────────${reset}`);
    console.log();

    if (!installJq()) {
        process.exit(1);
    }

    if (!fs.existsSync(STATUSLINE_SRC)) {
        fail(`Built statusline not found at ${STATUSLINE_SRC}`);
        info("  Run 'npm run prepare' or 'bash bin/build.sh' first");
        process.exit(1);
    }

    if (!fs.existsSync(CLAUDE_DIR)) {
        fs.mkdirSync(CLAUDE_DIR, { recursive: true });
        success(`Created ${dim}${CLAUDE_DIR}${reset}`);
    }

    if (fs.existsSync(STATUSLINE_DEST)) {
        fs.copyFileSync(STATUSLINE_DEST, STATUSLINE_DEST + ".bak");
        warn(`Backed up existing statusline to ${dim}statusline.sh.bak${reset}`);
    }

    fs.copyFileSync(STATUSLINE_SRC, STATUSLINE_DEST);
    fs.chmodSync(STATUSLINE_DEST, 0o755);
    success(`Installed statusline to ${dim}${STATUSLINE_DEST}${reset}`);

    let settings = {};
    if (fs.existsSync(SETTINGS_FILE)) {
        try {
            settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, "utf-8"));
        } catch {
            fail(`Could not parse ${SETTINGS_FILE} — fix it manually`);
            process.exit(1);
        }
    }

    const statusLineConfig = {
        type: "command",
        command: 'bash "$HOME/.claude/statusline.sh"',
    };

    if (
        settings.statusLine &&
        settings.statusLine.type === statusLineConfig.type &&
        settings.statusLine.command === statusLineConfig.command
    ) {
        success("Settings already configured");
    } else {
        settings.statusLine = statusLineConfig;
        fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + "\n");
        success(`Updated ${dim}settings.json${reset} with statusLine config`);
    }

    console.log();
    info(`${green}Done!${reset} Restart Claude Code to see your new status line.`);
    console.log();
}

if (process.argv.includes("--uninstall")) {
    uninstall();
} else {
    install();
}
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x bin/install.js
```

- [ ] **Step 3: Commit**

```bash
git add bin/install.js
git commit -m "feat: add install.js with jq auto-install, backup/restore, and uninstall"
```

---

### Task 10: install.sh — Standalone Shell Installer

**Files:**
- Create: `install.sh`

- [ ] **Step 1: Create install.sh**

Create `install.sh`:

```bash
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
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x install.sh
```

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "feat: add standalone install.sh with jq auto-install and uninstall support"
```

---

### Task 11: End-to-End Testing

**Files:**
- No new files

- [ ] **Step 1: Build the dist**

```bash
cd /Users/notsuhas/Work/Personal/claude-statusline && bash bin/build.sh
```

Expected: `Built dist/statusline.sh (v1.0.0)`

- [ ] **Step 2: Smoke test — basic input**

```bash
echo '{"workspace":{"current_dir":"/Users/notsuhas/Work/Personal/claude-statusline"},"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":42.5}}' | bash dist/statusline.sh
```

Expected: Line 1 with arrow, dir, model, ctx percentage. No line 2 (unless credentials happen to be available). No errors.

- [ ] **Step 3: Smoke test — empty input**

```bash
echo '' | bash dist/statusline.sh
```

Expected: `Claude`

- [ ] **Step 4: Smoke test — git repo detection**

```bash
echo '{"workspace":{"current_dir":"/Users/notsuhas/Work/Personal/claude-statusline"},"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":85}}' | bash dist/statusline.sh
```

Expected: Shows git branch info (if git init was done) and ctx should be red (85%).

- [ ] **Step 5: Smoke test — high context percentage colors**

```bash
echo '{"workspace":{"current_dir":"/tmp"},"model":{"display_name":"Test"},"context_window":{"used_percentage":95}}' | bash dist/statusline.sh
```

Expected: `ctx: 95%` in red.

- [ ] **Step 6: Smoke test — session time from JSON**

```bash
start=$(date -u -v-25M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "25 minutes ago" +"%Y-%m-%dT%H:%M:%SZ")
echo "{\"workspace\":{\"current_dir\":\"/tmp\"},\"model\":{\"display_name\":\"Test\"},\"context_window\":{\"used_percentage\":10},\"session\":{\"start_time\":\"$start\"}}" | bash dist/statusline.sh
```

Expected: Shows `⏱ 25m` (approximately).

- [ ] **Step 7: Commit any fixes if needed, then final commit**

```bash
git add -A
git status
```

If there are changes to commit:

```bash
git commit -m "chore: end-to-end testing fixes"
```

---

### Task 12: README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create README.md**

Create `README.md`:

```markdown
# Claude Statusline

A robbyrussell-themed status line for [Claude Code](https://claude.ai/code) with API rate limits, session time, and git integration.

Works on macOS and Linux, with or without Oh My Zsh.

## Preview

```
➜  my-project git:(main) ✗  Opus 4.6  ctx: 42%  ⏱ 23m
  ◉◉◉◉◉◎◎◎◎◎ 48% (5h)  ◉◉◎◎◎◎◎◎◎◎ 15% (7d)
```

**Line 1:** Directory, git branch/status, model, context usage, session time

**Line 2:** API rate limits (5-hour and 7-day) — shown only if credentials are available

## Install

With npm:

\`\`\`
npx @notsuhas/claude-statusline
\`\`\`

Without npm:

\`\`\`
curl -fsSL https://raw.githubusercontent.com/notsuhas/claude-statusline/main/install.sh | bash
\`\`\`

Restart Claude Code after installing.

## Uninstall

\`\`\`
npx @notsuhas/claude-statusline --uninstall
\`\`\`

Or:

\`\`\`
curl -fsSL https://raw.githubusercontent.com/notsuhas/claude-statusline/main/install.sh | bash -s -- --uninstall
\`\`\`

## What It Shows

| Segment | Description |
|---|---|
| `➜` | Green arrow |
| Directory | Current working directory |
| `git:(branch) ✗` | Git branch and dirty indicator |
| Model | Current Claude model |
| `ctx: N%` | Context window usage |
| `⏱ Nm` | Session elapsed time |
| Rate limit bars | 5-hour and 7-day API usage (if credentials available) |

## Requirements

- **bash** 3.2+
- **jq** (auto-installed if missing)
- **git** (optional — git info omitted if not installed)
- **curl** (optional — rate limits omitted if not installed)

## License

MIT
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with install instructions and feature overview"
```
