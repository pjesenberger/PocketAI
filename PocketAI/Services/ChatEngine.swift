//
//  ChatEngine.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 11/10/2026.
//

import Foundation

struct ChatTurn: Sendable {
    let role: Message.Role
    let content: String
    var images: [Data] = []
}
