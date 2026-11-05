//
//  FoundationModelsEngine.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 11/10/2026.
//

import Foundation
import FoundationModels
import MLXFoundationModels
import NaturalLanguage
import Synchronization
import UIKit

final class FoundationModelsEngine {
    private var model: any LanguageModel = SystemLanguageModel.default
    private let maxHistoryCharacters = 6000
    private var session: LanguageModelSession?
    private var sessionInstructions = ""
    private var sessionTurnCount = 0
    private var sessionIsTask = false

    var unavailableReason: String? {
        guard let model = model as? SystemLanguageModel else { return nil }
        return switch model.availability {
        case .available:
            nil
        case .unavailable(.deviceNotEligible):
            String(localized: "Download a model in Models to start chatting.")
        case .unavailable(.appleIntelligenceNotEnabled):
            String(localized: "Turn on Apple Intelligence in Settings to use PocketAI.")
        case .unavailable(.modelNotReady):
            String(localized: "The on-device model is still downloading. Try again in a moment.")
        case .unavailable:
            String(localized: "The on-device model is unavailable.")
        }
    }

    var supportsImages: Bool {
        model.capabilities.contains(.vision)
    }

    private var usesGPU: Bool {
        !(model is SystemLanguageModel)
    }

    var canRunInBackground: Bool {
        !usesGPU
    }

    func prewarm() {
        if let mlx = model as? MLXLanguageModel {
            Task {
                guard await mlx.availability == .available else { return }
                try? await mlx.preload()
            }
            return
        }
        guard session == nil, unavailableReason == nil else { return }
        startSession(instructions).prewarm()
    }

    func reset() {
        session = nil
    }

    func use(_ model: any LanguageModel) {
        self.model = model
        session = nil
    }

