//
//  SettingsView.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 13/10/2026.
//

import SwiftUI
import SwiftData
import FoundationModels

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ModelStore.self) private var models
    @Query(sort: \Shortcut.order) private var shortcuts: [Shortcut]
    @AppStorage("theme") private var theme = AppTheme.white
    @AppStorage("appIcon") private var appIcon = AppIconOption.current
    @AppStorage("compactShortcuts") private var isCompactShortcuts = false
    @State private var editing: Shortcut?
    @State private var isCreating = false
    @State private var isConfirmingDelete = false
    @State private var isFeedbackPresented = false
    @State private var isUpdatePresented = false
    @Environment(UpdateChecker.self) private var updates
    let onDeleteAll: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(spacing: 6) {
                        AppIconPreview(option: appIcon, size: 80)
                            .padding(.bottom, 6)
                        Text("PocketAI")
                            .font(.title2.weight(.bold))
                        if updates.isAvailable {
                            Button {
                                isUpdatePresented = true
                            } label: {
                                Label(version, systemImage: "exclamationmark.triangle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("New Update")
                        } else {
                            Text(version)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    section("Models") {
                        NavigationLink {
                            ModelsView()
                        } label: {
                            row("Model", value: models.selected.name) {
                                ModelIcon(model: models.selected, size: 28)
                            }
                        }
                    }

                    section("Customize PocketAI") {
                        VStack(spacing: 8) {
                            NavigationLink {
                                PersonalizationView()
                            } label: {
                                row("Personalization", value: nil) {
                                    Image(systemName: "person.crop.circle")
                                }
                            }

                            NavigationLink {
                                shortcutsPage
                            } label: {
                                row("Shortcuts", value: "\(shortcuts.filter(\.isPinned).count)") {
                                    Image(systemName: "bolt")
                                }
                            }
                        }
                    }

                    section("Appearance") {
                        VStack(spacing: 0) {
                            menuRow("Accent Color") {
                                ForEach(AppTheme.allCases) { item in
                                    Button {
                                        select(item)
                                    } label: {
                                        Label {
                                            Text(item.name)
                                        } icon: {
                                            Image(uiImage: UIImage(systemName: "circle.fill")!.withTintColor(UIColor(item.color), renderingMode: .alwaysOriginal))
                                        }
                                        if theme == item {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            } value: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 14, height: 14)
                                    Text(theme.name)
                                }
                            }

                            Divider()
                                .padding(.horizontal, 16)

                            VStack(alignment: .leading, spacing: 14) {
                                Text("App Icon")
                                    .padding(.horizontal, 16)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(AppIconOption.allCases) { item in
                                            Button {
                                                select(item)
                                            } label: {
                                                VStack(spacing: 8) {
                                                    AppIconPreview(option: item, size: 64)
                                                        .padding(3)
                                                        .overlay {
                                                            RoundedRectangle(cornerRadius: 64 * 0.225 + 3, style: .continuous)
                                                                .strokeBorder(appIcon == item ? Color.primary : .clear, lineWidth: 2)
                                                        }
                                                    Text(item.name)
                                                        .font(.footnote.weight(appIcon == item ? .semibold : .regular))
                                                        .foregroundStyle(appIcon == item ? .primary : .secondary)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(item.name)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                                .contentMargins(.horizontal, 16, for: .scrollContent)
                            }
                            .padding(.vertical, 14)
                        }
                        .tint(.primary)
                        .card()
                    }

                    section("Language") {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            row("App Language", value: Locale.current.localizedString(forIdentifier: Bundle.main.preferredLocalizations.first ?? "en")?.localizedCapitalized) {
                                Image(systemName: "globe")
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    section("Feedback") {
                        Button {
                            isFeedbackPresented = true
                        } label: {
                            row("Contact Us", value: nil) {
                                Image(systemName: "paperplane")
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    section("Data") {
                        Button {
                            isConfirmingDelete = true
                        } label: {
                            row("Delete All Chats", value: nil, isDestructive: true) {
                                Image(systemName: "trash")
                            }
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog("Delete all chats?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                            Button("Delete All Chats", role: .destructive) {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                onDeleteAll()
                            }
                        } message: {
                            Text("This can't be undone.")
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .sensoryFeedback(.selection, trigger: theme)
            .sensoryFeedback(.selection, trigger: appIcon)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .disablesVerticalToolbar()
            .sheet(item: $editing) { shortcut in
                ShortcutEditor(shortcut: shortcut, nextOrder: nextOrder)
            }
            .sheet(isPresented: $isCreating) {
                ShortcutEditor(shortcut: nil, nextOrder: nextOrder)
            }
            .sheet(isPresented: $isUpdatePresented) {
                UpdateSheet()
            }
            .sheet(isPresented: $isFeedbackPresented) {
                FeedbackView(version: build)
            }
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 16)
            content()
        }
    }

    private func row<Leading: View>(_ title: LocalizedStringKey, value: String?, isDestructive: Bool = false, @ViewBuilder icon: () -> Leading) -> some View {
        HStack(spacing: 12) {
            icon()
                .frame(width: 28)
            Text(title)
            Spacer()
            if let value {
                Text(value)
                    .foregroundStyle(.secondary)
            }
            if !isDestructive {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(isDestructive ? Color.red : .primary)
        .padding(.horizontal, 16)
        .frame(height: 52)
        .contentShape(Rectangle())
        .card()
    }

    private func select(_ item: AppTheme) {
        withAnimation(.easeInOut(duration: 0.2)) {
            theme = item
        }
    }

    private func menuRow<Content: View, Value: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            Menu {
                content()
            } label: {
                HStack(spacing: 6) {
                    value()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private func select(_ item: AppIconOption) {
        guard item != appIcon else { return }
        let previous = appIcon
        appIcon = item
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(item.iconName)
            } catch {
                appIcon = previous
            }
        }
    }

    private var version: String {
        String(localized: "Version \(UpdateChecker.currentVersion)")
    }

    private var build: String {
        "\(UpdateChecker.currentVersion) (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))"
    }

    private var customShortcuts: [Shortcut] {
        shortcuts.filter { !$0.isBuiltIn }
    }

    private var shortcutsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                section("My Shortcuts") {
                    VStack(spacing: 0) {
                        if !customShortcuts.isEmpty {
                            FlowLayout {
                                ForEach(customShortcuts) { shortcut in
                                    shortcutOption(shortcut)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Divider()
                                .padding(.horizontal, 16)
                        }

                        Button {
                            isCreating = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus")
                                Text("New Shortcut")
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .card()
                }

                section("Predefined Shortcuts") {
                    FlowLayout {
                        ForEach(shortcuts.filter(\.isBuiltIn)) { shortcut in
                            shortcutOption(shortcut)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Icons Only", isOn: $isCompactShortcuts)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .card()

                    Text("Selected shortcuts appear above the keyboard.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func shortcutOption(_ shortcut: Shortcut) -> some View {
        PromptOption(
            title: shortcut.name,
            symbol: shortcut.symbol,
            isSelected: Binding(
                get: { shortcut.isPinned },
                set: { isPinned in
                    shortcut.isPinned = isPinned
                    try? context.save()
                }
            )
        )
        .contextMenu {
            Button("Edit", systemImage: "pencil") {
                editing = shortcut
            }
            if let original = shortcut.original, shortcut.differs(from: original) {
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    shortcut.name = original.name
                    shortcut.symbol = original.symbol
                    shortcut.prompt = original.prompt
                    shortcut.isEdited = false
                    try? context.save()
                }
            }
            if !shortcut.isBuiltIn {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        withAnimation(.snappy(duration: 0.3)) {
                            context.delete(shortcut)
                        }
                        try? context.save()
                    }
                }
            }
        }
    }

    private var nextOrder: Int {
        (shortcuts.map(\.order).max() ?? -1) + 1
    }
}

@Generable
struct ShortcutDraft {
    @Guide(description: "A name of one or two words, in the language of the user's idea")
    var name: String

    @Guide(description: "An SF Symbols name that fits the shortcut, such as sparkles, flame, globe, book, lightbulb or envelope")
    var symbol: String

    @Guide(description: "The task in English, starting with a verb, such as: Rewrite the text in a formal tone. Say what to do and how to format the result.")
    var prompt: String
}

struct ShortcutEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ModelStore.self) private var models
    let shortcut: Shortcut?
    let nextOrder: Int
    @State private var name = ""
    @State private var symbol = "sparkles"
    @State private var prompt = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private let symbols = [
        "sparkles", "text.alignleft", "translate", "pencil", "lightbulb", "book",
        "checklist", "envelope", "briefcase", "globe", "brain", "heart",
        "terminal", "chart.bar", "fork.knife", "dumbbell", "airplane", "star",
        "wand.and.stars", "quote.bubble", "doc.text", "list.bullet", "magnifyingglass", "graduationcap",
        "flame", "leaf", "music.note", "face.smiling", "camera", "paintbrush",
        "hammer", "cart", "calendar", "clock", "map", "house",
        "person", "bubble.left", "phone", "gift", "cup.and.saucer", "car",
        "gamecontroller", "film", "photo", "mic", "bolt", "moon",
        "sun.max", "cloud", "pawprint", "stethoscope", "scalemass", "dollarsign.circle"
    ]

    private enum Field {
        case name, prompt
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Summarize", text: $name)
                        .focused($focus, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focus = .prompt }
                    TextField("What should it do? E.g. extract the text, explain simply…", text: $prompt, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focus, equals: .prompt)
                        .submitLabel(.done)
                        .onChange(of: prompt) {
                            if prompt.contains("\n") {
                                prompt = prompt.replacingOccurrences(of: "\n", with: "")
                                focus = nil
                            }
                        }
                    Button {
                        focus = nil
                        generate()
                    } label: {
                        Label(isGenerating ? "Writing…" : "Write with AI", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.white, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .opacity(idea.isEmpty || isGenerating ? 0.4 : 1)
                    .disabled(idea.isEmpty || isGenerating)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .listRowSeparator(.hidden)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    TabView {
                        ForEach(Array(stride(from: 0, to: symbols.count, by: 18)), id: \.self) { start in
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                                ForEach(symbols[start..<min(start + 18, symbols.count)], id: \.self) { item in
                                    Button {
                                        symbol = item
                                    } label: {
                                        Image(systemName: item)
                                            .font(.system(size: 18))
                                            .foregroundStyle(symbol == item ? Color(uiColor: .systemBackground) : .primary)
                                            .frame(width: 44, height: 44)
                                            .background(
                                                symbol == item ? Color.primary : Color.secondary.opacity(0.12),
                                                in: .rect(cornerRadius: 12, style: .continuous)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxHeight: .infinity, alignment: .top)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(shortcut == nil ? "New Shortcut" : "Edit Shortcut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || prompt.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let shortcut else { return }
                name = shortcut.name
                symbol = shortcut.symbol
                prompt = shortcut.prompt
            }
        }
    }

    private var idea: String {
        "\(name) \(prompt)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generate() {
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let session = LanguageModelSession(model: models.languageModel(for: models.selected), instructions: "You turn the user's idea into a shortcut for PocketAI, a chat app. A shortcut is a task applied to the next message, such as \"Answer in two or three sentences.\" or \"Translate the text into English.\" Write the task as clear, direct instructions that start with a verb. Do not give the assistant a role or a persona.")
                let draft = try await ModelLock.run(if: !models.selected.isBuiltIn) { try await session.respond(to: idea, generating: ShortcutDraft.self).content }
                name = Self.cleaned(draft.name)
                prompt = Self.cleaned(draft.prompt)
                symbol = Self.validSymbol(draft.symbol)
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private static func cleaned(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: "{}\"").union(.whitespacesAndNewlines))
    }

    private static func validSymbol(_ name: String) -> String {
        UIImage(systemName: name) == nil ? "sparkles" : name
    }

    private func save() {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let symbol = Self.validSymbol(symbol)

        if let shortcut {
            shortcut.name = name
            shortcut.symbol = symbol
            shortcut.prompt = prompt
            if let original = shortcut.original {
                shortcut.isEdited = shortcut.differs(from: original)
            }
        } else {
            context.insert(Shortcut(name: name, symbol: symbol, prompt: prompt, order: nextOrder))
        }
        try? context.save()
        dismiss()
    }
}

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    let version: String
    @State private var message = ""
    @State private var isSending = false
    @State private var didSend = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private static let accessKey = "07468e63-5257-49c8-a7d1-9f3166c733ba"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("A problem, an idea? Tell us.", text: $message, axis: .vertical)
                        .lineLimit(6...14)
                        .focused($isFocused)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else {
                        Text("Sent anonymously. Only your app version and device model are included.")
                    }
                }
            }
            .navigationTitle("Contact Us")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("Send", systemImage: "paperplane", action: send)
                            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .sensoryFeedback(.success, trigger: didSend) { _, new in new }
            .onAppear { isFocused = true }
        }
    }

    private func send() {
        isSending = true
        errorMessage = nil
        Task {
            do {
                var request = URLRequest(url: URL(string: "https://api.web3forms.com/submit")!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.httpBody = try JSONEncoder().encode([
                    "access_key": Self.accessKey,
                    "subject": "PocketAI feedback",
                    "from_name": "PocketAI",
                    "message": message.trimmingCharacters(in: .whitespacesAndNewlines),
                    "app": "\(version) · \(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)"
                ])
                let (_, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                didSend = true
                try? await Task.sleep(for: .seconds(0.6))
                dismiss()
            } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed].contains(error.code) {
                errorMessage = String(localized: "You're offline. Connect to the internet to send your message.")
            } catch {
                errorMessage = String(localized: "Couldn't send. Check your connection and try again.")
            }
            isSending = false
        }
    }
}

struct PersonalizationView: View {
    @Environment(ModelStore.self) private var models
    @AppStorage("customInstructions") private var instructions = ""
    @AppStorage("responseTone") private var tone = ResponseTone.standard
    @AppStorage("emojiUse") private var emojis = EmojiUse.standard
    @AppStorage("memoryEnabled") private var isMemoryEnabled = true
    @FocusState private var isFocused: Bool
    @State private var isGenerating = false
    @State private var errorMessage: String?

    private var draft: String {
        instructions.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(spacing: 0) {
                    menuRow("Style", value: tone.name) {
                        Picker("Style", selection: $tone) {
                            ForEach(ResponseTone.allCases, id: \.self) { Text($0.name).tag($0) }
                        }
                    }
                    Divider().padding(.horizontal, 16)
                    menuRow("Emojis", value: emojis.name) {
                        Picker("Emojis", selection: $emojis) {
                            ForEach(EmojiUse.allCases, id: \.self) { Text($0.name).tag($0) }
                        }
                    }
                }
                .tint(.primary)
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Instructions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 16)

                    VStack(alignment: .trailing, spacing: 12) {
                        TextField("For example: Be direct. Don't use emojis. Keep answers short.", text: $instructions, axis: .vertical)
                            .lineLimit(4...12)
                            .focused($isFocused)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            isFocused = false
                            generate()
                        } label: {
                            Label(isGenerating ? "Writing…" : "Write with AI", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.white, in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .opacity(draft.isEmpty || isGenerating ? 0.4 : 1)
                        .disabled(draft.isEmpty || isGenerating)
                    }
                    .padding(16)
                    .card()

                    Group {
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        } else {
                            Text("Used in every chat. Stays on your device.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.footnote)
                    .padding(.horizontal, 16)
                }

                NavigationLink {
                    MemoryView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "book")
                            .frame(width: 28)
                        Text("Memory")
                        Spacer()
                        Text(isMemoryEnabled ? "On" : "Off")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                    .card()
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(KeyboardDismisser())
        .sensoryFeedback(.selection, trigger: tone)
        .sensoryFeedback(.selection, trigger: emojis)
        .navigationTitle("Personalization")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func menuRow<Content: View>(_ title: LocalizedStringKey, value: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            Menu {
                content()
            } label: {
                HStack(spacing: 6) {
                    Text(value)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private func generate() {
        isGenerating = true
        errorMessage = nil
        let notes = draft
        Task {
            do {
                let session = LanguageModelSession(model: models.languageModel(for: models.selected), instructions: """
                You turn the user's notes into instructions that will be added to an AI assistant's system prompt.

                Rules:
                - Write in the same language as the notes.
                - One instruction per line, at most 6 lines.
                - Start each line with a verb addressed to the assistant, such as "Answer…", "Use…" or "Avoid…".
                - Facts about the user go on one line, such as "The user is a developer."
                - Keep only what the notes say. Do not add new rules.
                - No introduction, no quotes, no bullets, no Markdown.

                Example for "dev, short answers, no emojis":
                The user is a developer.
                Answer briefly and go straight to the point.
                Do not use emojis.
                """)
                let text = try await ModelLock.run(if: !models.selected.isBuiltIn) { try await session.respond(to: notes).content }
                instructions = text
                    .split(separator: "\n")
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-•*\"").union(.whitespaces)) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

struct MemoryView: View {
    @AppStorage("memoryEnabled") private var isEnabled = true
    @AppStorage("theme") private var theme = AppTheme.white
    @State private var items = Memory.items
    @State private var newItem = ""
    @State private var isConfirmingDelete = false
    @FocusState private var isAdding: Bool

    var body: some View {
        List {
            Section {
                Toggle("Memory", isOn: $isEnabled)
            } footer: {
                Text("Add things PocketAI should always know about you, like “I'm vegetarian”. Memories stay on your device.")
            }

            Section("Saved Memories") {
                ForEach(items, id: \.self) { item in
                    Text(item)
                }
                .onDelete { offsets in
                    items.remove(atOffsets: offsets)
                    Memory.items = items
                }

                if items.count < Memory.limit {
                    HStack {
                        TextField("Add a memory", text: $newItem)
                            .focused($isAdding)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Button("Add", systemImage: "plus.circle.fill", action: add)
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .tint(theme.color)
                            .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            if !items.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete All", systemImage: "trash", role: .destructive) {
                        isConfirmingDelete = true
                    }
                }
            }
        }
        .confirmationDialog("Delete all memories?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) {
                items = []
                Memory.items = []
            }
        }
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add() {
        Memory.add(newItem)
        items = Memory.items
        newItem = ""
        isAdding = false
    }
}

enum ResponseTone: String, CaseIterable {
    case standard, efficient, friendly, professional

    var name: String {
        switch self {
        case .standard: String(localized: "Default")
        case .efficient: String(localized: "Efficient")
        case .friendly: String(localized: "Friendly")
        case .professional: String(localized: "Professional")
        }
    }

    var instruction: String? {
        switch self {
        case .standard: nil
        case .efficient: "Be efficient: go straight to the point, without filler or small talk."
        case .friendly: "Be warm and friendly, like a helpful friend."
        case .professional: "Use a professional, precise and formal tone."
        }
    }
}

enum EmojiUse: String, CaseIterable {
    case standard, fewer, more

    var name: String {
        switch self {
        case .standard: String(localized: "Default")
        case .fewer: String(localized: "Fewer")
        case .more: String(localized: "More")
        }
    }

    var instruction: String? {
        switch self {
        case .standard: nil
        case .fewer: "Do not use emojis."
        case .more: "Use a few emojis where they fit."
        }
    }
}

struct KeyboardDismisser: UIViewRepresentable {
    func makeUIView(context: Context) -> DismissView {
        DismissView()
    }

    func updateUIView(_ uiView: DismissView, context: Context) {}

    final class DismissView: UIView, UIGestureRecognizerDelegate {
        private lazy var tap: UITapGestureRecognizer = {
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            return tap
        }()

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            tap.view?.removeGestureRecognizer(tap)
            newWindow?.addGestureRecognizer(tap)
        }

        @objc private func dismiss() {
            window?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            !sequence(first: touch.view, next: { $0?.superview }).contains { $0 is UITextInput }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

extension View {
    @ViewBuilder
    func disablesVerticalToolbar() -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(.disabled)
        } else {
            self
        }
    }
}
