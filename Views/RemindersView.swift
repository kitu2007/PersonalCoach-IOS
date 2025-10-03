import SwiftUI
import SwiftData
import UserNotifications

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
                        description: Text("Add a reminder to get started")
                    )
                } else {
                    List {
                        ForEach(reminders) { reminder in
                            HStack {
                                ReminderRow(reminder: reminder)
                                Spacer()
                                Button {
                                    selectedReminderForResponse = reminder
                                } label: {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(.green)
                                        .font(.title2)
                                }
                                .buttonStyle(.borderless)
                                NavigationLink(destination: EditReminderView(reminder: reminder)) {
                                    Image(systemName: "gear")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .onDelete(perform: deleteReminders)
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
            for index in offsets {
                let reminder = reminders[index]
                // First, cancel any pending notifications for this reminder (all matching identifiers)
                Task { await NotificationManager.shared.cancelNotifications(for: reminder) }
                // Now, delete the object from the model context.
                modelContext.delete(reminder)
            }
        }
        
        // No need to save or fetch explicitly. @Query and SwiftData handle it.
    }
}

#Preview {
    RemindersView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
