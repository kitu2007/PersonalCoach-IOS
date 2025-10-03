//
//  PersonalCoachApp.swift
//  PersonalCoach
//
//  Created by Kshitiz on 6/22/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import UIKit

@main
struct PersonalCoachApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    /// SAME string you added under App Groups in Signing & Capabilities
    private let appGroupID = "group.com.kg.personalcoach"
    
    @StateObject private var notificationManager = NotificationManager.shared
    let container: ModelContainer
    
    init() {
        // Shared file location inside the App-Group container
        let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
            .appendingPathComponent("PersonalCoach.sqlite")
        
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier(appGroupID)
        )
        
        // Removed the temporary flag reset to avoid re-creating duplicates
        
        do {
            container = try ModelContainer(for: Reminder.self, ResponseRecord.self, Session.self, configurations: config)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }
    
    @State private var selectedTab: Int = 0
    @State private var openedReminder: Reminder?
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                CoachChatView()
                    .modelContainer(container)
                    .tabItem { Label("Coach", systemImage: "message") }
                    .tag(0)
                
                ContentView()
                    .modelContainer(container)
                    .tabItem { Label("Home", systemImage: "house") }
                    .tag(1)
                
                RemindersView()
                    .tabItem { Label("Reminders", systemImage: "bell") }
                    .tag(2)
                
                ProgressView()
                    .tabItem { Label("Progress", systemImage: "chart.bar") }
                    .tag(3)
                
                // Uncomment after adding DebugDataView.swift to Xcode project
                // DebugDataView()
                //     .tabItem { Label("Debug", systemImage: "ladybug") }
                //     .tag(4)
            }
            .modelContainer(container)
            .environmentObject(notificationManager)
            .onAppear {
                // Request notification permission and set up notification categories
                notificationManager.requestAuthorization()
                notificationManager.configureNotificationCategories()
                
                // Handle notification responses when the app is opened from a notification
                UNUserNotificationCenter.current().delegate = notificationManager

                // Reschedule all reminders to ensure pending requests are in sync
                Task { @MainActor in
                    do {
                        // Use global staggered scheduling to avoid bursts
                        await notificationManager.scheduleAllReminders()
                    } catch {
                        print("Failed to reschedule reminders: \(error)")
                    }
                }
            }
            .onReceive(notificationManager.$lastOpenedReminderId.compactMap { $0 }) { reminderId in
                // Always bring to Reminders and present response UI so a tap never "does nothing"
                selectedTab = 2
                Task { @MainActor in
                    let desc = FetchDescriptor<Reminder>(predicate: #Predicate { $0.id == reminderId })
                    if let reminder = try? container.mainContext.fetch(desc).first {
                        openedReminder = reminder
                    }
                }
            }
            .sheet(item: $openedReminder) { reminder in
                ReminderResponseView(reminder: reminder)
                    .modelContainer(container)
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set the notification delegate as early as possible for cold-start taps
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationManager.shared
        NotificationManager.shared.configureNotificationCategories()
        return true
    }
}
