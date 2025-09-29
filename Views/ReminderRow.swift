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
                Text(reminder.times.map { $0.timeString }.joined(separator: ", "))
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
