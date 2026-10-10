import FamilyControls
import SwiftUI

/// Pick what gets shielded while driving. Shown on first launch and from the debug screen.
struct ShieldSetupView: View {
    @Environment(ShieldingService.self) private var shielding
    @Environment(\.dismiss) private var dismiss
    var isOnboarding = false
    @State private var pickingBlocked = false
    @State private var pickingAllowed = false

    var body: some View {
        @Bindable var shielding = shielding
        Form {
            Section {
                if shielding.isAuthorized {
                    Label("Screen Time access granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Allow Screen Time access") { Task { await shielding.requestAuthorization() } }
                }
            } header: { Text("Screen Time") } footer: {
                Text("DriveLock uses Screen Time to shield apps while you drive. It can't lock the phone.")
            }

            Section {
                Button("Choose apps to block") { pickingBlocked = true }
                Text(summary(shielding.blocked)).foregroundStyle(.secondary)
            } header: { Text("Block while driving") } footer: {
                Text("We suggest Messages, the Social category, and Browsers.")
            }
            .disabled(shielding.strictMode)

            Section {
                Toggle("Strict mode", isOn: $shielding.strictMode)
                if shielding.strictMode {
                    Button("Choose always-allowed apps") { pickingAllowed = true }
                    Text(summary(shielding.allowed)).foregroundStyle(.secondary)
                }
            } header: { Text("Strict mode") } footer: {
                Text("Blocks every app except the ones you allow. Pick Maps and your music app. Phone and some system apps are never blocked.")
            }
        }
        .navigationTitle("Shield settings")
        .familyActivityPicker(headerText: "Apps to block while driving",
                              isPresented: $pickingBlocked, selection: $shielding.blocked)
        .familyActivityPicker(headerText: "Apps always allowed in Strict mode",
                              isPresented: $pickingAllowed, selection: $shielding.allowed)
        .toolbar {
            if isOnboarding {
                Button("Done") {
                    shielding.hasCompletedSetup = true
                    dismiss()
                }
            }
        }
    }

    private func summary(_ s: FamilyActivitySelection) -> String {
        let a = s.applicationTokens.count, c = s.categoryTokens.count, w = s.webDomainTokens.count
        if a + c + w == 0 { return "Nothing chosen" }
        return "\(a) apps, \(c) categories, \(w) websites"
    }
}
