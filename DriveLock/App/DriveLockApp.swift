import SwiftData
import SwiftUI
import UIKit
import UserNotifications

/// Owns the services and starts detection at process launch. When iOS relaunches the app in the
/// background for a location event, no window is created, so SwiftUI view tasks never run;
/// starting here is what lets a drive be detected (and shielded) without opening the app.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let detection = DetectionService()
    let shielding = ShieldingService()
    let container: ModelContainer = {
        do { return try ModelContainer(for: Trip.self) }
        catch { fatalError("Could not open the trip store: \(error)") }
    }()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // A "screen active" line soon after means the user opened it; none means a silent background launch.
        detection.note(options?[.location] != nil ? "APP LAUNCH by iOS for a location event" : "APP LAUNCH")
        UNUserNotificationCenter.current().delegate = self

        detection.onDriveStarted = { [shielding, detection] _ in
            shielding.driveStarted()
            detection.note("shields on request: \(shielding.status)")
        }
        detection.onDriveEnded = { [shielding, detection, container] start, end, meters in
            let passenger = shielding.passengerOverride
            shielding.driveEnded()
            let context = container.mainContext
            let trip = TripRecorder(context: context)
                .record(start: start, end: end, meters: meters,
                        pickups: detection.pickups(from: start, to: end), passenger: passenger)
            let newestFirst = (try? context.fetch(FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.end, order: .reverse)]))) ?? []
            let streak = Streak.current(newestFirst: newestFirst.map(\.outcome))
            if let summary = DriveSummary.make(miles: trip.miles, pickups: trip.pickups,
                                               result: TripResult(score: trip.score, outcome: trip.outcome),
                                               streak: streak) {
                DriveNotifier.post(summary)
                detection.note("summary notification: \(summary.title)")
            }
        }
        detection.start()
        return true
    }

    /// Show the drive summary even if DriveLock is open when the drive ends.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions { [.banner, .sound] }

    func applicationWillTerminate(_ application: UIApplication) {
        detection.note("app terminating")
    }
}

@main
struct DriveLockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(app.detection)
                .environment(app.shielding)
                .modelContainer(app.container)
                .sheet(isPresented: Binding(get: { !app.shielding.hasCompletedSetup }, set: { _ in })) {
                    OnboardingView()
                        .environment(app.detection)
                        .environment(app.shielding)
                        .interactiveDismissDisabled()
                }
                .onChange(of: scenePhase) { _, phase in
                    app.detection.note("screen \(phase)")
                    if phase == .active { app.shielding.refresh(); app.detection.refreshPermissions() }
                }
        }
    }
}
