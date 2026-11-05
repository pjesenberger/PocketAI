//
//  MessageBubble.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 11/10/2026.
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    var isStreaming = false
    var isBeingEdited = false
    var onEdit: (() -> Void)?
    var onRetry: (() -> Void)?
    @State private var isCopied = false
    @State private var isSelectingText = false
    @State private var copyCount = 0
    @AppStorage("theme") private var theme = AppTheme.white

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 48)
                VStack(alignment: .trailing, spacing: 6) {
                    ForEach(message.files, id: \.self) { file in
                        HStack(spacing: 10) {
                            Image(systemName: file.symbol)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text(file.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 16, style: .continuous))
                    }
                    if message.images.count == 1 {
                        MessageImage(data: message.images[0], maxSize: 220)
                    } else if !message.images.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(message.images.indices, id: \.self) { index in
                                MessageImage(data: message.images[index], maxSize: 72)
                            }
                        }
                    }
                    if !message.content.isEmpty {
                        Group {
                            if isSelectingText {
                                SelectableText(text: message.content) {
                                    isSelectingText = false
                                }
                            } else {
                                Text(message.content)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundStyle(.white)
                        .background(theme.tint, in: .rect(cornerRadius: 20, style: .continuous))
                        .contextMenu {
                            Button("Copy", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = message.content
                                copyCount += 1
                            }
                            if onEdit != nil {
                                Button("Edit", systemImage: "pencil") {
                                    onEdit?()
                                }
                            }
                            Button("Select Text", systemImage: "selection.pin.in.out") {
                                isSelectingText = true
                            }
                        }
                    }
                    if isBeingEdited {
                        Text("Editing this message will restart the conversation from this point.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .transition(.opacity)
                    }
                }
                .sensoryFeedback(.success, trigger: copyCount)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if message.content.isEmpty {
                        ThinkingIndicator()
                    } else {
                        MarkdownText(content: message.content)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 4) {
                        Button {
                            copy()
                        } label: {
                            Image(systemName: isCopied ? "checkmark" : "square.on.square")
                                .contentTransition(.symbolEffect(.replace, options: .speed(2)))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .sensoryFeedback(.success, trigger: isCopied) { _, new in new }
                        .accessibilityLabel("Copy")

                        if let onRetry {
                            Button(action: onRetry) {
                                Image(systemName: "arrow.clockwise")
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Try Again")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .opacity(isStreaming ? 0 : 1)
                    .disabled(isStreaming)
                    .animation(.easeInOut(duration: 0.2), value: isStreaming)
                }
                .task(id: isCopied) {
                    guard isCopied else { return }
                    try? await Task.sleep(for: .seconds(1.5))
                    isCopied = false
                }
                Spacer(minLength: 24)
            }
        }
    }

    private func copy() {
        UIPasteboard.general.string = message.content
        isCopied = true
    }
}

private struct MarkdownText: View {
    let content: String

    private enum Block {
        case heading(Int, String)
        case bullet(String)
        case numbered(String, String)
        case code(String)
        case divider
        case paragraph(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
    }

    @ViewBuilder
    private func view(for block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(level <= 2 ? .title3.weight(.semibold) : .headline)
                .padding(.top, 4)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                inline(text)
            }
        case .numbered(let marker, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(marker)
                    .monospacedDigit()
                inline(text)
            }
        case .code(let code):
            Text(code)
                .font(.system(.callout, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 12, style: .continuous))
        case .divider:
            Divider()
        case .paragraph(let text):
            inline(text)
        }
    }

    private func inline(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return Text((try? AttributedString(markdown: text, options: options)) ?? AttributedString(text))
    }

    private var blocks: [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var code: [String]?

        func flush() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph = []
        }

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if let lines = code {
                    blocks.append(.code(lines.joined(separator: "\n")))
                    code = nil
                } else {
                    flush()
                    code = []
                }
            } else if code != nil {
                code?.append(line)
            } else if trimmed.isEmpty {
                flush()
            } else if trimmed.wholeMatch(of: /(-{3,}|\*{3,}|_{3,})/) != nil {
                flush()
                blocks.append(.divider)
            } else if let match = trimmed.wholeMatch(of: /(#{1,6})\s+(.*)/) {
                flush()
                blocks.append(.heading(match.1.count, String(match.2)))
            } else if let match = trimmed.wholeMatch(of: /[-*•+]\s+(.*)/) {
                flush()
                blocks.append(.bullet(String(match.1)))
            } else if let match = trimmed.wholeMatch(of: /(\d+[.)])\s+(.*)/) {
                flush()
                blocks.append(.numbered(String(match.1), String(match.2)))
            } else {
                paragraph.append(trimmed)
            }
        }

        if let code {
            blocks.append(.code(code.joined(separator: "\n")))
        }
        flush()
        return blocks
    }
}

