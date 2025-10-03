import UserNotifications
import SwiftUI
import OSLog
import SwiftData
#if os(watchOS)
import WatchKit
#endif

@MainActor
class NotificationManager: NSObject, ObservableObject, @preconcurrency UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let logger = Logger(subsystem: "com.kgarg.PersonalCoach", category: "NotificationManager")
    private let notificationCenter = UNUserNotificationCenter.current()
    private let sharedAppGroupID = "group.com.kg.personalcoach"
    @Published var lastOpenedReminderId: UUID?
    private let forcedFollowUpDelay: TimeInterval = 90 // seconds
    
    override private init() {
        super.init()
        notificationCenter.delegate = self
        // Ensure categories are registered early
        configureNotificationCategories()
        requestAuthorization()
    }
    
    func checkNotificationStatus() async -> UNAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }
    
    func requestAuthorization() {
        logger.info("Requesting notification authorization...")
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] success, error in
            guard let self = self else { return }
            
            Task { [weak self] in
                guard let self = self else { return }
                
                await MainActor.run {
                    if success {
                        self.logger.info("✅ Notification authorization granted")
                        Task { [weak self] in
                            guard let self = self else { return }
                            // Check current notification settings
                            let status = await self.checkNotificationStatus()
                            self.logger.info("📱 Current notification status: \(status.rawValue)")
                            await self.setupDefaultRemindersIfNeeded()
                        }
                    } else if let error = error {
                        self.logger.error("❌ Notification authorization failed: \(error.localizedDescription)")
                    } else {
                        self.logger.warning("⚠️ Notification authorization denied")
                        Task { [weak self] in
                            guard let self = self else { return }
                            let status = await self.checkNotificationStatus()
                            self.logger.info("📱 Current notification status: \(status.rawValue)")
                        }
                    }
                }
            }
        }
    }
    
    func scheduleNotifications(for reminder: Reminder) async {
        let reminderId = reminder.id.uuidString
        let center = UNUserNotificationCenter.current()
        
        // Remove any existing notifications for this reminder (match all suffixed identifiers)
        await cancelNotifications(for: reminder)
        
        // If reminder is inactive or has no times, we're done
        guard reminder.isActive, !reminder.times.isEmpty else {
            logger.info("ℹ️ Not scheduling - reminder is inactive or has no times")
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Schedule for each specific time
        for (index, time) in reminder.times.enumerated() {
            do {
                // Create date components for the notification time
                var dateComponents = DateComponents()
                dateComponents.hour = time.hour
                dateComponents.minute = time.minute
                
                // Make sure we have a valid date
                guard let triggerDate = calendar.date(from: dateComponents) else {
                    logger.error("❌ Failed to create date from components: \(dateComponents)")
                    continue
                }
                
                // If the time has already passed today, schedule for tomorrow
                let finalTriggerDate = triggerDate > now ? triggerDate : calendar.date(byAdding: .day, value: 1, to: triggerDate) ?? triggerDate
                
                let content = UNMutableNotificationContent()
                content.title = reminder.question
                content.body = "It's time to check in."
                content.categoryIdentifier = "REMINDER_ACTION"
                content.sound = .default
                if #available(iOS 15.0, watchOS 8.0, *) {
                    content.interruptionLevel = .timeSensitive
                    content.relevanceScore = 0.8
                }
                content.userInfo = [
                    "reminderId": reminderId,
                    "timePeriodId": time.periodId.uuidString
                ]
                
                // Create the trigger - use time interval for testing, calendar for production
                let triggerComponents = calendar.dateComponents([.hour, .minute], from: finalTriggerDate)
                logger.info("⏰ Scheduling for \(triggerComponents.hour ?? 0):\(triggerComponents.minute ?? 0)")
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: triggerComponents,
                    repeats: true
                )
                
                // Create and schedule the request
                let requestId = "\(reminderId)_\(index)"
                let request = UNNotificationRequest(
                    identifier: requestId,
                    content: content,
                    trigger: trigger
                )
                
                try await center.add(request)
                logger.info("✅ Scheduled: \(requestId) - \"\(reminder.question)\"")
                
                // Verify the notification was scheduled
            } catch {
                logger.error("❌ Failed to schedule notification: \(error.localizedDescription)")
                if let error = error as? URLError {
                    logger.error("   - Error code: \(error.errorCode)")
                }
            }
        }
        
        // No throw; just log error if needed
    }

    // Cancel all pending requests for a reminder (identifiers prefixed with reminder.id)
    func cancelNotifications(for reminder: Reminder) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let idsToRemove = pending
            .map { $0.identifier }
            .filter { $0.hasPrefix(reminder.id.uuidString) }
        if !idsToRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }
    }

    // MARK: - Global scheduling with staggering to avoid bursts
    func scheduleAllReminders() async {
        // Use App Group model container
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier(sharedAppGroupID)
        )
        guard let modelContainer = try? ModelContainer(for: Reminder.self, configurations: config) else {
            logger.error("Failed to create model container for scheduleAllReminders")
            return
        }
        let context = modelContainer.mainContext
        do {
            let activeReminders = try context.fetch(FetchDescriptor<Reminder>(predicate: #Predicate { $0.isActive }))
            // Cancel existing for all reminders
            for r in activeReminders { await cancelNotifications(for: r) }
            // Build buckets by (hour, minute)
            struct Item { let reminder: Reminder; let time: ReminderTime }
            var buckets: [String: [Item]] = [:]
            for r in activeReminders {
                for t in r.times {
                    let key = "\(t.hour):\(t.minute)"
                    buckets[key, default: []].append(Item(reminder: r, time: t))
                }
            }
            // Schedule with stagger inside each bucket: 0,3,6,9,12,15 minutes
            let center = UNUserNotificationCenter.current()
            for (_, items) in buckets {
                let sorted = items.sorted { $0.reminder.id.uuidString < $1.reminder.id.uuidString }
                for (idx, item) in sorted.enumerated() {
                    let baseHour = item.time.hour
                    let baseMinute = item.time.minute
                    let offset = (idx % 6) * 3 // 0..15 mins
                    let totalMinutes = baseMinute + offset
                    let hourCarry = totalMinutes / 60
                    let minuteFinal = totalMinutes % 60
                    let hourFinal = (baseHour + hourCarry) % 24

                    var components = DateComponents()
                    components.hour = hourFinal
                    components.minute = minuteFinal

                    let content = UNMutableNotificationContent()
                    content.title = item.reminder.question
                    content.body = "It's time to check in."
                    content.categoryIdentifier = "REMINDER_ACTION"
                    content.sound = .default
                    if #available(iOS 15.0, watchOS 8.0, *) {
                        content.interruptionLevel = .timeSensitive
                        content.relevanceScore = 0.8
                    }
                    content.userInfo = [
                        "reminderId": item.reminder.id.uuidString,
                        "timePeriodId": item.time.periodId.uuidString
                    ]

                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let requestId = "\(item.reminder.id.uuidString)_\(hourFinal)-\(minuteFinal)"
                    let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)
                    do {
                        try await center.add(request)
                        logger.info("✅ Scheduled (staggered): \(requestId)")
                    } catch {
                        logger.error("❌ Failed to schedule (staggered): \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            logger.error("Failed scheduleAllReminders fetch: \(error.localizedDescription)")
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate Methods
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Ensure actionable banner while app is foreground
        if #available(iOS 14.0, *) {
#if os(watchOS)
            WKInterfaceDevice.current().play(.notification)
#endif
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        // Record the last opened reminder for deep-linking UI
        if let reminderId = response.notification.request.content.userInfo["reminderId"] as? String,
           let uuid = UUID(uuidString: reminderId) {
            lastOpenedReminderId = uuid
        }
        handleNotificationResponse(response)
        completionHandler()
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        guard let reminderId = response.notification.request.content.userInfo["reminderId"] as? String,
              let uuid = UUID(uuidString: reminderId) else {
            logger.error("Invalid or missing reminderId in notification userInfo")
            return
        }
        
        // Get the model context (use shared App Group to match the app's store)
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier(sharedAppGroupID)
        )
        guard let modelContainer = try? ModelContainer(for: Reminder.self, configurations: config) else {
            logger.error("Failed to create model container")
            return
        }
        
        let context = modelContainer.mainContext
        
        // Find the reminder in the database
        let fetchDescriptor = FetchDescriptor<Reminder>(predicate: #Predicate { $0.id == uuid })
        
        do {
            guard let reminder = try context.fetch(fetchDescriptor).first else {
                logger.error("Could not find reminder with id: \(reminderId)")
                return
            }
            
            // Update last asked time
            reminder.lastAsked = Date()
            
            // Handle different response types
            switch response.actionIdentifier {
            case UNNotificationDefaultActionIdentifier:
                logger.info("User opened notification for: \(reminder.question)")
                try context.save()
            case "YES_ACTION":
                logger.info("User responded Yes to: \(reminder.question)")
                if reminder.responseType == .both {
                    showTextInput(for: reminder)
                } else {
                    // Record response for progress
                    let record = ResponseRecord(reminder: reminder, didComplete: true)
                    context.insert(record)
                    try context.save()
                }
                
            case "NO_ACTION":
                logger.info("User responded No to: \(reminder.question)")
                if reminder.responseType == .both {
                    showTextInput(for: reminder)
                } else {
                    let record = ResponseRecord(reminder: reminder, didComplete: false)
                    context.insert(record)
                    try context.save()
                }
            case "OPEN_APP":
                logger.info("User chose to open app for: \(reminder.question)")
                try context.save()
            case UNNotificationDismissActionIdentifier, "SKIP_ACTION":
                logger.info("Reminder dismissed without response: \(reminder.question). Re-scheduling soon.")
                scheduleSnoozedNotification(for: reminder, after: forcedFollowUpDelay)
                try context.save()
            case "TEXT_INPUT_ACTION":
                if let textResponse = (response as? UNTextInputNotificationResponse)?.userText, !textResponse.isEmpty {
                    reminder.lastResponse = textResponse
                    let record = ResponseRecord(reminder: reminder, didComplete: true)
                    context.insert(record)
                    logger.info("User provided text response for: \(reminder.question)")
                    try context.save()
                }
                
            default:
                logger.info("Unhandled action \(response.actionIdentifier) for: \(reminder.question). Scheduling follow-up.")
                scheduleSnoozedNotification(for: reminder, after: forcedFollowUpDelay)
                try context.save()
            }
        } catch {
            logger.error("Failed to handle notification response: \(error.localizedDescription)")
        }
    }
    
    // Show text input UI for reminders that require text responses
    @MainActor
    private func showTextInput(for reminder: Reminder) {
        // Create a text input action
        let textInputAction = UNTextInputNotificationAction(
            identifier: "TEXT_INPUT_ACTION",
            title: "Enter Response",
            options: [.authenticationRequired],
            textInputButtonTitle: "Submit",
            textInputPlaceholder: "Type your response here"
        )
        
        // Create a category with the text input action
        let category = UNNotificationCategory(
            identifier: "TEXT_INPUT_CATEGORY",
            actions: [textInputAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Register the category
        notificationCenter.setNotificationCategories([category])
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "\(reminder.question)"
        content.body = "Please enter your response"
        content.categoryIdentifier = "TEXT_INPUT_CATEGORY"
        content.sound = .default
        content.userInfo = ["reminderId": reminder.id.uuidString]
        
        // Create and add the request
        let request = UNNotificationRequest(
            identifier: "\(reminder.id.uuidString)_text_input",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        // Schedule the notification
        notificationCenter.add(request) { error in
            if let error = error {
                self.logger.error("Failed to schedule text input notification: \(error.localizedDescription)")
            }
        }
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func setupDefaultRemindersIfNeeded() {
        // Check if we've already set up default reminders
        let hasSetUpDefaults = UserDefaults.standard.bool(forKey: "hasSetUpDefaultReminders")
        guard !hasSetUpDefaults else { return }
        
        Task { @MainActor in
            do {
                // Get the shared model container (App Group)
                let config = ModelConfiguration(
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    groupContainer: .identifier(sharedAppGroupID)
                )
                guard let modelContainer = try? ModelContainer(for: Reminder.self, configurations: config) else {
                    Logger().error("Failed to create model container")
                    return
                }
                
                // Create default reminders from the globally-defined routines in Reminder.swift
                let defaultReminders = routines.map { (name, times, responseType) in
                    let reminderTimes = times.map { (hour, minute) in
                        ReminderTime(hour: hour, minute: minute, periodId: UUID())
                    }
                    return Reminder(
                        question: name,
                        isActive: true,
                        times: reminderTimes,
                        responseType: responseType
                    )
                }
                
                // Save default reminders
                let context = modelContainer.mainContext
                for reminder in defaultReminders {
                    context.insert(reminder)
                    await scheduleNotifications(for: reminder)
                }
                
                try context.save()
                // Mark as set up
                UserDefaults.standard.set(true, forKey: "hasSetUpDefaultReminders")
                Logger().info("Successfully set up default reminders")
            } catch {
                Logger().error("Failed to set up default reminders: \(error.localizedDescription)")
            }
        }
    }
    
    // Call this when your app launches
    // Custom action style that conforms to Codable
    enum ActionStyle: String, Codable, CaseIterable {
        case `default`
        case destructive
        
        var systemStyle: UNNotificationActionOptions {
            switch self {
            case .default: return []
            case .destructive: return .destructive
            }
        }
        
        var description: String {
            switch self {
            case .default: return "Default"
            case .destructive: return "Destructive"
            }
        }
    }
    
    // Configurable notification actions
    struct NotificationAction: Codable, Identifiable {
        let id: UUID
        var title: String
        var identifier: String
        var style: ActionStyle
        var requiresUnlock: Bool = false
        var bringsAppToForeground: Bool = false
        
        init(id: UUID = UUID(), title: String, identifier: String, style: ActionStyle = .default, requiresUnlock: Bool = false, bringsAppToForeground: Bool = false) {
            self.id = id
            self.title = title
            self.identifier = identifier
            self.style = style
            self.requiresUnlock = requiresUnlock
            self.bringsAppToForeground = bringsAppToForeground
        }
    }
    
    // Default actions (include snooze and a foreground "Open App")
    var defaultActions: [NotificationAction] = [
        NotificationAction(title: "Yes", identifier: "YES_ACTION", requiresUnlock: true),
        NotificationAction(title: "No", identifier: "NO_ACTION", requiresUnlock: true),
        NotificationAction(title: "Open App", identifier: "OPEN_APP", bringsAppToForeground: true)
    ]
    
    @Published var customActions: [NotificationAction] = []
    
    func configureNotificationCategories() {
        // Combine default and custom actions
        let allActions = defaultActions + customActions
        
        // Create notification actions
        let notificationActions: [UNNotificationAction] = allActions.map { action in
            var options: UNNotificationActionOptions = action.style.systemStyle
            if action.requiresUnlock { options.insert(.authenticationRequired) }
            if action.bringsAppToForeground { options.insert(.foreground) }
            return UNNotificationAction(identifier: action.identifier, title: action.title, options: options)
        }
        // A dedicated text input category is created in showTextInput when needed.
        
        // Create category with all actions
        let category = UNNotificationCategory(
            identifier: "REMINDER_ACTION",
            actions: notificationActions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // Schedule a one-off snoozed notification after a given number of seconds
    private func scheduleSnoozedNotification(for reminder: Reminder, after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = reminder.question
        content.body = "Snoozed reminder"
        content.categoryIdentifier = "REMINDER_ACTION"
        content.sound = .default
        if #available(iOS 15.0, watchOS 8.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        content.userInfo = ["reminderId": reminder.id.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let identifier = "\(reminder.id.uuidString)_snooze_\(Int(seconds))"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(req) { error in
            if let error = error { self.logger.error("Failed to schedule snooze: \(error.localizedDescription)") }
        }
    }
}
