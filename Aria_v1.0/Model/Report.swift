//
//  Report.swift
//  Aria_v1.0
//
//  Created by Giovanni Michele on 11/12/25.
//


import Foundation

enum ChatRole: String, Codable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: ChatRole
    var content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: ChatRole, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

struct Report: Identifiable, Codable, Equatable {
    let id: UUID
    let objectName: String
    let createdAt: Date
    let prompt: String
    let response: String
}

