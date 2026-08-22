import Foundation
import HiIntervalCore
import UserNotifications

@MainActor
final class ReminderScheduler {
    private static let identifierPrefix = "hiinterval.training-reminder"
    private let center: UNUserNotificationCenter
    private let bypassSystemScheduling: Bool
    private var synchronizationRevision = 0

    init(
        center: UNUserNotificationCenter = .current(),
        bypassSystemScheduling: Bool = ProcessInfo.processInfo.arguments.contains("--ui-testing")
    ) {
        self.center = center
        self.bypassSystemScheduling = bypassSystemScheduling
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Replaces HiInterval reminders without touching notifications owned by other features.
    @discardableResult
    func synchronize(settings: ReminderSettings) async throws -> Bool {
        synchronizationRevision &+= 1
        let revision = synchronizationRevision
        if bypassSystemScheduling { return true }

        guard settings.enabled, !settings.weekdays.isEmpty else {
            let pending = await center.pendingNotificationRequests()
            try ensureCurrent(revision)
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter(Self.isHiIntervalIdentifier)
            )
            return true
        }

        let notificationSettings = await center.notificationSettings()
        try ensureCurrent(revision)
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
        guard authorized else {
            let pending = await center.pendingNotificationRequests()
            try ensureCurrent(revision)
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter(Self.isHiIntervalIdentifier)
            )
            return false
        }

        let generation = UUID().uuidString.lowercased()
        var addedIdentifiers: [String] = []
        do {
            for weekday in settings.weekdays.sorted() where (1...7).contains(weekday) {
                try ensureCurrent(revision, cleaning: addedIdentifiers)
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
                let identifier = Self.identifier(generation: generation, weekday: weekday)
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )
                try await center.add(request)
                addedIdentifiers.append(identifier)
                try ensureCurrent(revision, cleaning: addedIdentifiers)
            }

            let pending = await center.pendingNotificationRequests()
            try ensureCurrent(revision, cleaning: addedIdentifiers)
            let current = Set(addedIdentifiers)
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter {
                    Self.isHiIntervalIdentifier($0) && !current.contains($0)
                }
            )
            return true
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: addedIdentifiers)
            throw error
        }
    }

    private func ensureCurrent(_ revision: Int, cleaning identifiers: [String] = []) throws {
        guard revision == synchronizationRevision, !Task.isCancelled else {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            throw CancellationError()
        }
    }

    private static func identifier(generation: String, weekday: Int) -> String {
        "\(identifierPrefix).\(generation).\(weekday)"
    }

    private static func isHiIntervalIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix("\(identifierPrefix).")
    }
}
