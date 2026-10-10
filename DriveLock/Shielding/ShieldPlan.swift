import FamilyControls

/// What to shield for a drive, decided from the user's settings.
enum ShieldPlan: Equatable {
    /// Nothing chosen: shielding would do nothing.
    case none
    /// Default mode: shield only the chosen apps, categories and sites.
    case block(FamilyActivitySelection)
    /// Strict mode: shield everything except the chosen apps and sites.
    case allowOnly(FamilyActivitySelection)

    static func make(strict: Bool, blocked: FamilyActivitySelection, allowed: FamilyActivitySelection) -> ShieldPlan {
        if strict { return .allowOnly(allowed) }
        let empty = blocked.applicationTokens.isEmpty && blocked.categoryTokens.isEmpty
            && blocked.webDomainTokens.isEmpty
        return empty ? .none : .block(blocked)
    }
}
