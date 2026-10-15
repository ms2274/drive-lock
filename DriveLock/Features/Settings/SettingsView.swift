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
                    NavigationLink { ShieldSetupView() } label: { Label("Shield settings", systemImage: "lock.shield") }
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

                Section("Help") {
                    NavigationLink { HowItWorksView() } label: {
                        Label("How DriveLock works", systemImage: "questionmark.circle")
                    }
                }

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
