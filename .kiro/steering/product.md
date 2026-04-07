# Product Overview

Kiro Kantoku is a native macOS desktop app for managing multiple AI coding agents in parallel. It provides a visual interface to create tasks, assign them to AI agents powered by kiro-cli (via the ACP protocol), and monitor their progress from a single window.

## Core Concepts

- **Task-centric architecture**: Tasks are the first-class entity. Each task is tied to a project directory and goes through a lifecycle (pending → starting → working → paused → completed/failed/cancelled).
- **Multi-agent**: Multiple agents can run simultaneously across different projects. A dashboard provides a grid overview of all active tasks.
- **ACP protocol**: Communication with kiro-cli happens over the Agent Communication Protocol (ACP) via subprocess pipes. The app uses the `aptove/swift-sdk` package for ACP types and transport.
- **Git worktree support**: Tasks can optionally run in isolated git worktrees so agents don't interfere with the user's main working tree.

## Key Features

- Chat interface with markdown rendering, tool call display, slash commands, image attachments
- Permission control for agent tool calls (allow/reject once or always)
- Context usage monitoring with color-coded bar
- Agent thinking/reasoning display
- Execution plan view
- Code panel with git diffs, terminal output, and debug log
- Skills discovery from `.kiro/skills/` directories
- Session history and persistence
- Onboarding flow for first-time setup
- MCP OAuth support
