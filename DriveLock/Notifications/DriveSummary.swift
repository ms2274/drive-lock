import Foundation
import UserNotifications

/// The "how did that drive go" notification shown when a drive ends.
struct DriveSummary: Equatable {
    var title: String
    var body: String

    /// nil for drives too short to score: a notification for a trip to the mailbox is noise.
    static func make(miles: Double, pickups: Int, result: TripResult, streak: Int) -> DriveSummary? {
        let distance = String(format: "%.1f mi", miles)
        let handled = pickups == 0 ? "no pickups" : pickups == 1 ? "1 pickup" : "\(pickups) pickups"
        switch result.outcome {
        case .clean:
            return DriveSummary(title: "Clean drive: \(result.score ?? 100)",
                                body: "\(distance), \(handled). Streak: \(streak).")
        case .notClean:
            return DriveSummary(title: "Drive scored \(result.score ?? 0)",
                                body: "\(distance), \(handled). Streak reset; your next clean drive starts a new one.")
        case .passenger:
            return DriveSummary(title: "Passenger ride",
                                body: "\(distance), not scored. Streak reset.")
        case .unscored:
            return nil
        }
    }
}

enum DriveNotifier {
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func isAllowed() async -> Bool {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        return s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
    }

    static func post(_ summary: DriveSummary) {
        let content = UNMutableNotificationContent()
        content.title = summary.title
        content.body = summary.body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "drive-summary-\(UUID().uuidString)", content: content, trigger: nil))
    }
}
