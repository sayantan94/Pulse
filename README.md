# Pulse

A macOS menu bar companion for [Claude Code](https://claude.ai/code). See what your AI sessions are doing without switching windows.

Pulse sits in your menu bar and shows a live indicator for every running Claude Code session. When Claude is working, the icon spins. When it needs your attention, the ring pulses in color. Click to see all sessions at a glance.

## Demo

![Pulse demo](demo.gif)

## What it looks like

- **Working** — sparkle with a spinning arc
- **Needs attention** — blinking colored sparkle (orange for risky commands, red for blocked)
- **Idle** — subtle faded sparkle, adapts to light and dark mode

Click the icon to see all active sessions, their status, and the working directory. Click a session to jump to its terminal.

## Install

```bash
git clone https://github.com/sayantan94/pulse.git
cd pulse
./pulse setup
./pulse start
```

**Requirements:** macOS 14+, Swift 5.9+, [jq](https://jqlang.github.io/jq/). Setup installs missing dependencies automatically.

## How it works

Pulse registers lightweight [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) with Claude Code. When Claude runs a tool, asks a question, or hits an error, the hook writes a small JSON file to `/tmp/pulse/`. The menu bar app watches that directory and updates in real time.

No network calls. No cloud. Everything stays on your machine.

## Session names

Sessions are automatically named after the working directory. To set a custom name:

```bash
export CLAUDE_SESSION_NAME="my-project"
```

Set this in your terminal before starting Claude Code.

## Risky command alerts

Pulse highlights dangerous commands before they run — `git push --force`, `rm -rf`, `sudo`, and more. The menu bar icon turns orange so you know to check.

Edit the patterns at `~/.pulse/hooks/risky-patterns.json`:

```json
{
  "patterns": [
    {"pattern": "git push", "label": "git push"},
    {"pattern": "rm -rf", "label": "rm -rf"},
    {"pattern": "sudo ", "label": "sudo"},
    {"pattern": "npm publish", "label": "npm publish"}
  ]
}
```

Add your own patterns — each entry is a regex matched against the command.

## Multiple sessions

Run Claude Code in as many terminals as you want. Pulse tracks each session independently. The menu bar icon reflects the highest-priority state across all sessions:

- Red (error) takes priority over orange (risky) over green (working) over gray (idle)

Click the icon to see every session with its name, status, and last activity.

## Commands

```bash
./pulse doctor   # Check dependencies and installation status
./pulse setup    # Install dependencies, build, and register hooks
./pulse start    # Launch Pulse in the menu bar
./pulse remove   # Stop, unregister hooks, delete everything
```

## License

MIT
