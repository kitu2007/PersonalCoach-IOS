import SwiftUI
import SwiftData

struct ReminderRow: View {
    @Bindable var reminder: Reminder
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(reminder.question)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: reminder.isActive ? "bell.fill" : "bell.slash")
                    .foregroundColor(reminder.isActive ? .blue : .gray)
            }
            
            if !reminder.times.isEmpty {
                let sortedTimes = reminder.times.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
                let timeStrings = sortedTimes.map { $0.timeString }
                let displayText: String
                if timeStrings.count <= 3 {
                    displayText = timeStrings.joined(separator: ", ")
                } else {
                    let firstThree = timeStrings.prefix(3).joined(separator: ", ")
                    let remaining = timeStrings.count - 3
                    displayText = "\(firstThree) +\(remaining) more"
                }
                Text(displayText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let lastResponse = reminder.lastResponse, !lastResponse.isEmpty {
                Text("Last response: \(lastResponse)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let reminder = Reminder(
        question: "Did you drink water?",
        isActive: true,
        times: [
            ReminderTime(hour: 9, minute: 0, periodId: UUID()),
            ReminderTime(hour: 13, minute: 0, periodId: UUID())
        ],
        responseType: .yesNo
    )
    
    List {
        ReminderRow(reminder: reminder)
    }
    .modelContainer(for: Reminder.self, inMemory: true)
}
