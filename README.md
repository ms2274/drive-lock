# DriveLock

iOS 17+ SwiftUI app that shields distracting apps while you drive and scores clean drives.

## Read this first: what iOS can and cannot do
- **iOS cannot lock the phone.** There is no API for it. DriveLock uses Screen Time (FamilyControls / ManagedSettings / DeviceActivity) to *shield* apps: opening one shows a block screen.
- **It is friction, not enforcement.** A user can open Settings and remove Screen Time access. Phone, some system apps, and notifications cannot be shielded.
- **Starts late, ends late.** Detection needs ~30 s of driving to confirm and ~5 min of stillness to end a trip, so shields come on shortly after you leave and linger after you park.
- **Passengers can't be detected.** The "I'm a passenger" button logs an override and costs the streak.
- **Pickup counts are approximate.**

## Privacy
Message contents are never read or stored. Trips live on device (SwiftData). Only account identity and leaderboard totals go to Supabase.

## Setup
```
brew install xcodegen
# edit project.yml: DEVELOPMENT_TEAM, bundle IDs
xcodegen && open DriveLock.xcodeproj
```
Run on a real iPhone. Family Controls and CoreMotion don't work in the simulator.

## Docs
`docs/TEST_PLAN.md` · `docs/DISTRIBUTION_CHECKLIST.md` · `CLAUDE.md` (decisions)
