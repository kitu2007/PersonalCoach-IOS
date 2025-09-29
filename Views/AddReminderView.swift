import SwiftUI
import SwiftData
import os

struct AddReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var question = ""
    @State private var selectedPeriods = Set<UUID>()
    @State private var responseType: ReminderResponseType = .yesNo
    @State private var customTime: Date? = nil
    
    let timePeriods: [TimePeriod]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Question")) {
                    TextField("What would you like to be reminded about?", text: $question)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.sentences)
                }
                
                Section(header: Text("Response Type")) {
                    Picker("Response Type", selection: $responseType) {
                        ForEach(ReminderResponseType.allCases, id: \.self) { type in
                            Text(type.description).tag(type)
                        }
                    }
                    .pickerStyle(.automatic)
                }
                
                Section(header: Text("Schedule")) {
                    ForEach(timePeriods) { period in
                        Toggle(period.displayName, isOn: Binding(
                            get: { selectedPeriods.contains(period.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedPeriods.insert(period.id)
                                } else {
                                    selectedPeriods.remove(period.id)
                                }
                            }
                        ))
                    }
                }
                
                Section(header: Text("Custom Time (Optional)")) {
                    DatePicker("Pick a time", selection: Binding(
                        get: { customTime ?? Date() },
                        set: { customTime = $0 }
                    ), displayedComponents: [.hourAndMinute])
                }
                
                Section {
                    Button("Add Default Reminders") {
                        addDefaultReminders()
                        dismiss()
                    }
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        selectedPeriods = []
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addReminder()
                        dismiss()
                        selectedPeriods = []
                    }
                    .disabled(question.isEmpty || selectedPeriods.isEmpty)
                }
            }
        }
    }
    
    private func addReminder() {
        withAnimation {
            var times: [ReminderTime] = []
            if let customTime = customTime {
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: customTime)
                let minute = calendar.component(.minute, from: customTime)
                times.append(ReminderTime(hour: hour, minute: minute, periodId: UUID()))
            } else {
                times = timePeriods
                    .filter { selectedPeriods.contains($0.id) }
                    .map { period in
                        ReminderTime(hour: period.hour, minute: period.minute, periodId: period.id)
                    }
            }
            // Fetch reminders with the same question
            let existing = try? modelContext.fetch(FetchDescriptor<Reminder>(predicate: #Predicate { $0.question == question }))
            if let existing = existing, existing.contains(where: { reminder in
                reminder.times.count == times.count &&
                zip(reminder.times, times).allSatisfy { $0.hour == $1.hour && $0.minute == $1.minute }
            }) {
                // If it already exists, make sure it's active and rescheduled
                if let match = existing.first {
                    match.isActive = true
                    try? modelContext.save()
                    match.scheduleNotifications()
                }
                return
            }
            let newReminder = Reminder(
                question: question,
                isActive: true,
                times: times,
                responseType: responseType
            )
            modelContext.insert(newReminder)
            try? modelContext.save()
            newReminder.scheduleNotifications()
        }
    }
    
    private func addDefaultReminders() {
        withAnimation {
            // Define default routines directly in the view
            let defaultRoutines: [(name: String, times: [(hour: Int, minute: Int)], responseType: ReminderResponseType)] = [
                ("Morning Routine", [(9, 30)], .both),
                ("Water", [(11, 0)], .yesNo),
                ("Sun exposure", [(11, 0)], .yesNo),
                ("Yoga/intention motion", [(11, 0)], .yesNo),
                ("Mental primer/Planning", [(11, 0)], .text),
                ("Breakfast", [(11, 0)], .yesNo),
                ("Meditation/Journaling", [(11, 0)], .yesNo),
                ("Lunch", [(16, 0)], .yesNo),
                ("Diffuse/Sensory reset", [(16, 0)], .yesNo),
                ("What's important/Reflection", [(16, 0)], .text),
                ("Exercise", [(18, 0)], .yesNo),
                ("Play with Guai/Eat/Nap", [(19, 0), (21, 0)], .yesNo),
                ("Nap", [(20, 30)], .yesNo),
                ("Brain dump", [(22, 0)], .text),
                ("Looking forward to", [(22, 0)], .text),
                ("Gratitude", [(22, 0)], .text),
                ("Reflection", [(22, 0)], .text),
                ("One thing looking forward", [(22, 0)], .text)
            ]
            
            for (name, times, responseType) in defaultRoutines {
                let periodTimes = times.map { (hour, minute) in
                    ReminderTime(hour: hour, minute: minute, periodId: UUID())
                }
                // Fetch reminders with the same question
                let existing = try? modelContext.fetch(FetchDescriptor<Reminder>(predicate: #Predicate { $0.question == name }))
                if let existing = existing, existing.contains(where: { reminder in
                    reminder.times.count == periodTimes.count &&
                    zip(reminder.times, periodTimes).allSatisfy { $0.hour == $1.hour && $0.minute == $1.minute }
                }) {
                        if let match = existing.first {
                            match.isActive = true
                            try? modelContext.save()
                            match.scheduleNotifications()
                        }
                        continue
                }
                let reminder = Reminder(
                    question: name,
                    isActive: true,
                    times: periodTimes,
                    responseType: responseType
                )
                modelContext.insert(reminder)
                    try? modelContext.save()
                    reminder.scheduleNotifications()
            }
        }
    }
}

#Preview {
    AddReminderView(timePeriods: TimePeriod.defaultPeriods)
    .modelContainer(for: Reminder.self, inMemory: true)
}
