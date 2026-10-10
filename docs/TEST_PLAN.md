# Driving detection test plan

## 1. Automated (no device): `DriveDetectorTests`
Replays scripted `Scenario`s through the pure `DriveDetector`. Same scenarios run on-device from Debug → "Run all".

| Scenario | Expected |
|---|---|
| Drive with 2 min red light | 1 trip, not split |
| Stop-and-go, 4 min stops | 1 trip |
| Bike ride (fast, not automotive) | no trip |
| Bus-stop dither (automotive blips) | no trip |
| Parked, engine on (automotive sticks) | trip ends after 10 min hard-stop |
| Short hop | 1 trip, ends when movement stopped |
| Invalid speed (-1) with automotive | no trip |

Also asserted: end time = last movement (not debounce expiry), start back-dated to first qualifying sample, distance accumulates.

## 2. Simulator (location only)
Simulator cannot fake CoreMotion, so automotive is never true. Use it to check location plumbing and GPS mode only.
1. Debug → Request permissions → allow Always.
2. Features → Location → Freeway Drive. Confirm speed updates; state stays `idle` (expected, no automotive).
3. Use a custom `.gpx` with a 2 min stationary waypoint to check distance filtering.

## 3. Device (required for real validation)
| # | Test | Pass |
|---|---|---|
| 1 | Walk 10 min, jog, ride a bike | No drive started |
| 2 | Bus/train ride | Note result (may false-positive; log it in CLAUDE.md) |
| 3 | 15 min real drive with a red light | One trip, start within ~2 min of leaving |
| 4 | Force-quit app, then drive | Significant-change wake-up detects it; note delay |
| 5 | Low Power Mode on, then drive | Note whether detection still occurs |
| 6 | Park, engine on, 12 min | Trip ends by 10 min |
| 7 | Battery: 1 full day, app installed vs. not | Target < 3% extra drain with no driving |

Record per test: start delay, end delay, false starts, battery %.
