import CoreLocation
import CoreMotion
import SwiftData
import SwiftUI

/// The whole app in one screen: streak, what DriveLock is doing now, and the last few drives.
struct HomeView: View {
    @Environment(DetectionService.self) private var detection
    @Environment(ShieldingService.self) private var shielding
    @Query(sort: \Trip.end, order: .reverse) private var trips: [Trip]
    @State private var showSettings = false

    private var streak: Int { Streak.current(newestFirst: trips.map(\.outcome)) }
    private var isDriving: Bool { if case .driving = detection.state { return true } else { return false } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if !issues.isEmpty { issuesBanner }
                    streakBlock
                    statusBlock
                    if isDriving && shielding.isShielded { passengerBlock }
                    recentDrives
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .navigationTitle("DriveLock")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    // MARK: Sections
    private var streakBlock: some View {
        VStack(spacing: 4) {
            Text("\(streak)")
                .font(.system(size: 88, weight: .bold, design: .rounded))
                .foregroundStyle(streak > 0 ? Color.green : Color.secondary)
                .contentTransition(.numericText())
            Text(streak == 1 ? "clean drive in a row" : "clean drives in a row")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var statusBlock: some View {
        let s = status
        return HStack(spacing: 12) {
            Image(systemName: s.icon).font(.title3).foregroundStyle(s.color)
            Text(s.text).font(.headline)
            Spacer()
        }
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    private var passengerBlock: some View {
        VStack(spacing: 8) {
            Button { shielding.imAPassenger() } label: {
                Text("I'm a passenger").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Text("Turns shields off for this drive and ends your streak.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private var recentDrives: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent drives").font(.headline)
            if trips.isEmpty {
                Text("No drives yet. Drive as you normally would; DriveLock notices on its own.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(trips.prefix(5).enumerated()), id: \.element.persistentModelID) { i, t in
                        if i > 0 { Divider() }
                        tripRow(t)
                    }
                }
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tripRow(_ t: Trip) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.end.formatted(date: .abbreviated, time: .shortened)).font(.subheadline)
                Text(detail(t)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(t.outcome.badge).font(.subheadline.weight(.semibold)).foregroundStyle(t.outcome.color)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }

    private func detail(_ t: Trip) -> String {
        let miles = String(format: "%.1f mi", t.miles)
        switch t.outcome {
        case .passenger, .unscored: return miles
        default: return "\(miles) · " + (t.pickups == 0 ? "no pickups" : t.pickups == 1 ? "1 pickup" : "\(t.pickups) pickups")
        }
    }

    // MARK: Status and issues
    private var status: (icon: String, text: String, color: Color) {
        if isDriving {
            if shielding.isShielded { return ("lock.fill", "Driving: apps are shielded", .green) }
            if shielding.passengerOverride { return ("person.fill", "Passenger: shields are off", .orange) }
            return ("exclamationmark.triangle.fill", "Driving: nothing is being shielded", .orange)
        }
        return ("car.fill", "Not driving", .secondary)
    }

    private var issues: [String] {
        var out: [String] = []
        if !shielding.isAuthorized { out.append("Screen Time access is off, so apps can't be shielded.") }
        else if shielding.plan == .none { out.append("No apps are chosen to block yet.") }
        switch detection.locationAuthorization {
        case .authorizedAlways: break
        case .notDetermined: out.append("Location isn't set up, so drives can't be detected.")
        default: out.append("Set Location to Always so drives are noticed when the app is closed.")
        }
        if detection.motionAuthorization == .denied || detection.motionAuthorization == .restricted {
            out.append("Motion & Fitness is off, so driving can't be confirmed.")
        }
        return out
    }

    private var issuesBanner: some View {
        Button { showSettings = true } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label("Needs attention", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline).foregroundStyle(.orange)
                ForEach(issues, id: \.self) { Text($0).font(.subheadline).foregroundStyle(.primary) }
                Text("Tap to fix").font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

extension TripOutcome {
    var badge: String {
        switch self {
        case .clean: return "Clean"
        case .notClean: return "Not clean"
        case .unscored: return "Short"
        case .passenger: return "Passenger"
        }
    }

    var color: Color {
        switch self {
        case .clean: return .green
        case .notClean: return .red
        case .unscored, .passenger: return .secondary
        }
    }
}
