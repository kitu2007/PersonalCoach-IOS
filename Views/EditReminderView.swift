import SwiftUI
import SwiftData

struct EditReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var reminder: Reminder
    @State private var showingTimeEditor = false
    @State private var editingTime: ReminderTime?
    @State private var newTimeDate = Date()
    
    var body: some View {
        Form {
            Section("Question") {
                TextField("Question", text: $reminder.question)
                    .textInputAutocapitalization(.sentences)
            }
            
            Section("Response Type") {
                Picker("Response Type", selection: $reminder.responseType) {
                    ForEach(ReminderResponseType.allCases, id: \.self) { type in
                        Text(type.description).tag(type)
                    }
                }
            }
            
            Section("Active") {
                Toggle("Active", isOn: $reminder.isActive)
            }
            
            Section("Times") {
                ForEach(reminder.times) { time in
                    HStack {
                        Text(time.timeString)
                        Spacer()
                        Button {
                            editingTime = time
                            let calendar = Calendar.current
                            newTimeDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
                            showingTimeEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                        }
                        Button(role: .destructive) {
                            reminder.times.removeAll { $0.id == time.id }
                            // Persist and reschedule after deletion
                            try? modelContext.save()
                            reminder.scheduleNotifications()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Button {
                    editingTime = nil
                    newTimeDate = Date()
                    showingTimeEditor = true
                } label: {
                    Label("Add Time", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Edit Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    try? modelContext.save()
                    reminder.scheduleNotifications()
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingTimeEditor) {
            NavigationStack {
                TimeEditorView(
                    time: $newTimeDate,
                    onSave: {
                        let calendar = Calendar.current
                        let hour = calendar.component(.hour, from: newTimeDate)
                        let minute = calendar.component(.minute, from: newTimeDate)
                        
                        if let editingTime = editingTime {
                            // Update existing time
                            editingTime.hour = hour
                            editingTime.minute = minute
                        } else {
                            // Add new time
                            let newTime = ReminderTime(hour: hour, minute: minute, periodId: UUID())
                            reminder.times.append(newTime)
                        }
                        // Persist and reschedule after time change
                        try? modelContext.save()
                        reminder.scheduleNotifications()
                        showingTimeEditor = false
                    },
                    onCancel: {
                        showingTimeEditor = false
                    }
                )
            }
        }
        // Reschedule if user toggles active state
        .onChange(of: reminder.isActive) { _, _ in
            try? modelContext.save()
            reminder.scheduleNotifications()
        }
    }
}

struct TimeEditorView: View {
    @Binding var time: Date
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Time")
                .font(.title2)
                .fontWeight(.semibold)
            
            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
            
            HStack(spacing: 20) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Reminder.self, configurations: config)
    let reminder = Reminder(question: "Sample Question", times: [])
    
    NavigationStack {
        EditReminderView(reminder: reminder)
            .modelContainer(container)
    }
} 