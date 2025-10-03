import SwiftUI
import SwiftData

struct ReminderResponseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var reminder: Reminder
    @State private var textResponse = ""
    @State private var yesNo: Bool? = nil
    @State private var scale: Double = 3
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(reminder.question)) {
                    switch reminder.responseType {
                    case .yesNo:
                        HStack {
                            Button {
                                yesNo = true
                            } label: { Label("Yes", systemImage: yesNo == true ? "checkmark.circle.fill" : "circle") }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            Button {
                                yesNo = false
                            } label: { Label("No", systemImage: yesNo == false ? "xmark.circle.fill" : "circle") }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    case .text:
                        TextEditor(text: $textResponse)
                            .frame(minHeight: 100)
                            .padding()
                    case .both:
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Button {
                                    yesNo = true
                                } label: { Label("Yes", systemImage: yesNo == true ? "checkmark.circle.fill" : "circle") }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                Button {
                                    yesNo = false
                                } label: { Label("No", systemImage: yesNo == false ? "xmark.circle.fill" : "circle") }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                            TextEditor(text: $textResponse)
                                .frame(minHeight: 100)
                                .padding()
                        }
                    case .scale:
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How do you feel (1-5)?")
                            Slider(value: $scale, in: 1...5, step: 1) { Text("Scale") }
                            HStack { ForEach(1...5, id: \..self) { n in Text("\(n)").font(.caption).frame(maxWidth: .infinity) } }
                        }
                    }
                }
                
                if let lastResponse = reminder.lastResponse, !lastResponse.isEmpty {
                    Section(header: Text("Previous Response")) {
                        Text(lastResponse)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveResponse() }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private func saveResponse() {
        print("🔵 saveResponse called for: \(reminder.question)")
        print("  → ModelContext: \(modelContext)")
        print("  → Container: \(modelContext.container)")
        
        var didComplete = false
        var text: String? = nil
        var scaleValue: Int? = nil
        switch reminder.responseType {
        case .yesNo:
            didComplete = (yesNo == true)
            print("  → Response type: yesNo, didComplete: \(didComplete)")
        case .text:
            text = textResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            didComplete = !(text ?? "").isEmpty
            print("  → Response type: text, text: '\(text ?? "")', didComplete: \(didComplete)")
        case .both:
            didComplete = (yesNo == true)
            text = textResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            print("  → Response type: both, didComplete: \(didComplete), text: '\(text ?? "")'")
        case .scale:
            scaleValue = Int(scale)
            didComplete = true
            print("  → Response type: scale, value: \(scaleValue!), didComplete: \(didComplete)")
        }
        
        reminder.lastResponse = text ?? (scaleValue != nil ? "\(scaleValue!)" : (didComplete ? "Yes" : "No"))
        reminder.lastResponseDate = Date()
        
        let record = ResponseRecord(reminder: reminder, didComplete: didComplete, text: text, scaleValue: scaleValue)
        print("  → Created ResponseRecord: reminderID=\(record.reminderID), question='\(record.reminderQuestion)'")
        print("  → Record timestamp: \(record.timestamp)")
        
        modelContext.insert(record)
        print("  → Inserted record into modelContext")
        
        do {
            try modelContext.save()
            print("✅ ResponseRecord saved successfully!")
            print("  → Saved to database at \(Date())")
        } catch {
            print("❌ Failed to save ResponseRecord: \(error)")
            print("  → Error details: \(error.localizedDescription)")
        }
        
        dismiss()
    }
    
    private var canSave: Bool {
        switch reminder.responseType {
        case .yesNo:
            return yesNo != nil
        case .text:
            return !textResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .both:
            return yesNo != nil || !textResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .scale:
            return true
        }
    }
}

#Preview {
    ReminderResponseView(reminder: Reminder(
        question: "What's important today?",
        responseType: .text
    ))
    .modelContainer(for: Reminder.self, inMemory: true)
}
