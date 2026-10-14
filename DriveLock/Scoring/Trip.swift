import Foundation
import SwiftData

/// One recorded drive. Stays on the device.
@Model
final class Trip {
    var start: Date
    var end: Date
    var miles: Double
    var pickups: Int
    var passenger: Bool
    var score: Int?
    var outcomeRaw: String

    var outcome: TripOutcome { TripOutcome(rawValue: outcomeRaw) ?? .unscored }

    init(start: Date, end: Date, miles: Double, pickups: Int, passenger: Bool, result: TripResult) {
        self.start = start
        self.end = end
        self.miles = miles
        self.pickups = pickups
        self.passenger = passenger
        self.score = result.score
        self.outcomeRaw = result.outcome.rawValue
    }
}
