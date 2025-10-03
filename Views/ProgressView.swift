import SwiftUI
import SwiftData

struct ProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ResponseRecord.timestamp, order: .reverse) private var allRecords: [ResponseRecord]
    @Query(sort: \Reminder.question) private var reminders: [Reminder]
    
    // Rolling 7-day window
    private var weeklyData: [ReminderWeeklyStats] {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        // Filter records from last 7 days
        let recentRecords = allRecords.filter { $0.timestamp >= weekAgo }
        
        // Group by reminder
        var stats: [UUID: ReminderWeeklyStats] = [:]
        
        for reminder in reminders {
            let reminderRecords = recentRecords.filter { $0.reminderID == reminder.id }
            
            // Calculate daily completion (how many days they responded vs how many days the reminder was active)
            var dailyResponses: [String: Bool] = [:]
            for record in reminderRecords {
                let dayKey = calendar.startOfDay(for: record.timestamp).ISO8601Format()
                if dailyResponses[dayKey] == nil || record.didComplete {
                    dailyResponses[dayKey] = record.didComplete
                }
            }
            
            let totalResponses = reminderRecords.count
            let completedResponses = reminderRecords.filter { $0.didComplete }.count
            let daysResponded = dailyResponses.count
            
            stats[reminder.id] = ReminderWeeklyStats(
                reminderID: reminder.id,
                question: reminder.question,
                totalResponses: totalResponses,
                completedResponses: completedResponses,
                daysResponded: daysResponded,
                completionRate: totalResponses > 0 ? Double(completedResponses) / Double(totalResponses) : 0,
                consistencyRate: Double(daysResponded) / 7.0
            )
        }
        
        return stats.values.sorted { $0.question < $1.question }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Debug header
                HStack {
                    Text("DB: \(allRecords.count) records")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") {
                        // Force refresh
                        modelContext.autosaveEnabled = true
                        try? modelContext.save()
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                
                if weeklyData.isEmpty {
                    ContentUnavailableView(
                        "No Weekly Data",
                        systemImage: "chart.bar",
                        description: Text("Complete reminders to see your weekly progress")
                    )
                } else {
                    List {
                        Section {
                            Text("Rolling 7-Day Window")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Shows your performance over the last 7 days")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        
                        ForEach(weeklyData) { stat in
                            VStack(alignment: .leading, spacing: 12) {
                                // Reminder name
                                Text(stat.question)
                                    .font(.headline)
                                
                                // Completion rate
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Completion Rate")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(Int(stat.completionRate * 100))%")
                                            .font(.caption)
                                            .bold()
                                    }
                                    SwiftUI.ProgressView(value: stat.completionRate)
                                        .progressViewStyle(.linear)
                                        .tint(stat.completionRate >= 0.7 ? .green : stat.completionRate >= 0.4 ? .orange : .red)
                                }
                                
                                // Consistency rate
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Consistency (Days Active)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(stat.daysResponded)/7 days")
                                            .font(.caption)
                                            .bold()
                                    }
                                    SwiftUI.ProgressView(value: stat.consistencyRate)
                                        .progressViewStyle(.linear)
                                        .tint(stat.consistencyRate >= 0.7 ? .green : stat.consistencyRate >= 0.4 ? .orange : .red)
                                }
                                
                                // Stats summary
                                HStack(spacing: 20) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Total")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("\(stat.totalResponses)")
                                            .font(.title3)
                                            .bold()
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Completed")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("\(stat.completedResponses)")
                                            .font(.title3)
                                            .bold()
                                            .foregroundStyle(.green)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Skipped")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("\(stat.totalResponses - stat.completedResponses)")
                                            .font(.title3)
                                            .bold()
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Weekly Progress")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        addTestData()
                    } label: {
                        Label("Add Test", systemImage: "plus.circle")
                    }
                }
            }
        }
    }
    
    private func addTestData() {
        guard let firstReminder = reminders.first else { return }
        
        let record = ResponseRecord(
            reminder: firstReminder,
            didComplete: Bool.random(),
            text: nil,
            scaleValue: nil
        )
        modelContext.insert(record)
        do {
            try modelContext.save()
            print("✅ Test record added successfully")
        } catch {
            print("❌ Failed to add test record: \(error)")
        }
    }
}

// MARK: - Models
private struct ReminderWeeklyStats: Identifiable {
    let id: UUID
    let reminderID: UUID
    let question: String
    let totalResponses: Int
    let completedResponses: Int
    let daysResponded: Int
    let completionRate: Double
    let consistencyRate: Double
    
    init(reminderID: UUID, question: String, totalResponses: Int, completedResponses: Int, daysResponded: Int, completionRate: Double, consistencyRate: Double) {
        self.id = UUID()
        self.reminderID = reminderID
        self.question = question
        self.totalResponses = totalResponses
        self.completedResponses = completedResponses
        self.daysResponded = daysResponded
        self.completionRate = completionRate
        self.consistencyRate = consistencyRate
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ResponseRecord.self, Reminder.self, configurations: config)
    ProgressView().modelContainer(container)
}
