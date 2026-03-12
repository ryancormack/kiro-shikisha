#if os(macOS)
import SwiftUI

/// View showing list of files changed in the worktree via git diff
struct FilesChangedView: View {
    let workspacePath: URL

    @State private var fileDiffs: [GitFileDiff] = []
    @State private var selectedFileDiff: GitFileDiff?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading diff...")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Error loading diff")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") {
                        Task { await loadDiff() }
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if fileDiffs.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No changes detected")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Summary header
                HStack {
                    Text("\(fileDiffs.count) file\(fileDiffs.count == 1 ? "" : "s") changed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 8) {
                        let totalAdded = fileDiffs.reduce(0) { $0 + $1.linesAdded }
                        let totalRemoved = fileDiffs.reduce(0) { $0 + $1.linesRemoved }
                        if totalAdded > 0 {
                            Text("+\(totalAdded)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        if totalRemoved > 0 {
                            Text("-\(totalRemoved)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    Button {
                        Task { await loadDiff() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // File list and diff detail
                HSplitView {
                    List(fileDiffs, selection: Binding<UUID?>(
                        get: { selectedFileDiff?.id },
                        set: { newId in
                            selectedFileDiff = newId.flatMap { id in fileDiffs.first { $0.id == id } }
                        }
                    )) { fileDiff in
                        FileChangeRow(fileDiff: fileDiff, isSelected: selectedFileDiff?.id == fileDiff.id)
                            .tag(fileDiff.id)
                    }
                    .listStyle(.sidebar)
                    .frame(minWidth: 200)

                    if let selected = selectedFileDiff {
                        DiffView(fileDiff: selected)
                            .frame(minWidth: 300)
                    } else {
                        VStack {
                            Spacer()
                            Text("Select a file to view changes")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onAppear {
            Task { await loadDiff() }
        }
    }

    private func loadDiff() async {
        isLoading = true
        errorMessage = nil

        do {
            let gitService = GitService()
            let rawDiff = try await gitService.getWorktreeDiff(at: workspacePath)
            let untrackedFiles = try await gitService.getUntrackedFiles(at: workspacePath)

            var diffs = GitDiffParser.parse(rawDiff)

            for untrackedFile in untrackedFiles {
                do {
                    let content = try await gitService.getFileContent(filePath: untrackedFile, in: workspacePath)
                    let diff = GitDiffParser.createUntrackedFileDiff(path: untrackedFile, content: content)
                    diffs.append(diff)
                } catch {
                    // Skip files we cannot read
                }
            }

            fileDiffs = diffs
            // Clear selection if selected file no longer exists
            if let selected = selectedFileDiff, !diffs.contains(where: { $0.filePath == selected.filePath }) {
                selectedFileDiff = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    FilesChangedView(workspacePath: URL(fileURLWithPath: "/Users/test/Projects/test-project"))
        .frame(width: 600, height: 400)
}
#endif
