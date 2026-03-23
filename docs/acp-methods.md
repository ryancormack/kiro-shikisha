# ACP Methods and Kiro Extensions

Comprehensive reference for all ACP (Agent Communication Protocol) methods and Kiro vendor extension notifications supported by Kiro Kantoku.

## Table of Contents

- [Overview](#overview)
- [Standard ACP Methods](#standard-acp-methods)
  - [session/new](#sessionnew)
  - [session/load](#sessionload)
  - [session/prompt](#sessionprompt)
  - [session/cancel](#sessioncancel)
  - [session/setMode](#sessionsetmode)
  - [session/setModel](#sessionsetmodel)
  - [session/setConfigOption](#sessionsetconfigoption)
- [Session Updates (Server to Client)](#session-updates-server-to-client)
  - [agentMessageChunk](#agentmessagechunk)
  - [toolCall](#toolcall)
  - [toolCallUpdate](#toolcallupdate)
  - [agentThoughtChunk](#agentthoughtchunk)
  - [userMessageChunk](#usermessagechunk)
  - [planUpdate](#planupdate)
  - [availableCommandsUpdate](#availablecommandsupdate)
  - [currentModeUpdate](#currentmodeupdate)
  - [configOptionUpdate](#configoptionupdate)
  - [sessionInfoUpdate](#sessioninfoupdate)
- [Client Capabilities](#client-capabilities)
  - [File System](#file-system)
  - [Terminal](#terminal)
  - [Permissions](#permissions)
  - [Client Info](#client-info)
- [Kiro Vendor Extension Notifications](#kiro-vendor-extension-notifications)
  - [_kiro.dev/commands/available](#kirodevcommandsavailable)
  - [_kiro.dev/commands/options](#kirodevcommandsoptions)
  - [_kiro.dev/commands/execute](#kirodevcommandsexecute)
  - [_kiro.dev/metadata](#kirodevmetadata)
  - [_kiro.dev/agent/switched](#kirodevagentswitched)
  - [_kiro.dev/session/update](#kirodevsessionupdate)
  - [_kiro.dev/compaction/status](#kirodevcompactionstatus)
  - [_kiro.dev/clear/status](#kirodevclearstatus)
  - [_kiro.dev/mcp/oauth_request](#kirodevmcpoauth_request)
  - [_kiro.dev/mcp/server_init_failure](#kirodevmcpserver_init_failure)

---

## Overview

Kiro Kantoku communicates with [kiro-cli](https://github.com/aptove/swift-sdk) using the Agent Communication Protocol (ACP). It spawns a `kiro-cli acp` subprocess and exchanges JSON-RPC messages over stdin/stdout pipes.

The communication stack consists of:

1. **ProcessTransport** -- Custom transport layer that manages the subprocess pipes and routes messages. Defined in `ACPConnection.swift`.
2. **KiroClient** -- ACP `Client` implementation that provides file system, terminal, and permission capabilities. Defined in `KiroClient.swift`.
3. **ClientConnection** -- From the [aptove/swift-sdk](https://github.com/aptove/swift-sdk), this handles JSON-RPC framing, initialization handshake, and method routing.
4. **ACPConnection** -- Actor that orchestrates the subprocess lifecycle, creates the transport and client, and exposes high-level methods for session management. Defined in `ACPConnection.swift`.

Kiro vendor extension notifications (`_kiro.dev/*`) are intercepted by `ProcessTransport` before reaching the SDK's `ClientConnection` and routed to `AgentManager.handleKiroNotification()`.

---

## Standard ACP Methods

These methods are part of the standard ACP protocol and are called by Kantoku (client to server).

### session/new

Creates a new ACP session.

| Property | Value |
|---|---|
| **Direction** | Client to Server |
| **SDK Method** | `ClientConnection.createSession(request:)` |
| **Kantoku Caller** | `ACPConnection.createSession(cwd:)` |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `cwd` | `String` | Working directory for the session |
| `mcpServers` | `[McpServer]` | MCP server configurations (sent as empty array) |

**Response (`NewSessionResponse`):**

| Field | Type | Description |
|---|---|---|
| `sessionId` | `SessionId` | Unique identifier for the new session |
| `configOptions` | `[SessionConfigOption]` | Available configuration options |
| `modes` | `[SessionMode]` | Available agent modes |
| `models` | `[ModelInfo]` | Available AI models |

**Kantoku behavior:** After receiving the response, Kantoku populates the agent's `configOptions`, `availableModes`, `currentModeId`, `availableModels`, and `currentModelId` from the response data.

---

### session/load

Loads an existing session by ID for resumption.

| Property | Value |
|---|---|
| **Direction** | Client to Server |
| **SDK Method** | `ClientConnection.loadSession(request:)` |
| **Kantoku Caller** | `ACPConnection.loadSession(sessionId:cwd:)` |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `sessionId` | `SessionId` | Session ID to load |
| `cwd` | `String` | Working directory for the session |
| `mcpServers` | `[McpServer]` | MCP server configurations (sent as empty array) |

**Response (`LoadSessionResponse`):**

| Field | Type | Description |
|---|---|---|
| `configOptions` | `[SessionConfigOption]` | Available configuration options |
| `modes` | `[SessionMode]` | Available agent modes |
| `models` | `[ModelInfo]` | Available AI models |

**Kantoku behavior:** Used when resuming paused tasks or reconnecting to a previous session. Before calling `session/load`, Kantoku proactively removes any stale lock file for the session. If a `SESSION_LOCKED` error is returned, Kantoku removes the lock file and retries. If the retry also fails, it falls back to starting a fresh session with `session/new`. During session loading, `agent.isReplayingSession` is set to `true` so that replayed message chunks are discarded.

---

### session/prompt

Sends a user prompt to the agent for processing.

| Property | Value |
|---|---|
| **Direction** | Client to Server |
| **SDK Method** | `ClientConnection.prompt(request:)` |
| **Kantoku Caller** | `ACPConnection.prompt(sessionId:prompt:)` |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `sessionId` | `SessionId` | Session to send the prompt to |
| `prompt` | `[ContentBlock]` | Array of content blocks (text and/or image) |

Content blocks can be:
- **Text**: `ContentBlock.text(TextContent(text: "..."))` for text prompts
- **Image**: `ContentBlock.image(ImageContent(data: "<base64>", mimeType: "image/png"))` for image attachments

**Response (`PromptResponse`):**

| Field | Type | Description |
|---|---|---|
| `stopReason` | `StopReason` | Why the agent stopped: `endTurn`, `maxTokens`, `maxTurnRequests`, `cancelled`, or `refusal` |

**Kantoku behavior:** Before sending, Kantoku appends a user chat message and marks the agent as `.active`. The actual agent output streams back via [session updates](#session-updates-server-to-client) during processing. After the response completes, Kantoku clears `activeToolCalls` and `thoughtContent`, then updates the agent status based on the stop reason: `.idle` for `endTurn`, `maxTokens`, `maxTurnRequests`, or `cancelled`; `.error` for `refusal`.

---

### session/cancel

Cancels the currently running agent action.

| Property | Value |
|---|---|
| **Direction** | Client to Server (notification, no response) |
| **Transport** | Sent directly via `ProcessTransport.send()` as a JSON-RPC notification |
| **Kantoku Caller** | `ACPConnection.cancelSession(sessionId:)` |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `sessionId` | `SessionId` | Session to cancel |

**Kantoku behavior:** Sent as a JSON-RPC notification (not a request), so no response is expected. Manually constructs a `JsonRpcNotification` with method `"session/cancel"` and sends it through the transport, bypassing the SDK's `ClientConnection`. Triggered by the **Cmd+.** keyboard shortcut.

---

### session/setMode

Switches the agent mode for a session.

| Property | Value |
|---|---|
| **Direction** | Client to Server |
| **SDK Method** | `ClientConnection.setSessionMode(request:)` |
| **Kantoku Caller** | `ACPConnection.setSessionMode(sessionId:modeId:)` |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `sessionId` | `SessionId` | Target session |
| `modeId` | `SessionModeId` | ID of the mode to activate (e.g. "default", "planner") |

**Kantoku behavior:** Called from the mode picker in the `ConfigSelectorBar` UI. Updates `agent.currentModeId` after success.

---

### session/setModel

Switches the AI model for a session.

| Property | Value |
|---|---|
| **Direction** | Client to Server |
| **SDK Method** | `ClientConnection.setSessionModel(request:)` |
| **Kantoku Caller** | `ACPConnection.setSessionModel(sessionId:modelId:)` |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `sessionId` | `SessionId` | Target session |
| `modelId` | `ModelId` | ID of the model to use |

**Kantoku behavior:** Called from the model picker in the `ConfigSelectorBar` UI. Updates `agent.currentModelId` after success.

---

### session/setConfigOption

Sets a session configuration option.

| Property | Value |
|---|---|
| **Direction** | Client to Server |
| **SDK Method** | `ClientConnection.setSessionConfigOption(request:)` |
| **Kantoku Caller** | `ACPConnection.setSessionConfigOption(sessionId:configId:value:)` |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `sessionId` | `SessionId` | Target session |
| `configId` | `SessionConfigId` | Configuration option identifier |
| `value` | `SessionConfigValueId` | New value for the option |

**Kantoku behavior:** Used for toggling session-level settings like autonomous mode. The available options are provided by the server during session creation and updated via `configOptionUpdate` session updates.

---

## Session Updates (Server to Client)

Session updates are delivered from the server to Kantoku via the ACP SDK's `Client.onSessionUpdate()` callback. They are handled in `AgentManager.handleSessionUpdate()`.

### agentMessageChunk

Streaming text from the agent.

| Field | Type | Description |
|---|---|---|
| `content` | `ContentBlock` | A text content block containing the chunk |

**Kantoku behavior:** Accumulates text chunks into `ChatMessage` entries in the agent's message history. If the last message is from the assistant, the chunk is appended; otherwise a new assistant message is created. Chunks received during session replay (`agent.isReplayingSession == true`) are discarded to prevent duplication. Also scans for skill activation patterns (e.g. `[skill: <name> activated]`).

### toolCall

A new tool call has been initiated by the agent.

| Field | Type | Description |
|---|---|---|
| `toolCallId` | `ToolCallId` | Unique identifier for the tool call |
| `title` | `String` | Human-readable title |
| `kind` | `String?` | Type of tool call |
| `status` | `ToolCallStatus?` | Current status |
| `content` | `[ContentBlock]?` | Tool call content |
| `locations` | `[Location]?` | File locations involved |
| `rawInput` | `String?` | Raw input to the tool |
| `rawOutput` | `String?` | Raw output from the tool |

**Kantoku behavior:** Creates an entry in `agent.activeToolCalls` and `agent.toolCallHistory`. Inserts a system chat message as a marker for the tool call. Emits an activity event for the dashboard.

### toolCallUpdate

Status or content update for an existing tool call.

| Field | Type | Description |
|---|---|---|
| `toolCallId` | `ToolCallId` | ID of the tool call to update |
| `title` | `String?` | Updated title (merged if present) |
| `kind` | `String?` | Updated kind |
| `status` | `ToolCallStatus?` | Updated status |
| `content` | `[ContentBlock]?` | Updated content |
| `locations` | `[Location]?` | Updated locations |
| `rawInput` | `String?` | Updated raw input |
| `rawOutput` | `String?` | Updated raw output |

**Kantoku behavior:** Merges updated fields into the existing tool call entry (non-nil fields overwrite). Extracts file changes from diff content blocks and rawInput to populate the code panel's "Files Changed" tab.

### agentThoughtChunk

Agent's internal reasoning, streamed in chunks.

| Field | Type | Description |
|---|---|---|
| `content` | `ContentBlock` | A text content block with the thought text |

**Kantoku behavior:** Appends the thought text to `agent.thoughtContent`, which is displayed in the `ThoughtBubbleView`. Skipped during session replay (`agent.isReplayingSession == true`).

### userMessageChunk

Echo of a user message sent to the server.

**Kantoku behavior:** Logged to the debug panel but not displayed in the chat UI.

### planUpdate

Execution plan with step entries.

| Field | Type | Description |
|---|---|---|
| `entries` | `[PlanEntry]` | Array of plan entries with content, priority, and status |

**Kantoku behavior:** Stored in `agent.currentPlan`. Displayed in the `PlanView` component.

### availableCommandsUpdate

Updated list of available slash commands.

| Field | Type | Description |
|---|---|---|
| `availableCommands` | `[AvailableCommand]` | Array of commands with name, description, and input type |

**Kantoku behavior:** Stored in `agent.availableCommands`. These are standard ACP commands and are merged with Kiro extension commands (from `_kiro.dev/commands/available`) to build the unified slash command autocomplete list.

### currentModeUpdate

The current agent mode has changed.

| Field | Type | Description |
|---|---|---|
| `currentModeId` | `SessionModeId` | The new active mode ID |

**Kantoku behavior:** Updates `agent.currentModeId`, which is reflected in the mode picker UI.

### configOptionUpdate

Configuration options have been updated by the server.

| Field | Type | Description |
|---|---|---|
| `configOptions` | `[SessionConfigOption]` | Updated list of configuration options |

**Kantoku behavior:** Replaces `agent.configOptions` with the new list.

### sessionInfoUpdate

Session metadata update.

| Field | Type | Description |
|---|---|---|
| `title` | `String?` | Server-generated session title |

**Kantoku behavior:** Updates `agent.sessionTitle` if a title is provided.

---

## Client Capabilities

KiroClient reports these capabilities to the server during the ACP initialization handshake. Defined in `KiroClient.swift`.

### File System

| Capability | Value | Description |
|---|---|---|
| `fs.readTextFile` | `true` | Reads text files from disk. Supports optional `line` (1-indexed start line) and `limit` (number of lines) parameters for partial reads. |
| `fs.writeTextFile` | `true` | Writes text files to disk. Automatically creates intermediate directories as needed. |

### Terminal

| Capability | Value | Description |
|---|---|---|
| `terminal` | `true` | Creates subprocesses via `/usr/bin/env`. Supports `command`, `args`, `cwd`, `env`, and `outputByteLimit`. Provides `output`, `kill`, `waitForExit`, and `release` operations on created terminals. |

### Permissions

KiroClient implements `requestPermissions()` to present a permission request UI to the user when the agent needs approval for a tool call. The UI shows the tool call details along with the available permission options (e.g. allow once, allow always, reject once, reject always). The selected outcome is returned to the server. If no UI handler is registered, it falls back to auto-approving with `allowOnce`.

### Client Info

| Field | Value |
|---|---|
| `name` | `KiroKantoku` |
| `version` | `1.0.0` |

---

## Kiro Vendor Extension Notifications

These are `_kiro.dev/*` JSON-RPC notifications and requests used by kiro-cli that extend the standard ACP protocol. Notifications from the server are intercepted by `ProcessTransport` (which checks for the `_kiro.dev/` prefix) and routed to `AgentManager.handleKiroNotification()`. Requests from Kantoku to the server use the pending response handler mechanism on `ProcessTransport`.

### _kiro.dev/commands/available

Updates the list of available Kiro-specific slash commands.

| Property | Value |
|---|---|
| **Direction** | Server to Client (notification) |
| **Handler** | `AgentManager.handleKiroNotification()` |
| **Model** | `KiroCommandsAvailableParams` |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `sessionId` | `String` | Session ID |
| `commands` | `[KiroAvailableCommand]` | Array of available commands |

Each `KiroAvailableCommand` has:

| Field | Type | Description |
|---|---|---|
| `name` | `String` | Command name (may include leading `/`) |
| `description` | `String` | Human-readable description |
| `meta` | `JsonValue?` | Optional metadata object |

The `meta` object can contain:

| Field | Type | Description |
|---|---|---|
| `inputType` | `String` | `"selection"` for option-picker commands, `"panel"` for panel commands |
| `optionsMethod` | `String` | Method name for fetching options (selection-type commands only) |
| `local` | `Bool` | If `true`, command is handled client-side |

**Kantoku behavior:** Stores the commands in `agent.kiroAvailableCommands`. These are merged with standard ACP commands via `mergeSlashCommands()` to build the unified autocomplete list in `ChatInputView`. Only commands in the supported set (`compact`, `context`, `help`, `tools`, `usage`) are shown in the GUI autocomplete picker.

---

### _kiro.dev/commands/options

Requests available options for a selection-type slash command.

| Property | Value |
|---|---|
| **Direction** | Client to Server (request/response) |
| **Caller** | `ACPConnection.requestCommandOptions(sessionId:command:partial:)` |

**Request Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `command` | `String` | Command name (without leading `/`) |
| `sessionId` | `String` | Session ID |
| `partial` | `String` | Partial input for filtering (default: empty string) |

**Response (`CommandOptionsResponse`):**

| Field | Type | Description |
|---|---|---|
| `options` | `[CommandOption]` | Array of option objects |
| `hasMore` | `Bool` | Whether more options are available |

Each `CommandOption` has:

| Field | Type | Description |
|---|---|---|
| `value` | `String` | Option value to submit |
| `label` | `String` | Display label |
| `description` | `String?` | Optional description text |
| `group` | `String?` | Optional group name for categorization |

**Kantoku behavior:** Sent as a JSON-RPC request with a randomly generated integer ID. A pending response handler is registered on the transport before sending, so the response is consumed directly rather than being forwarded to the SDK. Uses a 30-second timeout. Results are displayed in the command options picker in `ChatInputView`.

---

### _kiro.dev/commands/execute

Executes a slash command on the server.

| Property | Value |
|---|---|
| **Direction** | Client to Server (request/response) |
| **Caller** | `ACPConnection.executeSlashCommand(sessionId:commandName:args:)` |

**Request Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `sessionId` | `String` | Session ID |
| `command` | `Object` | Command object containing `command` (name) and `args` (key-value pairs) |

The `command` parameter is structured as:
```json
{
  "command": "<name>",
  "args": { "<key>": "<value>", ... }
}
```

**Response:**

The response is an acknowledgment. The actual command output arrives through normal session updates (agent message chunks).

**Kantoku behavior:** Sent as a JSON-RPC request with a randomly generated integer ID. Uses the same pending response handler pattern as `_kiro.dev/commands/options` with a 30-second timeout. Leading `/` is stripped from the command name before sending. The response string is extracted from the result by checking for `message`, `text`, or `content` fields, or falling back to JSON serialization.

---

### _kiro.dev/metadata

Provides session metadata, including context window usage.

| Property | Value |
|---|---|
| **Direction** | Server to Client (notification) |
| **Handler** | `AgentManager.handleKiroNotification()` |
| **Model** | `KiroMetadataParams` |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `sessionId` | `String` | Session ID |
| `contextUsagePercentage` | `Double` | Context window usage from 0.0 to 100.0 |

**Kantoku behavior:** Updates `agent.contextUsagePercentage`. Displayed as a color-coded bar in the chat panel (`ContextUsageBar`): green for low usage, yellow for moderate, red for high.

---

### _kiro.dev/agent/switched

Notifies that the active agent has changed (e.g. switching from a default agent to a planner).

| Property | Value |
|---|---|
| **Direction** | Server to Client (notification) |
| **Handler** | `AgentManager.handleKiroNotification()` |
| **Model** | `KiroAgentSwitchedParams` |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `sessionId` | `String` | Session ID |
| `agentName` | `String` | Name of the new active agent |
| `previousAgentName` | `String` | Name of the previous agent |
| `welcomeMessage` | `String?` | Optional welcome message from the new agent |

**Kantoku behavior:** Updates `agent.name` to the new agent name. Appends a system message to chat: "Agent switched from {previous} to {new}". If a welcome message is provided, it is appended as a separate system message.

---

### _kiro.dev/session/update

Multiplexed notification carrying different types of session updates. The `sessionUpdate` field determines the update type.

| Property | Value |
|---|---|
| **Direction** | Server to Client (notification) |
| **Handler** | `AgentManager.handleKiroNotification()` |

#### Type: `tool_call_chunk`

**Model:** `KiroToolCallChunkUpdate`

| Parameter | Type | Description |
|---|---|---|
| `sessionUpdate` | `String` | Always `"tool_call_chunk"` |
| `toolCallId` | `String` | Tool call ID |
| `title` | `String` | Title of the tool call |
| `kind` | `String` | Kind of tool call |

**Kantoku behavior:** Logged for debugging purposes. Not currently surfaced in the UI beyond the debug log.

#### Type: `plan`

**Model:** `KiroPlanUpdate`

| Parameter | Type | Description |
|---|---|---|
| `sessionUpdate` | `String` | Always `"plan"` |
| `title` | `String?` | Optional plan title |
| `steps` | `[KiroPlanStep]` | Array of plan steps |

Each `KiroPlanStep` has:

| Field | Type | Description |
|---|---|---|
| `description` | `String` | Step description |
| `status` | `String` | One of: `"pending"`, `"in_progress"`, `"completed"` |

**Kantoku behavior:** Converts steps to `PlanEntry` objects with mapped status values (`"completed"` -> `.completed`, `"in_progress"` -> `.inProgress`, default -> `.pending`). Stores the result in `agent.currentPlan`, which is displayed in `PlanView`.

#### Type: `agent_thought_chunk`

**Model:** `KiroAgentThoughtChunkUpdate`

| Parameter | Type | Description |
|---|---|---|
| `sessionUpdate` | `String` | Always `"agent_thought_chunk"` |
| `content` | `KiroThoughtContent` | Thought content object |

`KiroThoughtContent` has:

| Field | Type | Description |
|---|---|---|
| `type` | `String` | Content type |
| `text` | `String` | The thought text |

**Kantoku behavior:** Appends `content.text` to `agent.thoughtContent`, displayed in `ThoughtBubbleView`. Skipped during session replay (`agent.isReplayingSession == true`) to avoid duplication.

---

### _kiro.dev/compaction/status

Notifies that a context compaction operation is in progress.

| Property | Value |
|---|---|
| **Direction** | Server to Client (notification) |
| **Handler** | `AgentManager.handleKiroNotification()` |
| **Model** | `KiroCompactionStatusParams` |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `message` | `String` | Status message describing the compaction operation |

**Kantoku behavior:** Sets `agent.isCompacting = true` and stores the message in `agent.compactionMessage`. Displayed as a blue status banner in the chat panel via `StatusBannerView`.

---

### _kiro.dev/clear/status

Notifies that a history clearing operation is in progress.

| Property | Value |
|---|---|
| **Direction** | Server to Client (notification) |
| **Handler** | `AgentManager.handleKiroNotification()` |
| **Model** | `KiroClearStatusParams` |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `message` | `String` | Status message describing the clear operation |

**Kantoku behavior:** Sets `agent.isClearingHistory = true` and stores the message in `agent.clearStatusMessage`. Displayed as an orange status banner in the chat panel via `StatusBannerView`.

---

### _kiro.dev/mcp/oauth_request

Presents an OAuth authentication prompt for an MCP server.

| Property | Value |
|---|---|
| **Direction** | Server to Client (notification) |
| **Handler** | `AgentManager.handleKiroNotification()` |
| **Model** | `KiroMcpOAuthRequestParams` |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `url` | `String` | OAuth URL that needs to be opened in a browser |

**Kantoku behavior:** Sets `agent.pendingOAuthURL` to the provided URL. Displayed as an inline "Open in Browser" prompt via `OAuthRequestView`.

---

### _kiro.dev/mcp/server_init_failure

Notifies that an MCP server failed to initialize.

| Property | Value |
|---|---|
| **Direction** | Server to Client (notification) |
| **Handler** | Falls through to the `default` case in `handleKiroNotification()` |
| **Model** | `KiroMcpServerInitFailureParams` (defined but not explicitly handled) |

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `sessionId` | `String` | Session ID |
| `serverName` | `String` | Name of the MCP server that failed |
| `error` | `String` | Error message |

**Kantoku behavior:** The model `KiroMcpServerInitFailureParams` is defined in `KiroExtensions.swift`, but this notification is not explicitly handled in `handleKiroNotification()`. It falls through to the `default` case, which logs it as an "Unknown Kiro notification" in the debug panel. Not currently surfaced in the UI.
