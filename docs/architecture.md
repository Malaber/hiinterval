# Architecture

## Boundaries

`ios/HiIntervalIOS/Sources/HiIntervalCore` contains platform-light domain code:

- `WorkoutPlan`: plan, exercise, round override, duration/recovery, left/right configuration, validation.
- `WorkoutTimeline`: expands configuration into ordered warm-up/work/switch/recovery/round-recovery/cool-down phases.
- `IntervalTimerEngine`: injected-time state machine for start, tick, pause, resume, skip, finish, and delayed ticks.
- `AppData`: Codable plans, preferences, history, selected plan, usage, and stable JSON codec.
- `HistorySummary`: totals and calendar-day streaks.
- `EntitlementPolicy`: disabled-by-default future purchase/trial/monthly-credit decisions.

`ios/HiIntervalIOS/App` owns SwiftUI presentation and Apple frameworks. `AppStore` is main-actor state owner and local persistence boundary. Views never implement interval arithmetic; session controller consumes expanded core timeline.

iPhone stays portrait for a stable glanceable workout console; iPad supports every orientation and multitasking size.

No server or identity exists. Authentication and `Malaber/python-libs` passkey package are intentionally absent. Planini code needs no extraction or PR for current scope.

`PrivacyInfo.xcprivacy` declares no tracking or collected data and records the app-only UserDefaults required-reason API use (`CA92.1`).

## Data and evolution

App persists one sorted-key JSON payload in `UserDefaults`. History stores optional plan snapshot so later plan edits do not rewrite completed training. Corrupt payload recovery preserves the unreadable bytes under a recovery key before creating starter data and showing a user-facing error.

Future schema changes should decode old payloads into `AppData`, normalize selection/history, then add focused codec migration tests before changing persistence key.

## Monetization boundary

Current app constructs `EntitlementPolicy()` with `monetizationEnabled == false`; every workout is allowed. Future StoreKit work should map verified transaction state to `UsageRecord.purchasedUnlimited`, enable policy through explicit release configuration, and keep StoreKit outside `HiIntervalCore`.
