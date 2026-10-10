import SwiftUI

@main
struct DriveLockApp: App {
    @State private var detection = DetectionService()

    var body: some Scene {
        WindowGroup {
            NavigationStack { DebugView() }
                .environment(detection)
                .task { detection.start() }
        }
    }
}
