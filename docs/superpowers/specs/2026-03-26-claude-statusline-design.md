# Claude Statusline Design Spec

**Date:** 2026-03-26
**Package:** `@notsuhas/claude-statusline`
**Repo:** https://github.com/notsuhas/claude-statusline

## Overview

A cross-platform Claude Code statusline with a robbyrussell theme aesthetic. Works on macOS and Linux, with or without Oh My Zsh. Merges upstream features from `kamranahmedse/claude-statusline` (API rate limits, session time, credential resolution, caching) into a robbyrussell-styled multi-line display.

Distributed as both an npm package and a standalone shell installer.

## Output Format

### Two-line layout

```
➜  project-dir git:(main) ✗  Opus 4.6  ctx: 78%  ⏱ 23m
  ◉◉◉◉◉◎◎◎◎◎ 48% (5h)  ◉◉◎◎◎◎◎◎◎◎ 15% (7d)
```

**Line 1** — always shown:
| Segment | Source | Color | Notes |
|---|---|---|---|
| `➜` | Static | Green | Always present |
| `project-dir` | `workspace.current_dir` basename | Cyan | Always present |
| `git:(main) ✗` | git.sh | Blue label, red branch if dirty, yellow `✗` | Only in git repos; omitted if git not installed |
| `Opus 4.6` | `model.display_name` | Magenta | Always present |
| `ctx: 78%` | `context_window.used_percentage` | Green <50%, Yellow 50-79%, Red >=80% | Plain percentage, no bar |
| `⏱ 23m` | Session elapsed time | Dim/gray | Always present. Uses stdin JSON if available, otherwise tracks start timestamp in `/tmp/claude-statusline-session-$PPID` |

**Line 2** — only shown if API credentials are available:
| Segment | Source | Color | Notes |
|---|---|---|---|
| `◉◉◉◉◉◎◎◎◎◎ 48% (5h)` | API 5-hour rate limit | Green <50%, Yellow 50-79%, Red >=80% | 10 circles |
| `◉◉◎◎◎◎◎◎◎◎ 15% (7d)` | API 7-day rate limit | Same thresholds | 10 circles |

Line 2 is indented 2 spaces to visually nest under line 1.

If no API credentials found or API call fails, only line 1 is shown. No errors displayed.

## Architecture

### Approach: Modular source, single-file distribution

Source code is split into focused modules for development. A build step concatenates them into a single `dist/statusline.sh` for installation.

### Project Structure

```
claude-statusline/
├── src/
│   ├── main.sh              # Entry point: reads stdin JSON, orchestrates output
│   ├── git.sh               # Git branch + dirty detection
│   ├── credentials.sh       # Multi-platform credential resolution
│   ├── api.sh               # Rate limit fetching + 60s caching
│   ├── format.sh            # Progress bars, token formatting, color utilities
│   └── themes/
│       └── robbyrussell.sh  # Theme: assembles final output string
├── bin/
│   ├── install.js           # NPM post-install entry point
│   └── build.sh             # Concatenates src/ into dist/statusline.sh
├── install.sh               # Standalone installer (no Node required)
├── dist/
│   └── statusline.sh        # Built single-file output (gitignored)
├── package.json
├── LICENSE
└── README.md
```

### Data Flow

```
Claude Code stdin (JSON)
        │
        ▼
    main.sh
    ├── Parse JSON with jq → model name, context %, current dir
    ├── git.sh → branch name, dirty flag
    ├── credentials.sh → API key (or empty string)
    ├── api.sh → rate limits (if key available, cached 60s)
    ├── format.sh → progress bar builder, token formatter
    └── themes/robbyrussell.sh → assemble + print final output
        │
        ▼
    stdout → Claude Code renders status line
```

### Stdin JSON Shape

Provided by Claude Code:

```json
{
  "workspace": { "current_dir": "/path/to/dir" },
  "model": { "display_name": "Opus 4.6" },
  "context_window": { "used_percentage": 42.5 }
}
```

### Build Process

`bin/build.sh` concatenates source modules in order:

1. Shebang + header comment (version, repo URL)
2. `src/format.sh` — color utilities, progress bars, token formatting
3. `src/credentials.sh` — platform detection, credential resolution
4. `src/api.sh` — rate limit fetch + cache logic
5. `src/git.sh` — branch + dirty detection
6. `src/themes/robbyrussell.sh` — output assembly
7. `src/main.sh` — stdin parsing, orchestration, calls theme

