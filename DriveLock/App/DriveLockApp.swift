import SwiftData
import SwiftUI

@main
struct DriveLockApp: App {
    @State private var detection = DetectionService()
    @State private var shielding = ShieldingService()
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    init() {
        do { container = try ModelContainer(for: Trip.self) }
        catch { fatalError("Could not open the trip store: \(error)") }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack { DebugView() }
                .environment(detection)
                .environment(shielding)
                .modelContainer(container)
                .sheet(isPresented: Binding(get: { !shielding.hasCompletedSetup }, set: { _ in })) {
                    NavigationStack { ShieldSetupView(isOnboarding: true) }
                        .environment(shielding)
                        .interactiveDismissDisabled()
                }
                .task {
                    detection.onDriveStarted = { _ in shielding.driveStarted() }
                    detection.onDriveEnded = { start, end, meters in
                        let passenger = shielding.passengerOverride
                        shielding.driveEnded()
                        TripRecorder(context: container.mainContext)
                            .record(start: start, end: end, meters: meters, passenger: passenger)
                    }
                    detection.start()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { shielding.refresh() }
                }
        }
    }
}
