import CoreLocation
import CoreMotion
import SwiftUI

struct SettingsView: View {
    @Environment(DetectionService.self) private var detection
    @Environment(ShieldingService.self) private var shielding
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section("Apps") {
                    NavigationLink("Shield settings") { ShieldSetupView() }
                }

                Section {
                    permissionRow("Screen Time", ok: shielding.isAuthorized,
                                  okText: "Allowed", badText: "Off")
                    permissionRow("Location", ok: detection.locationAuthorization == .authorizedAlways,
                                  okText: "Always", badText: locationText)
                    permissionRow("Motion & Fitness",
                                  ok: detection.motionAuthorization == .authorized,
                                  okText: "Allowed",
                                  badText: detection.motionAuthorization == .notDetermined ? "Not asked yet" : "Off",
                                  neutral: detection.motionAuthorization == .notDetermined)
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } header: { Text("Permissions") }

                Section {
                    Text("**Let Messages be blocked.** Open iOS Settings, then Screen Time, then Always Allowed, and remove Messages. Until you do, iOS keeps Messages open no matter what DriveLock does.")
                    Text("**Set Location to Always.** That's how DriveLock notices a drive when the app is closed.")
                    Text("**Pick Maps and music in Strict mode.** Strict mode blocks everything except the apps you allow.")
                    Text("**Passenger?** Tap \"I'm a passenger\" on the main screen. It turns shields off for that drive and ends your streak, because DriveLock can't tell who is driving.")
                } header: { Text("How to use it") }

                Section {
                    Text("DriveLock can't lock your phone. It shields apps, so opening one shows a block screen. Phone calls and some system apps can't be shielded.")
                    Text("Shields come on about a minute after you start driving and stay on for about five minutes after you park.")
                    Text("Pickups are counted from phone motion and are approximate.")
                    Text("Message contents are never read. Trips stay on your phone.")
                } header: { Text("What to expect") }

                Section("Developer") {
                    NavigationLink("Debug screen") { DebugView() }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .onAppear { detection.refreshPermissions(); shielding.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { detection.refreshPermissions(); shielding.refresh() }
            }
        }
    }

    private var locationText: String {
        switch detection.locationAuthorization {
        case .authorizedWhenInUse: return "Only while using: change to Always"
        case .notDetermined: return "Not asked yet"
        default: return "Off"
        }
    }

    private func permissionRow(_ name: String, ok: Bool, okText: String, badText: String,
                               neutral: Bool = false) -> some View {
        HStack {
            Text(name)
            Spacer()
            Label(ok ? okText : badText,
                  systemImage: ok ? "checkmark.circle.fill" : neutral ? "circle" : "exclamationmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(ok ? Color.green : neutral ? Color.secondary : Color.orange)
                .font(.subheadline)
        }
    }
}
