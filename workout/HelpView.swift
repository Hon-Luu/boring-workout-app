import SwiftUI

// MARK: - Parsed block types

private enum MDBlock {
    case h1(String)
    case h2(String)
    case h3(String)
    case h4(String)
    case paragraph(String)
    case bulletItem(String, indent: Int)
    case numberedItem(String, number: Int)
    case codeBlock([String])
    case blockquote(String)
    case table(header: [String], rows: [[String]])
    case rule
}

// MARK: - Parser

private func parseMarkdown(_ text: String) -> [MDBlock] {
    var blocks: [MDBlock] = []
    let lines = text.components(separatedBy: "\n")
    var i = 0

    while i < lines.count {
        let raw = lines[i]
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        // Fenced code block
        if trimmed.hasPrefix("```") {
            i += 1
            var codeLines: [String] = []
            while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                codeLines.append(lines[i])
                i += 1
            }
            blocks.append(.codeBlock(codeLines))
            i += 1
            continue
        }

        // Horizontal rule
        if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            blocks.append(.rule)
            i += 1
            continue
        }

        // Table (detect by | at start after trimming)
        if trimmed.hasPrefix("|") {
            var tableLines: [String] = []
            while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                tableLines.append(lines[i].trimmingCharacters(in: .whitespaces))
                i += 1
            }
            if tableLines.count >= 2 {
                let headerCells = parseCells(tableLines[0])
                // tableLines[1] is the separator row (---|---), skip it
                let dataRows = tableLines.dropFirst(2).map { parseCells($0) }
                blocks.append(.table(header: headerCells, rows: dataRows))
            }
            continue
        }

        // Headers
        if trimmed.hasPrefix("#### ") {
            blocks.append(.h4(String(trimmed.dropFirst(5))))
        } else if trimmed.hasPrefix("### ") {
            blocks.append(.h3(String(trimmed.dropFirst(4))))
        } else if trimmed.hasPrefix("## ") {
            blocks.append(.h2(String(trimmed.dropFirst(3))))
        } else if trimmed.hasPrefix("# ") {
            blocks.append(.h1(String(trimmed.dropFirst(2))))

        // Blockquote
        } else if trimmed.hasPrefix("> ") {
            blocks.append(.blockquote(String(trimmed.dropFirst(2))))

        // Bullet list (-, *, +)
        } else if let (indent, text) = parseBullet(raw) {
            blocks.append(.bulletItem(text, indent: indent))

        // Numbered list
        } else if let (num, text) = parseNumbered(trimmed) {
            blocks.append(.numberedItem(text, number: num))

        // Empty line — skip
        } else if trimmed.isEmpty {
            // skip

        // Paragraph
        } else {
            blocks.append(.paragraph(trimmed))
        }

        i += 1
    }
    return blocks
}

private func parseCells(_ line: String) -> [String] {
    var s = line
    if s.hasPrefix("|") { s = String(s.dropFirst()) }
    if s.hasSuffix("|") { s = String(s.dropLast()) }
    return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
}

private func parseBullet(_ raw: String) -> (indent: Int, text: String)? {
    let indent = raw.prefix(while: { $0 == " " }).count
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    for prefix in ["- ", "* ", "+ "] {
        if trimmed.hasPrefix(prefix) {
            return (indent / 2, String(trimmed.dropFirst(prefix.count)))
        }
    }
    return nil
}

private func parseNumbered(_ trimmed: String) -> (Int, String)? {
    let parts = trimmed.split(separator: ".", maxSplits: 1)
    guard parts.count == 2, let num = Int(parts[0]) else { return nil }
    return (num, parts[1].trimmingCharacters(in: .whitespaces))
}

// Convert inline markdown (* ** ` []) to AttributedString
private func inlineAttr(_ raw: String) -> AttributedString {
    // Strip markdown link syntax [text](#anchor) → text
    let cleaned = raw.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]*\)"#,
                                            with: "$1",
                                            options: .regularExpression)
    // iOS 15+ AttributedString handles **bold**, *italic*, `code`
    return (try? AttributedString(markdown: cleaned)) ?? AttributedString(cleaned)
}

