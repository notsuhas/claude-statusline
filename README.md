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

```
npx @notsuhas/claude-statusline@latest
```

Without npm:

```
curl -fsSL https://raw.githubusercontent.com/notsuhas/claude-statusline/main/install.sh | bash
```

Restart Claude Code after installing.

## Uninstall

```
npx @notsuhas/claude-statusline@latest --uninstall
```

Or:

```
curl -fsSL https://raw.githubusercontent.com/notsuhas/claude-statusline/main/install.sh | bash -s -- --uninstall
```

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
