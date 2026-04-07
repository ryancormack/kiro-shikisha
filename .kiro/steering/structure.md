# Project Structure

```
Sources/KiroKantoku/
├── App/                    # App entry point (@main), lifecycle, keyboard commands
├── Models/                 # Data models and enums
│   ├── Agent.swift         # AI agent state (@Observable, @MainActor)
│   ├── AgentTask.swift     # Task entity (the primary unit of work)
│   ├── Workspace.swift     # Project directory reference
│   ├── ChatMessage.swift   # Chat message model
│   ├── TaskStatus.swift    # Task lifecycle enum
│   ├── FileChange.swift    # Git file change tracking
│   ├── GitDiff.swift       # Diff parsing
│   └── ...                 # Other domain models
├── Services/               # Business logic and external communication
│   ├── ACPConnection.swift # ACP protocol transport (subprocess pipes to kiro-cli)
│   ├── AgentManager.swift  # Agent lifecycle, prompt sending, session management
│   ├── TaskManager.swift   # Task CRUD, state transitions, persistence
│   ├── AppStateManager.swift # Global app state (selection, persistence)
│   ├── GitService.swift    # Git repo detection, worktree operations
│   ├── SessionStorage.swift # Session file persistence
│   └── ...                 # Other services
├── Views/
│   ├── Agent/              # Chat panel, message rendering, input, permissions
│   ├── Code/               # Diff viewer, terminal output, debug log
│   ├── Dashboard/          # Multi-task overview grid
│   ├── Task/               # Task detail view, new task sheet
│   ├── Sidebar/            # Navigation sidebar
│   ├── Session/            # Session history browser
│   ├── Settings/           # General, Agents, Appearance settings
│   ├── Workspace/          # Workspace management
│   ├── Components/         # Shared UI (DesignConstants, badges, error banners)
│   ├── Onboarding/         # First-launch setup wizard
│   ├── PixelOffice/        # Pixel art office view (easter egg / fun feature)
│   └── MainView.swift      # Root view with NavigationSplitView
├── Resources/              # Bundled assets (images)
└── Info.plist              # App bundle metadata

Tests/KiroKantokuTests/     # Unit tests (swift test)

.github/workflows/          # CI (ci.yml) and release (release.yml) workflows
Casks/                      # Homebrew cask formula
```

## Architecture Patterns

- **MVVM-ish with Observation**: Models use `@Observable` and `@MainActor`. Views read state directly from observable models injected via SwiftUI `.environment()`. No separate ViewModel layer — services act as the logic layer.
- **Service injection**: `AgentManager`, `TaskManager`, `AppStateManager`, and `AppSettings` are created in the App struct and passed down via `.environment()`.
- **Concurrency**: Swift structured concurrency (`async/await`, `Task {}`) throughout. `@MainActor` on all models and services that touch UI state.
- **Platform guards**: `#if os(macOS)` wraps all SwiftUI/AppKit code. Models provide a non-Observable fallback for Linux compilation.

## Conventions

- Models are `public final class` with `@Observable @MainActor` (macOS) or plain class (Linux fallback)
- Services are `@Observable @MainActor public final class`
- Views are `public struct` conforming to `View`, wrapped in `#if os(macOS)`
- UI constants live in `DesignConstants` — use these instead of magic numbers
- Doc comments (`///`) on all public types and methods
- Errors are enums conforming to `Error, Sendable, LocalizedError`
