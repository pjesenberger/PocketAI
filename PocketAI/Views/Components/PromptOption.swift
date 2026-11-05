//
//  PromptOption.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 11/10/2026.
//

import SwiftUI

struct PromptOption: View {
    let title: String
    let symbol: String
    @Binding var isSelected: Bool
    @AppStorage("theme") private var theme = AppTheme.white
    @AppStorage("compactShortcuts") private var isCompact = false

    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            if isCompact {
                Image(systemName: symbol)
                    .foregroundStyle(isSelected ? theme.onColor : .secondary)
                    .frame(width: 38, height: 38)
                    .contentShape(.circle)
                    .glassEffect(.regular.tint(isSelected ? theme.color : nil).interactive(), in: .circle)
            } else {
                Label(title, systemImage: symbol)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(isSelected ? theme.onColor : .secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 38)
                    .glassEffect(.regular.tint(isSelected ? theme.color : nil).interactive(), in: .capsule)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

#Preview {
    @Previewable @State var isSelected = false

    PromptOption(
        title: "Search",
        symbol: "globe",
        isSelected: $isSelected
    )
}
