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
                    NavigationLink { ShieldSetupView() } label: {
                        row("square.grid.2x2", "Blocked apps", shieldSummary)
                    }
                }

                Section {
                    permissionRow("hourglass", "Screen Time", ok: shielding.isAuthorized,
                                  okText: "Allowed", badText: "Off")
                    permissionRow("location.fill", "Location", ok: detection.locationAuthorization == .authorizedAlways,
                                  okText: "Always", badText: locationText)
                    permissionRow("figure.walk.motion", "Motion & Fitness",
                                  ok: detection.motionAuthorization == .authorized,
                                  okText: "Allowed",
                                  badText: detection.motionAuthorization == .notDetermined ? "Not asked yet" : "Off",
                                  neutral: detection.motionAuthorization == .notDetermined)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: { row("gear", "Open iOS Settings", nil) }
                } header: { Text("Permissions") }

                Section("Help") {
                    NavigationLink { HowItWorksView() } label: {
                        row("questionmark.circle", "How DriveLock works", nil)
                    }
                }

                Section("Developer") {
                    NavigationLink { DebugView() } label: { row("ladybug", "Debug screen", nil) }
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

    private var shieldSummary: String {
        if shielding.strictMode { return "Strict mode: all but allowed apps" }
        return shielding.plan == .none ? "None chosen" : "Chosen apps and categories"
    }

    /// Icon, title and an optional line underneath, like a system settings row.
    private func row(_ icon: String, _ title: String, _ subtitle: String?,
                     subtitleColor: Color = .secondary) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(subtitleColor) }
            }
        }
        .padding(.vertical, 2)
    }

    private func permissionRow(_ icon: String, _ name: String, ok: Bool, okText: String, badText: String,
                               neutral: Bool = false) -> some View {
        HStack {
            row(icon, name, ok ? okText : badText,
                subtitleColor: ok ? .green : neutral ? .secondary : .orange)
            Spacer()
            Image(systemName: ok ? "checkmark.circle.fill" : neutral ? "circle" : "exclamationmark.circle.fill")
                .foregroundStyle(ok ? Color.green : neutral ? Color.secondary : Color.orange)
                .accessibilityHidden(true)
        }
    }
}
