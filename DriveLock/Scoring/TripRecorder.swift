import Foundation
import SwiftData

/// Turns a finished drive into a saved, scored Trip.
@MainActor
struct TripRecorder {
    let context: ModelContext
    var rules = ScoringRules.default
    var pickupCount: (_ start: Date, _ end: Date) -> Int = { ShieldAttemptLog.count(from: $0, to: $1) }

    @discardableResult
    func record(start: Date, end: Date, meters: Double, passenger: Bool) -> Trip {
        let miles = meters / 1609.344
        let pickups = pickupCount(start, end)
        let result = TripScorer.result(miles: miles, pickups: pickups, passenger: passenger, rules: rules)
        let trip = Trip(start: start, end: end, miles: miles, pickups: pickups,
                        passenger: passenger, result: result)
        context.insert(trip)
        try? context.save()
        return trip
    }
}
