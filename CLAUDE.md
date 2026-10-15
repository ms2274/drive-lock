# DriveLock: decisions & open questions

## Decisions
- SwiftUI, iOS 17+, SwiftData local-first. Supabase only for auth + leaderboard.
- **No third-party dependencies.** Supabase via raw REST (URLSession). Project via XcodeGen (`project.yml`).
- Miles only.
- Team ID `7MP9JX7CM4`. Bundle `com.michaelscardena.drivelock` (+ `.monitor`, `.tests`), App Group `group.com.michaelscardena.drivelock`.
- Detector is a pure state machine (`DriveDetector`) with injected time; sensors wrapped in `MotionSource`/`LocationSource`; `DetectionService` wires them.
- Start: automotive AND speed ≥ 10 mph for 30 s (back-dated). End: no movement ≥ 1 min, even if still "automotive" (Mike, 2026-10-15; accepted that stops > 1 min split the trip and lift shields). Trip end time = last movement.
- Battery: significant-change always on; GPS low when automotive seen; high during drive; off after 3 idle min.
- Shielding: block-list default (prefilled Messages/Social/Browsers); **Strict mode** toggle = allow-list (all except Maps/music/user-picked). Chosen: option C.
- Shielding (b): iOS gives only opaque picker tokens, so block-list can't be prefilled; setup screen suggests Messages/Social/Browsers, and Strict mode asks the user to pick Maps + music. `ShieldingService` reacts to drive start/end; `DriveLockMonitor` extension clears shields if a 1 h safety window (renewed every 15 min while shielded) runs out. "I'm a passenger" lifts shields for the current drive only; streak penalty comes in (c).
- Device finding (2026-10-11): shielding works on a real iPhone, but Messages is NOT shielded while it is in Settings > Screen Time > Always Allowed (Apple's default). Removing it from that list makes the shield work. Safari and other apps shield fine either way. Debug screen has "Chosen" / "In system" rows to read back what iOS holds.
- Scoring (c): 100 start, -10/pickup, clean >= 80, drives < 0.5 mi unscored, passenger override unscored + resets streak (`ScoringRules`, all in `Scoring.swift`).
- Pickups (c): option A (count shield-screen displays from a ShieldConfiguration extension) FAILED on device: the extension draws its screen but cannot write anything to the App Group (UserDefaults, atomic file, direct file all tried). Removed. Chosen: option B, a motion heuristic. `PickupDetector` watches gravity direction in the phone frame: >= 35 deg swing within 2 s = pickup; handling within 10 s of the last tilt is the same pickup. Only counted between drive start and the back-dated drive end. Debug screen has a "pickup test" switch to try it without a drive. Thresholds are guesses until tuned on real drives.
- UI (d): extremely simple, one screen; no tabs. Gear opens Settings sheet. Onboarding: welcome, Screen Time + pick apps, remove Messages from Always Allowed, Location Always, done. Home shows an orange banner listing anything missing.
- UI restyle (2026-10-15, from Mike's mockup): always-dark, glowing status ring on home, today stats (streak / drive time / pickups), icon rows in Settings, teal gradient welcome. Wording says "apps shielded", never "phone locked". `DriveLockShield` extension is back for the block screen's look only (it still can't write to the App Group). No emergency-unlock button; passenger button covers that.
- Process: commit after each milestone; ask before adding deps/features outside spec.

## Constraints
- Builds on Mac (Xcode 27, iOS 27 simulator; deployment target iOS 17). Regenerate with `xcodegen`, then `xcodebuild test -scheme DriveLock -destination 'platform=iOS Simulator,name=iPhone 17'`.

## Open questions / to verify on device
- LATE START (first real drive, 2026-10-15): shields came on partway through the drive, not within ~1 min. Trip recorded 40 s / bogus 1.46 mi (stale-fix distance jump, fixed in 9f335f6). Code review found: (1) `detection.start()` and the shield/trip wiring lived in a SwiftUI `.task`, which never runs on a silent background relaunch, so a drive could only start once the app was opened; moved to `AppDelegate.didFinishLaunching`. (2) background GPS was only enabled at launch if already Always; now also on auth change. (3) still open, by design: a significant-change wake only turns GPS on if motion already says automotive in the last 5 min, and motion often lags at drive start, so the app may sleep until the next significant-change wake (often several minutes / ~500 m). Possible fix (needs OK, changes battery spec): brief low GPS on every wake, or a geofence around the parked spot. Event log now persists to Documents/drivelock-events.log (Settings > Developer > Share full log) with launches, wakes + 5 min motion history, GPS mode changes, iOS pauses, 15 s heartbeats while GPS is on.
- Do Siri/CarPlay still read and send texts while Messages is shielded? (Messages must first be removed from Always Allowed to shield it at all.)
- Bus/train false positives?
- Detection delay after force-quit; behavior in Low Power Mode.
- Does the safety monitor reliably fire after the app is killed mid-drive?
- Pickup detector thresholds (35 deg / 2 s / 10 s): tune on real drives (false positives from bumps, mount adjustments; misses with phone in a pocket).

## Milestones
- [x] (a) Detection + debug screen
- [x] (b) App shielding (simulator build + unit tests only; device test pending)
- [~] (c) Trip scoring (built + tested in simulator; real-drive tuning pending)
- [x] (d) UI: single screen (streak, status, last 5 drives, passenger button) + settings sheet + 5-step onboarding incl. 'remove Messages from Always Allowed'. Debug screen lives under Settings > Developer.
- [ ] (e) Leaderboard
