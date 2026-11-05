//
//  ModelStore.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 14/10/2026.
//

import SwiftUI
import FoundationModels
import HuggingFace
import MLXFoundationModels
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import MLXVLM
import Tokenizers

struct AIModel: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String
    let summary: String
    let size: String?
    let minimumMemory: UInt64
    var isRecommended = false
    var supportsVision = false

    var isBuiltIn: Bool { size == nil }

    static var recommended: AIModel {
        all.first { $0.isRecommended && $0.fitsDevice } ?? (isAppleSupported ? apple : all[1])
    }

    var isCustom: Bool { provider == "Custom" }

    var styledName: Text {
        guard let space = name.lastIndex(of: " "), name.hasSuffix("B"), name[space...].contains(where: \.isNumber) else {
            return Text(verbatim: name)
        }
        var styled = AttributedString(String(name[...space]))
        var variant = AttributedString(String(name[name.index(after: space)...]))
        variant.foregroundColor = .secondary
        styled.append(variant)
        return Text(styled)
    }

    var fitsDevice: Bool {
        isBuiltIn ? Self.isAppleSupported : ProcessInfo.processInfo.physicalMemory >= minimumMemory
    }

    static var isAppleSupported: Bool {
        if case .unavailable(.deviceNotEligible) = SystemLanguageModel.default.availability {
            return false
        }
        return true
    }

    var logo: ImageResource? {
        switch provider {
        case "Meta": .metaLogo
        case "Google": .googleLogo
        case "Alibaba": .qwenLogo
        default: nil
        }
    }

    static let apple = AIModel(
        id: "apple",
        name: "Apple Foundation",
        provider: "Apple",
        summary: String(localized: "Apple's on-device model, the one behind Apple Intelligence."),
        size: nil,
        minimumMemory: 0,
        supportsVision: true
    )

    static let all: [AIModel] = [
        apple,
        AIModel(
            id: LLMRegistry.llama3_2_1B_4bit.name,
            name: "Llama 3.2 1B",
            provider: "Meta",
            summary: String(localized: "Meta's lightest model. Quick answers on any device."),
            size: "0.7 GB",
            minimumMemory: 0
        ),
        AIModel(
            id: LLMRegistry.gemma3_1B_qat_4bit.name,
            name: "Gemma 3 1B",
            provider: "Google",
            summary: String(localized: "Google's compact model, good in many languages."),
            size: "0.8 GB",
            minimumMemory: 0
        ),
        AIModel(
            id: LLMRegistry.llama3_2_3B_4bit.name,
            name: "Llama 3.2 3B",
            provider: "Meta",
            summary: String(localized: "Smarter answers, great for writing and reasoning."),
            size: "1.8 GB",
            minimumMemory: 5_500_000_000
        ),
        AIModel(
            id: LLMRegistry.qwen3_5_2b_4bit.name,
            name: "Qwen 3.5 2B",
            provider: "Alibaba",
            summary: String(localized: "Alibaba's newest small model. Great in many languages."),
            size: "1.8 GB",
            minimumMemory: 5_500_000_000,
            isRecommended: true,
            supportsVision: true
        ),
        AIModel(
            id: LLMRegistry.qwen3_4b_4bit.name,
            name: "Qwen 3 4B",
            provider: "Alibaba",
            summary: String(localized: "Very smart for its size. Best for reasoning and code."),
            size: "2.3 GB",
            minimumMemory: 7_500_000_000
        ),
        AIModel(
            id: LLMRegistry.gemma4_e2b_it_4bit.name,
            name: "Gemma 4 E2B",
            provider: "Google",
            summary: String(localized: "Google's latest generation. Balanced and capable."),
            size: "3.6 GB",
            minimumMemory: 7_500_000_000,
            supportsVision: true
        ),
        AIModel(
            id: LLMRegistry.gemma4_e4b_it_4bit.name,
            name: "Gemma 4 E4B",
            provider: "Google",
            summary: String(localized: "Google's most capable model here. For high-end devices."),
            size: "5.2 GB",
            minimumMemory: 11_000_000_000,
            supportsVision: true
        )
    ]

    var configuration: ModelConfiguration? {
        if isCustom {
            return ModelConfiguration(id: id)
        }
        return [LLMRegistry.llama3_2_1B_4bit, LLMRegistry.gemma3_1B_qat_4bit, LLMRegistry.llama3_2_3B_4bit, LLMRegistry.qwen3_5_2b_4bit, LLMRegistry.qwen3_4b_4bit, VLMRegistry.gemma4_E2B_it_4bit, VLMRegistry.gemma4_E4B_it_4bit]
            .first { $0.name == id }
    }
}

struct CustomModel: Codable, Hashable {
    let id: String
    let bytes: Int64
    let supportsVision: Bool

    var model: AIModel {
        AIModel(
            id: id,
            name: String(id.split(separator: "/").last ?? Substring(id)).replacingOccurrences(of: "-", with: " "),
            provider: "Custom",
            summary: id,
            size: String(format: "%.1f GB", Double(bytes) / 1_000_000_000),
            minimumMemory: UInt64(Double(bytes) * 2.1),
            supportsVision: supportsVision
        )
    }

