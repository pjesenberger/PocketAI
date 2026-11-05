//
//  ChatViewModel.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 11/10/2026.
//

import SwiftUI
import SwiftData
import FoundationModels
import LocalAuthentication

@Observable
final class ChatViewModel {
    var text = ""
    var selectedShortcuts: Set<UUID> = []
    var images: [Data] = []
    var files: [FileAttachment] = []
    var conversation: Conversation?
    private var replies: [ObjectIdentifier: Message] = [:]
    var errorMessage: String?
    var isTemporaryChat = false
    var editingMessage: Message?
    private(set) var supportsImages = false

    private let engine = FoundationModelsEngine()
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    @ObservationIgnored private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let temporaryContext = ModelContext(
        try! ModelContainer(
            for: Conversation.self, Message.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    )

    init() {
        supportsImages = engine.supportsImages
    }

    var unavailableReason: String? {
        engine.unavailableReason
    }

    var messages: [Message] {
        conversation?.messages.sorted { $0.createdAt < $1.createdAt } ?? []
    }

    var streamingReply: Message? {
        conversation.flatMap { replies[ObjectIdentifier($0)] }
    }

    var isResponding: Bool {
        streamingReply != nil
    }

    var respondingIDs: Set<ObjectIdentifier> {
        Set(replies.keys)
    }

    var canSend: Bool {
        !isResponding && (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty || !files.isEmpty) && unavailableReason == nil
    }

    func send(in persistentContext: ModelContext, instructions: [String] = []) {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }

        let images = self.images
        let files = self.files
        let context = isTemporaryChat ? temporaryContext : persistentContext

        if let editingMessage {
            for item in messages where item.createdAt >= editingMessage.createdAt {
                context.delete(item)
            }
            self.editingMessage = nil
            engine.reset()
        }

        let conversation = conversation ?? {
            let new = Conversation(title: prompt.isEmpty ? files.first?.name ?? String(localized: "Image") : String(prompt.prefix(40)))
            context.insert(new)
            self.conversation = new
            return new
        }()

        let request = prompt.isEmpty ? (instructions.isEmpty ? (files.isEmpty ? "Describe these images." : "Summarize this.") : "Use the attached content.") : prompt
        let turns = messages.map { ChatTurn(role: $0.role, content: FileAttachment.prompt($0.content, files: $0.files), images: $0.images) } + [ChatTurn(role: .user, content: FileAttachment.prompt(request, files: files), images: images)]

        let userMessage = Message(role: .user, content: prompt, images: images, files: files, conversation: conversation)
        context.insert(userMessage)

        let reply = Message(role: .assistant, content: "", createdAt: userMessage.createdAt.addingTimeInterval(0.001), conversation: conversation)
        context.insert(reply)

        text = ""
        self.images = []
        self.files = []
        selectedShortcuts = []
        stream(turns, into: reply, of: conversation, context: context, instructions: instructions)
    }

    func regenerate(in persistentContext: ModelContext) {
        guard !isResponding, let conversation, let reply = messages.last, reply.role == .assistant else { return }
        let history = messages.dropLast()
        guard let question = history.last, question.role == .user else { return }
        let context = isTemporaryChat ? temporaryContext : persistentContext

        var turns = history.map { ChatTurn(role: $0.role, content: FileAttachment.prompt($0.content, files: $0.files), images: $0.images) }
        if question.content.isEmpty {
            turns[turns.count - 1] = ChatTurn(role: .user, content: FileAttachment.prompt(question.files.isEmpty ? "Describe these images." : "Summarize this.", files: question.files), images: question.images)
        }

        let createdAt = reply.createdAt
        context.delete(reply)
        engine.reset()
        let newReply = Message(role: .assistant, content: "", createdAt: createdAt, conversation: conversation)
        context.insert(newReply)
        stream(turns, into: newReply, of: conversation, context: context, instructions: [])
    }

