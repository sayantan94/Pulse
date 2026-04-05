# Pulse

A macOS menu bar companion for [Claude Code](https://claude.ai/code). See what your AI sessions are doing without switching windows.

Pulse sits in your menu bar and shows a live indicator for every running Claude Code session. When Claude is working, the icon spins. When it needs your attention, the icon blinks in color. Click to see all sessions at a glance — with session cards showing model, permission mode, tool usage stats, task progress, last prompt, and activity timeline.

## Demo

![Pulse demo](demo.gif)

## Install

```bash
git clone https://github.com/sayantan94/pulse.git
cd pulse
./pulse setup
./pulse start
```

That's it. Setup checks for dependencies (Swift, jq), builds from source, and registers all 26 hook events with Claude Code. If jq is missing, it installs it via Homebrew.

## What you'll see

The menu bar icon changes based on what Claude is doing:

| Icon | Meaning |
|------|---------|
| Gray breathe | No active sessions |
| Sparkle + spinning arc | Claude is working |
| Static blue sparkle | Response ready (your turn) |
| Blinking yellow sparkle | Permission prompt or input needed |
| Blinking orange sparkle | Risky command, idle session, or permission denied |
| Blinking red sparkle | Command blocked or stuck |

Click the icon to open the panel. Each session shows a card with:

- **Session name** and full working directory path
- **State badge** — colored capsule showing Running, Waiting, Done, Caution, or Error
- **Model** — exact model ID from Claude Code (e.g. `claude-opus-4-6`)
- **Permission mode** — current mode (Default, Plan, Auto, Bypass, etc.)
- **Duration timer** — how long the session has been active
- **Last prompt** — what the user last asked Claude
- **Task progress** — progress bar with completed/total count
- **Tool stats** — horizontal bars showing usage counts for each tool (Bash, Read, Edit, Write, Grep, etc.)
- **Activity feed** — recent events with timestamps (tool calls, permissions, prompts, errors)
- **Quick actions** — jump to terminal or dismiss session (on hover)

Adapts to both dark and light mode.

## Hook events

Pulse listens to all 26 [Claude Code hook events](https://code.claude.com/docs/en/hooks):

| Event | State | Tracked Data |
|-------|-------|-------------|
| SessionStart | Green | Model, terminal PID, start time |
| SessionEnd | Gray | End reason |
| UserPromptSubmit | Green | User prompt text saved |
| PreToolUse (Bash) | Orange/Red if risky | Command matched against patterns |
| PreToolUse (AskUserQuestion) | Yellow | Question text |
| PostToolUse | Green | Tool count incremented |
| PostToolUseFailure (3+) | Red (stuck) | Failure count |
| PermissionRequest | Yellow | Tool name |
| PermissionDenied | Orange | Tool + reason |
| SubagentStart | Green | Agent type |
| SubagentStop | Green | Activity log |
| TeammateIdle | Yellow | Teammate name |
| Stop | Blue or Orange | Distinguishes end_turn vs tool_limit |
| StopFailure | Red | Error type + message |
| PreCompact / PostCompact | Green | Activity log |
| CwdChanged | Updates session name | New directory |
| TaskCreated | Activity log | Task subject, progress updated |
| TaskCompleted | Activity log | Progress bar updated |
| InstructionsLoaded | Activity log | CLAUDE.md filename |
| FileChanged | Activity log | Changed filename |
| ConfigChange | Activity log | Config source |
| Elicitation | Yellow | MCP server name |
| ElicitationResult | Green | MCP response |
| WorktreeCreate / WorktreeRemove | Activity log | Worktree path |
| Notification | Yellow | Permission, idle, auth, MCP dialog |

## Session data

Every hook event is tracked per session. The panel shows:

- **Model** — exact model ID passed by Claude Code at session start
- **Permission mode** — updated on every event from Claude Code
- **Last prompt** — the most recent user prompt text
- **Task progress** — created/completed counts with progress bar
- **Tool usage counts** — how many times each tool has been used, displayed as horizontal stat bars
- **Activity timeline** — the last 20 events with icons and relative timestamps
- **Session duration** — elapsed time since session start

All data is captured directly from Claude Code hook events with no hardcoded values. Stats reset when a new session starts.

## Idle detection

A background watcher monitors session activity and updates the icon:

| Starting state | After idle | What happens |
|---------------|------------|--------------|
| Yellow (permission/input) | 60s | Orange blink with duration |
| Green (working) | 120s | Orange blink with duration |
| Blue (done) | 60s | Gray (session idle) |
| Orange (already idle) | every 10s | Duration keeps updating |

Sessions older than 5 minutes are automatically cleaned up.

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

red (blocked) > orange (risky/idle) > yellow (waiting) > blue (done) = green (working) > gray (no sessions)

## Session names

Sessions are named after the working directory automatically. To override:

```bash
export CLAUDE_SESSION_NAME="my-project"
```

Set this before starting Claude Code.

## Commands

```bash
./pulse doctor   # Check dependencies and installation status
./pulse setup    # Install deps, build, register 26 hook events
./pulse start    # Launch Pulse in the menu bar
./pulse remove   # Stop, unregister hooks, delete everything
```

Run `./pulse doctor` anytime to check if everything is set up correctly.

## How it works

Pulse uses [Claude Code hooks](https://code.claude.com/docs/en/hooks) — shell scripts that run on every hook event. When Claude does anything, the hook writes session data to `/tmp/pulse/`. The menu bar app watches that directory and updates in real time.

`./pulse setup` adds the following to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] },
      { "matcher": "AskUserQuestion", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }
    ],
    "PostToolUse":          [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "PostToolUseFailure":   [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "UserPromptSubmit":     [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "PermissionRequest":    [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "PermissionDenied":     [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "SubagentStart":        [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "SubagentStop":         [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "TeammateIdle":         [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "SessionStart":         [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "SessionEnd":           [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "Stop":                 [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "StopFailure":          [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "PreCompact":           [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "PostCompact":          [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "CwdChanged":           [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "TaskCreated":          [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "TaskCompleted":        [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "InstructionsLoaded":   [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "FileChanged":          [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "ConfigChange":         [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "Elicitation":          [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "ElicitationResult":    [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "WorktreeCreate":       [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "WorktreeRemove":       [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }],
    "Notification":         [{ "matcher": "permission_prompt|idle_prompt|auth_success|elicitation_dialog", "hooks": [{ "type": "command", "command": "~/.pulse/hooks/pulse-hook.sh", "timeout": 5 }] }]
  }
}
```

`./pulse remove` cleanly removes all these entries.

Per-session data is stored in `/tmp/pulse/`:
- `{session}.json` — current state, label, and session name
- `{session}.meta` — model ID and permission mode
- `{session}.stats` — tool usage counts (JSON object)
- `{session}.log` — recent activity events (newline-delimited JSON)
- `{session}.prompt` — last user prompt text
- `{session}.tasks` — task created/completed counts and active list
- `{session}.start` — session start timestamp
- `{session}.ts` — last activity timestamp

No network calls. No cloud. Everything stays on your machine.

## Requirements

- macOS 14+
- Swift 5.9+ (comes with Xcode Command Line Tools)
- [jq](https://jqlang.github.io/jq/) (setup installs it automatically)

## License

MIT
