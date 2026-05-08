# Product Overview

Kiro Kantoku is a native macOS desktop app for managing multiple AI coding agents in parallel. It provides a visual interface to create tasks, assign them to AI agents powered by kiro-cli (via the ACP protocol), and monitor their progress from a single window.

## Core Concepts

- **Task-centric architecture**: Tasks are the first-class entity. Each task is tied to a project directory and goes through a lifecycle (pending -> starting -> working -> paused -> completed/failed/cancelled).
- **Multi-agent**: Multiple agents can run simultaneously across different projects. A dashboard provides a grid overview of all active tasks.
- **ACP protocol**: Communication with kiro-cli happens over the Agent Communication Protocol (ACP) via subprocess pipes. The app uses the `aptove/swift-sdk` package for ACP types and transport.
- **Git worktree support**: Tasks can optionally run in isolated git worktrees so agents don't interfere with the user's main working tree.
- **macOS native**: Built with SwiftUI. Supports light/dark/system themes, configurable font sizes, adjustable split views, keyboard shortcuts (e.g. Cmd+Shift+T for new task, Cmd+Return to send), and macOS notifications for agent events.

## Key Features

### Chat Interface
- Markdown rendering, inline tool call display, image attachments (PNG, JPEG, GIF, WebP)
- Agent thinking/reasoning displayed in collapsible thought bubbles (streamed via ACP `agentThoughtChunk` and `_kiro.dev/session/update` notifications)
- Context usage monitoring with a color-coded bar (green/yellow/red) driven by `_kiro.dev/metadata`
- Execution plan view showing planned steps and their status (pending, in progress, completed)

### Slash Commands
Type `/` to see every command the agent advertises. Both standard ACP commands and Kiro vendor extensions are merged into a single autocomplete list.

- **Built-in commands**: `/agent`, `/chat`, `/clear`, `/code`, `/compact`, `/context`, `/checkpoint`, `/copy`, `/help`, `/hooks`, `/knowledge`, `/mcp`, `/model`, `/plan`, `/prompts`, `/tools`, `/usage`, `/changelog`, and whatever else kiro-cli reports. No short allow-list filtering.
- **Skill-based commands**: Every skill discovered in `.kiro/skills/` and `~/.kiro/skills/` appears as a `/skill-name` slash command with a purple "Skill" badge.
- **Selection commands**: Commands like `/model` that need an argument open an interactive options picker populated via `_kiro.dev/commands/options`.
- **GUI-only exclusions**: Commands requiring a terminal `$EDITOR`/`$PAGER` or duplicating native macOS behavior are hidden (`/editor`, `/reply`, `/transcript`, `/logdump`, `/theme`, `/experiment`, `/paste`, `/todos`, `/issue`, `/tangent`, `/quit`).

### Agent & Model Selector
A compact selector bar above the chat input lets you switch between agents (e.g. default, planner) and models (e.g. Claude Opus, Sonnet, Haiku, DeepSeek, MiniMax, Qwen) on the fly. Changes take effect immediately via ACP.

### Agent Configuration Profiles
Define multiple agent profiles in Settings > Agents. Each profile has a name, an agent identifier, and optional tags. Set a default profile or pick one per task at creation time.

### Configuration Options
Session-level configuration options (e.g. autonomous mode toggles) are surfaced from the server and displayed in the UI. Options arrive during session creation and update via `configOptionUpdate` session updates. Changes are sent back via `session/setConfigOption`.

### Permission Control
When agents need approval for tool calls (shell commands, file writes), an inline permission request UI appears. Allow or reject once, or set a permanent rule for that tool. Integrates with the ACP SDK's `requestPermissions` callback.

### Code Panel
Real-time view of agent activity:
- **Files Changed** -- git diff with syntax-highlighted, word-level diffs
- **Terminal** -- output from commands the agent executes
- **Debug** -- raw ACP protocol log for troubleshooting

Code panel position is configurable (right of chat or below) via Settings > Appearance.

### Skills Discovery
Discovers SKILL.md files from workspace-local (`.kiro/skills/`) and global (`~/.kiro/skills/`) directories. Skills are parsed from YAML frontmatter. Workspace skills override global skills with the same name.
- Collapsible panel above chat input listing discovered skills with description, reference-file count, and Active badge
- "Use" button and `/` autocomplete both invoke the skill as a `/skill-name` slash command (falls back to natural-language prompt on older CLIs)
- Refresh button re-scans skill directories without restarting the task

### Session History
Reads kiro-cli's on-disk sessions (`~/.kiro/sessions/cli/`) and provides multiple ways to resume:
- **File > Load Session (Cmd+Shift+L)**: Browse all sessions grouped by workspace directory
- **File > Resume Last Session (Cmd+Shift+R)**: Reconnect current task or load most recently updated session
- **New Task sheet**: Auto-discovers past sessions for the chosen directory and offers "Resume an existing session"
- **Per-task history**: Clock button in task header shows sessions for that task's workspace
- **Global session browser**: Clock-arrow button in sidebar toolbar
- **Delete from disk**: Right-click or swipe-to-delete to remove session files (`.json`, `.jsonl`, `.lock`) with confirmation

Uses ACP's `session/load` method to reconnect, with workspace-based fallback and automatic stale-lock recovery.

### Stale Session Lock Recovery
Automatically detects `SESSION_LOCKED` errors when loading a session with a stale lock (e.g. from a crashed kiro-cli process), removes the lock file, and retries. Falls back to a fresh session if recovery fails.

### Task Persistence and Restoration
Tasks are auto-saved to UserDefaults and restored on relaunch. Active tasks restore in a paused state. Stale kiro-cli processes from previous launches are detected and terminated on startup for clean recovery.

### Compaction and Clear Status
Status banners appear during context compaction (blue) and history clearing (orange). Triggered by `_kiro.dev/compaction/status` and `_kiro.dev/clear/status` notifications; visible while the operation is in progress.

### MCP OAuth Support
When an MCP server requires browser-based OAuth, an inline prompt appears with an "Open in Browser" button. OAuth URL provided by `_kiro.dev/mcp/oauth_request` notification.

### Onboarding Flow
First-launch wizard: auto-detects kiro-cli path, validates it exists and is executable, and helps create the first workspace.
