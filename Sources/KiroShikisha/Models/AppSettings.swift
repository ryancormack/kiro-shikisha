#if os(macOS)
import Foundation
import SwiftUI

/// Observable settings class for app configuration
/// Uses @AppStorage for automatic persistence to UserDefaults
@Observable
@MainActor
public final class AppSettings {
    // MARK: - General Settings
    
    /// Path to the kiro-cli executable
    @ObservationIgnored @AppStorage("kirocliPath")
    public var kirocliPath: String = "~/.local/bin/kiro-cli"
    
    /// Default directory for new workspaces
    @ObservationIgnored @AppStorage("defaultWorkspaceDirectory")
    public var defaultWorkspaceDirectory: String = "~"
    
    /// Whether to launch the app at system startup
    @ObservationIgnored @AppStorage("launchAtStartup")
    public var launchAtStartup: Bool = false
    
    /// Whether the user has completed the onboarding flow
    @ObservationIgnored @AppStorage("hasCompletedOnboarding")
    public var hasCompletedOnboarding: Bool = false
    
    // MARK: - Agent Settings
    
    /// Default agent configuration path (passed via --agent flag)
    @ObservationIgnored @AppStorage("defaultAgentConfig")
    public var defaultAgentConfig: String = ""
    
    /// Whether to automatically start agent when workspace is selected
    @ObservationIgnored @AppStorage("autoStartAgent")
    public var autoStartAgent: Bool = true
    
    // MARK: - Appearance Settings
    
    /// Application theme: "light", "dark", or "system"
    @ObservationIgnored @AppStorage("theme")
    public var theme: String = "system"
    
    /// Base font size for the application
    @ObservationIgnored @AppStorage("fontSize")
    public var fontSize: Double = 13.0
    
    /// Position of the code panel: "right" or "bottom"
    @ObservationIgnored @AppStorage("codePanelPosition")
    public var codePanelPosition: String = "right"
    
    // MARK: - Computed Properties
    
    /// Expands the kiro-cli path, resolving ~ to the user's home directory
    public var expandedKirocliPath: String {
        if kirocliPath.hasPrefix("~") {
            let homePath = FileManager.default.homeDirectoryForCurrentUser.path
            return kirocliPath.replacingOccurrences(of: "~", with: homePath, options: .anchored)
        }
        return kirocliPath
    }
    
    /// Expands the default workspace directory, resolving ~ to the user's home directory
    public var expandedDefaultWorkspaceDirectory: String {
        if defaultWorkspaceDirectory.hasPrefix("~") {
            let homePath = FileManager.default.homeDirectoryForCurrentUser.path
            return defaultWorkspaceDirectory.replacingOccurrences(of: "~", with: homePath, options: .anchored)
        }
        return defaultWorkspaceDirectory
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Validation
    
    /// Validates that the kiro-cli executable exists and is executable
    /// - Returns: true if the kiro-cli path is valid
    public func validateKirocliPath() -> Bool {
        let fileManager = FileManager.default
        let path = expandedKirocliPath
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        
        guard !isDirectory.boolValue else {
            return false
        }
        
        return fileManager.isExecutableFile(atPath: path)
    }
    
    /// Validates that the default workspace directory exists
    /// - Returns: true if the directory exists
    public func validateDefaultWorkspaceDirectory() -> Bool {
        let fileManager = FileManager.default
        let path = expandedDefaultWorkspaceDirectory
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        
        return isDirectory.boolValue
    }
    
    /// Returns the color scheme based on the theme setting
    public var colorScheme: ColorScheme? {
        switch theme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
}

#else

// Stub implementation for non-macOS platforms (Linux)
import Foundation

@MainActor
public final class AppSettings {
    public var kirocliPath: String = "~/.local/bin/kiro-cli"
    public var defaultWorkspaceDirectory: String = "~"
    public var launchAtStartup: Bool = false
    public var hasCompletedOnboarding: Bool = false
    public var defaultAgentConfig: String = ""
    public var autoStartAgent: Bool = true
    public var theme: String = "system"
    public var fontSize: Double = 13.0
    public var codePanelPosition: String = "right"
    
    public var expandedKirocliPath: String {
        if kirocliPath.hasPrefix("~") {
            let homePath = FileManager.default.homeDirectoryForCurrentUser.path
            return kirocliPath.replacingOccurrences(of: "~", with: homePath, options: .anchored)
        }
        return kirocliPath
    }
    
    public var expandedDefaultWorkspaceDirectory: String {
        if defaultWorkspaceDirectory.hasPrefix("~") {
            let homePath = FileManager.default.homeDirectoryForCurrentUser.path
            return defaultWorkspaceDirectory.replacingOccurrences(of: "~", with: homePath, options: .anchored)
        }
        return defaultWorkspaceDirectory
    }
    
    public init() {}
    
    public func validateKirocliPath() -> Bool {
        return false
    }
    
    public func validateDefaultWorkspaceDirectory() -> Bool {
        return false
    }
}

#endif
