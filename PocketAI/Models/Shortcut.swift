//
//  Shortcut.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 13/10/2026.
//

import Foundation
import SwiftData

@Model
final class Shortcut {
    var id: UUID
    var name: String
    var symbol: String
    var prompt: String
    var isPinned: Bool
    var order: Int
    var isBuiltIn = false
    var defaultSymbol = ""
    var isEdited = false

    private static let nameKeys = [
        "text.alignleft": "Concise",
        "translate": "Translate",
        "flame": "Calories",
        "text.viewfinder": "Extract Text"
    ]

    var original: Shortcut? {
        guard isBuiltIn else { return nil }
        return Shortcut.defaults().first { $0.symbol == defaultSymbol }
    }

    func differs(from other: Shortcut) -> Bool {
        name != other.name || symbol != other.symbol || prompt != other.prompt
    }

    static func syncBuiltIns(_ shortcuts: [Shortcut]) {
        let defaults = Shortcut.defaults()
        for shortcut in shortcuts where shortcut.isBuiltIn && !shortcut.isEdited {
            guard let original = defaults.first(where: { $0.symbol == shortcut.defaultSymbol }) else { continue }
            guard shortcut.symbol == shortcut.defaultSymbol, shortcut.hasDefaultName, shortcut.hasDefaultPrompt(original) else {
                shortcut.isEdited = true
                continue
            }
            if shortcut.name != original.name { shortcut.name = original.name }
            if shortcut.prompt != original.prompt { shortcut.prompt = original.prompt }
        }
    }

    private var hasDefaultName: Bool {
        guard let key = Self.nameKeys[defaultSymbol] else { return false }
        if name == key { return true }
        return Bundle.main.localizations.contains { code in
            guard let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else { return false }
            return bundle.localizedString(forKey: key, value: key, table: nil) == name
        }
    }

    private func hasDefaultPrompt(_ original: Shortcut) -> Bool {
        guard defaultSymbol == "translate" else { return prompt == original.prompt }
        let format = { (text: String) in text.components(separatedBy: "\n\nFormat:").last }
        return prompt.hasPrefix("Translate the text into ") && format(prompt) == format(original.prompt)
    }

    init(name: String, symbol: String, prompt: String, isPinned: Bool = true, order: Int, isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.symbol = symbol
        self.prompt = prompt
        self.isPinned = isPinned
        self.order = order
        self.isBuiltIn = isBuiltIn
        self.defaultSymbol = isBuiltIn ? symbol : ""
    }

    static func defaults() -> [Shortcut] {
        let language = Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "English"
        return [
            Shortcut(
                name: String(localized: "Concise"),
                symbol: "text.alignleft",
                prompt: "Answer the message in two or three sentences.",
                order: 0,
                isBuiltIn: true
            ),
            Shortcut(
                name: String(localized: "Translate"),
                symbol: "translate",
                prompt: "Translate the text into \(language). If it is already in \(language), translate it into English. Always translate it, even a single word or a polite particle like ครับ.\n\nFormat:\n**Translation in bold**\nIf the original or the translation uses a non-Latin script, add a second line with that text and its pronunciation in simple Latin letters, as a beginner would say it.\n\nExample for ปลา:\n**Fish**\nปลา (plaa)\n\nAdd one short note on tone or politeness only when it changes the meaning.",
                order: 1,
                isBuiltIn: true
            ),
            Shortcut(
                name: String(localized: "Calories"),
                symbol: "flame",
                prompt: "Estimate the calories of the food in the text or in the attached images. Assume typical portions when a quantity is missing.\n\nFormat:\n- One line per item with its quantity, kcal, and protein, carbs and fat in grams.\n- **Total: kcal** in bold.\n- One or two short tips, such as a lighter swap.",
                order: 2,
                isBuiltIn: true
            ),
            Shortcut(
                name: String(localized: "Extract Text"),
                symbol: "text.viewfinder",
                prompt: "Copy all the text from the attached images or the message exactly as written, with the same language, line breaks, lists and order. Do not translate, correct or comment. If there is no text, say so in one short sentence.",
                order: 3,
                isBuiltIn: true
            )
        ]
    }
}
