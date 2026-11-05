//
//  Message.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 11/10/2026.
//

import Foundation
import SwiftData

@Model
final class Message {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var role: Role
    var content: String
    var images: [Data] = []
    var files: [FileAttachment] = []
    var createdAt: Date
    var conversation: Conversation?

    init(role: Role, content: String, images: [Data] = [], files: [FileAttachment] = [], createdAt: Date = .now, conversation: Conversation? = nil) {
        self.role = role
        self.content = content
        self.images = images
        self.files = files
        self.createdAt = createdAt
        self.conversation = conversation
    }
}
