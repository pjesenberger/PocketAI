//
//  Conversation.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 11/10/2026.
//

import Foundation
import SwiftData

@Model
final class Conversation {
    var title: String
    var createdAt: Date
    var isPinned = false
    var isLocked = false
    var hasUnreadReply = false
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    init(title: String = String(localized: "New chat"), createdAt: Date = .now) {
        self.title = title
        self.createdAt = createdAt
    }
}
