import Foundation
import SwiftData

/// Stores a single response the user gives for a reminder at a point in time.
@Model
final class ResponseRecord: Identifiable {
    @Attribute(.unique) var id = UUID()
    var reminderID: UUID  // links back to Reminder.id
    var reminderQuestion: String
    var timestamp: Date
    var didComplete: Bool
    var text: String?
    var scaleValue: Int?
    
    init(reminder: Reminder, didComplete: Bool, text: String? = nil, scaleValue: Int? = nil) {
        self.reminderID = reminder.id
        self.reminderQuestion = reminder.question
        self.timestamp = .now
        self.didComplete = didComplete
        self.text = text
        self.scaleValue = scaleValue
    }
} 