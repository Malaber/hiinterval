import Foundation
import HiIntervalCore
import UserNotifications

@MainActor
final class ReminderScheduler {
    private static let identifierPrefix = "hiinterval.training-reminder"
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Replaces HiInterval reminders without touching notifications owned by other features.
    @discardableResult
    func synchronize(settings: ReminderSettings) async throws -> Bool {
        let identifiers = (1...7).map(Self.identifier(for:))
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        guard settings.enabled, !settings.weekdays.isEmpty else { return true }

        let notificationSettings = await center.notificationSettings()
        let authorized: Bool
        switch notificationSettings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorized = true
        case .notDetermined:
            authorized = try await center.requestAuthorization(options: [.alert, .sound])
        case .denied:
            authorized = false
        @unknown default:
            authorized = false
        }
        guard authorized else { return false }

        for weekday in settings.weekdays.sorted() where (1...7).contains(weekday) {
            let content = UNMutableNotificationContent()
            content.title = "Time to move"
            content.body = "Your interval workout is ready when you are."
            content.sound = .default

            var date = DateComponents()
            date.calendar = Calendar(identifier: .gregorian)
            date.weekday = weekday
            date.hour = min(23, max(0, settings.hour))
            date.minute = min(59, max(0, settings.minute))
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.identifier(for: weekday),
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
        return true
    }

    func removeAll() {
        center.removePendingNotificationRequests(
            withIdentifiers: (1...7).map(Self.identifier(for:))
        )
    }

    private static func identifier(for weekday: Int) -> String {
        "\(identifierPrefix).\(weekday)"
    }
}
