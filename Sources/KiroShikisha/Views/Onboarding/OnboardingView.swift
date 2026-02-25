#if os(macOS)
import SwiftUI

/// First-launch onboarding experience
public struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppStateManager.self) private var appStateManager
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var kirocliPath: String = "~/.local/bin/kiro-cli"
    @State private var isKirocliValid: Bool = false
    @State private var workspaceName: String = ""
    @State private var workspacePath: String = ""
    @State private var showFolderPicker: Bool = false
    @State private var isAutoDetecting: Bool = false
    
    /// Common kiro-cli installation paths to check
    private let commonPaths = [
        "~/.local/bin/kiro-cli",
        "/usr/local/bin/kiro-cli",
        "~/.kiro/bin/kiro-cli",
        "/opt/homebrew/bin/kiro-cli"
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Content
            VStack(spacing: 24) {
                switch currentStep {
                case .welcome:
                    welcomeStep
                case .configureCli:
                    configureCliStep
                case .createWorkspace:
                    createWorkspaceStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
            
            Divider()
            
            // Navigation buttons
            HStack {
                if currentStep != .welcome {
                    Button("Back") {
                        withAnimation {
                            currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .welcome
                        }
                    }
                }
                
                Spacer()
                
                if currentStep == .createWorkspace {
                    Button("Skip") {
                        completeOnboarding()
                    }
                }
                
                Button(currentStep == .createWorkspace ? "Get Started" : "Continue") {
                    handleContinue()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canContinue)
            }
            .padding(24)
        }
        .frame(width: 550, height: 450)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            autoDetectKiroCli()
        }
    }
    
    // MARK: - Step Views
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 72))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Text("Welcome to Kiro Shikisha")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("A powerful macOS client for interacting with AI coding agents through the Kiro CLI.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "terminal", text: "Connect to kiro-cli agents")
                featureRow(icon: "folder.badge.gearshape", text: "Manage multiple workspaces")
                featureRow(icon: "arrow.triangle.branch", text: "Work with git worktrees")
                featureRow(icon: "rectangle.split.3x1", text: "Monitor all agents from a dashboard")
            }
            .padding(.top, 8)
        }
    }
    
    private var configureCliStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("Configure kiro-cli")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Kiro Shikisha needs to know where kiro-cli is installed on your system.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("kiro-cli Path")
                    .font(.headline)
                
                HStack {
                    TextField("Path to kiro-cli", text: $kirocliPath)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: kirocliPath) { _, _ in
                            validateKirocliPath()
                        }
                    
                    if isAutoDetecting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: isKirocliValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isKirocliValid ? .green : .red)
                    }
                    
                    Button("Browse...") {
                        browseForKiroCli()
                    }
                }
                
                if !isKirocliValid && !kirocliPath.isEmpty {
                    Text("kiro-cli not found at this path. Make sure it's installed and executable.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button("Auto-Detect") {
                    autoDetectKiroCli()
                }
                .font(.caption)
                .padding(.top, 4)
            }
            .frame(maxWidth: 400)
        }
    }
    
    private var createWorkspaceStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("Create Your First Workspace")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("A workspace is a folder containing your project. You can add more workspaces later.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.headline)
                    TextField("Workspace name", text: $workspaceName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder")
                        .font(.headline)
                    HStack {
                        TextField("Select a folder", text: $workspacePath)
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)
                        
                        Button("Browse...") {
                            showFolderPicker = true
                        }
                    }
                }
            }
            .frame(maxWidth: 400)
            
            Text("You can skip this step and add workspaces later from the sidebar.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                workspacePath = url.path
                if workspaceName.isEmpty {
                    workspaceName = url.lastPathComponent
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            Text(text)
                .font(.body)
        }
    }
    
    // MARK: - Navigation Logic
    
    private var canContinue: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .configureCli:
            return isKirocliValid
        case .createWorkspace:
            // Can always continue from workspace step (either with or without workspace)
            return true
        }
    }
    
    private func handleContinue() {
        switch currentStep {
        case .welcome:
            withAnimation {
                currentStep = .configureCli
            }
        case .configureCli:
            // Save the kiro-cli path
            settings.kirocliPath = kirocliPath
            withAnimation {
                currentStep = .createWorkspace
            }
        case .createWorkspace:
            // Create workspace if provided
            if !workspaceName.isEmpty && !workspacePath.isEmpty {
                let workspace = Workspace(
                    name: workspaceName,
                    path: URL(fileURLWithPath: workspacePath)
                )
                appStateManager.addWorkspace(workspace)
            }
            completeOnboarding()
        }
    }
    
    private func completeOnboarding() {
        settings.hasCompletedOnboarding = true
    }
    
    // MARK: - kiro-cli Detection
    
    private func autoDetectKiroCli() {
        isAutoDetecting = true
        
        Task {
            // Check common paths
            for path in commonPaths {
                let expandedPath = expandPath(path)
                if FileManager.default.isExecutableFile(atPath: expandedPath) {
                    await MainActor.run {
                        kirocliPath = path
                        isKirocliValid = true
                        isAutoDetecting = false
                    }
                    return
                }
            }
            
            // Try which command
            if let whichPath = try? await runWhich() {
                await MainActor.run {
                    kirocliPath = whichPath
                    validateKirocliPath()
                    isAutoDetecting = false
                }
                return
            }
            
            await MainActor.run {
                validateKirocliPath()
                isAutoDetecting = false
            }
        }
    }
    
    private func runWhich() async throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["kiro-cli"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if process.terminationStatus == 0, let path = output, !path.isEmpty {
            return path
        }
        return nil
    }
    
    private func validateKirocliPath() {
        let expandedPath = expandPath(kirocliPath)
        isKirocliValid = FileManager.default.isExecutableFile(atPath: expandedPath)
    }
    
    private func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            let homePath = FileManager.default.homeDirectoryForCurrentUser.path
            return path.replacingOccurrences(of: "~", with: homePath, options: .anchored)
        }
        return path
    }
    
    private func browseForKiroCli() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        panel.message = "Select the kiro-cli executable"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK, let url = panel.url {
            kirocliPath = url.path
            validateKirocliPath()
        }
    }
}

/// Onboarding steps
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case configureCli = 1
    case createWorkspace = 2
}

#Preview {
    OnboardingView()
        .environment(AppSettings())
        .environment(AppStateManager())
}
#endif
