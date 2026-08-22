# Delivery and testing

## Repeatable gates

`ios/HiIntervalIOS/Scripts/check_coverage.sh` runs SwiftPM tests with LLVM coverage and enforces 99% `HiIntervalCore` line coverage. It writes JSON, LCOV, text report, and summary under ignored `ios/HiIntervalIOS/coverage`.

Current test inventory is 36 portable core tests plus 10 XCUITest flows. Core coverage spans plan validation/timeline expansion, timer transitions and clock edge cases, persistence/history/safe export, active-duration accounting, and disabled future entitlement rules. UI coverage spans empty states, plan/library/history operations, preference persistence, workout execution, system accessibility audit, and largest Dynamic Type.

`ios/HiIntervalIOS/Scripts/run_ui_e2e.sh`:

1. Deletes prior artifact and derived-data directories.
2. Requires exact named simulator and generates project from `project.yml`.
3. Builds once for testing with signing disabled and parallel testing off.
4. Shuts down only the target simulator, boots it, uninstalls app, then runs tests serially.
5. Retries one complete isolated run after infrastructure/test failure.
6. Keeps logs, screenshots produced by tests, summary, and `TestResults.xcresult`; removes derived data.

UI tests launch with deterministic `--ui-testing` fixture mode. Tests must query accessibility identifiers and wait for observable state, never sleep for animation timing.

## GitHub Actions

- `ci.yml`: push, pull request, and manual CI entry point.
- `ios-checks.yml`: reusable Linux coverage plus macOS iPhone/iPad XCUITest matrix.
- `testflight.yml`: accepts only successful checks. Successful `main` push uploads when repository variable `TESTFLIGHT_UPLOAD_ENABLED` is `true`; manual upload reruns all checks first and must also target current `main`. GitHub environment `testflight` can require approval.

TestFlight variables:

- `TESTFLIGHT_UPLOAD_ENABLED`: `true` for automatic successful-`main` delivery.
- `APPLE_TEAM_ID`: defaults to `VWKG94374J`.
- `IOS_BUNDLE_IDENTIFIER`: defaults to `de.malaber.hiinterval`.
- `IOS_MARKETING_VERSION`: defaults to `0.1.0`.
- `APP_STORE_CONNECT_APP_ID`: numeric App Store Connect app ID.

TestFlight secrets:

- `KEYCHAIN_PASSWORD`
- `BUILD_CERTIFICATE_BASE64`: base64 Apple Distribution `.p12`.
- `P12_PASSWORD`
- `BUILD_PROVISION_PROFILE_BASE64`: base64 App Store provisioning profile for configured bundle ID.
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`: complete `.p8` contents.

Workflow scopes secrets only to validation and steps that consume them, imports signing material into temporary keychain, archives with manual signing, exports IPA, uploads signed archive evidence for 14 days, sends IPA with `altool --upload-package` and App Store Connect API key, then removes temporary key/profile files.

Superseded CI runs cancel by event/ref. Both automatic and manual delivery verify current `origin/main` before installing signing tools, then fetch and recheck after export immediately before upload. A commit superseded during either checks or archive cannot reach TestFlight.
