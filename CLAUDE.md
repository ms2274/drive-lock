# DriveLock: decisions & open questions

## Decisions
- SwiftUI, iOS 17+, SwiftData local-first. Supabase only for auth + leaderboard.
- **No third-party dependencies.** Supabase via raw REST (URLSession). Project via XcodeGen (`project.yml`).
- Miles only.
- Placeholders: bundle `com.example.drivelock`, App Group `group.com.example.drivelock`, empty Team ID.
- Detector is a pure state machine (`DriveDetector`) with injected time; sensors wrapped in `MotionSource`/`LocationSource`; `DetectionService` wires them.
- Start: automotive AND speed ≥ 10 mph for 30 s (back-dated). End: no movement ≥ 5 min (≥ 10 min if still "automotive"). Trip end time = last movement.
- Battery: significant-change always on; GPS low when automotive seen; high during drive; off after 3 idle min.
- Shielding: block-list default (prefilled Messages/Social/Browsers); **Strict mode** toggle = allow-list (all except Maps/music/user-picked). Chosen: option C.
- Process: commit after each milestone; ask before adding deps/features outside spec.

## Constraints
- Builds on Mac (Xcode 27, iOS 27 simulator; deployment target iOS 17). Regenerate with `xcodegen`, then `xcodebuild test -scheme DriveLock -destination 'platform=iOS Simulator,name=iPhone 17'`.

## Open questions / to verify on device
- Do Siri/CarPlay still read and send texts while Messages is shielded?
- Bus/train false positives?
- Detection delay after force-quit; behavior in Low Power Mode.
- Pickup counting approach (milestone c): DeviceActivity thresholds + CoreMotion handling.

## Milestones
- [x] (a) Detection + debug screen
- [ ] (b) App shielding
- [ ] (c) Trip scoring
- [ ] (d) UI
- [ ] (e) Leaderboard
