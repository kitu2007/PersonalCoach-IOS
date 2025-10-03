//
//  WatchCoachView.swift
//  PersonalCoachWatch Watch App
//
//  Created by Kshitiz on 6/22/25.
//
import SwiftUI
import SwiftData


struct WatchCoachView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var reminders: [Reminder]
    
    @State private var currentQuote: String = ""
    @State private var showConfirmation = false
    @State private var selectedReminder: Reminder?
    
    private let motivationalQuotes = [
        "Believe you can and you're halfway there.",
        "The only way to do great work is to love what you do.",
        "Success is not final, failure is not fatal: It is the courage to continue that counts.",
        "You are never too old to set another goal or to dream a new dream.",
        "The future belongs to those who believe in the beauty of their dreams.",
        "Everything you've ever wanted is on the other side of fear.",
        "The only limit to our realization of tomorrow will be our doubts of today.",
        "The best way to predict the future is to create it.",
        "Don't watch the clock; do what it does. Keep going.",
        "The secret of getting ahead is getting started."
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Motivational Quote Card
                VStack(alignment: .center, spacing: 8) {
                    Text("💡 Today's Motivation")
                        .font(.headline)
                    Text(currentQuote)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .fixedSize(horizontal: false, vertical: true)
                        .onAppear {
                            currentQuote = motivationalQuotes.randomElement() ?? "Stay focused and keep pushing forward."
                        }
                }
                .padding(.horizontal)
                
                // Reminders List
                List {
                    if reminders.isEmpty {
                        Text("No reminders yet. Add some in the iPhone app!")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else {
                        ForEach(reminders) { reminder in
                            if reminder.isActive {
                                WatchReminderRow(reminder: reminder) { response in
                                    updateReminder(reminder, response: response)
                                }
                            }
                        }
                        .onDelete(perform: deleteReminders)
                    }
                }
                #if os(watchOS)
                .listStyle(.carousel)
                #endif
            }
            .navigationTitle("My Coach")
            .alert("Log Response", isPresented: $showConfirmation) {
                if selectedReminder != nil {
                    Text(selectedReminder!.question)
                    Button("Yes") {
                        updateReminder(selectedReminder!, response: true)
                    }
                    Button("No") {
                        updateReminder(selectedReminder!, response: false)
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } message: {
                Text("Did you complete this task?")
            }
        }
    }
    
    private func updateReminder(_ reminder: Reminder, response: Bool) {
        reminder.lastResponse = response ? "Yes" : "No"
        reminder.lastResponseDate = Date()
        
        // Schedule a new quote for the next interaction
        currentQuote = motivationalQuotes.randomElement() ?? "Great job! Keep it up!"
        
        // NEW: store this response for analytics
        let record = ResponseRecord(reminder: reminder, didComplete: response)
        modelContext.insert(record)
        try? modelContext.save()
    }
    private func deleteReminders(at offsets: IndexSet) {
        for index in offsets {
            let reminder = reminders[index]
            modelContext.delete(reminder)
        }
    }
}

struct WatchReminderRow: View {
    let reminder: Reminder
    let onResponse: (Bool) -> Void
    
    var body: some View {
        HStack {
            Text(reminder.question)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: { onResponse(true) }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                
                Button(action: { onResponse(false) }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Reminder.self, configurations: config)
    
    WatchCoachView()
        .modelContainer(container)
}
