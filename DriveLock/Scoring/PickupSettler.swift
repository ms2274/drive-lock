import Foundation
import SwiftData

/// Finishes a drive's score once Apple's motion recorder has caught up (its data can lag up to
/// 3 minutes). Until then the trip keeps the live count, and the summary notification waits.
@MainActor
final class PickupSettler {
    struct Pending: Codable, Equatable { var start: Date; var end: Date }

    var log: ((String) -> Void)?
    var onSettled: ((Trip) -> Void)?
    /// After this long, settle with whatever data exists rather than wait forever.
    static let giveUpAfter: TimeInterval = 15 * 60

    private let context: ModelContext
    private let defaults: UserDefaults
    private var busy = false
    private static let key = "pickups.pending"

    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.defaults = defaults
    }

    private(set) var pending: [Pending] {
        get { (defaults.data(forKey: Self.key)).flatMap { try? JSONDecoder().decode([Pending].self, from: $0) } ?? [] }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.key) }
    }

    func add(start: Date, end: Date) {
        pending.append(Pending(start: start, end: end))
        settle()
    }

    /// Safe to call often (every wake, app open); it does nothing while a check is running.
    func settle() {
        guard !busy, !pending.isEmpty else { return }
        busy = true
        Task {
            defer { busy = false }
            for p in pending {
                let result = await PickupRecorder.count(from: p.start, to: p.end)
                let overdue = Date().timeIntervalSince(p.end) > Self.giveUpAfter
                guard result?.complete == true || overdue else {
                    log?("pickups: waiting for motion recorder (\(result?.samples ?? 0) samples so far)")
                    continue
                }
                finish(p, with: result)
            }
        }
    }

    private func finish(_ p: Pending, with result: PickupRecorder.Result?) {
        pending.removeAll { $0 == p }
        let start = p.start
        guard let trip = try? context.fetch(FetchDescriptor<Trip>(predicate: #Predicate { $0.start == start })).first
        else { return }
        if let r = result, r.samples > 0 {
            log?("pickups settled: \(r.pickups) from \(r.samples) recorded samples (live count was \(trip.pickups))\(r.complete ? "" : ", data incomplete")")
            if !r.times.isEmpty {
                log?("pickup times: " + r.times.map { $0.formatted(date: .omitted, time: .standard) }.joined(separator: ", "))
            }
            TripRecorder(context: context).rescore(trip, pickups: r.pickups)
        } else {
            log?("pickups: no recorded motion data; keeping live count \(trip.pickups)")
        }
        onSettled?(trip)
    }
}