    enum ImportError: LocalizedError {
        case notFound, notMLX, unsupported(String), offline

        var errorDescription: String? {
            switch self {
            case .notFound: String(localized: "This model wasn't found on Hugging Face.")
            case .notMLX: String(localized: "This model isn't in MLX format. Try one from mlx-community.")
            case .unsupported(let type): String(localized: "This model type (\(type)) isn't supported yet.")
            case .offline: String(localized: "Connect to the internet to add a model.")
            }
        }
    }

    private static let textTypes: Set<String> = ["mistral", "mixtral", "llama", "phi", "phi3", "phimoe", "gemma", "gemma2", "gemma3", "gemma3_text", "gemma3n", "gemma4", "gemma4_unified", "gemma4_text", "qwen2", "qwen3", "qwen3_moe", "qwen3_next", "qwen3_5", "qwen3_5_moe", "qwen3_5_text", "nanbeige", "minicpm", "starcoder2", "cohere", "openelm", "internlm2", "deepseek_v2", "deepseek_v3", "granite", "helium", "granitemoehybrid", "mimo", "mimo_v2_flash", "minimax", "glm4", "glm4_moe", "glm4_moe_lite", "acereason", "falcon_h1", "bitnet", "smollm3", "ernie4_5", "lfm2", "baichuan_m1", "exaone4", "gpt_oss", "olmoe", "olmo2", "olmo3", "bailing_moe", "lfm2_moe", "nanochat", "nemotron_h", "afmoe", "jamba", "mamba2", "mistral3", "apertus", "hunyuan_v1_dense"]
    private static let visionTypes: Set<String> = ["paligemma", "qwen2_vl", "qwen2_5_vl", "qwen3_vl", "qwen3_vl_moe", "qwen3_5", "qwen3_5_moe", "idefics3", "gemma3", "gemma4", "gemma4_unified", "smolvlm", "fastvlm", "llava_qwen2", "pixtral", "mistral3", "lfm2_vl", "glm_ocr"]

    static func inspect(_ input: String) async throws -> CustomModel {
        var id = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = id.range(of: "huggingface.co/") {
            id = String(id[range.upperBound...])
        }
        id = id.split(separator: "/").prefix(2).joined(separator: "/")
        guard id.contains("/"), let infoURL = URL(string: "https://huggingface.co/api/models/\(id)?blobs=true"), let configURL = URL(string: "https://huggingface.co/\(id)/resolve/main/config.json") else {
            throw ImportError.notFound
        }

        struct Info: Decodable {
            struct File: Decodable {
                let rfilename: String
                let size: Int64?
            }
            let siblings: [File]
            let pipeline_tag: String?
        }
        struct Config: Decodable {
            struct Text: Decodable {
                let model_type: String?
            }
            let model_type: String?
            let text_config: Text?
        }

        let (infoData, infoResponse): (Data, URLResponse)
        do {
            (infoData, infoResponse) = try await URLSession.shared.data(from: infoURL)
        } catch {
            throw ImportError.offline
        }
        guard (infoResponse as? HTTPURLResponse)?.statusCode == 200, let info = try? JSONDecoder().decode(Info.self, from: infoData) else {
            throw ImportError.notFound
        }
        let files = Set(info.siblings.map(\.rfilename))
        guard files.contains(where: { $0.hasSuffix(".safetensors") }), files.contains("config.json"), files.contains("tokenizer.json") || files.contains("tokenizer.model") else {
            throw ImportError.notMLX
        }

        let (configData, _) = try await URLSession.shared.data(from: configURL)
        guard let config = try? JSONDecoder().decode(Config.self, from: configData), let type = config.model_type ?? config.text_config?.model_type else {
            throw ImportError.notMLX
        }
        guard textTypes.contains(type) || visionTypes.contains(type) else {
            throw ImportError.unsupported(type)
        }

        let bytes = info.siblings.reduce(0) { $0 + ($1.size ?? 0) }
        let vision = visionTypes.contains(type) && info.pipeline_tag == "image-text-to-text"
        return CustomModel(id: id, bytes: bytes, supportsVision: vision)
    }
}

