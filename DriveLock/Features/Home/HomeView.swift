import CoreLocation
import CoreMotion
import SwiftData
import SwiftUI

/// The whole app in one screen: streak, what DriveLock is doing now, and the last few drives.
struct HomeView: View {
    @Environment(DetectionService.self) private var detection
    @Environment(ShieldingService.self) private var shielding
    @Environment(\.openURL) private var openURL
    @Query(sort: \Trip.end, order: .reverse) private var trips: [Trip]
    @State private var showSettings = false
    @State private var showShieldSetup = false

    private var streak: Int { Streak.current(newestFirst: trips.map(\.outcome)) }
    private var isDriving: Bool { if case .driving = detection.state { return true } else { return false } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if !issues.isEmpty { issuesBanner }
                    hero
                    statsRow
                    if isDriving && shielding.isShielded { passengerCard }
                    recentDrives
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(backdrop)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(isPresented: $showShieldSetup) { ShieldSetupView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    // MARK: Status
    private struct Status {
        let icon: String, title: String, detail: String, color: Color
    }

    private static let idleColor = Color(red: 0.45, green: 0.55, blue: 0.68)

    private var status: Status {
        if isDriving {
            if shielding.isShielded {
                return Status(icon: "lock.fill", title: "DriveLock is on",
                              detail: "You're driving. Distracting apps are shielded.", color: .green)
            }
            if shielding.passengerOverride {
                return Status(icon: "person.fill", title: "Passenger mode",
                              detail: "Shields are off for this drive.", color: .orange)
            }
            return Status(icon: "exclamationmark", title: "Nothing is shielded",
                          detail: "You're driving, but no apps are set to be blocked.", color: .orange)
        }
        return Status(icon: "car.fill", title: "Ready",
                      detail: "Apps will be shielded when you start driving.", color: Self.idleColor)
    }

    /// Soft glow in the state color behind the ring, on a black page.
    private var backdrop: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [status.color.opacity(0.22), .clear],
                           center: .init(x: 0.5, y: 0.22), startRadius: 0, endRadius: 320)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: status.title)
    }

    private var hero: some View {
        let s = status
        return VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(s.color, lineWidth: 8)
                    .shadow(color: s.color.opacity(0.8), radius: 14)
                    .shadow(color: s.color.opacity(0.4), radius: 30)
                Image(systemName: s.icon)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 190, height: 190)
            .padding(.top, 16)

            VStack(spacing: 8) {
                Text(s.title).font(.title2.weight(.semibold))
                Text(s.detail)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Stats
    private var todaysTrips: [Trip] { trips.filter { Calendar.current.isDateInToday($0.end) } }

    private var statsRow: some View {
        let today = todaysTrips
        let seconds = today.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
        let pickups = today.filter { $0.outcome != .passenger }.reduce(0) { $0 + $1.pickups }
        return HStack(spacing: 0) {
            stat("\(streak)", streak == 1 ? "Clean drive\nin a row" : "Clean drives\nin a row",
                 color: streak > 0 ? .accentColor : .primary)
            Divider().frame(height: 56)
            stat(Self.duration(seconds), "Drive time\ntoday")
            Divider().frame(height: 56)
            stat("\(pickups)", pickups == 1 ? "Pickup\ntoday" : "Pickups\ntoday")
        }
        .padding(.vertical, 18)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }

    private func stat(_ value: String, _ label: String, color: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// "0m", "42m", "4h 32m".
    static func duration(_ seconds: TimeInterval) -> String {
        let m = Int((seconds / 60).rounded())
        return m < 60 ? "\(m)m" : "\(m / 60)h \(m % 60)m"
    }

    private var passengerCard: some View {
        VStack(spacing: 8) {
            Button { shielding.imAPassenger() } label: {
                Label("I'm a passenger", systemImage: "person.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Text("Turns shields off for this drive and ends your streak.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    // MARK: Drives
    private var recentDrives: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent drives").font(.headline).padding(.leading, 4)
            if trips.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "road.lanes").font(.largeTitle).foregroundStyle(.tertiary)
                    Text("No drives yet. Drive as you normally would; DriveLock notices on its own.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(trips.prefix(5).enumerated()), id: \.element.persistentModelID) { i, t in
                        if i > 0 { Divider().padding(.leading, 16) }
                        tripRow(t)
                    }
                }
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tripRow(_ t: Trip) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.when(t.end)).font(.body.weight(.medium))
                Text(detail(t)).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            scorePill(t)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func scorePill(_ t: Trip) -> some View {
        let scored = t.outcome == .clean || t.outcome == .notClean
        let label = scored ? "\(t.score ?? 0)" : t.outcome.badge
        return Text(label)
            .font(scored ? .headline.monospacedDigit() : .caption.weight(.semibold))
            .foregroundStyle(scored ? .white : .secondary)
            .frame(minWidth: 44)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(scored ? t.outcome.color : Color(.tertiarySystemFill), in: Capsule())
            .accessibilityLabel(scored ? "Score \(label), \(t.outcome.badge)" : t.outcome.badge)
    }

    private func detail(_ t: Trip) -> String {
        let minutes = Int((t.end.timeIntervalSince(t.start) / 60).rounded())
        var parts = [minutes < 1 ? "<1 min" : "\(minutes) min", String(format: "%.1f mi", t.miles)]
        switch t.outcome {
        case .passenger, .unscored: break
        default: parts.append(t.pickups == 0 ? "no pickups" : t.pickups == 1 ? "1 pickup" : "\(t.pickups) pickups")
        }
        return parts.joined(separator: " · ")
    }

    /// "Today, 8:42 AM", "Yesterday, 6:10 PM", or "Oct 12, 7:05 AM".
    static func when(_ date: Date, calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "Today, \(time)" }
        if calendar.isDateInYesterday(date) { return "Yesterday, \(time)" }
        return "\(date.formatted(.dateTime.month(.abbreviated).day())), \(time)"
    }

    // MARK: Issues
    private enum Fix { case allowScreenTime, chooseApps, askLocation, openSettings }

    private struct Issue: Hashable {
        let text: String
        let button: String
        let fix: Fix
    }

    private var issues: [Issue] {
        var out: [Issue] = []
        if !shielding.isAuthorized {
            out.append(Issue(text: "Screen Time access is off, so apps can't be shielded.",
                             button: "Allow", fix: .allowScreenTime))
        } else if shielding.plan == .none {
            out.append(Issue(text: "No apps are chosen to block yet.", button: "Choose", fix: .chooseApps))
        }
        switch detection.locationAuthorization {
        case .authorizedAlways: break
        case .notDetermined:
            out.append(Issue(text: "Location isn't set up, so drives can't be detected.",
                             button: "Allow", fix: .askLocation))
        default:
            out.append(Issue(text: "Set Location to Always so drives are noticed when the app is closed.",
                             button: "Open", fix: .openSettings))
        }
        if detection.motionAuthorization == .denied || detection.motionAuthorization == .restricted {
            out.append(Issue(text: "Motion & Fitness is off, so driving can't be confirmed.",
                             button: "Open", fix: .openSettings))
        }
        return out
    }

    private func perform(_ fix: Fix) {
        switch fix {
        case .allowScreenTime: Task { await shielding.requestAuthorization() }
        case .chooseApps: showShieldSetup = true
        case .askLocation: detection.requestPermissions()
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        }
    }

    private var issuesBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Needs attention", systemImage: "exclamationmark.triangle.fill")
                .font(.headline).foregroundStyle(.orange)
            ForEach(issues, id: \.self) { issue in
                HStack(alignment: .center, spacing: 12) {
                    Text(issue.text).font(.subheadline)
                    Spacer(minLength: 0)
                    Button(issue.button) { perform(issue.fix) }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
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
