//
//  OnboardingView.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 14/10/2026.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(ModelStore.self) private var models
    @AppStorage("appIcon") private var appIcon = AppIconOption.current
    @Query(sort: \Shortcut.order) private var shortcuts: [Shortcut]
    @State private var step = 0
    @State private var choice = AIModel.recommended
    @State private var isCreating = false
    let onFinish: () -> Void

    private let pageCount = 3

    var body: some View {
        ZStack {
            switch step {
            case 0: welcome.transition(pageTransition)
            case 1: modelPage.transition(pageTransition)
            default: shortcutsPage.transition(pageTransition)
            }
        }
        .safeAreaBar(edge: .top) {
            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: index == step ? 22 : 8, height: 8)
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 4) {
                switch step {
                case 0: welcomeButtons
                case 1: modelButtons
                default: shortcutsButtons
                }
            }
            .frame(maxWidth: 504)
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .animation(.spring(duration: 0.45, bounce: 0.1), value: step)
        .sensoryFeedback(.impact(weight: .light), trigger: step)
        .sheet(isPresented: $isCreating) {
            ShortcutEditor(shortcut: nil, nextOrder: (shortcuts.map(\.order).max() ?? -1) + 1)
        }
    }

    private var pageTransition: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))
    }

    private func header(_ title: LocalizedStringKey, _ subtitle: LocalizedStringKey) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center, for: .alignment)
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    private var welcome: some View {
        page {
            VStack(spacing: 0) {
                PocketGlyph(option: appIcon, size: 88)
                    .padding(.top, 24)
                    .padding(.bottom, 28)

                header("PocketAI", "Your private AI, right on your device.")

                VStack(alignment: .leading, spacing: 24) {
                    feature("iphone", "Runs on your device", "The AI works directly on your device. Nothing is sent to a server.")
                    feature("airplane", "Works offline", "No internet needed once it's set up. Even in airplane mode.")
                    feature("lock.fill", "Private by design", "No account, no cloud, no tracking. Your chats stay with you.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 40)
            }
        }
    }

    private var welcomeButtons: some View {
        Button("Continue") { step = 1 }
            .buttonStyle(PrimaryButtonStyle())
    }

    private var modelPage: some View {
        page {
            VStack(spacing: 24) {
                header("Choose your AI", "It runs on your device. Download it once, then use it offline.")

                VStack(spacing: 12) {
                    ForEach(AIModel.all.filter(\.fitsDevice).sorted { $0 == AIModel.recommended && $1 != AIModel.recommended }) { model in
                        modelCard(model)
                    }
                }

                Text("Keep the app open while downloading.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var modelButtons: some View {
        Button("Continue") {
            models.choose(choice)
            step = 2
        }
        .buttonStyle(PrimaryButtonStyle())

        if AIModel.isAppleSupported {
            Button("Skip") { step = 2 }
                .font(.headline)
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
                .frame(height: 44)
        }
    }

    private func modelCard(_ model: AIModel) -> some View {
        let isSelected = choice == model

        return Button {
            choice = model
        } label: {
            HStack(spacing: 16) {
                ModelIcon(model: model, size: 36)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        model.styledName
                            .font(.headline)
                        if model == AIModel.recommended {
                            RecommendedBadge()
                        }
                    }
                    Text(model.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let size = model.size {
                        Text(size)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .secondary, isSelected ? Color.primary : .secondary)
            }
            .padding(20)
            .background(Color(uiColor: .secondarySystemBackground).opacity(isSelected ? 1 : 0.5), in: .rect(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(isSelected ? Color.primary : Color.primary.opacity(0.12), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var shortcutsPage: some View {
        page {
            VStack(spacing: 28) {
                header("Pick your shortcuts", "They sit above the keyboard. Tap one before sending to change the answer. Choose the ones to show.")

                VStack(spacing: 12) {
                    ForEach(shortcuts) { shortcut in
                        shortcutCard(shortcut)
                    }

                    Button {
                        isCreating = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "plus")
                                .font(.title3)
                                .frame(width: 32)
                            Text("Create your own")
                                .font(.headline)
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .padding(18)
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var shortcutsButtons: some View {
        Button("Start Chatting") {
            try? context.save()
            onFinish()
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private func shortcutCard(_ shortcut: Shortcut) -> some View {
        Button {
            shortcut.isPinned.toggle()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: shortcut.symbol)
                    .font(.title3)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(shortcut.name)
                        .font(.headline)
                    if let detail = Self.details[shortcut.symbol] {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: shortcut.isPinned ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(shortcut.isPinned ? Color(uiColor: .systemBackground) : .secondary, shortcut.isPinned ? Color.primary : .secondary)
            }
            .padding(18)
            .background(Color(uiColor: .secondarySystemBackground).opacity(shortcut.isPinned ? 1 : 0.5), in: .rect(cornerRadius: 22, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: shortcut.isPinned)
        .animation(.easeInOut(duration: 0.2), value: shortcut.isPinned)
    }

    private static let details: [String: LocalizedStringKey] = [
        "text.alignleft": "Short answers, a few sentences at most.",
        "translate": "Translates your message or the text in a photo.",
        "flame": "Estimates the calories of a meal from a photo or a list.",
        "text.viewfinder": "Copies all the text from a photo: receipts, menus, pages."
    ]

    private func feature(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            width = max(width, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct RecommendedBadge: View {
    var body: some View {
        Text("Recommended")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.green)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.green.opacity(0.18), in: .capsule)
    }
}
