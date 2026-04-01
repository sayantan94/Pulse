# Pulse

A macOS menu bar companion for [Claude Code](https://claude.ai/code). See what your AI sessions are doing without switching windows.

Pulse sits in your menu bar and shows a live indicator for every running Claude Code session. When Claude is working, the icon spins. When it needs your attention, the icon blinks in color. Click to see all sessions at a glance.

## Demo

![Pulse demo](demo.gif)

## Install

```bash
git clone https://github.com/sayantan94/pulse.git
cd pulse
./pulse setup
./pulse start
```

That's it. Setup checks for dependencies (Swift, jq), builds from source, and registers hooks with Claude Code. If jq is missing, it installs it via Homebrew.

## What you'll see

The menu bar icon changes based on what Claude is doing:

| Icon | Meaning |
|------|---------|
| Faded sparkle | No active sessions |
| Sparkle + spinning arc | Claude is working |
| Blinking orange sparkle | Risky command detected (warn) or session idle |
| Blinking red sparkle | Command blocked |

Click the icon to open the panel. You'll see every active session listed by its working directory, with the current status. Click a session to jump to its terminal.

## Warn and block commands

Pulse watches every shell command Claude runs. If it matches a pattern you've defined, it either warns you (orange blink, command still runs) or blocks it (red blink, command prevented).

Default patterns include `rm`, `git push`, `sudo`, `rm -rf`, `npm publish`, and more. Some warn, some block.

You can change this two ways:

**From the menu bar panel** — click the icon, expand the Rules section. Toggle any pattern between Warn and Block. Add new patterns. Turn on "Block all by default" to block everything that matches.

**From the config file** — edit `~/.pulse/hooks/risky-patterns.json`:

```json
{
  "blockByDefault": false,
  "patterns": [
    {"pattern": "rm -rf", "label": "rm -rf", "mode": "block"},
    {"pattern": "git push", "label": "git push", "mode": "warn"},
    {"pattern": "npm publish", "label": "npm publish", "mode": "warn"}
  ]
}
```

Each pattern is a regex. Mode is `"warn"` or `"block"`. Changes take effect immediately.

## Multiple sessions

Run Claude Code in as many terminals as you want. Each session is tracked by its working directory. The menu bar icon shows the highest priority state:

red (blocked) > orange (risky/idle) > green (working) > gray (no sessions)

## Session names

Sessions are named after the working directory automatically. To override:

```bash
export CLAUDE_SESSION_NAME="my-project"
```

Set this before starting Claude Code.

## Commands

```bash
./pulse doctor   # Check dependencies and installation status
./pulse setup    # Install deps, build, register hooks
./pulse start    # Launch Pulse in the menu bar
./pulse remove   # Stop, unregister hooks, delete everything
```

Run `./pulse doctor` anytime to check if everything is set up correctly.

## How it works

Pulse uses [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) — shell scripts that run before and after every tool call. When Claude runs a command, the hook writes a small JSON file to `/tmp/pulse/`. The menu bar app watches that directory and updates in real time.

No network calls. No cloud. Everything stays on your machine.

## Requirements

- macOS 14+
- Swift 5.9+ (comes with Xcode Command Line Tools)
- [jq](https://jqlang.github.io/jq/) (setup installs it automatically)

## License

MIT