// MARK: - Block renderer

private struct BlockView: View {
    let block: MDBlock

    var body: some View {
        switch block {

        case .h1(let t):
            Text(inlineAttr(t))
                .font(.title.bold())
                .padding(.top, 8)

        case .h2(let t):
            Text(inlineAttr(t))
                .font(.title2.bold())
                .padding(.top, 12)
                .foregroundStyle(.primary)

        case .h3(let t):
            Text(inlineAttr(t))
                .font(.headline)
                .padding(.top, 8)

        case .h4(let t):
            Text(inlineAttr(t))
                .font(.subheadline.bold())
                .padding(.top, 6)
                .foregroundStyle(.secondary)

        case .paragraph(let t):
            Text(inlineAttr(t))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

        case .bulletItem(let t, let indent):
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(inlineAttr(t))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(indent) * 12)

        case .numberedItem(let t, let number):
            HStack(alignment: .top, spacing: 6) {
                Text("\(number).")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 20, alignment: .trailing)
                Text(inlineAttr(t))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

        case .codeBlock(let lines):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(lines.joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        case .blockquote(let t):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                Text(inlineAttr(t))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)

        case .table(let header, let rows):
            TableBlockView(header: header, rows: rows)

        case .rule:
            Divider()
                .padding(.vertical, 4)
        }
    }
}

private struct TableBlockView: View {
    let header: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(header.indices, id: \.self) { c in
                        Text(inlineAttr(header[c]))
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(minWidth: colWidth(c), alignment: .leading)
                            .background(Color(.tertiarySystemBackground))
                    }
                }
                Divider()
                // Data rows
                ForEach(rows.indices, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<max(rows[r].count, header.count), id: \.self) { c in
                            let cell = c < rows[r].count ? rows[r][c] : ""
                            Text(inlineAttr(cell))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(minWidth: colWidth(c), alignment: .leading)
                        }
                    }
                    .background(r % 2 == 0 ? Color.clear : Color(.secondarySystemBackground).opacity(0.5))
                    Divider().opacity(0.4)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func colWidth(_ col: Int) -> CGFloat {
        // First column wider, rest equal
        col == 0 ? 140 : 110
    }
}

// MARK: - Help View

struct HelpView: View {
    @State private var searchText = ""
    @State private var blocks: [MDBlock] = []
    @State private var rawText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(visibleBlocks.indices, id: \.self) { i in
                        BlockView(block: visibleBlocks[i])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("User Manual")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search manual")
        }
        .onAppear { loadManual() }
    }

    private var visibleBlocks: [MDBlock] {
        guard !searchText.isEmpty else { return blocks }
        let q = searchText.lowercased()
        return blocks.filter { blockMatchesSearch($0, query: q) }
    }

    private func blockMatchesSearch(_ block: MDBlock, query: String) -> Bool {
        switch block {
        case .h1(let t), .h2(let t), .h3(let t), .h4(let t),
             .paragraph(let t), .blockquote(let t):
            return t.lowercased().contains(query)
        case .bulletItem(let t, _), .numberedItem(let t, _):
            return t.lowercased().contains(query)
        case .codeBlock(let lines):
            return lines.joined().lowercased().contains(query)
        case .table(let h, let rows):
            return h.joined().lowercased().contains(query) ||
                   rows.joined().joined().lowercased().contains(query)
        case .rule:
            return false
        }
    }

    private func loadManual() {
        guard let url = Bundle.main.url(forResource: "USER_MANUAL", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            blocks = [.paragraph("Manual not found. Please reinstall the app.")]
            return
        }
        rawText = text
        blocks  = parseMarkdown(text)
    }
}

// MARK: - Entry point for Settings row

struct HelpNavigationLink: View {
    @State private var showHelp = false

    var body: some View {
        Button {
            showHelp = true
        } label: {
            Label("User Manual", systemImage: "book.pages")
        }
        .foregroundStyle(.primary)
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
    }
}
