# DriveLock: decisions & open questions

## Decisions
- SwiftUI, iOS 17+, SwiftData local-first. Supabase only for auth + leaderboard.
- **No third-party dependencies.** Supabase via raw REST (URLSession). Project via XcodeGen (`project.yml`).
- Miles only.
- Team ID `7MP9JX7CM4`. Bundle `com.michaelscardena.drivelock` (+ `.monitor`, `.tests`), App Group `group.com.michaelscardena.drivelock`.
- Detector is a pure state machine (`DriveDetector`) with injected time; sensors wrapped in `MotionSource`/`LocationSource`; `DetectionService` wires them.
- Start: automotive AND speed ≥ 10 mph for 30 s (back-dated). End: no movement ≥ 5 min (≥ 10 min if still "automotive"). Trip end time = last movement.
- Battery: significant-change always on; GPS low when automotive seen; high during drive; off after 3 idle min.
- Shielding: block-list default (prefilled Messages/Social/Browsers); **Strict mode** toggle = allow-list (all except Maps/music/user-picked). Chosen: option C.
- Shielding (b): iOS gives only opaque picker tokens, so block-list can't be prefilled; setup screen suggests Messages/Social/Browsers, and Strict mode asks the user to pick Maps + music. `ShieldingService` reacts to drive start/end; `DriveLockMonitor` extension clears shields if a 1 h safety window (renewed every 15 min while shielded) runs out. "I'm a passenger" lifts shields for the current drive only; streak penalty comes in (c).
- Device finding (2026-10-11): shielding works on a real iPhone, but Messages is NOT shielded while it is in Settings > Screen Time > Always Allowed (Apple's default). Removing it from that list makes the shield work. Safari and other apps shield fine either way. Debug screen has "Chosen" / "In system" rows to read back what iOS holds.
- Scoring (c): 100 start, -10/pickup, clean >= 80, drives < 0.5 mi unscored, passenger override unscored + resets streak (`ScoringRules`, all in `Scoring.swift`).
- Pickups (c): option A (count shield-screen displays from a ShieldConfiguration extension) FAILED on device: the extension draws its screen but cannot write anything to the App Group (UserDefaults, atomic file, direct file all tried). Removed. Chosen: option B, a motion heuristic. `PickupDetector` watches gravity direction in the phone frame: >= 35 deg swing within 2 s = pickup; handling within 20 s of the last tilt is the same pickup. Only counted between drive start and the back-dated drive end. Debug screen has a "pickup test" switch to try it without a drive. Thresholds are guesses until tuned on real drives.
- Process: commit after each milestone; ask before adding deps/features outside spec.

## Constraints
- Builds on Mac (Xcode 27, iOS 27 simulator; deployment target iOS 17). Regenerate with `xcodegen`, then `xcodebuild test -scheme DriveLock -destination 'platform=iOS Simulator,name=iPhone 17'`.

## Open questions / to verify on device
- Do Siri/CarPlay still read and send texts while Messages is shielded? (Messages must first be removed from Always Allowed to shield it at all.)
- Should the setup screen tell users to remove Messages from Always Allowed? (not built; needs your OK)
- Bus/train false positives?
- Detection delay after force-quit; behavior in Low Power Mode.
- Does the safety monitor reliably fire after the app is killed mid-drive?
- Pickup detector thresholds (35 deg / 2 s / 20 s): tune on real drives (false positives from bumps, mount adjustments; misses with phone in a pocket).

## Milestones
- [x] (a) Detection + debug screen
- [x] (b) App shielding (simulator build + unit tests only; device test pending)
- [~] (c) Trip scoring (built + tested in simulator; real-drive tuning pending)
- [ ] (d) UI
- [ ] (e) Leaderboard
