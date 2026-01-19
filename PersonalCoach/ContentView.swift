//
//  ContentView.swift
//  PersonalCoach
//
//  Created by Kshitiz on 6/22/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.question) private var reminders: [Reminder]
    @State private var newQuote = ""
    @StateObject private var store = CoachStore() // shared quotes
    @State private var hasCleanedDuplicates = false
    @State private var showingDatabaseError = false
    
    var body: some View {
        NavigationStack {
            List {
                // Home Section
                Section {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Personal Coach")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Stay on track with your daily routines and habits")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        NavigationLink {
                            RemindersView()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add New Reminder")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.top, 20)
                    }
                    .padding(.vertical)
                }
                
                // Upcoming Reminders Section
                if !reminders.isEmpty {
                    Section("Upcoming Reminders") {
                        ForEach(reminders.prefix(5)) { reminder in
                            HStack {
                                Circle()
                                    .fill(reminder.isActive ? Color.green : Color.gray)
                                    .frame(width: 10, height: 10)
                                Text(reminder.question)
                                    .lineLimit(1)
                                Spacer()
                                if let nextTime = nextScheduledTime(for: reminder) {
                                    Text(nextTime, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        if reminders.count > 5 {
                            NavigationLink("View All Reminders") {
                                RemindersView()
                            }
                            .font(.caption)
                        }
                    }
                }
                
                // Quotes Section
                Section("Motivational Quotes") {
                    if store.quotes.isEmpty {
                        Text("No quotes yet. Add some below!")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(store.quotes, id: \.self) { quote in
                            Text(quote)
                                .padding(.vertical, 4)
                        }
                    }
                    
                    HStack {
                        TextField("Add a new quote", text: $newQuote)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: addQuote) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .disabled(newQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("More")
            .onAppear {
                if !hasCleanedDuplicates {
                    cleanDuplicateReminders()
                    hasCleanedDuplicates = true
                }
                
                // Check for database errors
                do {
                    _ = try modelContext.fetch(FetchDescriptor<Reminder>())
                } catch {
                    showingDatabaseError = true
                }
            }
            .alert("Database Error", isPresented: $showingDatabaseError) {
                Button("Reset Database") {
                    resetDatabase()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("There was an issue with the database. You can reset it to fix the problem.")
            }
        }
    }
    
    private func addQuote() {
        let trimmedQuote = newQuote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuote.isEmpty else { return }
        
        store.addQuote(trimmedQuote)
        newQuote = ""
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func nextScheduledTime(for reminder: Reminder) -> Date? {
        guard !reminder.times.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Find the next scheduled time for today or the next day
        for time in reminder.times.sorted(by: { $0.hour < $1.hour }) {
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            components.hour = time.hour
            components.minute = time.minute
            
            if let date = calendar.date(from: components), date > now {
                return date
            }
        }
        
        // If no more times today, return first time tomorrow
        if let firstTime = reminder.times.sorted(by: { $0.hour < $1.hour }).first {
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            components.hour = firstTime.hour
            components.minute = firstTime.minute
            return calendar.date(byAdding: .day, value: 1, to: calendar.date(from: components)!)!
        }
        
        return nil
    }
    
    private func cleanDuplicateReminders() {
        let descriptor = FetchDescriptor<Reminder>()
        guard let allReminders = try? modelContext.fetch(descriptor) else { return }

        var seenKeys = Set<String>()
        var duplicatesToDelete: [Reminder] = []

        for reminder in allReminders {
            // Build a unique key based on question and all times
            let timesKey = reminder.times
                .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
                .map { "\($0.hour):\($0.minute)" }
                .joined(separator: ",")
            let key = "\(reminder.question)|\(timesKey)"

            if seenKeys.contains(key) {
                duplicatesToDelete.append(reminder)
            } else {
                seenKeys.insert(key)
            }
        }

        // Delete duplicates
        for duplicate in duplicatesToDelete {
            modelContext.delete(duplicate)
        }

        // Save changes
        try? modelContext.save()
    }
    
    private func resetDatabase() {
        let descriptor = FetchDescriptor<Reminder>()
        guard let allReminders = try? modelContext.fetch(descriptor) else { return }
        
        for reminder in allReminders {
            modelContext.delete(reminder)
        }
        
        try? modelContext.save()
        hasCleanedDuplicates = false // Reset the flag
        showingDatabaseError = false // Hide the alert
    }
}
