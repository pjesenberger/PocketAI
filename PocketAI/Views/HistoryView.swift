//
//  HistoryView.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 11/10/2026.
//

import SwiftUI
import SwiftData

struct HistoryView: View, Equatable {
    @Environment(\.modelContext) private var context
    @Query(sort: \Conversation.createdAt, order: .reverse) private var conversations: [Conversation]
    @State private var search = ""
    @Environment(\.sideMenuTopInset) private var topInset
    @State private var renaming: Conversation?
    @State private var newTitle = ""
    @FocusState private var isSearchFocused: Bool
    @State private var isSearching = false
    @Namespace private var glass

    let selected: Conversation?
    let isOpen: Bool
    let responding: Set<ObjectIdentifier>
    let onSelect: (Conversation) -> Void
    let onDelete: (Conversation) -> Void
    let onSettings: () -> Void

    static func == (lhs: HistoryView, rhs: HistoryView) -> Bool {
        lhs.selected == rhs.selected && lhs.isOpen == rhs.isOpen && lhs.responding == rhs.responding
    }

    private var filtered: [Conversation] {
        search.isEmpty ? conversations : conversations.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    private func header(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }

    private func row(_ conversation: Conversation) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return Button {
            onSelect(conversation)
        } label: {
            HStack(spacing: 8) {
                if conversation.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if conversation.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(conversation.title)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Spacer()
                if responding.contains(ObjectIdentifier(conversation)) {
                    ProgressView()
                        .controlSize(.small)
                } else if conversation.hasUnreadReply {
                    Circle()
                        .fill(.primary)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel("New reply")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(shape.fill(conversation == selected ? Color.secondary.opacity(0.2) : .clear))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .contextMenu {
            Button(conversation.isPinned ? "Unpin" : "Pin", systemImage: conversation.isPinned ? "pin.slash" : "pin") {
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    conversation.isPinned.toggle()
                    try? context.save()
                }
            }
            Button(conversation.isLocked ? "Unlock" : "Lock", systemImage: conversation.isLocked ? "lock.open" : "lock") {
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    if !conversation.isLocked {
                        conversation.isLocked = true
                        try? context.save()
                    } else if await ChatLock.authenticate() {
                        conversation.isLocked = false
                        try? context.save()
                    }
                }
            }
            Button("Rename", systemImage: "pencil") {
                newTitle = conversation.title
                renaming = conversation
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    onDelete(conversation)
                }
            }
        } preview: {
            ChatPreview(conversation: conversation)
        }
    }

    private func setSearching(_ searching: Bool) {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            isSearching = searching
            if !searching {
                search = ""
            }
        }
        isSearchFocused = searching
    }

    private var searchHeader: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                if isSearching {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search", text: $search)
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .glassEffectID("search", in: glass)
                } else {
                    Text("PocketAI")
                        .font(.title2.weight(.bold))
                        .padding(.leading, 8)
                        .transition(.opacity)
                    Spacer()
                }

                Button {
                    setSearching(!isSearching)
                } label: {
                    Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .contentTransition(.symbolEffect(.replace.downUp, options: .speed(1.5)))
                        .foregroundStyle(.primary)
                        .frame(width: 48, height: 48)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .glassEffectID("button", in: glass)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var body: some View {
        let items = filtered
        let pinned = items.filter(\.isPinned)
        let recent = items.filter { !$0.isPinned }

        return ScrollView {
            VStack(spacing: 0) {
                if !pinned.isEmpty {
                    header("Pinned")
                    ForEach(pinned, content: row)
                }
                if !recent.isEmpty {
                    header("Recent")
                    ForEach(recent, content: row)
                }
            }
            .padding(.bottom, 16)
            .animation(.snappy(duration: 0.3), value: pinned.map(\.persistentModelID))
            .animation(.snappy(duration: 0.3), value: recent.map(\.persistentModelID))
        }
        .scrollIndicators(.hidden)
        .safeAreaBar(edge: .top) {
            searchHeader
                .padding(.horizontal, 20)
                .padding(.top, topInset == 0 ? 24 : 0)
                .padding(.bottom, 32)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView(
                    search.isEmpty ? "No chats yet" : "No results",
                    systemImage: search.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass"
                )
                .allowsHitTesting(false)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()

                Button {
                    isSearchFocused = false
                    onSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 52, height: 52)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .onChange(of: isOpen) {
            if !isOpen {
                isSearchFocused = false
                if search.isEmpty {
                    isSearching = false
                }
            }
        }
        .alert("Rename Chat", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if let renaming, !title.isEmpty {
                    renaming.title = title
                    try? context.save()
                }
            }
        }
    }
}

#Preview {
    HistoryView(selected: nil, isOpen: true, responding: [], onSelect: { _ in }, onDelete: { _ in }, onSettings: {})
        .modelContainer(for: [Conversation.self, Message.self], inMemory: true)
}

private struct ChatPreview: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(conversation.title)
                .font(.headline)
                .lineLimit(1)
            if conversation.isLocked {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(conversation.messages.sorted { $0.createdAt < $1.createdAt }.suffix(4)) { message in
                    if message.role == .user {
                        Text(message.content)
                            .lineLimit(3)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.2), in: .rect(cornerRadius: 20))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text((try? AttributedString(markdown: message.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(message.content))
                            .lineLimit(8)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .font(.subheadline)
        .padding(20)
        .frame(width: 320, height: 420, alignment: .top)
        .background(Color(uiColor: .systemBackground))
    }
}
