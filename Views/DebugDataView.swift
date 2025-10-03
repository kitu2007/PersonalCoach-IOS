import SwiftUI
import SwiftData

struct DebugDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ResponseRecord.timestamp, order: .reverse) private var records: [ResponseRecord]
    @Query(sort: \Reminder.question) private var reminders: [Reminder]
    @Query(sort: \Session.timestamp, order: .reverse) private var sessions: [Session]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Database Location:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kg.personalcoach") {
                        Text(containerURL.path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section(header: HStack {
                    Text("Response Records")
                    Spacer()
                    Text("\(records.count)")
                        .foregroundStyle(.secondary)
                }) {
                    if records.isEmpty {
                        Text("No response records yet")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(records.prefix(20)) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.reminderQuestion)
                                    .font(.headline)
                                HStack {
                                    Label(record.didComplete ? "Complete" : "Skipped", 
                                          systemImage: record.didComplete ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(record.didComplete ? .green : .orange)
                                    Spacer()
                                    Text(record.timestamp.formatted(.dateTime.month().day().hour().minute()))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let text = record.text, !text.isEmpty {
                                    Text("Note: \(text)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let scale = record.scaleValue {
                                    Text("Scale: \(scale)/5")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        if records.count > 20 {
                            Text("+ \(records.count - 20) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section(header: HStack {
                    Text("Reminders")
                    Spacer()
                    Text("\(reminders.count)")
                        .foregroundStyle(.secondary)
                }) {
                    if reminders.isEmpty {
                        Text("No reminders yet")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(reminders) { reminder in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(reminder.question)
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: reminder.isActive ? "bell.fill" : "bell.slash")
                                        .foregroundStyle(reminder.isActive ? .blue : .gray)
                                }
                                Text("Times: \(reminder.times.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let lastResponse = reminder.lastResponse {
                                    Text("Last: \(lastResponse)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section(header: HStack {
                    Text("Chat Sessions")
                    Spacer()
                    Text("\(sessions.count)")
                        .foregroundStyle(.secondary)
                }) {
                    if sessions.isEmpty {
                        Text("No chat sessions yet")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(sessions.prefix(10)) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                if !session.userText.isEmpty {
                                    Text("You: \(session.userText)")
                                        .font(.caption)
                                }
                                if !session.assistantText.isEmpty {
                                    Text("AI: \(session.assistantText)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(session.timestamp.formatted(.dateTime.month().day().hour().minute()))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        if sessions.count > 10 {
                            Text("+ \(sessions.count - 10) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    Button("Add Test Response Record") {
                        addTestRecord()
                    }
                    Button("Clear All Response Records", role: .destructive) {
                        clearRecords()
                    }
                }
            }
            .navigationTitle("Debug Data")
        }
    }
    
    private func addTestRecord() {
        guard let firstReminder = reminders.first else {
            print("No reminders to create test record for")
            return
        }
        
        let testRecord = ResponseRecord(
            reminder: firstReminder,
            didComplete: Bool.random(),
            text: "Test response at \(Date().formatted(.dateTime.hour().minute()))",
            scaleValue: nil
        )
        modelContext.insert(testRecord)
        try? modelContext.save()
    }
    
    private func clearRecords() {
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ResponseRecord.self, Reminder.self, Session.self, configurations: config)
    DebugDataView().modelContainer(container)
}

