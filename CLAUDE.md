# DriveLock: decisions & open questions

## Decisions
- SwiftUI, iOS 17+, SwiftData local-first. Supabase only for auth + leaderboard.
- **No third-party dependencies.** Supabase via raw REST (URLSession). Project via XcodeGen (`project.yml`).
- Miles only.
- Team ID `7MP9JX7CM4`. Placeholders still: bundle `com.example.drivelock`, App Group `group.com.example.drivelock` (change before first device build).
- Detector is a pure state machine (`DriveDetector`) with injected time; sensors wrapped in `MotionSource`/`LocationSource`; `DetectionService` wires them.
- Start: automotive AND speed ≥ 10 mph for 30 s (back-dated). End: no movement ≥ 5 min (≥ 10 min if still "automotive"). Trip end time = last movement.
- Battery: significant-change always on; GPS low when automotive seen; high during drive; off after 3 idle min.
- Shielding: block-list default (prefilled Messages/Social/Browsers); **Strict mode** toggle = allow-list (all except Maps/music/user-picked). Chosen: option C.
- Shielding (b): iOS gives only opaque picker tokens, so block-list can't be prefilled; setup screen suggests Messages/Social/Browsers, and Strict mode asks the user to pick Maps + music. `ShieldingService` reacts to drive start/end; `DriveLockMonitor` extension clears shields if a 1 h safety window (renewed every 15 min while shielded) runs out. "I'm a passenger" lifts shields for the current drive only; streak penalty comes in (c).
- Process: commit after each milestone; ask before adding deps/features outside spec.

## Constraints
- Builds on Mac (Xcode 27, iOS 27 simulator; deployment target iOS 17). Regenerate with `xcodegen`, then `xcodebuild test -scheme DriveLock -destination 'platform=iOS Simulator,name=iPhone 17'`.

## Open questions / to verify on device
- Do Siri/CarPlay still read and send texts while Messages is shielded?
- Bus/train false positives?
- Detection delay after force-quit; behavior in Low Power Mode.
- Does the safety monitor reliably fire after the app is killed mid-drive?
- Pickup counting approach (milestone c): DeviceActivity thresholds + CoreMotion handling.

## Milestones
- [x] (a) Detection + debug screen
- [x] (b) App shielding (simulator build + unit tests only; device test pending)
- [ ] (c) Trip scoring
- [ ] (d) UI
- [ ] (e) Leaderboard
