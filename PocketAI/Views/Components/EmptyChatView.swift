//
//  EmptyChatView.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 11/10/2026.
//

import SwiftUI

struct EmptyChatView: View {
    let isTemporaryChat: Bool
    let unavailableReason: String?
    @AppStorage("appIcon") private var appIcon = AppIconOption.current

    var body: some View {
        VStack(spacing: 16) {
            description
                .hidden()
                .accessibilityHidden(true)

            ZStack {
                if isTemporaryChat {
                    IncognitoGlyph(option: appIcon, size: 64)
                        .accessibilityLabel("Temporary Chat")
                        .transition(.opacity.combined(with: .offset(y: 12)))
                } else {
                    PocketGlyph(option: appIcon, size: 64)
                        .accessibilityLabel("PocketAI")
                        .transition(.opacity.combined(with: .offset(y: 12)))
                }
            }

            description
                .opacity(isTemporaryChat ? 1 : 0)
                .offset(y: isTemporaryChat ? 0 : 12)
                .accessibilityHidden(!isTemporaryChat)
        }
        .animation(.easeInOut(duration: 0.28), value: isTemporaryChat)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 48)
        .overlay(alignment: .bottom) {
            if let unavailableReason {
                Text(unavailableReason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 64)
            }
        }
        .padding(.horizontal)
        .ignoresSafeArea(.container, edges: .horizontal)
    }

    private var description: some View {
        Text("Not saved to your history.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    EmptyChatView(isTemporaryChat: true, unavailableReason: nil)
}
