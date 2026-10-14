import Foundation

/// Tunable numbers for scoring a drive. Change them here only.
struct ScoringRules: Equatable {
    var startScore = 100
    var pointsPerPickup = 10
    /// A drive at or above this score counts as clean and extends the streak.
    var cleanThreshold = 80
    /// Shorter drives are not scored and do not touch the streak.
    var minimumMiles = 0.5

    static let `default` = ScoringRules()
}

enum TripOutcome: String, Codable {
    case clean
    case notClean
    case unscored
    case passenger
}

struct TripResult: Equatable {
    var score: Int?
    var outcome: TripOutcome
}

enum TripScorer {
    static func result(miles: Double, pickups: Int, passenger: Bool,
                       rules: ScoringRules = .default) -> TripResult {
        if passenger { return TripResult(score: nil, outcome: .passenger) }
        if miles < rules.minimumMiles { return TripResult(score: nil, outcome: .unscored) }
        let score = max(0, rules.startScore - max(0, pickups) * rules.pointsPerPickup)
        return TripResult(score: score, outcome: score >= rules.cleanThreshold ? .clean : .notClean)
    }
}

enum Streak {
    /// Counts clean drives back from the newest. A not-clean drive or a passenger override ends the count;
    /// unscored short drives are skipped.
    static func current(newestFirst outcomes: [TripOutcome]) -> Int {
        var n = 0
        for o in outcomes {
            switch o {
            case .clean: n += 1
            case .unscored: continue
            case .notClean, .passenger: return n
            }
        }
        return n
    }
}
