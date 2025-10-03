import SwiftUI
import SwiftData
import Charts

struct ProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ResponseRecord.timestamp, order: .reverse) private var allRecords: [ResponseRecord]
    @Query(sort: \Reminder.question) private var reminders: [Reminder]
    
    // Rolling 7-day window
    private var weeklyData: [ReminderWeeklyStats] {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        print("📊 ProgressView weeklyData calculation:")
        print("  → Total records in DB: \(allRecords.count)")
        print("  → Date range: \(weekAgo) to \(now)")
        
        // Filter records from last 7 days
        let recentRecords = allRecords.filter { $0.timestamp >= weekAgo }
        print("  → Recent records (last 7 days): \(recentRecords.count)")
        
        // Debug: Print all recent records
        for (idx, record) in recentRecords.enumerated() {
            print("    [\(idx)] \(record.reminderQuestion) - \(record.timestamp) - completed: \(record.didComplete)")
        }
        
        // Group by reminder
        var stats: [UUID: ReminderWeeklyStats] = [:]
        
        for reminder in reminders {
            let reminderRecords = recentRecords.filter { $0.reminderID == reminder.id }
            print("  → Reminder '\(reminder.question)': \(reminderRecords.count) records")
            
            // Calculate daily completion (how many days they responded vs how many days the reminder was active)
            var dailyResponses: [String: Bool] = [:]
            for record in reminderRecords {
                let dayKey = calendar.startOfDay(for: record.timestamp).ISO8601Format()
                if dailyResponses[dayKey] == nil || record.didComplete {
                    dailyResponses[dayKey] = record.didComplete
                }
                print("    → Day: \(dayKey), didComplete: \(record.didComplete)")
            }
            
            let totalResponses = reminderRecords.count
            let completedResponses = reminderRecords.filter { $0.didComplete }.count
            let daysResponded = dailyResponses.count
            
            print("    → Stats: total=\(totalResponses), completed=\(completedResponses), days=\(daysResponded)")
            
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DB: \(allRecords.count) records")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !allRecords.isEmpty {
                            Text("Latest: \(allRecords.first?.timestamp.formatted(.dateTime.month().day().hour().minute()) ?? "N/A")")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Button("Refresh") {
                        print("🔄 Manual refresh triggered")
                        print("  → Current record count: \(allRecords.count)")
                        for (idx, record) in allRecords.prefix(5).enumerated() {
                            print("    [\(idx)] \(record.reminderQuestion) @ \(record.timestamp)")
                        }
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
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Weekly Activity Count")
                                    .font(.headline)
                                Text("Number of times you completed each activity in the last 7 days")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                if #available(iOS 16.0, *) {
                                    Chart(weeklyData) { stat in
                                        BarMark(
                                            x: .value("Count", stat.completedResponses),
                                            y: .value("Activity", stat.shortQuestion)
                                        )
                                        .foregroundStyle(by: .value("Activity", stat.shortQuestion))
                                        .annotation(position: .trailing) {
                                            Text("\(stat.completedResponses)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks(position: .bottom)
                                    }
                                    .chartYAxis {
                                        AxisMarks(position: .leading) { value in
                                            AxisValueLabel() {
                                                if let name = value.as(String.self) {
                                                    Text(name)
                                                        .font(.caption)
                                                }
                                            }
                                        }
                                    }
                                    .chartLegend(.hidden)
                                    .frame(height: CGFloat(weeklyData.count * 50))
                                    .padding(.vertical, 8)
                                } else {
                                    // Fallback for iOS 15 and earlier
                                    VStack(spacing: 8) {
                                        ForEach(weeklyData) { stat in
                                            HStack {
                                                Text(stat.shortQuestion)
                                                    .font(.caption)
                                                    .frame(width: 80, alignment: .leading)
                                                GeometryReader { geometry in
                                                    ZStack(alignment: .leading) {
                                                        Rectangle()
                                                            .fill(Color.gray.opacity(0.2))
                                                        Rectangle()
                                                            .fill(Color.blue)
                                                            .frame(width: geometry.size.width * CGFloat(stat.completedResponses) / CGFloat(max(weeklyData.map { $0.completedResponses }.max() ?? 1, 1)))
                                                    }
                                                }
                                                .frame(height: 20)
                                                Text("\(stat.completedResponses)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .frame(width: 30)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        Section {
                            Text("Detailed Stats")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Rolling 7-day window showing completion and consistency rates")
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
    
    var shortQuestion: String {
        // Truncate long questions for chart display
        if question.count > 20 {
            return String(question.prefix(17)) + "..."
        }
        return question
    }
    
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
