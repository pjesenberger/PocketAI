//
//  ChatView.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 10/10/2026.
//

import SwiftUI
import SwiftData
import StoreKit

struct ChatView: View {
    @Environment(\.modelContext) private var context
    @Environment(ModelStore.self) private var models
    @Environment(UpdateChecker.self) private var updates
    @AppStorage("didOnboard") private var didOnboard = false
    @AppStorage("replyCount") private var replyCount = 0
    @Environment(\.requestReview) private var requestReview
    @State private var isModelsPresented = false
    @State private var isRenaming = false
    @State private var newTitle = ""
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @State private var isAwayFromBottom = false
    @State private var didUserScroll = false
    @Query(sort: \Shortcut.order) private var shortcuts: [Shortcut]
    @AppStorage("didSeedShortcuts") private var didSeedShortcuts = false
    @State private var viewModel = ChatViewModel()
    @State private var isMenuOpen = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLandscape = false
    @State private var isKeyboardLocked = false
    @State private var isSettingsPresented = false
    @State private var attachment: AttachmentMode?
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            if didOnboard {
                main
                    .overlay(alignment: .top) {
                        DownloadToast()
                    }
                    .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        didOnboard = true
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        isFocused = true
                    }
                }
                .transition(.opacity)
            }
        }
        .task {
            if !didSeedShortcuts {
                Shortcut.defaults().forEach(context.insert)
                try? context.save()
                didSeedShortcuts = true
            } else {
                Shortcut.syncBuiltIns(shortcuts)
                try? context.save()
            }
            viewModel.use(models.languageModel(for: models.selected))
            if didOnboard {
                await updates.check()
                if !updates.isSheetPresented {
                    isFocused = true
                }
            }
        }
    }

    private var main: some View {
        SideMenu(isOpen: $isMenuOpen, isSidebar: isSidebar) {
            HistoryView(
                selected: viewModel.conversation,
                isOpen: isMenuOpen,
                responding: viewModel.respondingIDs,
                onSelect: { conversation in
                    Task {
                        if conversation.isLocked && conversation != viewModel.conversation {
                            guard await ChatLock.authenticate() else { return }
                        }
                        viewModel.open(conversation)
                        if !isSidebar {
                            setMenu(false)
                        }
                    }
                },
                onDelete: { viewModel.delete($0, in: context) },
                onSettings: {
                    isFocused = false
                    isSettingsPresented = true
                }
            )
            .equatable()
        } content: {
            chat
        }
        .ignoresSafeArea(isKeyboardLocked ? .keyboard : [])
        .background {
            Color.clear
                .ignoresSafeArea(.keyboard)
                .onGeometryChange(for: Bool.self) { proxy in
                    proxy.size.width > proxy.size.height
                } action: { landscape in
                    isLandscape = landscape
                }
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .background else { return }
            viewModel.enterBackground()
            if viewModel.conversation?.isLocked == true {
                viewModel.newChat()
            }
        }
        .onChange(of: isSidebar, initial: true) {
            isMenuOpen = isSidebar
        }
        .onChange(of: isMenuOpen) {
            if isMenuOpen && !isSidebar {
                isFocused = false
                attachment = nil
            }
        }
        .task(id: isMenuOpen) {
            try? await Task.sleep(for: .seconds(0.4))
            isKeyboardLocked = isMenuOpen && !isSidebar
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            SettingsView {
                viewModel.deleteAll(in: context)
            }
        }
        .sheet(isPresented: Bindable(updates).isSheetPresented) {
            UpdateSheet()
        }
        .onChange(of: updates.isSheetPresented) {
            if updates.isSheetPresented {
                isFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .sheet(isPresented: $isModelsPresented) {
            NavigationStack {
                ModelsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                isModelsPresented = false
                            } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
        }
        .alert("Rename Chat", isPresented: $isRenaming) {
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if let conversation = viewModel.conversation, !title.isEmpty {
                    conversation.title = title
                    try? context.save()
                }
            }
        }
        .onChange(of: viewModel.isResponding) {
            guard !viewModel.isResponding, !viewModel.isTemporaryChat, viewModel.messages.last?.role == .assistant else { return }
            replyCount += 1
            if replyCount == 8 || replyCount == 40 {
                requestReview()
            }
        }
        .onChange(of: models.selectedID) {
            viewModel.use(models.languageModel(for: models.selected))
            if !viewModel.supportsImages && (attachment == .photos || attachment == .camera) {
                attachment = .choosing
            }
        }
    }

    private var selectedInstructions: [String] {
        shortcuts.filter { viewModel.selectedShortcuts.contains($0.id) }.map(\.prompt)
    }

    private func startNewChat() {
        viewModel.newChat()
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            isFocused = true
        }
    }

    private var isSidebar: Bool {
        horizontalSizeClass == .regular && isLandscape
    }

    private func setMenu(_ open: Bool) {
        withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
            isMenuOpen = open
        }
    }

    private var chat: some View {
        let messages = viewModel.messages

        return NavigationStack {
            Group {
                if messages.isEmpty {
                    EmptyChatView(
                        isTemporaryChat: viewModel.isTemporaryChat,
                        unavailableReason: viewModel.unavailableReason
                    )
                    .ignoresSafeArea(isFocused ? [] : .keyboard)
                    .transition(.opacity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(messages) { message in
                                MessageBubble(
                                    message: message,
                                    isStreaming: message == viewModel.streamingReply,
                                    isBeingEdited: message == viewModel.editingMessage,
                                    onEdit: viewModel.isResponding ? nil : {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            viewModel.startEditing(message)
                                        }
                                        attachment = nil
                                        isFocused = true
                                    },
                                    onRetry: message == messages.last && message.role == .assistant && !viewModel.isResponding ? {
                                        viewModel.regenerate(in: context)
                                    } : nil
                                )
                            }
                        }
                        .padding(.bottom, 56)
                        .padding()
                        .frame(maxWidth: 760)
                        .frame(maxWidth: .infinity)
                    }
                    .defaultScrollAnchor(.bottom)
                    .defaultScrollAnchor(.bottom, for: .sizeChanges)
                    .scrollDismissesKeyboard(.immediately)
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .scrollPosition($scrollPosition)
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        geometry.visibleRect.maxY < geometry.contentSize.height - 120
                    } action: { _, isAway in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isAwayFromBottom = isAway
                            if !isAway {
                                didUserScroll = false
                            }
                        }
                    }
                    .onScrollPhaseChange { _, phase in
                        if phase == .interacting {
                            didUserScroll = true
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if isAwayFromBottom && didUserScroll {
                            Button {
                                withAnimation(.spring(duration: 0.4)) {
                                    didUserScroll = false
                                    scrollPosition.scrollTo(edge: .bottom)
                                }
                            } label: {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .frame(width: 44, height: 44)
                                    .glassEffect(.regular.interactive(), in: .circle)
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, isFocused || attachment != nil ? 60 : 12)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: messages.isEmpty)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                if attachment != nil {
                    attachment = nil
                } else {
                    isFocused = false
                }
            }
            .safeAreaInset(edge: .bottom) {
                ChatInputView(
                    text: $viewModel.text,
                    shortcuts: shortcuts.filter(\.isPinned),
                    selectedShortcuts: $viewModel.selectedShortcuts,
                    images: $viewModel.images,
                    files: $viewModel.files,
                    supportsImages: viewModel.supportsImages,
                    isFocused: $isFocused,
                    attachment: $attachment,
                    errorMessage: viewModel.errorMessage,
                    isResponding: viewModel.isResponding,
                    isEditing: viewModel.editingMessage != nil,
                    canSend: viewModel.canSend,
                    onSend: {
                        isFocused = false
                        attachment = nil
                        viewModel.send(in: context, instructions: selectedInstructions)
                    },
                    onStop: { viewModel.stop() },
                    onCancelEdit: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.cancelEditing()
                        }
                    }
                )
                .ignoresSafeArea(.container, edges: isLandscape ? [] : .trailing)
            }
            .ignoresSafeArea(isKeyboardLocked ? .keyboard : [])
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        setMenu(!isMenuOpen)
                    } label: {
                        MenuIcon()
                    }
                }
                .prefersVerticalAxis(true)

                ToolbarItem(placement: .principal) {
                    Menu {
                        Section("Select a Model") {
                            ForEach(models.installed) { model in
                                Button {
                                    models.select(model)
                                } label: {
                                    if model.id == models.selectedID {
                                        Label(model.name, systemImage: "checkmark")
                                    } else {
                                        Text(model.name)
                                    }
                                }
                            }
                        }
                        Section {
                            Button("Manage Models", systemImage: "square.and.arrow.down") {
                                isModelsPresented = true
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if viewModel.isTemporaryChat && !messages.isEmpty {
                                IncognitoGlyph(color: .primary, size: 16)
                                    .padding(.trailing, 4)
                                    .accessibilityLabel("Temporary Chat")
                            }
                            models.selected.styledName
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if messages.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                viewModel.isTemporaryChat.toggle()
                            }
                        } label: {
                            IncognitoGlyph(color: viewModel.isTemporaryChat ? .white : .gray, size: 20)
                                .accessibilityLabel(viewModel.isTemporaryChat ? "Turn off temporary chat" : "Temporary chat")
                        }
                        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isTemporaryChat)
                    } else if viewModel.isTemporaryChat {
                        Menu {
                            Button("New Chat", systemImage: "square.and.pencil") {
                                startNewChat()
                            }
                            Button("Save Chat", systemImage: "square.and.arrow.down") {
                                withAnimation(.easeInOut(duration: 0.24)) {
                                    viewModel.saveTemporaryChat(in: context)
                                }
                            }
                            .disabled(viewModel.isResponding)
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.primary)
                                .accessibilityLabel("More")
                        }
                    } else {
                        Button {
                            startNewChat()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .foregroundStyle(.primary)
                        }
                        .accessibilityLabel("New Chat")
                    }
                }
                .prefersVerticalAxis(true)

                if let conversation = viewModel.conversation, !viewModel.isTemporaryChat, !messages.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(conversation.isPinned ? "Unpin" : "Pin", systemImage: conversation.isPinned ? "pin.slash" : "pin") {
                                conversation.isPinned.toggle()
                                try? context.save()
                            }
                            Button(conversation.isLocked ? "Unlock" : "Lock", systemImage: conversation.isLocked ? "lock.open" : "lock") {
                                Task {
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
                                isRenaming = true
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.primary)
                                .accessibilityLabel("More")
                        }
                    }
                }
            }
            .onChange(of: isFocused) {
                if isFocused {
                    attachment = nil
                    viewModel.prewarm()
                }
                if !isFocused && attachment == .choosing {
                    attachment = nil
                }
            }
        }
    }
}

#Preview {
    ChatView()
        .environment(ModelStore())
        .environment(UpdateChecker())
        .modelContainer(for: [Conversation.self, Message.self, Shortcut.self], inMemory: true)
}

extension ToolbarContent {
    @ToolbarContentBuilder
    func prefersVerticalAxis(_ isVertical: Bool) -> some ToolbarContent {
        if #available(iOS 27.1, *) {
            axisBehavior(isVertical ? .verticalPreferred : .horizontalOnly)
        } else {
            self
        }
    }
}
