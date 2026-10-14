import CoreLocation
import SwiftUI

/// First-launch guide. Every step can be skipped; the main screen flags anything still missing.
struct OnboardingView: View {
    @Environment(DetectionService.self) private var detection
    @Environment(ShieldingService.self) private var shielding
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var step = 0

    private let lastStep = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) { content }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                footer
            }
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { detection.refreshPermissions(); shielding.refresh() }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0:
            header("car.fill", "Drive without distractions")
            Text("DriveLock shields distracting apps while you drive and keeps a streak of clean drives.")
            Text("It can't lock your phone. It makes opening apps harder by showing a block screen, and it keeps score so you can see how you're doing.")
                .foregroundStyle(.secondary)
        case 1:
            header("hourglass", "Allow Screen Time")
            Text("DriveLock uses Screen Time to shield apps. You choose which ones.")
            if shielding.isAuthorized {
                Label("Screen Time allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("Allow Screen Time") { Task { await shielding.requestAuthorization() } }
                    .buttonStyle(.borderedProminent)
            }
            NavigationLink("Choose apps to block") { ShieldSetupView() }
                .disabled(!shielding.isAuthorized)
            Text("We suggest Messages, the Social category, and Browsers.")
                .font(.footnote).foregroundStyle(.secondary)
        case 2:
            header("message.fill", "Let Messages be blocked")
            Text("By default iOS keeps Messages open no matter what an app does. To let DriveLock block it:")
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Open the iOS **Settings** app")
                Text("2. Tap **Screen Time**")
                Text("3. Tap **Always Allowed**")
                Text("4. Tap the red minus next to **Messages**")
            }
            Button("Open iOS Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.bordered)
            Text("Phone calls always stay available, so you can still reach emergency help.")
                .font(.footnote).foregroundStyle(.secondary)
        case 3:
            header("location.fill", "Notice when you drive")
            Text("DriveLock uses your location and motion to tell when you're in a car, even when the app is closed. Location stays on your phone.")
            Text("Choose **Always** when iOS asks for location access.")
            if detection.locationAuthorization == .authorizedAlways {
                Label("Location: Always", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("Allow Location") { detection.requestPermissions() }
                    .buttonStyle(.borderedProminent)
                if detection.locationAuthorization == .authorizedWhenInUse {
                    Text("Currently \"While Using\". Tap again and choose Always, or change it in iOS Settings.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        default:
            header("checkmark.seal.fill", "You're set")
            Text("Just drive as normal. When a drive starts, DriveLock shields your apps. When it ends, they come back.")
            Text("You can change any of this later from the gear icon on the main screen.")
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") { step -= 1 }.buttonStyle(.bordered)
            }
            Spacer()
            Button(step == lastStep ? "Start" : "Continue") {
                if step == lastStep { shielding.hasCompletedSetup = true } else { step += 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(16)
        .background(.bar)
    }

    private func header(_ icon: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(.tint)
            Text(title).font(.largeTitle.bold())
        }
    }
}
