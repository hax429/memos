import SwiftUI

struct MemoListView: View {
    @StateObject private var viewModel = MemoListViewModel()
    @State private var showingEditor = false
    @State private var selectedMemo: Memo?
    @State private var searchText = ""

    var filteredMemos: [Memo] {
        if searchText.isEmpty {
            return viewModel.memos
        } else {
            return viewModel.memos.filter { memo in
                memo.content.localizedCaseInsensitiveContains(searchText) ||
                memo.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.memos.isEmpty {
                ProgressView("Loading memos...")
            } else if viewModel.memos.isEmpty {
                emptyState
            } else {
                memoList
            }
        }
        .searchable(text: $searchText, prompt: "Search memos...")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingEditor = true }) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            MemoEditorView(memo: selectedMemo) { content in
                do {
                    if let selectedMemo = selectedMemo {
                        // Update existing memo
                        try await viewModel.updateMemo(name: selectedMemo.name, content: content)
                    } else {
                        // Create new memo
                        try await viewModel.createMemo(content: content)
                    }
                    self.selectedMemo = nil
                } catch {
                    // Error will be displayed via the viewModel.error alert
                    print("Failed to save memo: \(error)")
                }
            }
        }
        .task {
            await viewModel.loadMemos()
        }
        .refreshable {
            await viewModel.loadMemos()
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("No Memos Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap the edit button to create your first memo")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(action: { showingEditor = true }) {
                Label("Create Memo", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var memoList: some View {
        List {
            // Tags section
            if let stats = viewModel.userStats, !stats.tagCount.isEmpty {
                Section("Tags") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(stats.sortedTags.prefix(10), id: \.0) { tag, count in
                                TagButton(tag: tag, count: count) {
                                    searchText = "#\(tag)"
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Memos section
            Section {
                ForEach(filteredMemos) { memo in
                    MemoRow(memo: memo)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMemo = memo
                            showingEditor = true
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteMemo(memo)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                HStack {
                    Text("Memos")
                    Spacer()
                    Text("\(filteredMemos.count)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct MemoRow: View {
    let memo: Memo

    private var formattedDate: String {
        guard let date = memo.displayDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Content preview
            Text(memo.content)
                .lineLimit(3)
                .font(.body)

            // Tags and metadata
            HStack(spacing: 8) {
                if !memo.tags.isEmpty {
                    ForEach(memo.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                Spacer()

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Property indicators
            if let property = memo.property {
                HStack(spacing: 12) {
                    if property.hasLink == true {
                        Label("", systemImage: "link")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if property.hasTaskList == true {
                        Label("", systemImage: "checklist")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if property.hasCode == true {
                        Label("", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TagButton: View {
    let tag: String
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("#\(tag)")
                    .font(.subheadline)
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(16)
        }
    }
}

#Preview {
    NavigationView {
        MemoListView()
    }
}
