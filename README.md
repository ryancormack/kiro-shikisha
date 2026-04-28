<p align="center">
  <img src="screenshots/logo.png" alt="Kiro Kantoku" width="200">
</p>

# Kiro Kantoku

A native macOS desktop app for managing multiple AI coding agents in parallel. Kiro Kantoku gives you a visual interface to create tasks, assign them to AI agents powered by [kiro-cli](https://github.com/aptove/swift-sdk), and monitor their progress -- all from a single window.

![Main View](screenshots/main-view.png)

## Quick Start

```bash
# Install via Homebrew
brew tap ryancormack/kiro-kantoku
brew install --cask kiro-kantoku

# Make sure kiro-cli is installed and authenticated
kiro-cli login

# Launch the app
open -a KiroKantoku
```

1. The onboarding flow will guide you through verifying your `kiro-cli` path.
2. Create a new task with **⌘⇧T** or the **+** button.
3. Give it a name, choose a project directory, and optionally configure a git branch or worktree.
4. The agent connects and you can start chatting.

## Features

### Task-Centric Workflow

Create named tasks, each tied to a project directory. Tasks go through a full lifecycle -- pending, starting, working, paused, completed, failed, or cancelled -- so you always know what's happening.

![New Task](screenshots/new-task.png)

### Multi-Agent Dashboard

Run multiple agents simultaneously across different projects. The dashboard gives you a grid overview of all active tasks, an activity feed, and highlights tasks that need your attention.

![Dashboard](screenshots/dashboard.png)

### Chat Interface

Converse with agents directly. The chat panel supports markdown rendering, inline tool call display, slash commands, and image attachments (PNG, JPEG, GIF, WebP).

![Chat](screenshots/chat.png)

### Slash Commands

The chat input supports slash commands with an autocomplete picker. Type `/` to see every command the agent advertises — both standard ACP commands and Kiro vendor extensions are merged into a single list.

- **Built-in commands.** `/agent`, `/chat`, `/clear`, `/code`, `/compact`, `/context`, `/checkpoint`, `/copy`, `/help`, `/hooks`, `/knowledge`, `/mcp`, `/model`, `/plan`, `/prompts`, `/tools`, `/usage`, `/changelog` — whatever kiro-cli reports for the session. The app no longer filters commands to a short allow-list.
- **Skill-based commands.** Every skill discovered in `.kiro/skills/` and `~/.kiro/skills/` is also available as a `/skill-name` slash command. These appear in the picker with a purple **Skill** badge so they are easy to spot.
- **Selection commands.** Commands like `/model` that need an argument open an interactive options picker populated via `_kiro.dev/commands/options`.
- **GUI-only exclusions.** Commands that require a terminal `$EDITOR`/`$PAGER` or duplicate native macOS behavior are hidden (`/editor`, `/reply`, `/transcript`, `/logdump`, `/theme`, `/experiment`, `/paste`, `/todos`, `/issue`, `/tangent`, `/quit`). Everything else passes through.

### Permission Control

When agents need approval for tool calls (e.g. shell commands, file writes), an interactive permission request UI appears inline. You can allow or reject the request once, or choose to always allow or always reject for that tool. The permission flow integrates with the ACP SDK's `requestPermissions` callback.

### Context Usage Monitoring

A visual context usage bar shows the percentage of the agent's context window currently in use. The bar is color-coded: green when usage is low, yellow when moderate, and red when nearing the limit. Context usage data arrives via the `_kiro.dev/metadata` notification.

### Agent Thinking/Reasoning

A collapsible thought bubble displays the agent's internal reasoning in real time as it works. Thought chunks stream in via both ACP `agentThoughtChunk` session updates and `_kiro.dev/session/update` notifications with `agent_thought_chunk` type. Thought content is suppressed during session replay to avoid duplication.

### Execution Plans

A live execution plan view shows the agent's planned steps along with their current status (pending, in progress, or completed). Plan updates arrive via the `_kiro.dev/session/update` notification with `plan` type, and also through the standard ACP `planUpdate` session update.

### Agent & Model Selector

Switch between agents and models on the fly. A compact selector bar above the chat input lets you pick which agent (e.g. default, planner) and which model (e.g. Claude Opus, Sonnet, Haiku, DeepSeek, MiniMax, Qwen) to use for the current session. Changes take effect immediately via ACP.

### Code Panel

See what the agent is doing in real time:

- **Files Changed** -- git diff view with syntax-highlighted, word-level diffs
- **Terminal** -- output from commands the agent executes
- **Debug** -- raw ACP protocol log for troubleshooting

The code panel position is configurable: place it to the right of the chat or below it. This setting is available in Settings > Appearance.

![Code Panel](screenshots/code-panel.png)

### Skills Discovery

Kiro Kantoku discovers SKILL.md files from both workspace-local (`.kiro/skills/`) and global (`~/.kiro/skills/`) directories. Each skill is parsed from YAML frontmatter, and any files in its `references/` subfolder are counted for display. Workspace skills override global skills with the same name.

- **Collapsible panel.** A panel above the chat input lists every discovered skill with its description, reference-file count, and an Active badge when the agent has activated it.
- **Invoke as slash commands.** The "Use" button and the `/` autocomplete picker both invoke the skill as a real `/skill-name` slash command when kiro-cli advertises it. Older CLIs fall back to a natural-language prompt automatically.
- **Live refresh.** A refresh button on the panel re-scans both skill directories so newly-added skills appear without restarting the task.

### MCP OAuth Support

When an MCP server requires browser-based OAuth authentication, an inline prompt appears with an "Open in Browser" button. The OAuth URL is provided by the `_kiro.dev/mcp/oauth_request` notification.

### Compaction and Clear Status

Status banners appear during context compaction (blue) and history clearing (orange) operations. These are triggered by `_kiro.dev/compaction/status` and `_kiro.dev/clear/status` notifications respectively and remain visible while the operation is in progress.

### Session History

Kiro Kantoku reads kiro-cli's on-disk sessions (`~/.kiro/sessions/cli/`) and gives you several ways to pick up where you left off:

- **File > Load Session… (⌘⇧L)** opens a browser of every session on disk, grouped by workspace directory. Pick one and it starts a new task reconnected to that session.
- **File > Resume Last Session (⌘⇧R)** reconnects the currently selected task (if it has a saved session) or, if no task is selected, loads the most recently updated session on disk — the same behavior as `kiro-cli chat --resume`.
- **New Task sheet** automatically discovers past sessions for the directory you pick and offers a "Resume an existing session for this directory" option right in the form, so you don't need to leave the new-task flow.
- **Per-task history** — click the clock button in the task header to see just the sessions for that task's workspace directory.
- **Sidebar toolbar** has a clock-arrow button that opens the same global session browser.
- **Delete from disk** — right-click any session (or swipe-to-delete in the per-workspace history) to permanently remove its `.json`, `.jsonl`, and any stale `.lock` file. A confirmation alert prevents accidents.

Under the hood the app uses ACP's `session/load` method to reconnect, with workspace-based fallback and automatic stale-lock recovery if a previous kiro-cli process crashed with a session locked.

### Configuration Options

Session-level configuration options (e.g. autonomous mode toggles) are surfaced from the server and displayed in the UI. Options are provided during session creation and updated via `configOptionUpdate` session updates. Changes are sent back to the server via `session/setConfigOption`.

### Git Worktree Support

When creating a task, Kiro Kantoku detects git repositories automatically. You can optionally create a new git worktree so the agent works on an isolated branch without touching your main working tree.

### Agent Configuration Profiles

Define multiple agent profiles in Settings > Agents. Each profile has a name, an agent identifier, and optional tags. Set a default profile or pick one per task at creation time.

### Task Persistence and Restoration

Tasks are automatically saved to UserDefaults and restored on relaunch. Active tasks are restored in a paused state. Stale kiro-cli processes from previous launches are detected and terminated on startup, ensuring clean recovery.

### Stale Session Lock Recovery

When loading a session that has a stale lock (e.g. from a crashed kiro-cli process), Kiro Kantoku automatically detects the `SESSION_LOCKED` error, removes the stale lock file, and retries the session load. If recovery fails, it falls back to starting a fresh session.

### Onboarding Flow

A first-launch wizard guides you through initial setup: auto-detecting the kiro-cli path, validating it exists and is executable, and creating your first workspace.

### Session Persistence

Tasks and their ACP sessions are saved automatically. When you relaunch the app, paused tasks reconnect to their previous sessions.

### macOS Native

Built with SwiftUI. Supports light/dark/system themes, configurable font sizes, adjustable split views, keyboard shortcuts, and macOS notifications for agent events.

## Documentation

- [ACP Methods and Kiro Extensions](docs/acp-methods.md) -- Detailed reference for all ACP protocol methods and Kiro vendor extension notifications supported by Kiro Kantoku.

## Requirements

- macOS 14 (Sonoma) or later
- [kiro-cli](https://github.com/aptove/swift-sdk) installed and authenticated (`kiro-cli login`)
- Swift 6.0+ toolchain (for building from source)

## Installation

### Homebrew (Recommended)

```bash
brew tap ryancormack/kiro-kantoku
brew install --cask kiro-kantoku
```

### Build from Source

```bash
git clone https://github.com/ryancormack/kiro-kantoku.git
cd kiro-kantoku
swift build
```

The built binary will be at `.build/debug/KiroKantoku`. You can run it directly:

```bash
.build/debug/KiroKantoku
```

For a release build:

```bash
swift build -c release
```

The optimised binary will be at `.build/release/KiroKantoku`.

### kiro-cli Setup

Kiro Kantoku expects `kiro-cli` at `~/.local/bin/kiro-cli` by default. You can change this in Settings > General.

Make sure you're authenticated before launching:

```bash
kiro-cli login
```

## Getting Started

1. Launch the app. The onboarding flow will guide you through verifying your `kiro-cli` path.
2. Create a new task with **⌘⇧T** or the **+** button.
3. Give it a name, choose a project directory, and optionally configure a git branch or worktree.
4. The agent connects and you can start chatting.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| ⌘⇧T | New Task |
| ⌘⇧L | Load Session… (browse every session on disk) |
| ⌘⇧R | Resume Last Session (re-open selected task, or newest session) |
| ⌘D | Toggle Dashboard |
| ⌘1–9 | Switch between tasks |
| ⌘Return | Send prompt |
| ⌘. | Cancel current agent action |
| ⌘⇧K | Clear chat history |
| ⌘, | Settings |

## Project Structure

```
Sources/KiroKantoku/
├── App/                  # App entry point and lifecycle
├── Models/               # Data models (Agent, AgentTask, Workspace, etc.)
├── Services/             # Core services
│   ├── AgentManager      # Manages agent lifecycle and ACP communication
│   ├── TaskManager        # Task creation, state transitions, persistence
│   ├── ACPConnection      # ACP protocol transport over subprocess pipes
│   ├── GitService         # Git repo detection, worktree operations
│   ├── SessionStorage     # Session persistence
│   └── NotificationManager # macOS notifications
└── Views/
    ├── Agent/            # Chat panel, message rendering, input
    ├── Code/             # Diff viewer, terminal output, debug log
    ├── Dashboard/        # Multi-task overview grid
    ├── Task/             # Task detail view, new task sheet
    ├── Sidebar/          # Navigation sidebar
    ├── Session/          # Session history
    ├── Settings/         # General, Agents, Appearance settings
    ├── Workspace/        # Workspace management
    ├── Components/       # Shared UI components
    └── Onboarding/       # First-launch setup
```

## Contributing

Contributions are welcome. Please open an issue first to discuss what you'd like to change.

## License

This project is licensed under the [MIT License](LICENSE).

## Why "Kiro Kantoku"?

**Kiro** rhymes with "hero" -- the team behind Kiro chose the name to evoke a tireless, hardworking partner for developers. It also happens to be a Japanese word (岐路) meaning "crossroads."

**Kantoku** (監督) is Japanese for "director" or "supervisor" -- the standard term for film directors, sports coaches, and project managers. Kiro Kantoku is exactly that: the supervisor and director for your Kiro agents, giving you a single UI to manage them all.
