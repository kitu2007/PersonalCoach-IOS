//
//  Session.swift
//  PersonalCoach
//
//  Created by Kshitiz on 6/22/25.
//

import Foundation
import SwiftData

@Model
final class Session: Identifiable {
    @Attribute(.unique) var id = UUID()
    var timestamp: Date
    var userText: String
    var assistantText: String
    
    init(_ user: String, _ ai: String) {
        self.timestamp = .now
        self.userText  = user
        self.assistantText = ai
    }
}