    func reply(to turns: [ChatTurn], extraInstructions: [String]) -> AsyncThrowingStream<String, Error> {
        let instructions = instructions
        let images = turns.last?.images.compactMap { UIImage(data: $0)?.cgImage } ?? []
        let isTask = !extraInstructions.isEmpty
        let history = Array(turns.dropLast())
        let session = if let session, sessionInstructions == instructions, sessionIsTask == isTask, sessionTurnCount == history.count {
            session
        } else {
            startSession(instructions, history: history, isTask: isTask)
        }
        let text = prompt(turns.last?.content ?? "", extraInstructions: extraInstructions, language: Self.language(of: turns))
        let filter = RepetitionFilter(previous: extraInstructions.isEmpty ? history.filter { $0.role == .assistant }.map(\.content) : [])

        let usesGPU = usesGPU
        return AsyncThrowingStream { continuation in
            let task = Task {
                var used = session
                do {
                    try await ModelLock.run(if: usesGPU) {
                        var reply: String
                        do {
                            reply = try await self.stream(used, text: text, images: images, filter: filter, into: continuation)
                        } catch LanguageModelError.contextSizeExceeded {
                            used = self.startSession(instructions, history: Array(self.trimmed(history).suffix(2)), isTask: isTask)
                            reply = try await self.stream(used, text: text, images: images, filter: filter, into: continuation)
                        }
                        if reply.isEmpty {
                            used = self.startSession(instructions, history: history, isTask: isTask)
                            reply = try await self.stream(used, text: text, images: images, filter: filter, into: continuation)
                        }
                        if reply.isEmpty {
                            throw ResponseError.empty
                        }
                    }
                    if self.session === used {
                        self.sessionTurnCount = turns.count + 1
                    }
                    continuation.finish()
                } catch {
                    if self.session === used || self.session === session {
                        self.session = nil
                    }
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @discardableResult
    private func startSession(_ instructions: String, history: [ChatTurn] = [], isTask: Bool = false) -> LanguageModelSession {
        let model: any LanguageModel = isTask && self.model is SystemLanguageModel ? SystemLanguageModel(guardrails: .permissiveContentTransformations) : self.model
        let session: LanguageModelSession
        if history.isEmpty {
            session = LanguageModelSession(model: model, instructions: instructions)
        } else {
            var entries: [Transcript.Entry] = [.instructions(Transcript.Instructions(segments: [segment(instructions)], toolDefinitions: []))]
            for turn in trimmed(history) {
                let content = turn.images.isEmpty ? turn.content : "[image] \(turn.content)"
                if turn.role == .user {
                    entries.append(.prompt(Transcript.Prompt(segments: [segment(content)])))
                } else {
                    entries.append(.response(Transcript.Response(assetIDs: [], segments: [segment(content)])))
                }
            }
            session = LanguageModelSession(model: model, transcript: Transcript(entries: entries))
        }
        self.session = session
        sessionInstructions = instructions
        sessionIsTask = isTask
        sessionTurnCount = history.count
        return session
    }

    private func segment(_ text: String) -> Transcript.Segment {
        .text(Transcript.TextSegment(content: text))
    }

    private func trimmed(_ history: [ChatTurn]) -> [ChatTurn] {
        var kept: [ChatTurn] = []
        var length = 0
        for turn in history.reversed() {
            length += turn.content.count
            if length > maxHistoryCharacters { break }
            kept.insert(turn, at: 0)
        }
        if kept.first?.role == .assistant {
            kept.removeFirst()
        }
        return kept
    }

    private func stream(_ session: LanguageModelSession, text: String, images: [CGImage], filter: RepetitionFilter, into continuation: AsyncThrowingStream<String, Error>.Continuation) async throws -> String {
        let responses = if images.isEmpty {
            session.streamResponse(to: text)
        } else {
            session.streamResponse {
                text
                for image in images {
                    Attachment(image)
                }
            }
        }
        let watchdog = Watchdog(first: usesGPU ? .seconds(90) : .seconds(30))
        return try await withThrowingTaskGroup(of: String?.self) { group in
            group.addTask {
                try await watchdog.run()
                return nil
            }
            group.addTask {
                var latest = ""
                var yieldedAt = ContinuousClock.now - .seconds(1)
                for try await snapshot in responses {
                    watchdog.touch()
                    latest = snapshot.content
                    if yieldedAt.duration(to: .now) >= .milliseconds(33) {
                        continuation.yield(filter.apply(to: Self.removingThinking(latest)))
                        yieldedAt = .now
                    }
                }
                let reply = filter.apply(to: Self.removingThinking(latest))
                if !reply.isEmpty {
                    continuation.yield(reply)
                }
                return reply
            }
            defer { group.cancelAll() }
            let reply = try await group.next().flatMap(\.self) ?? ""
            try Task.checkCancellation()
            return reply
        }
    }

    nonisolated private static func removingThinking(_ text: String) -> String {
        var result = text
        while let start = result.range(of: "<think>") {
            if let end = result.range(of: "</think>", range: start.upperBound..<result.endIndex) {
                result.removeSubrange(start.lowerBound..<end.upperBound)
            } else {
                result.removeSubrange(start.lowerBound..<result.endIndex)
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var replyLanguage: String {
        Locale(identifier: "en").localizedString(forIdentifier: Bundle.main.preferredLocalizations.first ?? "en") ?? "English"
    }

    static func language(of turns: [ChatTurn]) -> String {
        let recognizer = NLLanguageRecognizer()
        for turn in turns.reversed() where turn.role == .user {
            let text = turn.content.replacing(/```[\s\S]*?```|`[^`]*`|https?:\/\/\S+/, with: " ")
            guard text.filter(\.isLetter).count >= 8 else { continue }
            recognizer.reset()
            recognizer.processString(text)
            if let top = recognizer.languageHypotheses(withMaximum: 1).first, top.value >= 0.8,
               let name = Locale(identifier: "en").localizedString(forLanguageCode: top.key.rawValue) {
                return name
            }
        }
        return replyLanguage
    }

    private func prompt(_ message: String, extraInstructions: [String], language: String) -> String {
        guard !extraInstructions.isEmpty else { return "\(message)\n\n(Reply in \(language), unless I ask for another language.)" }
        let language = Self.replyLanguage
        return """
        Task:
        \(extraInstructions.joined(separator: "\n\n"))

        Do this task on the text below, even if it is a single word. Reply with the result only. Write any explanation in \(language).

        Text:
        \"\"\"
        \(message)
        \"\"\"
        """
    }

    private var instructions: String {
        var sections = ["You are PocketAI, a helpful assistant that runs privately on the user's device. Reply naturally to what the user says. Reply in the language the user writes in, unless they ask for another language. If it is unclear, reply in \(Self.replyLanguage)."]
        let defaults = UserDefaults.standard
        var preferences = [
            ResponseTone(rawValue: defaults.string(forKey: "responseTone") ?? "")?.instruction,
            EmojiUse(rawValue: defaults.string(forKey: "emojiUse") ?? "")?.instruction
        ].compactMap(\.self)
        if let custom = defaults.string(forKey: "customInstructions")?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            preferences.append(custom)
        }
        if !preferences.isEmpty {
            sections.append("# The user's preferences\n" + preferences.joined(separator: "\n"))
        }
        if Memory.isEnabled, !Memory.items.isEmpty {
            sections.append("# What the user wants you to know\n" + Memory.items.map { "- \($0)" }.joined(separator: "\n"))
        }
        sections.append("# Tasks\nSome messages start with a task. Do that task on the text and reply with the result only.")
        return sections.joined(separator: "\n\n")
    }
}

nonisolated enum ResponseError: LocalizedError {
    case empty, timedOut

    var errorDescription: String? {
        switch self {
        case .empty: String(localized: "The model didn't reply. Try again.")
        case .timedOut: String(localized: "The model took too long to reply. Try again.")
        }
    }
}

nonisolated final class Watchdog: Sendable {
    private let deadline: Mutex<ContinuousClock.Instant>
    private let interval: Duration

    init(first: Duration, interval: Duration = .seconds(20)) {
        deadline = Mutex(.now + first)
        self.interval = interval
    }

    func touch() {
        deadline.withLock { $0 = .now + interval }
    }

    func run() async throws {
        while true {
            let deadline = deadline.withLock { $0 }
            if deadline <= .now {
                throw ResponseError.timedOut
            }
            try await Task.sleep(until: deadline)
        }
    }
}

nonisolated final class RepetitionFilter: @unchecked Sendable {
    private let known: [Set<String>]
    private var cache: [String: Bool] = [:]
    private let threshold = 0.5
    private let minimumWords = 5

    init(previous: [String]) {
        known = previous
            .flatMap { $0.components(separatedBy: "\n").flatMap(Self.sentences) }
            .map(Self.words)
            .filter { $0.count >= 5 }
    }

    func apply(to text: String) -> String {
        var seen: [Set<String>] = []
        var lines: [String] = []
        var isInCode = false

        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                isInCode.toggle()
            }
            guard !isInCode, !line.trimmingCharacters(in: .whitespaces).isEmpty else {
                lines.append(line)
                continue
            }

            let marker = line.prefixMatch(of: /\s*(?:[-*•+]|\d+[.)]|#{1,6})\s+/).map { String($0.output) } ?? ""
            let kept = Self.sentences(String(line.dropFirst(marker.count))).filter { sentence in
                let words = Self.words(sentence)
                guard words.count >= minimumWords else { return true }
                if isKnown(sentence, words) || seen.contains(where: { Self.similarity($0, words) >= threshold }) {
                    return false
                }
                seen.append(words)
                return true
            }
            if !kept.isEmpty {
                lines.append(marker + kept.joined())
            }
        }

        let result = lines.joined(separator: "\n")
        return result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? text : result
    }

    private func isKnown(_ sentence: String, _ words: Set<String>) -> Bool {
        if let cached = cache[sentence] { return cached }
        let isKnown = known.contains { Self.similarity($0, words) >= threshold }
        cache[sentence] = isKnown
        return isKnown
    }

    nonisolated private static func sentences(_ text: String) -> [String] {
        text.matches(of: /.+?(?:[.!?]+(?=\s|$)|$)\s*/).map { String($0.output) }
    }

    nonisolated private static func words(_ text: String) -> Set<String> {
        Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }.filter { $0.count > 2 }.map(String.init))
    }

    nonisolated private static func similarity(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        Double(lhs.intersection(rhs).count) / Double(max(lhs.union(rhs).count, 1))
    }
}

actor ModelLock {
    private static let shared = ModelLock()
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    static func run<T>(if isNeeded: Bool = true, _ operation: () async throws -> T) async throws -> T {
        guard isNeeded else { return try await operation() }
        await shared.acquire()
        do {
            try Task.checkCancellation()
            let result = try await operation()
            await shared.release()
            return result
        } catch {
            await shared.release()
            throw error
        }
    }

    private func acquire() async {
        guard isBusy else {
            isBusy = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if waiters.isEmpty {
            isBusy = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

nonisolated enum Memory {
    static let key = "memories"
    static let limit = 15

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "memoryEnabled") as? Bool ?? true
    }

    static var items: [String] {
        get { UserDefaults.standard.stringArray(forKey: key) ?? [] }
        set { UserDefaults.standard.set(Array(newValue.suffix(limit)), forKey: key) }
    }

    static func add(_ fact: String) {
        let fact = fact.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"")))
        guard !fact.isEmpty else { return }
        items = items.filter { $0.caseInsensitiveCompare(fact) != .orderedSame } + [fact]
    }
}
