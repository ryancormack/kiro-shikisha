# Tech Stack

## Language & Platform

- Swift 6.0+ with strict concurrency
- macOS 14 (Sonoma) minimum deployment target
- SwiftUI for all UI
- Swift Package Manager (SPM) for dependency management and builds

## Dependencies

| Package | Purpose |
|---------|---------|
| `aptove/swift-sdk` (ACPModel, ACP) | ACP protocol types and transport for communicating with kiro-cli |
| `apple/swift-collections` | Transitive dependency |
| `apple/swift-log` | Transitive dependency |

## Key Frameworks

- `Observation` framework (`@Observable`, `@MainActor`) for reactive state
- `AppKit` (NSApplication) for macOS-specific lifecycle
- `Foundation` for process management, file I/O, JSON encoding

## Build & Run Commands

```bash
# Build (debug)
swift build

# Build (release)
swift build -c release

# Run tests
swift test

# Run the app (debug build)
.build/debug/KiroKantoku

# Run the app (release build)
.build/release/KiroKantoku
```

## CI

- GitHub Actions on macOS 15 runner with Xcode 26.1
- Runs `swift test` on all pull requests
- Release workflow handles signing, notarization, DMG creation, and Homebrew cask update

## Platform Conditional Compilation

The codebase uses `#if os(macOS)` and `#if canImport(Observation)` guards extensively. The macOS path uses `@Observable` and SwiftUI. A minimal fallback exists for non-macOS platforms (Linux) that provides the same model types without Observation or UI.

## Bundle Info

- Bundle ID: `com.kiro.kantoku`
- Info.plist is embedded via linker flags (not Xcode project)
- Entitlements file: `KiroKantoku.entitlements`
