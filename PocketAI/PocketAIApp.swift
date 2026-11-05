//
//  PocketAIApp.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 10/10/2026.
//

import SwiftUI
import SwiftData

@main
struct PocketAIApp: App {
    @State private var models = ModelStore()
    @State private var updates = UpdateChecker()

    var body: some Scene {
        WindowGroup {
            ChatView()
                .environment(models)
                .environment(updates)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [Conversation.self, Message.self, Shortcut.self])
    }
}
