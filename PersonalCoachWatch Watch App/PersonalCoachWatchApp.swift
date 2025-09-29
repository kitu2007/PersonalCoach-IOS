//
//  PersonalCoachWatchApp.swift
//  PersonalCoachWatch Watch App
//
//  Created by Kshitiz on 6/22/25.
//
import SwiftUI
import SwiftData
import UserNotifications

@main
struct PersonalCoachWatchApp: App {
    /// SAME string as in the main app
    private let appGroupID = "group.com.kg.personalcoach"
    @Environment(\.scenePhase) private var scenePhase
    
    var sharedModelContainer: ModelContainer = {
        // Shared file location inside the App-Group container
        let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.kg.personalcoach")!
            .appendingPathComponent("PersonalCoach.sqlite")
        
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier("group.com.kg.personalcoach")
        )
        
        do {
            return try ModelContainer(for: Reminder.self, ResponseRecord.self, Session.self, configurations: config)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            WatchCoachView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Request notification permission on watch and register categories
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                NotificationManager.shared.configureNotificationCategories()
                // Reschedule reminders locally on watch for independence
                Task { @MainActor in
                    await NotificationManager.shared.scheduleAllReminders()
                }
            }
        }
    }
}
