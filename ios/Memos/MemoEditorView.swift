import SwiftUI

struct MemoEditorView: View {
    let memo: Memo?
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var content: String
    @State private var showingPreview = false
    @FocusState private var isTextEditorFocused: Bool

    init(memo: Memo? = nil, onSave: @escaping (String) -> Void) {
        self.memo = memo
        self.onSave = onSave
        _content = State(initialValue: memo?.content ?? "")
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                if showingPreview {
                    ScrollView {
                        MarkdownView(content: content)
                            .padding()
                    }
                } else {
                    TextEditor(text: $content)
                        .focused($isTextEditorFocused)
                        .font(.body)
                        .padding(8)
                        .autocorrectionDisabled(false)
                }

                // Tag suggestions bottom bar
                if !extractedTags.isEmpty && !showingPreview {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(extractedTags, id: \.self) { tag in
                                TagChip(tag: tag)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle(memo == nil ? "New Memo" : "Edit Memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showingPreview.toggle() }) {
                            Image(systemName: showingPreview ? "pencil" : "eye")
                        }

                        Button("Save") {
                            onSave(content)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(content.isEmpty)
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    HStack {
                        // Markdown shortcuts
                        Button(action: { insertMarkdown("**", "**") }) {
                            Text("B")
                                .fontWeight(.bold)
                        }
                        Button(action: { insertMarkdown("*", "*") }) {
                            Text("I")
                                .italic()
                        }
                        Button(action: { insertMarkdown("`", "`") }) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                        }
                        Button(action: { insertMarkdown("- ", "") }) {
                            Image(systemName: "list.bullet")
                        }
                        Button(action: { insertMarkdown("- [ ] ", "") }) {
                            Image(systemName: "checklist")
                        }
                        Button(action: { insertMarkdown("#", " ") }) {
                            Image(systemName: "number")
                        }

                        Spacer()

                        Button("Done") {
                            isTextEditorFocused = false
                        }
                    }
                }
            }
            .onAppear {
                if memo == nil {
                    isTextEditorFocused = true
                }
            }
        }
    }

    // Extract tags from content for preview
    private var extractedTags: [String] {
        let pattern = "#([a-zA-Z0-9_\\-/]+)"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(content.startIndex..., in: content)

        guard let matches = regex?.matches(in: content, range: range) else {
            return []
        }

        var tags: [String] = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: content) {
                tags.append(String(content[range]))
            }
        }

        return Array(Set(tags)).sorted()
    }

    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        content += prefix + suffix
        // Move cursor between prefix and suffix (simplified)
    }
}

struct TagChip: View {
    let tag: String

    var body: some View {
        Text("#\(tag)")
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.15))
            .foregroundColor(.blue)
            .cornerRadius(12)
    }
}

// Simple markdown rendering view
struct MarkdownView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseMarkdown(), id: \.self) { line in
                if line.hasPrefix("# ") {
                    Text(line.dropFirst(2))
                        .font(.title)
                        .fontWeight(.bold)
                } else if line.hasPrefix("## ") {
                    Text(line.dropFirst(3))
                        .font(.title2)
                        .fontWeight(.bold)
                } else if line.hasPrefix("### ") {
                    Text(line.dropFirst(4))
                        .font(.title3)
                        .fontWeight(.bold)
                } else if line.hasPrefix("- [ ] ") {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "square")
                            .font(.body)
                        Text(line.dropFirst(6))
                    }
                } else if line.hasPrefix("- [x] ") {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.square.fill")
                            .font(.body)
                            .foregroundColor(.green)
                        Text(line.dropFirst(6))
                    }
                } else if line.hasPrefix("- ") {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text(line.dropFirst(2))
                    }
                } else if line.hasPrefix("`") && line.hasSuffix("`") {
                    Text(line)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    Text(attributedString(for: line))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func parseMarkdown() -> [String] {
        content.components(separatedBy: "\n")
    }

    private func attributedString(for text: String) -> AttributedString {
        var result = AttributedString(text)

        // Bold
        if let boldRegex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*") {
            let matches = boldRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    if let attrRange = Range(range, in: result) {
                        result[attrRange].font = .body.bold()
                    }
                }
            }
        }

        // Italic
        if let italicRegex = try? NSRegularExpression(pattern: "\\*(.+?)\\*") {
            let matches = italicRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    if let attrRange = Range(range, in: result) {
                        result[attrRange].font = .body.italic()
                    }
                }
            }
        }

        // Tags (#tag)
        if let tagRegex = try? NSRegularExpression(pattern: "#([a-zA-Z0-9_\\-/]+)") {
            let matches = tagRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    if let attrRange = Range(range, in: result) {
                        result[attrRange].foregroundColor = .blue
                        result[attrRange].font = .body.bold()
                    }
                }
            }
        }

        return result
    }
}

#Preview {
    MemoEditorView { content in
        print("Saved: \(content)")
    }
}