@Observable
final class ModelStore {
    var selectedID = UserDefaults.standard.string(forKey: "selectedModel") ?? AIModel.apple.id {
        didSet { UserDefaults.standard.set(selectedID, forKey: "selectedModel") }
    }
    var downloaded: Set<String> = [AIModel.apple.id]
    var downloading: Set<String> = []
    var errorMessage: String?
    var pendingID: String?
    var completed: AIModel?
    var completedCount = 0
    var custom: [CustomModel] = (try? JSONDecoder().decode([CustomModel].self, from: UserDefaults.standard.data(forKey: "customModels") ?? Data())) ?? [] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(custom), forKey: "customModels") }
    }

    var all: [AIModel] {
        AIModel.all + custom.map(\.model)
    }

    @ObservationIgnored private var peakProgress: [String: Double] = [:]
    private var models: [String: MLXLanguageModel] = [:]
    private var tasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var interrupted: Set<String> = []
    @ObservationIgnored private var userCancelled: Set<String> = []
    @ObservationIgnored private var backgroundedAt: Date?
    @ObservationIgnored private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    init() {
        Task {
            await refresh()
        }
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                self?.endBackgroundTask()
                self?.resumeInterrupted()
            }
        }
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didEnterBackgroundNotification) {
                self?.backgroundedAt = .now
                self?.keepAliveInBackground()
            }
        }
    }

    private func keepAliveInBackground() {
        guard !downloading.isEmpty, backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private func resumeInterrupted() {
        let ids = interrupted
        interrupted.removeAll()
        for model in all where ids.contains(model.id) {
            download(model)
        }
    }

    var selected: AIModel {
        all.first { $0.id == selectedID } ?? .apple
    }

    private var fallbackID: String {
        (AIModel.isAppleSupported ? AIModel.apple : installed.first ?? AIModel.apple).id
    }

    var installed: [AIModel] {
        all.filter { downloaded.contains($0.id) && $0.fitsDevice }
    }

    func languageModel(for model: AIModel) -> any FoundationModels.LanguageModel {
        mlxModel(for: model) ?? SystemLanguageModel.default
    }

    func progress(of model: AIModel) -> Double {
        let current = MLXDownloadProgress.shared.download(forModelID: model.id)?.fractionCompleted ?? 0
        let peak = max(current, peakProgress[model.id] ?? 0)
        peakProgress[model.id] = peak
        return peak
    }

    func refresh() async {
        for model in all where !model.isBuiltIn {
            guard let mlx = mlxModel(for: model) else { continue }
            if await mlx.availability == .available {
                downloaded.insert(model.id)
            } else {
                downloaded.remove(model.id)
            }
        }
        if !installed.contains(selected) {
            selectedID = fallbackID
        }
    }

    func download(_ model: AIModel) {
        guard let mlx = mlxModel(for: model), tasks[model.id] == nil else { return }
        downloading.insert(model.id)
        userCancelled.remove(model.id)
        errorMessage = nil
        tasks[model.id] = Task {
            let startedAt = Date.now
            do {
                try await mlx.preload()
                downloaded.insert(model.id)
                completed = model
                completedCount += 1
                if pendingID == model.id {
                    pendingID = nil
                    select(model)
                } else if model.id != selectedID {
                    await mlx.evict()
                }
            } catch where !userCancelled.contains(model.id) {
                if UIApplication.shared.applicationState != .active || (backgroundedAt ?? .distantPast) > startedAt {
                    interrupted.insert(model.id)
                    tasks[model.id] = nil
                    if UIApplication.shared.applicationState == .active {
                        resumeInterrupted()
                    }
                    return
                }
                if !Self.isCancellation(error) {
                    errorMessage = error.localizedDescription
                }
            } catch {}
            downloading.remove(model.id)
            peakProgress[model.id] = nil
            tasks[model.id] = nil
            if downloading.isEmpty {
                endBackgroundTask()
            }
        }
    }

    func cancel(_ model: AIModel) {
        userCancelled.insert(model.id)
        interrupted.remove(model.id)
        downloading.remove(model.id)
        tasks[model.id]?.cancel()
        errorMessage = nil
        if pendingID == model.id {
            pendingID = nil
        }
        Task {
            await mlxModel(for: model)?.evict()
            delete(model)
        }
    }

    func delete(_ model: AIModel) {
        guard let mlx = mlxModel(for: model) else { return }
        downloaded.remove(model.id)
        custom.removeAll { $0.id == model.id }
        models[model.id] = nil
        if selectedID == model.id {
            selectedID = fallbackID
        }
        Task {
            await mlx.evict()
            var url = mlx.weightsLocation(mlx.modelID)
            while !url.lastPathComponent.hasPrefix("models--") && url.pathComponents.count > 2 {
                url.deleteLastPathComponent()
            }
            if url.lastPathComponent.hasPrefix("models--") {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    func add(_ model: CustomModel) {
        if let builtIn = AIModel.all.first(where: { $0.id.caseInsensitiveCompare(model.id) == .orderedSame }) {
            choose(builtIn)
            return
        }
        if !custom.contains(where: { $0.id == model.id }) {
            custom.append(model)
        }
        choose(model.model)
    }

    func choose(_ model: AIModel) {
        if downloaded.contains(model.id) {
            select(model)
        } else {
            pendingID = model.id
            download(model)
        }
    }

    func select(_ model: AIModel) {
        guard downloaded.contains(model.id), model.id != selectedID else { return }
        let previous = selected
        selectedID = model.id
        if let old = mlxModel(for: previous) {
            Task { await old.evict() }
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let error = error as NSError
        return (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) || (error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError)
    }

    private func mlxModel(for model: AIModel) -> MLXLanguageModel? {
        if let cached = models[model.id] { return cached }
        guard let configuration = model.configuration else { return nil }
        let mlx = #huggingFaceLanguageModel(configuration: configuration, capabilities: model.supportsVision ? [.guidedGeneration, .vision] : [.guidedGeneration])
        models[model.id] = mlx
        return mlx
    }
}