    private func stream(_ turns: [ChatTurn], into reply: Message, of owner: Conversation, context: ModelContext, instructions: [String]) {
        let id = ObjectIdentifier(owner)
        errorMessage = nil
        replies[id] = reply
        tasks[id] = Task {
            do {
                for try await partial in engine.reply(to: turns, extraInstructions: instructions) {
                    reply.content = partial
                }
            } catch is CancellationError {
            } catch LanguageModelError.guardrailViolation where owner == conversation {
                errorMessage = String(localized: "Apple's on-device model blocked this request. Try rephrasing it or use a downloaded model.")
            } catch where owner == conversation {
                errorMessage = error.localizedDescription
            } catch {}

            if reply.content.isEmpty {
                context.delete(reply)
            } else if owner != conversation {
                owner.hasUnreadReply = true
            }
            try? context.save()
            if replies[id] == reply {
                replies[id] = nil
                tasks[id] = nil
            }
            if tasks.isEmpty {
                endBackgroundTask()
            }
        }
    }

    private func cancel(_ conversation: Conversation?) {
        guard let conversation else { return }
        tasks[ObjectIdentifier(conversation)]?.cancel()
    }

    func startEditing(_ message: Message) {
        guard !isResponding else { return }
        editingMessage = message
        text = message.content
        images = message.images
        files = message.files
    }

    func cancelEditing() {
        guard editingMessage != nil else { return }
        editingMessage = nil
        text = ""
        images = []
        files = []
    }

    func prewarm() {
        engine.prewarm()
    }

    func use(_ model: any LanguageModel) {
        stopAll()
        engine.use(model)
        engine.prewarm()
        supportsImages = engine.supportsImages
        if !supportsImages {
            images = []
        }
    }

    func deleteAll(in context: ModelContext) {
        stopAll()
        newChat()
        try? context.delete(model: Message.self)
        try? context.delete(model: Conversation.self)
        try? context.save()
    }

    func stop() {
        cancel(conversation)
    }

    func stopAll() {
        tasks.values.forEach { $0.cancel() }
    }

    func enterBackground() {
        guard !tasks.isEmpty else { return }
        guard engine.canRunInBackground else {
            stopAll()
            return
        }
        endBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.stopAll()
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    func open(_ conversation: Conversation) {
        stopIfTemporary()
        cancelEditing()
        engine.reset()
        leaveTemporaryChat()
        self.conversation = conversation
        conversation.hasUnreadReply = false
        errorMessage = nil
    }

    func newChat() {
        stopIfTemporary()
        cancelEditing()
        engine.reset()
        leaveTemporaryChat()
        conversation = nil
        errorMessage = nil
    }

    func saveTemporaryChat(in persistentContext: ModelContext) {
        guard isTemporaryChat, !isResponding, let temporary = conversation else { return }
        let saved = Conversation(title: temporary.title, createdAt: temporary.createdAt)
        persistentContext.insert(saved)
        for message in temporary.messages {
            persistentContext.insert(Message(role: message.role, content: message.content, images: message.images, files: message.files, createdAt: message.createdAt, conversation: saved))
        }
        try? persistentContext.save()
        temporaryContext.delete(temporary)
        try? temporaryContext.save()
        conversation = saved
        isTemporaryChat = false
    }

    private func stopIfTemporary() {
        if isTemporaryChat {
            cancel(conversation)
        }
    }

    private func leaveTemporaryChat() {
        guard isTemporaryChat else { return }
        if let conversation {
            temporaryContext.delete(conversation)
            try? temporaryContext.save()
        }
        isTemporaryChat = false
    }

    func delete(_ conversation: Conversation, in context: ModelContext) {
        cancel(conversation)
        if conversation == self.conversation {
            newChat()
        }
        context.delete(conversation)
        try? context.save()
    }
}

enum ChatLock {
    static func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "Unlock this chat"))) ?? false
    }
}
