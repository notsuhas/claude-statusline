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
