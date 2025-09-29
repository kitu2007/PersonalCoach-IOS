import Foundation
import SwiftData
import OSLog

// Represents a specific time period for reminders
struct TimePeriod: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var emoji: String
    var hour: Int
    var minute: Int
    var isEnabled: Bool
    
    var displayName: String {
        "\(emoji) \(name) (\(formattedTime))"
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
    
    var timeComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }
    
    // Default time periods
    static let defaultPeriods: [TimePeriod] = [
        TimePeriod(name: "Morning Routine", emoji: "🌅", hour: 9, minute: 30, isEnabled: true),
        TimePeriod(name: "Morning", emoji: "🌞", hour: 11, minute: 0, isEnabled: true),
        TimePeriod(name: "Early Afternoon", emoji: "🕛", hour: 13, minute: 0, isEnabled: true),
        TimePeriod(name: "Afternoon Ritual", emoji: "🧘", hour: 14, minute: 0, isEnabled: true),
        TimePeriod(name: "Mid Afternoon", emoji: "☕", hour: 15, minute: 30, isEnabled: true),
        TimePeriod(name: "Evening", emoji: "🌆", hour: 18, minute: 30, isEnabled: true),
        TimePeriod(name: "Early Night", emoji: "🌃", hour: 21, minute: 0, isEnabled: true),
        TimePeriod(name: "Late Night", emoji: "🌙", hour: 23, minute: 0, isEnabled: true),
        TimePeriod(name: "Sleep Ritual", emoji: "😴", hour: 1, minute: 0, isEnabled: true)
    ]
    
    init(id: UUID = UUID(), name: String, emoji: String, hour: Int, minute: Int, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
    }
    
    // Create a copy with updated values
    func with(hour: Int? = nil, minute: Int? = nil, isEnabled: Bool? = nil) -> TimePeriod {
        return TimePeriod(
            id: self.id,
            name: self.name,
            emoji: self.emoji,
            hour: hour ?? self.hour,
            minute: minute ?? self.minute,
            isEnabled: isEnabled ?? self.isEnabled
        )
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Represents a specific time slot for reminders
@Model
final class ReminderTime: Identifiable, Hashable, @unchecked Sendable {
    @Attribute(.unique) var id = UUID()
    var hour: Int
    var minute: Int
    var periodId: UUID
    
    // Relationship to Reminder
    @Relationship(deleteRule: .cascade, inverse: \Reminder.times) var reminder: Reminder?
    
    init(hour: Int, minute: Int, periodId: UUID) {
        self.hour = hour
        self.minute = minute
        self.periodId = periodId
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
    
    var dateComponents: DateComponents {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return components
    }
    
    // Required for Hashable conformance
    nonisolated static func == (lhs: ReminderTime, rhs: ReminderTime) -> Bool {
        lhs.id == rhs.id
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Create a thread-safe copy
    func copy() -> ReminderTime {
        return ReminderTime(hour: hour, minute: minute, periodId: periodId)
    }
}

// Represents a reminder
@Model
final class Reminder: Identifiable, @unchecked Sendable {
    @Attribute(.unique) var id = UUID()
    var question: String
    var isActive: Bool
    var lastAsked: Date?
    var lastResponse: String?
    var lastResponseDate: Date?
    var responseCount: Int?
    var responseType: ReminderResponseType
    
    // Relationship to ReminderTime
    @Relationship(deleteRule: .cascade) var times: [ReminderTime] = []
    
    init(question: String, isActive: Bool = true, times: [ReminderTime] = [], responseType: ReminderResponseType = .yesNo) {
        self.question = question
        self.isActive = isActive
        self.responseType = responseType
        self.times = times
    }
    
    // Helper function to schedule notifications
    func scheduleNotifications() {
        Task { [weak self] in
            guard let self = self else { return }
            await NotificationManager.shared.scheduleNotifications(for: self)
        }
    }
    
    // Add a new time to this reminder
    @MainActor
    func addTime(_ time: ReminderTime) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.times.contains(where: { $0.periodId == time.periodId }) {
                self.times.append(time)
            }
        }
    }
    
    // Remove a time from this reminder
    @MainActor
    func removeTime(withId periodId: UUID) {
        DispatchQueue.main.async { [weak self] in
            self?.times.removeAll { $0.periodId == periodId }
        }
    }
    
    // Check if this reminder has a specific time period
    func hasTimePeriod(_ periodId: UUID) -> Bool {
        var result = false
        DispatchQueue.main.sync { [weak self] in
            result = self?.times.contains { $0.periodId == periodId } ?? false
        }
        return result
    }
}

// Your specific routines and tasks
let routines: [(name: String, times: [(hour: Int, minute: Int)], responseType: ReminderResponseType)] = [
    // Morning Routine
    ("Morning Routine", [(11, 0)], .both),
    ("Water", [(11, 0)], .yesNo),
    ("Sun exposure", [(11, 0)], .yesNo),
    ("Yoga/intention motion", [(11, 0)], .yesNo),
    ("Mental primer/Planning", [(11, 0)], .text),
    ("Breakfast", [(11, 0)], .yesNo),
    ("Meditation/Journaling", [(11, 0)], .yesNo),
    
    // Afternoon
    ("Lunch", [(16, 0)], .yesNo),
    ("Diffuse/Sensory reset", [(16, 0)], .yesNo),
    ("What's important/Reflection", [(16, 0)], .text),
    
    // Evening
    ("Exercise", [(18, 0)], .yesNo),
    ("Play with Guai/Eat/Nap", [(19, 0), (21, 0)], .yesNo),
    ("Nap", [(20, 30)], .yesNo),
    
    // Night
    ("Brain dump", [(22, 0)], .text),
    ("Looking forward to", [(22, 0)], .text),
    ("Gratitude", [(22, 0)], .text),
    ("Reflection", [(22, 0)], .text),
    ("One thing looking forward", [(22, 0)], .text)
]

// Default questions with suggested time periods
let defaultQuestions: [(question: String, timePeriods: [TimePeriod])] = [
    ("Did you drink enough water today?", [
        TimePeriod.defaultPeriods[0],  // Morning Routine
        TimePeriod.defaultPeriods[2],  // Early Afternoon
        TimePeriod.defaultPeriods[5]   // Evening
    ]),
    ("Did you take breaks from sitting?", [
        TimePeriod.defaultPeriods[1],  // Morning
        TimePeriod.defaultPeriods[4],  // Mid Afternoon
        TimePeriod.defaultPeriods[6]   // Early Night
    ]),
    ("Have you had your breakfast?", [
        TimePeriod.defaultPeriods[0]   // Morning Routine
    ]),
    ("Have you had your lunch?", [
        TimePeriod.defaultPeriods[2]   // Early Afternoon
    ]),
    ("Have you had your dinner?", [
        TimePeriod.defaultPeriods[5]   // Evening
    ]),
    ("Did you complete your workout today?", [
        TimePeriod.defaultPeriods[5],  // Evening
        TimePeriod.defaultPeriods[6]   // Early Night
    ]),
    ("Have you taken your medication?", [
        TimePeriod.defaultPeriods[0],  // Morning Routine
        TimePeriod.defaultPeriods[6]   // Early Night
    ]),
    ("Did you practice mindfulness today?", [
        TimePeriod.defaultPeriods[0],  // Morning Routine
        TimePeriod.defaultPeriods[3],  // Afternoon Ritual
        TimePeriod.defaultPeriods[8]   // Sleep Ritual
    ]),
    ("Are you ready for bed? Time to wind down.", [
        TimePeriod.defaultPeriods[7]   // Late Night
    ]),
    ("Time for some deep breathing exercises", [
        TimePeriod.defaultPeriods[3]   // Afternoon Ritual
    ]),
    ("Have you planned your day ahead?", [
        TimePeriod.defaultPeriods[1]   // Morning
    ]),
    ("Time for a quick stretch break", [
        TimePeriod.defaultPeriods[4]   // Mid Afternoon
    ]),
    ("Have you reviewed your goals for today?", [
        TimePeriod.defaultPeriods[6]   // Early Night
    ])
]
