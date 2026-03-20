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
    public var kirocliPath: String = UserDefaults.standard.string(forKey: "kirocliPath") ?? "~/.local/bin/kiro-cli" {
        didSet { UserDefaults.standard.set(kirocliPath, forKey: "kirocliPath") }
    }
    
    /// Default directory for new workspaces
    public var defaultWorkspaceDirectory: String = UserDefaults.standard.string(forKey: "defaultWorkspaceDirectory") ?? "~" {
        didSet { UserDefaults.standard.set(defaultWorkspaceDirectory, forKey: "defaultWorkspaceDirectory") }
    }
    
    /// Whether to launch the app at system startup
    public var launchAtStartup: Bool = UserDefaults.standard.bool(forKey: "launchAtStartup") {
        didSet { UserDefaults.standard.set(launchAtStartup, forKey: "launchAtStartup") }
    }
    
    /// Whether the user has completed the onboarding flow
    public var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    
    // MARK: - Agent Settings
    
    /// Default agent configuration path (passed via --agent flag)
    public var defaultAgentConfig: String = UserDefaults.standard.string(forKey: "defaultAgentConfig") ?? "" {
        didSet { UserDefaults.standard.set(defaultAgentConfig, forKey: "defaultAgentConfig") }
    }
    
    /// Whether to automatically start agent when workspace is selected
    public var autoStartAgent: Bool = {
        UserDefaults.standard.object(forKey: "autoStartAgent") != nil ? UserDefaults.standard.bool(forKey: "autoStartAgent") : true
    }() {
        didSet { UserDefaults.standard.set(autoStartAgent, forKey: "autoStartAgent") }
    }
    
    // MARK: - Appearance Settings
    
    /// Application theme: "light", "dark", or "system"
    public var theme: String = UserDefaults.standard.string(forKey: "theme") ?? "system" {
        didSet { UserDefaults.standard.set(theme, forKey: "theme") }
    }
    
    /// Base font size for the application
    public var fontSize: Double = {
        let val = UserDefaults.standard.double(forKey: "fontSize")
        return val > 0 ? val : 13.0
    }() {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    
    /// Position of the code panel: "right" or "bottom"
    public var codePanelPosition: String = UserDefaults.standard.string(forKey: "codePanelPosition") ?? "right" {
        didSet { UserDefaults.standard.set(codePanelPosition, forKey: "codePanelPosition") }
    }
    
    // MARK: - Agent Configuration Profiles
    
    /// Named agent configuration profiles
    public var agentConfigurations: [AgentConfiguration] = {
        guard let data = UserDefaults.standard.data(forKey: "agentConfigurations") else { return [] }
        return (try? JSONDecoder().decode([AgentConfiguration].self, from: data)) ?? []
    }() {
        didSet {
            if let data = try? JSONEncoder().encode(agentConfigurations) {
                UserDefaults.standard.set(data, forKey: "agentConfigurations")
            }
        }
    }
    
    /// The default agent configuration, or the first one if none is marked default
    public var defaultAgentConfiguration: AgentConfiguration? {
        return agentConfigurations.first(where: { $0.isDefault }) ?? agentConfigurations.first
    }
    
    /// Looks up an agent configuration by ID
    public func agentConfiguration(forId id: UUID) -> AgentConfiguration? {
        return agentConfigurations.first(where: { $0.id == id })
    }
    
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
    
    public var agentConfigurations: [AgentConfiguration] = []
    
    public var defaultAgentConfiguration: AgentConfiguration? {
        return agentConfigurations.first(where: { $0.isDefault }) ?? agentConfigurations.first
    }
    
    public func agentConfiguration(forId id: UUID) -> AgentConfiguration? {
        return agentConfigurations.first(where: { $0.id == id })
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