Each source file contains only functions and variables (no shebang). `main.sh` calls into the others.

**npm lifecycle:**
- `npm prepare` → `bin/build.sh` → produces `dist/statusline.sh`
- `npm postinstall` → `bin/install.js` → copies dist to `~/.claude/`

`dist/` is gitignored.

## Credential Resolution

Stops at first success:

| Priority | Method | macOS | Linux |
|---|---|---|---|
| 1 | `$ANTHROPIC_API_KEY` env var | Yes | Yes |
| 2 | macOS Keychain (`security find-generic-password`) | Yes | Skipped |
| 3 | Linux `secret-tool` (`secret-tool lookup`) | Skipped | Yes (if installed) |
| 4 | `~/.claude/credentials.json` file | Yes | Yes |

Platform detected once via `uname -s` at script start, stored in a variable.

## Caching

API responses cached to `/tmp/claude-statusline-cache-$UID` with a 60-second TTL. Cache file stores timestamp + JSON response. If cache is fresh, no API call is made.

## Cross-Platform Compatibility

- Shebang: `#!/usr/bin/env bash`
- Compatible with bash 3.2+ (macOS ships old bash)
- No bashisms beyond bash 3.2 support
- All `jq`, `git`, `curl` calls use POSIX-compatible flags
- No dependency on Oh My Zsh — borrows robbyrussell visual style only
- Claude Code invokes it via `settings.json`, independent of shell prompt config

### Dependencies

| Dependency | Required | Notes |
|---|---|---|
| `bash` (3.2+) | Yes | Script interpreter |
| `jq` | Yes | Auto-installed by installer if missing |
| `git` | No | Git segments omitted if missing |
| `curl` | No | Rate limits omitted if missing |

### Automatic jq Installation

If `jq` is not found, the installer installs it:

| Platform | Method |
|---|---|
| macOS | `brew install jq` (if Homebrew available) |
| Debian/Ubuntu | `sudo apt-get install -y jq` |
| Fedora/RHEL | `sudo dnf install -y jq` |
| Arch | `sudo pacman -S --noconfirm jq` |
| Fallback | Download static binary from jq GitHub releases to `~/.local/bin/` |

Flow: check if installed → detect platform/package manager → attempt install → fallback to static binary → if all fail, warn and exit.

## Install / Uninstall

### Install

Both npm and standalone follow the same logic:

1. Check/install `jq`
2. Detect platform (`uname -s`)
3. Create `~/.claude/` if needed
4. If `~/.claude/statusline.sh` exists, back up to `~/.claude/statusline.sh.bak`
5. If `~/.claude/settings.json` has `statusLine` config, back up to `~/.claude/settings.json.bak`
6. Copy `dist/statusline.sh` to `~/.claude/statusline.sh` with executable permissions
7. Update `~/.claude/settings.json`: set `statusLine.type = "command"` and `statusLine.command = "bash \"$HOME/.claude/statusline.sh\""`
8. Print success message

### Uninstall

Triggered via `--uninstall` flag:

1. If `~/.claude/statusline.sh.bak` exists, restore it (previous statusline comes back)
2. If no backup, remove `~/.claude/statusline.sh` and remove `statusLine` key from `settings.json`
3. If `~/.claude/settings.json.bak` exists, restore it
4. Print confirmation

### Entry Points

| Method | Command |
|---|---|
| NPM install | `npx @notsuhas/claude-statusline` |
| NPM uninstall | `npx @notsuhas/claude-statusline --uninstall` |
| Standalone install | `curl -fsSL <raw-url>/install.sh \| bash` |
| Standalone uninstall | `bash install.sh --uninstall` |

## Theming

Robbyrussell is the default and only shipped theme. The architecture supports adding themes later:

- Themes live in `src/themes/<name>.sh`
- Each theme exports a function that receives all data and prints the formatted output
- `main.sh` calls the active theme's function
- Theme selection could be added via env var or config in the future

## Color Thresholds

Used consistently across context percentage and rate limit bars:

| Usage | Color |
|---|---|
| < 50% | Green |
| 50% - 79% | Yellow |
| >= 80% | Red |
