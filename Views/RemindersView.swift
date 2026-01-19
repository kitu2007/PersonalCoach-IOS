import SwiftUI
import SwiftData
import UserNotifications

enum TimeCategory: String, CaseIterable {
    case morning = "🌅 Morning (5 AM - 11 AM)"
    case afternoon = "☀️ Afternoon (12 PM - 5 PM)"
    case evening = "🌆 Evening (6 PM - 9 PM)"
    case night = "🌙 Night (10 PM - 4 AM)"
    
    func contains(hour: Int) -> Bool {
        switch self {
        case .morning: return hour >= 5 && hour < 12
        case .afternoon: return hour >= 12 && hour < 18
        case .evening: return hour >= 18 && hour < 22
        case .night: return hour >= 22 || hour < 5
        }
    }
}

struct RemindersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.question) private var reminders: [Reminder]
    
    @State private var showingAddReminder = false
    @State private var showingNotificationActions = false
    @State private var selectedReminderForResponse: Reminder?
    
    // Get the container from the context
    private var container: ModelContainer {
        modelContext.container
    }
    
    // Group reminders by time category
    private var categorizedReminders: [(TimeCategory?, [Reminder])] {
        var categories: [TimeCategory?: [Reminder]] = [:]
        var uncategorized: [Reminder] = []
        
        for reminder in reminders where reminder.isActive {
            // Get the earliest time for this reminder to determine its category
            if let earliestTime = reminder.times.min(by: { $0.hour < $1.hour }) {
                var foundCategory: TimeCategory? = nil
                for category in TimeCategory.allCases {
                    if category.contains(hour: earliestTime.hour) {
                        foundCategory = category
                        break
                    }
                }
                if let category = foundCategory {
                    categories[category, default: []].append(reminder)
                } else {
                    uncategorized.append(reminder)
                }
            } else {
                // Reminder has no times
                uncategorized.append(reminder)
            }
        }
        
        // Build result: categorized first, then uncategorized
        var result: [(TimeCategory?, [Reminder])] = []
        
        // Add categorized reminders, sorted by time within each category
        for category in TimeCategory.allCases {
            if let categoryReminders = categories[category], !categoryReminders.isEmpty {
                let sorted = categoryReminders.sorted { r1, r2 in
                    let t1 = r1.times.min(by: { $0.hour < $1.hour })?.hour ?? 0
                    let t2 = r2.times.min(by: { $0.hour < $1.hour })?.hour ?? 0
                    return t1 < t2
                }
                result.append((category, sorted))
            }
        }
        
        // Add uncategorized reminders if any
        if !uncategorized.isEmpty {
            result.append((nil, uncategorized))
        }
        
        return result
    }
    
    // Flatten categorized reminders for deletion tracking
    private var allCategorizedReminders: [Reminder] {
        categorizedReminders.flatMap { $0.1 }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
#if os(watchOS)
                if reminders.isEmpty {
                    Text("No reminders yet. Add some in the iPhone app!")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List {
                        ForEach(reminders) { reminder in
                            ReminderRow(reminder: reminder)
                        }
                        .onDelete(perform: deleteReminders)
                    }
                }
#else
                if reminders.isEmpty {
                    ContentUnavailableView(
                        "No Reminders",
                        systemImage: "bell.slash.fill",
                        description: Text("Tap the + button to add your first reminder")
                    )
                } else if categorizedReminders.isEmpty {
                    ContentUnavailableView(
                        "No Active Reminders",
                        systemImage: "bell.slash",
                        description: Text("All your reminders are currently inactive. Activate them to start receiving notifications.")
                    )
                } else {
                    List {
                        ForEach(Array(categorizedReminders.enumerated()), id: \.offset) { sectionIndex, categoryTuple in
                            let (category, categoryReminders) = categoryTuple
                            Section(header: Text(category?.rawValue ?? "📋 Uncategorized").font(.headline)) {
                                ForEach(categoryReminders, id: \.id) { reminder in
                                    HStack {
                                        ReminderRow(reminder: reminder)
                                        Spacer()
                                        Button {
                                            // Haptic feedback
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedReminderForResponse = reminder
                                            }
                                        } label: {
                                            Image(systemName: "checkmark.circle")
                                                .foregroundStyle(.green)
                                                .font(.title2)
                                        }
                                        .buttonStyle(.borderless)
                                        .frame(minWidth: 44, minHeight: 44)
                                        .contentShape(Rectangle())
                                        
                                        NavigationLink(destination: EditReminderView(reminder: reminder)) {
                                            Image(systemName: "gear")
                                                .foregroundStyle(.blue)
                                        }
                                        .buttonStyle(.borderless)
                                        .frame(minWidth: 44, minHeight: 44)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                Task { await NotificationManager.shared.cancelNotifications(for: reminder) }
                                                modelContext.delete(reminder)
                                                try? modelContext.save()
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
#endif
            }
            .navigationTitle("Reminders")
            .toolbar {
#if os(watchOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { /* action */ }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { /* action */ }
                }
#else
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingNotificationActions = true
                    }) {
                        Label("Actions", systemImage: "gear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddReminder = true }) {
                        Label("Add", systemImage: "plus")
                    }
                }
#endif
            }
#if !os(watchOS)
            .sheet(isPresented: $showingNotificationActions) {
                NavigationStack {
                    NotificationActionsView()
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView(timePeriods: TimePeriod.defaultPeriods)
            }
            .sheet(item: $selectedReminderForResponse) { reminder in
                ReminderResponseView(reminder: reminder)
                    .modelContainer(container)
            }
#endif
        }
    }
    
    private func deleteReminders(offsets: IndexSet) {
        withAnimation {
            // For watchOS, use simple index-based deletion
            #if os(watchOS)
            for index in offsets {
                guard index < reminders.count else { continue }
                let reminder = reminders[index]
                Task { await NotificationManager.shared.cancelNotifications(for: reminder) }
                modelContext.delete(reminder)
            }
            #else
            // For iOS, we need to map offsets to actual reminders from categorized view
            let allReminders = allCategorizedReminders
            for index in offsets {
                guard index < allReminders.count else { continue }
                let reminder = allReminders[index]
                Task { await NotificationManager.shared.cancelNotifications(for: reminder) }
                modelContext.delete(reminder)
            }
            #endif
        }
        
        // Save changes
        try? modelContext.save()
    }
}

#Preview {
    RemindersView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
