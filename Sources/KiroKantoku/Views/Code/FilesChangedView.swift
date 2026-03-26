#if os(macOS)
import SwiftUI

/// View showing list of files changed in the worktree via git diff.
/// Uses a stacked layout: horizontal file chip strip on top, full-width diff view below.
struct FilesChangedView: View {
    let workspacePath: URL
    let fileChangeCount: Int

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
                VStack(spacing: DesignConstants.spacingSM) {
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
                // Summary bar
                summaryBar

                Divider()

                // Horizontal file chip strip
                fileChipStrip

                Divider()

                // Full-width diff view
                if let selected = selectedFileDiff {
                    DiffView(fileDiff: selected)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: workspacePath.path) {
            await loadDiff()
        }
        .onChange(of: fileChangeCount) {
            Task { await loadDiff() }
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: DesignConstants.spacingSM) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(fileDiffs.count) file\(fileDiffs.count == 1 ? "" : "s") changed")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: DesignConstants.spacingSM) {
                let totalAdded = fileDiffs.reduce(0) { $0 + $1.linesAdded }
                let totalRemoved = fileDiffs.reduce(0) { $0 + $1.linesRemoved }
                if totalAdded > 0 {
                    Text("+\(totalAdded)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                if totalRemoved > 0 {
                    Text("-\(totalRemoved)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            }

            Button {
                Task { await loadDiff() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Refresh diff")
        }
        .padding(.horizontal, DesignConstants.spacingMD)
        .padding(.vertical, DesignConstants.spacingSM)
        .background(DesignConstants.cardBackground)
    }

    // MARK: - File Chip Strip

    private var fileChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignConstants.spacingSM) {
                ForEach(fileDiffs) { fileDiff in
                    fileChip(for: fileDiff)
                }
            }
            .padding(.horizontal, DesignConstants.spacingMD)
            .padding(.vertical, DesignConstants.spacingSM)
        }
        .background(DesignConstants.cardBackground.opacity(0.5))
    }

    private func fileChip(for fileDiff: GitFileDiff) -> some View {
        let isActive = selectedFileDiff?.id == fileDiff.id

        return Button(action: {
            selectedFileDiff = fileDiff
        }) {
            HStack(spacing: DesignConstants.spacingXS) {
                // Colored dot for change type
                Circle()
                    .fill(chipAccentColor(for: fileDiff))
                    .frame(width: 6, height: 6)

                // File icon
                Image(systemName: chipFileIcon(for: fileDiff))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // File name
                Text(fileDiff.fileName)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)

                // Change badge
                Image(systemName: chipChangeIcon(for: fileDiff))
                    .font(.system(size: 8))
                    .foregroundColor(chipAccentColor(for: fileDiff))

                // Mini +/- counts
                if fileDiff.linesAdded > 0 {
                    Text("+\(fileDiff.linesAdded)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.green)
                }
                if fileDiff.linesRemoved > 0 {
                    Text("-\(fileDiff.linesRemoved)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, DesignConstants.spacingSM)
            .padding(.vertical, DesignConstants.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.chipCornerRadius)
                    .fill(isActive
                          ? Color.accentColor.opacity(0.15)
                          : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.chipCornerRadius)
                    .stroke(isActive
                            ? Color.accentColor.opacity(0.4)
                            : Color(nsColor: .separatorColor).opacity(0.5),
                            lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chip Helpers

    private func chipAccentColor(for fileDiff: GitFileDiff) -> Color {
        switch fileDiff.changeType {
        case .created: return .green
        case .modified: return .yellow
        case .deleted: return .red
        }
    }

    private func chipChangeIcon(for fileDiff: GitFileDiff) -> String {
        switch fileDiff.changeType {
        case .created: return "plus.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .deleted: return "minus.circle.fill"
        }
    }

    private func chipFileIcon(for fileDiff: GitFileDiff) -> String {
        let ext = (fileDiff.filePath as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "doc.text"
        case "json": return "curlybraces"
        case "md", "markdown": return "doc.richtext"
        default: return "doc"
        }
    }

    // MARK: - Data Loading

    private func loadDiff() async {
        fileDiffs = []
        selectedFileDiff = nil
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

            // Auto-select the first file
            if !diffs.isEmpty {
                selectedFileDiff = diffs.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
#endif
