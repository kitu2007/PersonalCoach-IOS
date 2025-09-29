//
//  CoachStore.swift
//  PersonalCoach
//
//  Created by Kshitiz on 6/22/25.
//

import Foundation
import UserNotifications
import WatchConnectivity

let appGroupID = "group.com.kg.personalcoach"    // ← EXACT same string
private let quotesKey = "positive_quotes"

@MainActor
final class CoachStore: NSObject, ObservableObject {
    @Published var quotes: [String] = []
    private let defaults = UserDefaults(suiteName: appGroupID)!
    override init() {
        super.init()
        quotes = defaults.stringArray(forKey: quotesKey) ?? fallback
        setupWC()
    }
    func addQuote(_ q: String) { quotes.append(q); persist() }
    func fireRandomQuote() {
        guard let q = quotes.randomElement() else { return }
        let c = UNMutableNotificationContent()
        c.title="Coach"; c.body = q; c.sound = .default
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }
            try? await center.add(UNNotificationRequest(identifier:UUID().uuidString,
                                       content:c, trigger:nil))
        }
    }
    private func persist() {
        defaults.set(quotes, forKey: quotesKey)
        WCSession.default.transferUserInfo([quotesKey: quotes])
    }
    // MARK: – WatchConnectivity
    private func setupWC() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate=self; WCSession.default.activate()
    }
}
extension CoachStore: @preconcurrency WCSessionDelegate {
    func session(_ s:WCSession, didReceiveUserInfo u:[String:Any]=[:]) {
        if let q=u[quotesKey] as? [String] { quotes=q; persist() }
    }
    func session(_ s:WCSession, activationDidCompleteWith:WCSessionActivationState,
                 error:Error?) {}
    #if os(iOS)
    func sessionDidBecomeInactive(_ s:WCSession) {}
    func sessionDidDeactivate(_ s:WCSession){ WCSession.default.activate() }
    #endif
}


private let fallback = [
    "Begin, and the mind grows quiet.",
    "Progress > perfection.",
    "You can restart right now.",
    "Small steps remake mountains.",
    "Energy follows attention.",
    "Breathe—slow is smooth.",
    "Direction beats speed.",
    "Doubt is a low battery—recharge.",
    "Eyes up. Shoulders back.",
    "Turn the page, not the book.",
    "Learn, then let go.",
    "Momentum loves tiny wins.",
    "Done > great in draft.",
    "Curiosity is a compass.",
    "Effort compounds quietly.",
    "Next hour ≠ last hour.",
    "Trade noise for intention.",
    "Outcome starts with outlook.",
    "Challenge grows capacity.",
    "Feed focus; starve fear.",
    "Less hurry, more purpose.",
    "Write it down. Unclutter.",
    "Begin where your feet are.",
    "Consistency births clarity.",
    "Reflection is free coaching.",
    "Silence can be strategy.",
    "The obstacle is information.",
    "Gratitude fuels grit.",
    "Action answers anxiety.",
    "Today’s effort shapes tomorrow."
]