private struct SelectableText: UIViewRepresentable {
    let text: String
    let onEnd: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.text = text
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            textView.becomeFirstResponder()
            textView.selectAll(nil)
            coordinator.isActive = true
        }
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.onEnd = onEnd
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? .greatestFiniteMagnitude
        let font = uiView.font ?? .preferredFont(forTextStyle: .body)
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return CGSize(width: min(ceil(rect.width) + 1, width), height: ceil(rect.height))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onEnd: onEnd)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onEnd: () -> Void
        var isActive = false

        init(onEnd: @escaping () -> Void) {
            self.onEnd = onEnd
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if isActive && textView.selectedRange.length == 0 {
                onEnd()
            }
        }
    }
}

private struct MessageImage: View {
    let data: Data
    let maxSize: CGFloat

    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: maxSize, maxHeight: maxSize)
                .clipShape(.rect(cornerRadius: maxSize > 100 ? 16 : 10, style: .continuous))
        }
    }
}

private struct ThinkingIndicator: View {
    @AppStorage("appIcon") private var appIcon = AppIconOption.current
    @State private var style = PixelLoader.Style.allCases.randomElement() ?? .snake
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            PixelLoader(style: style, time: timeline.date.timeIntervalSince(start), colors: appIcon.colors)
        }
        .frame(height: 22)
        .accessibilityHidden(true)
    }
}

struct PixelLoader: View {
    enum Style: CaseIterable {
        case snake, cross, wave, burst, spiral
    }

    let style: Style
    let time: Double
    let colors: [Color]
    var cell: CGFloat = 6
    var gap: CGFloat = 2

    var body: some View {
        VStack(spacing: gap) {
            ForEach(0..<3) { row in
                HStack(spacing: gap) {
                    ForEach(0..<3) { column in
                        let amount = amount(row: row, column: column)
                        Rectangle()
                            .fill(colors[row * 2])
                            .frame(width: cell, height: cell)
                            .scaleEffect(amount)
                            .opacity(amount)
                    }
                }
            }
        }
    }

    private func amount(row: Int, column: Int) -> Double {
        let index = row * 3 + column
        switch style {
        case .snake:
            return sequence(index, order: [0, 1, 2, 5, 4, 3, 6, 7, 8])
        case .spiral:
            return sequence(index, order: [0, 1, 2, 5, 8, 7, 6, 3, 4])
        case .cross:
            let local = fraction(time / 0.8)
            let isShowing = (local < 0.5) == index.isMultiple(of: 2)
            return isShowing ? bump(fraction(local * 2)) : 0
        case .wave:
            return bump(fraction(time / 0.75 - Double(row + column) * 0.12))
        case .burst:
            let ring = index == 4 ? 0 : index.isMultiple(of: 2) ? 2 : 1
            return bump(fraction(time / 0.7 - Double(ring) * 0.16) * 1.6)
        }
    }

    private func sequence(_ index: Int, order: [Int]) -> Double {
        let step = 0.06
        let fillEnd = step * 9
        let local = fraction(time / (fillEnd + 0.4)) * (fillEnd + 0.4)
        let appear = clamp((local - Double(order.firstIndex(of: index) ?? 0) * step) / step)
        let disappear = 1 - clamp((local - fillEnd - 0.15) / 0.2)
        return appear * disappear
    }

    private func bump(_ value: Double) -> Double {
        value >= 1 ? 0 : pow(sin(.pi * value), 0.7)
    }

    private func fraction(_ value: Double) -> Double {
        value - value.rounded(.down)
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBubble(message: Message(role: .user, content: "Hello"))
        MessageBubble(message: Message(role: .assistant, content: "Hi! How can I help?"))
    }
    .padding()
}
