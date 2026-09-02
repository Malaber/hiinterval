# HiInterval

Native iPhone and iPad HIIT timer. Fast planning, glanceable training, local history, no account.

## Product

- Build reusable workouts with configurable warm-up, work, recovery, round recovery, cool-down, rounds, and exercise order.
- Override individual exercise duration/recovery.
- Split exercises or selected rounds into deterministic left/right phases, including switch time.
- Run pause/resume/skip-safe sessions without timer drift; get sound, spoken, haptic, and final-countdown cues.
- Review history, streak, duration, and completed-workout totals.
- Configure appearance, screen wake behavior, reminders, spoken/tonal cues, music ducking, haptics, and app-inactive behavior.
- Persist everything locally as versioned Codable data. No backend, web component, analytics, or authentication.

App is completely free now. The planned monetization policy keeps every feature free until both at least 30 days have passed and 10 workouts have been completed, then includes three workouts each calendar month unless unlimited access was purchased. The current domain logic is disabled and still needs to be aligned with that policy before monetization launches. No StoreKit product or paywall ships yet.

## Stack

- Swift 6, SwiftUI, iOS 17+
- Pure `HiIntervalCore` Swift package for plans, timeline expansion, timer state, history, persistence schema, and entitlement policy
- XcodeGen project spec; generated `.xcodeproj` stays untracked
- XCTest + XCUITest on iPhone and iPad
- Invoke tasks matching Planini delivery ergonomics

## Local setup

Requires Xcode 26, iOS 26 simulator runtimes, Homebrew, and Python 3.11+.

```bash
python3 -m venv .venv
.venv/bin/pip install -e .
.venv/bin/inv install-xcodegen
.venv/bin/inv generate-ios-project
open ios/HiIntervalIOS/HiIntervalApp.xcodeproj
```

Generated project uses scheme `HiInterval` and defaults to bundle ID `de.malaber.hiinterval`.

## Verification

```bash
# Portable core tests + 99% line-coverage gate
.venv/bin/inv check-ios-package

# Deterministic serial XCUITest; logs/screenshots/xcresult land under e2e-artifacts/
.venv/bin/inv ios-ui-e2e --device-name="iPhone 17 Pro"
.venv/bin/inv ios-ui-e2e \
  --device-name="iPad Pro 13-inch (M5)" \
  --artifact-dir=e2e-artifacts/ios-ipad

# Same complete gate used before manual TestFlight uploads
.venv/bin/inv check
```

CI runs Swift package coverage in Linux Swift 6.2 plus full XCUITest on named iPhone and iPad simulators. Test execution is serial, starts from reset app data and clean derived data, retries only failed XCTest cases when they can be identified (with a full-run fallback), and always uploads diagnostic evidence. Pull requests run once through the PR event; pushes run automatically on `main`.

Current suite contains 36 portable core tests and 10 XCUITest flows. Core tests cover plans/timeline expansion, drift-safe timer behavior, persistence/history/safe export, active duration, and future entitlement policy. UI flows cover empty states, plan/library/history management, settings persistence, full training transitions, accessibility audit, and largest Dynamic Type.

See [architecture](docs/architecture.md), [delivery/testing](docs/delivery.md), and the
[App Store Connect/TestFlight setup](docs/app-store-connect-setup.md).
