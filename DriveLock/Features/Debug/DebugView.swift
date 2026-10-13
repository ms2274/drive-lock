import SwiftUI

/// Milestone (a) screen: live detector state plus a replay harness.
struct DebugView: View {
    @Environment(DetectionService.self) private var detection
    @Environment(ShieldingService.self) private var shielding
    @State private var replayResults: [ReplayResult] = []

    var body: some View {
        List {
            Section("Live") {
                row("State", String(describing: detection.state))
                row("Automotive", detection.automotive ? "yes" : "no")
                row("Speed", String(format: "%.0f mph", detection.speedMph))
                row("Trip distance", String(format: "%.2f mi", detection.miles))
                row("GPS mode", detection.trackingMode.rawValue)
                Button("Request permissions") { detection.requestPermissions() }
            }
            Section("Shielding") {
                row("Shields", shielding.isShielded ? "on" : "off")
                row("Mode", shielding.strictMode ? "strict" : "block-list")
                row("Screen Time", shielding.isAuthorized ? "granted" : "not granted")
                if !shielding.status.isEmpty { row("Last", shielding.status) }
                row("Chosen", "apps \(shielding.blocked.applicationTokens.count), categories \(shielding.blocked.categoryTokens.count), sites \(shielding.blocked.webDomainTokens.count)")
                row("In system", shielding.appliedSummary)
                NavigationLink("Shield settings") { ShieldSetupView() }
                Button("Shield now") { shielding.shieldNow() }
                Button("Unshield") { shielding.unshield() }
                Button("I'm a passenger") { shielding.imAPassenger() }
                    .disabled(!shielding.isShielded)
            }
            Section("Replay scenarios (offline, no sensors)") {
                Button("Run all") { replayResults = Scenario.all.map(ReplayResult.run) }
                ForEach(replayResults) { r in
                    HStack {
                        Image(systemName: r.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(r.passed ? .green : .red)
                        VStack(alignment: .leading) {
                            Text(r.name).font(.subheadline)
                            Text(r.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Event log") {
                ForEach(detection.log) { e in
                    Text("\(e.date.formatted(date: .omitted, time: .standard))  \(e.text)")
                        .font(.caption.monospaced())
                }
            }
        }
        .navigationTitle("Detection Debug")
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k); Spacer(); Text(v).foregroundStyle(.secondary) }
    }
}

struct ReplayResult: Identifiable {
    let id = UUID()
    let name: String
    let passed: Bool
    let detail: String

    static func run(_ s: Scenario) -> ReplayResult {
        var d = DriveDetector()
        var events: [DetectorEvent] = []
        for sample in s.samples() { events += d.ingest(sample) }
        let ended = events.compactMap { e -> Double? in
            if case .driveEnded(_, _, let m) = e { return m } else { return nil }
        }
        let started = events.contains { if case .driveStarted = $0 { return true } else { return false } }
        let ok = started == s.expectsDrive && ended.count == (s.expectsDrive ? 1 : 0)
        return ReplayResult(name: s.name, passed: ok,
            detail: "started=\(started) ended=\(ended.count) miles=\(ended.first.map { String(format: "%.1f", $0 / 1609.344) } ?? "-")")
    }
}
