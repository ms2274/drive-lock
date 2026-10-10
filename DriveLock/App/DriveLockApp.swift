import SwiftUI

@main
struct DriveLockApp: App {
    @State private var detection = DetectionService()
    @State private var shielding = ShieldingService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack { DebugView() }
                .environment(detection)
                .environment(shielding)
                .sheet(isPresented: Binding(get: { !shielding.hasCompletedSetup }, set: { _ in })) {
                    NavigationStack { ShieldSetupView(isOnboarding: true) }
                        .environment(shielding)
                        .interactiveDismissDisabled()
                }
                .task {
                    detection.onDriveStarted = { _ in shielding.driveStarted() }
                    detection.onDriveEnded = { _, _, _ in shielding.driveEnded() }
                    detection.start()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { shielding.refresh() }
                }
        }
    }
}
