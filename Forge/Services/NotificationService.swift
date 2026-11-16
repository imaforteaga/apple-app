import Foundation
import UserNotifications

enum ReminderKind: String, CaseIterable, Identifiable {
    case verse, workout, water, journal, weigh
    var id: String { rawValue }

    var title: String {
        switch self {
        case .verse: return "Verse of the day"
        case .workout: return "Training"
        case .water: return "Water"
        case .journal: return "Evening journal"
        case .weigh: return "Weekly weigh-in (Mondays)"
        }
    }
    var icon: String {
        switch self {
        case .verse: return "book.closed"
        case .workout: return "dumbbell"
        case .water: return "drop"
        case .journal: return "square.and.pencil"
        case .weigh: return "scalemass"
        }
    }
    var message: String {
        switch self {
        case .verse: return "Today's verse is ready. Start the day grounded."
        case .workout: return "Time to train. Open Forge and start your session."
        case .water: return "Quick water check. Log a glass."
        case .journal: return "Take two minutes to reflect on today."
        case .weigh: return "Log this week's weight."
        }
    }
    var defaultHour: Int {
        switch self {
        case .verse: return 7
        case .workout: return 17
        case .water: return 10
        case .journal: return 21
        case .weigh: return 8
        }
    }
    var enabledKey: String { "rem_\(rawValue)_on" }
    var hourKey: String { "rem_\(rawValue)_h" }
    var minuteKey: String { "rem_\(rawValue)_m" }
}

enum NotificationService {
    private static var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: Daily reminders

    static func schedule(_ kind: ReminderKind, hour: Int, minute: Int) async {
        cancel(kind)
        let content = UNMutableNotificationContent()
        content.title = "Forge"
        content.body = kind.message
        content.sound = .default

        switch kind {
        case .water:
            // Four gentle nudges through the day, starting at the chosen hour.
            for i in 0..<4 {
                var comps = DateComponents()
                comps.hour = min(23, hour + i * 3)
                comps.minute = minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                try? await center.add(UNNotificationRequest(identifier: "rem-water-\(i)", content: content, trigger: trigger))
            }
        case .weigh:
            var comps = DateComponents()
            comps.weekday = 2
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: "rem-weigh", content: content, trigger: trigger))
        default:
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: "rem-\(kind.rawValue)", content: content, trigger: trigger))
        }
    }

    static func cancel(_ kind: ReminderKind) {
        var ids = ["rem-\(kind.rawValue)"]
        if kind == .water { ids = (0..<4).map { "rem-water-\($0)" } }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: Supplements

    static func scheduleSupplement(_ s: Supplement) async {
        cancelSupplement(id: s.id)
        guard s.reminderEnabled, s.isActive else { return }
        let content = UNMutableNotificationContent()
        content.title = "Supplement"
        content.body = "Take \(s.name)\(s.dosage.isEmpty ? "" : " – \(s.dosage)")."
        content.sound = .default
        for weekday in 1...7 where (s.weekdayMask & (1 << (weekday - 1))) != 0 {
            var comps = DateComponents()
            comps.weekday = weekday
            comps.hour = s.reminderHour
            comps.minute = s.reminderMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: "supp-\(s.id.uuidString)-\(weekday)", content: content, trigger: trigger))
        }
    }

    static func cancelSupplement(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: (1...7).map { "supp-\(id.uuidString)-\($0)" })
    }

    // MARK: Rest timer (fires if the app is backgrounded)

    static func scheduleRestEnd(after seconds: Int) {
        center.removePendingNotificationRequests(withIdentifiers: ["rest-timer"])
        guard seconds > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "Time for your next set."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: "rest-timer", content: content, trigger: trigger))
    }

    static func cancelRestEnd() {
        center.removePendingNotificationRequests(withIdentifiers: ["rest-timer"])
    }
}
