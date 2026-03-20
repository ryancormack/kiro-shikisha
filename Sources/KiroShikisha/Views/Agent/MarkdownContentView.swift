#if os(macOS)
import SwiftUI

/// A SwiftUI view that parses a markdown string and renders it as distinct styled blocks
public struct MarkdownContentView: View {
    let content: String

    public init(content: String) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Types

    private enum MarkdownBlock {
        case heading(level: Int, text: String)
        case codeBlock(language: String?, code: String)
        case unorderedListItem(text: String)
        case orderedListItem(number: Int, text: String)
        case blockquote(text: String)
        case paragraph(text: String)
    }

    // MARK: - Parsing

    private func parseBlocks() -> [MarkdownBlock] {
        guard !content.isEmpty else { return [] }

        let lines = content.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]

            // Fenced code block
            if line.hasPrefix("```") {
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                index += 1
                while index < lines.count && !lines[index].hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                // Skip closing ```
                if index < lines.count {
                    index += 1
                }
                let lang = language.isEmpty ? nil : language
                blocks.append(.codeBlock(language: lang, code: codeLines.joined(separator: "\n")))
                continue
            }

            // Heading
            if let headingMatch = parseHeading(line) {
                blocks.append(headingMatch)
                index += 1
                continue
            }

            // Unordered list item
            if let listItem = parseUnorderedListItem(line) {
                blocks.append(listItem)
                index += 1
                continue
            }

            // Ordered list item
            if let listItem = parseOrderedListItem(line) {
                blocks.append(listItem)
                index += 1
                continue
            }

            // Blockquote
            if line.hasPrefix("> ") || line == ">" {
                let text = line.hasPrefix("> ") ? String(line.dropFirst(2)) : ""
                blocks.append(.blockquote(text: text))
                index += 1
                continue
            }

            // Empty line - skip
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            // Paragraph - accumulate consecutive non-empty lines
            var paragraphLines: [String] = []
            while index < lines.count {
                let pLine = lines[index]
                if pLine.trimmingCharacters(in: .whitespaces).isEmpty
                    || pLine.hasPrefix("```")
                    || parseHeading(pLine) != nil
                    || parseUnorderedListItem(pLine) != nil
                    || parseOrderedListItem(pLine) != nil
                    || pLine.hasPrefix("> ") || pLine == ">"
                {
                    break
                }
                paragraphLines.append(pLine)
                index += 1
            }
            if !paragraphLines.isEmpty {
                blocks.append(.paragraph(text: paragraphLines.joined(separator: "\n")))
            }
        }

        return blocks
    }

    private func parseHeading(_ line: String) -> MarkdownBlock? {
        if line.hasPrefix("#### ") {
            return .heading(level: 4, text: String(line.dropFirst(5)))
        } else if line.hasPrefix("### ") {
            return .heading(level: 3, text: String(line.dropFirst(4)))
        } else if line.hasPrefix("## ") {
            return .heading(level: 2, text: String(line.dropFirst(3)))
        } else if line.hasPrefix("# ") {
            return .heading(level: 1, text: String(line.dropFirst(2)))
        }
        return nil
    }

    private func parseUnorderedListItem(_ line: String) -> MarkdownBlock? {
        let trimmed = line
        if trimmed.hasPrefix("- ") {
            return .unorderedListItem(text: String(trimmed.dropFirst(2)))
        } else if trimmed.hasPrefix("* ") {
            return .unorderedListItem(text: String(trimmed.dropFirst(2)))
        }
        return nil
    }

    private func parseOrderedListItem(_ line: String) -> MarkdownBlock? {
        let trimmed = line
        // Match lines like "1. ", "2. ", "10. "
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let prefix = trimmed[trimmed.startIndex..<dotIndex]
        guard let number = Int(prefix), number > 0 else { return nil }
        let afterDot = trimmed.index(after: dotIndex)
        guard afterDot < trimmed.endIndex, trimmed[afterDot] == " " else { return nil }
        let text = String(trimmed[trimmed.index(after: afterDot)...])
        return .orderedListItem(number: number, text: text)
    }

    // MARK: - Rendering

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            renderHeading(level: level, text: text)
        case .codeBlock(let language, let code):
            renderCodeBlock(language: language, code: code)
        case .unorderedListItem(let text):
            renderUnorderedListItem(text: text)
        case .orderedListItem(let number, let text):
            renderOrderedListItem(number: number, text: text)
        case .blockquote(let text):
            renderBlockquote(text: text)
        case .paragraph(let text):
            renderParagraph(text: text)
        }
    }

    private func renderHeading(level: Int, text: String) -> some View {
        let font: Font = switch level {
        case 1: .title
        case 2: .title2
        case 3: .title3
        default: .headline
        }
        return Text(text)
            .font(font)
            .fontWeight(.bold)
    }

    private func renderCodeBlock(language: String?, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language = language {
                Text(language.lowercased() == "mermaid" ? "Mermaid Diagram" : language)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DesignConstants.spacingSM)
                    .padding(.vertical, DesignConstants.spacingXS)
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: DesignConstants.codeFontSize, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(DesignConstants.spacingSM)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private func renderUnorderedListItem(text: String) -> some View {
        HStack(alignment: .top, spacing: DesignConstants.spacingSM) {
            Text("\u{2022}")
                .font(.body)
            renderInlineMarkdown(text)
        }
        .padding(.leading, DesignConstants.spacingMD)
    }

    private func renderOrderedListItem(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: DesignConstants.spacingSM) {
            Text("\(number).")
                .font(.body)
            renderInlineMarkdown(text)
        }
        .padding(.leading, DesignConstants.spacingMD)
    }

    private func renderBlockquote(text: String) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3)

            renderInlineMarkdown(text)
                .foregroundColor(.secondary)
                .padding(.leading, DesignConstants.spacingSM)
        }
        .padding(.leading, DesignConstants.spacingXS)
    }

    @ViewBuilder
    private func renderParagraph(text: String) -> some View {
        renderInlineMarkdown(text)
    }

    private func renderInlineMarkdown(_ text: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            return Text(attributed)
        } else {
            return Text(text)
        }
    }
}

#Preview {
    ScrollView {
        MarkdownContentView(
            content: """
            # Heading 1

            ## Heading 2

            This is a paragraph with **bold**, *italic*, and `inline code`.

            - Bullet one
            - Bullet two
            - **Bold bullet**

            1. First item
            2. Second item

            ```swift
            func hello() {
                print("Hello, world!")
            }
            ```

            > This is a blockquote

            ```mermaid
            graph TD
                A[Start] --> B[End]
            ```
            """
        )
        .padding()
    }
    .frame(width: 500, height: 600)
}
#endif
