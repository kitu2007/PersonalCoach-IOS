import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.question) private var allReminders: [Reminder]
    @Query(sort: \ResponseRecord.timestamp, order: .reverse) private var allRecords: [ResponseRecord]
    
    @State private var selectedReminder: Reminder?
    
    private var container: ModelContainer {
        modelContext.container
    }
    
    // Get today's start
    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    // Get all active reminders with their status for today
    private var todayReminders: [ReminderStatus] {
        let calendar = Calendar.current
        let now = Date()
        let todayRecords = allRecords.filter { $0.timestamp >= todayStart }
        
        return allReminders
            .filter { $0.isActive }
            .compactMap { reminder -> ReminderStatus? in
                guard !reminder.times.isEmpty else { return nil }
                
                // Find if there's a response for today
                let todayResponses = todayRecords.filter { $0.reminderID == reminder.id }
                let hasResponded = !todayResponses.isEmpty
                
                // Check if any scheduled time has passed today
                let passedTimes = reminder.times.filter { time in
                    var components = calendar.dateComponents([.year, .month, .day], from: now)
                    components.hour = time.hour
                    components.minute = time.minute
                    components.second = 0
                    guard let scheduledTime = calendar.date(from: components) else {
                        return false
                    }
                    return scheduledTime < now
                }
                
                let isPending = !passedTimes.isEmpty && !hasResponded
                
                // Find next upcoming time
                let nextTime = reminder.times.sorted(by: { 
                    ($0.hour, $0.minute) < ($1.hour, $1.minute) 
                }).first { time in
                    var components = calendar.dateComponents([.year, .month, .day], from: now)
                    components.hour = time.hour
                    components.minute = time.minute
                    components.second = 0
                    guard let scheduledTime = calendar.date(from: components) else {
                        return false
                    }
                    return scheduledTime > now
                }
                
                return ReminderStatus(
                    reminder: reminder,
                    hasResponded: hasResponded,
                    isPending: isPending,
                    nextTime: nextTime,
                    responses: todayResponses
                )
            }
            .sorted { r1, r2 in
                // Sort: pending first, then by earliest time
                if r1.isPending != r2.isPending {
                    return r1.isPending
                }
                let t1 = r1.reminder.times.min(by: { ($0.hour, $0.minute) < ($1.hour, $1.minute) })
                let t2 = r2.reminder.times.min(by: { ($0.hour, $0.minute) < ($1.hour, $1.minute) })
                let hour1 = t1?.hour ?? 99
                let hour2 = t2?.hour ?? 99
                let min1 = t1?.minute ?? 99
                let min2 = t2?.minute ?? 99
                return (hour1, min1) < (hour2, min2)
            }
    }
    
    private var pendingCount: Int {
        todayReminders.filter { $0.isPending }.count
    }
    
    private var completedCount: Int {
        todayReminders.filter { $0.hasResponded }.count
    }
    
    var body: some View {
        NavigationStack {
            if allReminders.isEmpty {
                ContentUnavailableView(
                    "No Reminders Yet",
                    systemImage: "bell.slash.fill",
                    description: Text("Add reminders in the Reminders tab to track your daily progress")
                )
            } else if todayReminders.isEmpty {
                ContentUnavailableView(
                    "No Active Reminders",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("You don't have any active reminders scheduled for today")
                )
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Summary Card
                        VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.title)
                                .foregroundStyle(.blue)
                            Text("Today's Overview")
                                .font(.title2)
                                .bold()
                        }
                        
                        HStack(spacing: 30) {
                            VStack {
                                Text("\(completedCount)")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(.green)
                                Text("Completed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Divider()
                                .frame(height: 50)
                            
                            VStack {
                                Text("\(pendingCount)")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(.orange)
                                Text("Pending")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Divider()
                                .frame(height: 50)
                            
                            VStack {
                                Text("\(todayReminders.count)")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(.blue)
                                Text("Total")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    // Pending Reminders
                    if pendingCount > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.orange)
                                Text("Need Your Response")
                                    .font(.headline)
                            }
                            .padding(.horizontal)
                            
                            ForEach(todayReminders.filter { $0.isPending }) { status in
                                Button {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedReminder = status.reminder
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(status.reminder.question)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.primary)
                                            if let firstTime = status.reminder.times.sorted(by: { ($0.hour, $0.minute) < ($1.hour, $1.minute) }).first {
                                                Text("Scheduled: \(firstTime.timeString)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.orange)
                                            .font(.caption)
                                    }
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Completed Today
                    if completedCount > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Completed Today")
                                    .font(.headline)
                            }
                            .padding(.horizontal)
                            
                            ForEach(todayReminders.filter { $0.hasResponded }) { status in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(status.reminder.question)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        if let lastResponse = status.responses.first {
                                            HStack {
                                                Text(lastResponse.didComplete ? "✓ Complete" : "○ Skipped")
                                                    .font(.caption)
                                                    .foregroundStyle(lastResponse.didComplete ? .green : .orange)
                                                Text("at \(lastResponse.timestamp.formatted(.dateTime.hour().minute()))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.green.opacity(0.05))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Upcoming
                    let upcomingReminders = todayReminders.filter { !$0.hasResponded && !$0.isPending }
                    if !upcomingReminders.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(.blue)
                                Text("Coming Up")
                                    .font(.headline)
                            }
                            .padding(.horizontal)
                            
                            ForEach(upcomingReminders) { status in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(status.reminder.question)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        if let nextTime = status.nextTime {
                                            Text("Next: \(nextTime.timeString)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
                .refreshable {
                    // Force refresh by accessing the computed property
                    _ = todayReminders
                }
            }
            .navigationTitle("Today")
            .sheet(item: $selectedReminder) { reminder in
                ReminderResponseView(reminder: reminder)
                    .modelContainer(container)
            }
        }
    }
}

// Helper struct
private struct ReminderStatus: Identifiable {
    let id: UUID
    let reminder: Reminder
    let hasResponded: Bool
    let isPending: Bool
    let nextTime: ReminderTime?
    let responses: [ResponseRecord]
    
    init(reminder: Reminder, hasResponded: Bool, isPending: Bool, nextTime: ReminderTime?, responses: [ResponseRecord]) {
        self.id = reminder.id
        self.reminder = reminder
        self.hasResponded = hasResponded
        self.isPending = isPending
        self.nextTime = nextTime
        self.responses = responses
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Reminder.self, ResponseRecord.self, configurations: config)
    TodayView().modelContainer(container)
}

