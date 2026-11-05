//
//  FileAttachment.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 14/10/2026.
//

import Foundation
import PDFKit
import UniformTypeIdentifiers

struct FileAttachment: Codable, Hashable, Sendable {
    var name: String
    var text: String

    nonisolated static let maxCharacters = 8000

    static let contentTypes: [UTType] = [.pdf, .plainText, .utf8PlainText, .text, .rtf, .json, .commaSeparatedText, .tabSeparatedText, .sourceCode, .html, .xml, .yaml, .image]

    var symbol: String {
        switch (name as NSString).pathExtension.lowercased() {
        case "pdf": "doc.richtext"
        case "csv", "tsv": "tablecells"
        case "json", "xml", "yaml", "yml", "html", "swift", "py", "js", "ts", "c", "cpp", "java", "kt", "rb", "go", "rs", "sh": "chevron.left.forwardslash.chevron.right"
        default: "doc.text"
        }
    }

    nonisolated static func read(_ url: URL) -> FileAttachment? {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
        }

        let text: String?
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true {
            text = PDFDocument(url: url)?.string
        } else if let plain = try? String(contentsOf: url, encoding: .utf8) {
            text = plain
        } else {
            text = try? NSAttributedString(url: url, options: [:], documentAttributes: nil).string
        }

        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let clipped = text.count > maxCharacters ? String(text.prefix(maxCharacters)) + "\n[…]" : text
        return FileAttachment(name: url.lastPathComponent, text: clipped)
    }

    static func prompt(_ message: String, files: [FileAttachment]) -> String {
        guard !files.isEmpty else { return message }
        let documents = files.map { "File: \($0.name)\n\"\"\"\n\($0.text)\n\"\"\"" }.joined(separator: "\n\n")
        return "\(documents)\n\n\(message)"
    }
}
