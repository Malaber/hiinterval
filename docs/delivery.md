# Delivery and testing

## Repeatable gates

`ios/HiIntervalIOS/Scripts/check_coverage.sh` runs SwiftPM tests with LLVM coverage and enforces 99% `HiIntervalCore` line coverage. It writes JSON, LCOV, text report, and summary under ignored `ios/HiIntervalIOS/coverage`.

The current inventory is defined by the XCTest sources. Core coverage includes catalogue migration/merging, generation filters and alternation, and plan validation/timeline expansion, timer transitions and clock edge cases, persistence/history/safe export, active-duration accounting, and disabled future entitlement rules. UI coverage spans empty states, plan/library/history operations, preference persistence, workout execution, explicit accessibility-label, hit-target, and phase-semantic contracts, plus largest Dynamic Type.

`ios/HiIntervalIOS/Scripts/run_ui_e2e.sh`:

1. Deletes prior artifact and derived-data directories.
2. Requires exact named simulator and generates project from `project.yml`.
3. Builds once for testing with signing disabled and parallel testing off.
4. Shuts down only the target simulator, boots it, uninstalls app, then runs tests serially.
5. Runs each device suite once. Any assertion or infrastructure failure fails the job directly.
6. Keeps logs, screenshots produced by tests, summary, and `TestResults.xcresult`; removes derived data.

UI tests launch with deterministic `--ui-testing` fixture mode. Tests must query accessibility identifiers and wait for observable state, never sleep for animation timing.

## Local Xcode upload

With an Xcode Apple account configured for team `VWKG94374J`, upload a signed archive directly:

```bash
.venv/bin/inv upload-testflight --marketing-version=0.5.4 --build-number=1
```

Each later upload uses a fresh marketing version, increased by at least one SemVer patch. Never
upload a marketing version twice. After required local checks pass, pushes containing app changes
are followed immediately by CLI TestFlight delivery without polling remote CI. Documentation-only
pushes require no version bump or upload. The task generates the
Xcode project, archives with automatic signing, exports with
`ExportOptions.TestFlight.plist`, and uploads to App Store Connect. It deliberately gives Xcode a
system-only `PATH`: Homebrew `rsync` does not support Apple's extended-attribute option and causes
an opaque `exportArchive Copy failed` error. The signed archive remains at the printed temporary
path for Organizer inspection.

## GitHub Actions

- `ci.yml`: `main` push, pull request, and manual CI entry point. PR branch pushes are covered only by the pull-request event, avoiding duplicate matrices.
- `ios-checks.yml`: reusable Linux coverage plus macOS iPhone/iPad XCUITest matrix.
- `testflight.yml`: accepts only successful checks. Successful `main` push uploads when repository variable `TESTFLIGHT_UPLOAD_ENABLED` is `true`; manual upload reruns all checks first and must also target current `main`. GitHub environment `testflight` can require approval.

Until the App Store Connect record and signing settings are provisioned, leave
`TESTFLIGHT_UPLOAD_ENABLED` unset. Pull requests never upload. Follow the
[one-time App Store Connect setup](app-store-connect-setup.md), perform one manual upload from
`main`, then enable automatic delivery.

TestFlight variables:

- `TESTFLIGHT_UPLOAD_ENABLED`: `true` for automatic successful-`main` delivery.
- `APPLE_TEAM_ID`: defaults to `VWKG94374J`.
- `IOS_BUNDLE_IDENTIFIER`: defaults to `de.malaber.hiinterval`.
- `IOS_MARKETING_VERSION`: defaults to `0.5.4`.
- `APP_STORE_CONNECT_APP_ID`: numeric App Store Connect app ID.

TestFlight secrets:

- `KEYCHAIN_PASSWORD`
- `BUILD_CERTIFICATE_BASE64`: base64 Apple Distribution `.p12`.
- `P12_PASSWORD`
- `BUILD_PROVISION_PROFILE_BASE64`: base64 App Store provisioning profile for configured bundle ID.
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`: complete `.p8` contents.

Workflow scopes secrets only to validation and steps that consume them, imports signing material into temporary keychain, archives with manual signing, exports IPA, uploads signed archive evidence for 14 days, sends IPA with Planini's proven `altool --upload-app` and App Store Connect API-key flow, then removes temporary key/profile files.

Superseded CI runs cancel by event/ref. Both automatic and manual delivery verify current `origin/main` before installing signing tools, then fetch and recheck after export immediately before upload. A commit superseded during either checks or archive cannot reach TestFlight.

## UI CI parallelism and timeouts

UI tests run on `macos-26`, with three isolated class shards for each iPhone/iPad
suite (up to six jobs). Each simulator still runs serially. The shard selector
balances discovered classes by test-method count and includes new classes automatically;
each class runs exactly once per device. Artifact names include the shard index.

The command has a 35-minute deadline and exits 124 with an explicit error on timeout.
The 50-minute job deadline leaves room for setup and uploading failure evidence.
Different source commits do not cancel one another; duplicate runs of the same commit
may be superseded. GitHub account concurrency limits can still queue jobs.

Local `invoke check` remains the full unsharded gate. To exercise a CI shard locally:

```bash
HIINTERVAL_UI_SHARD_INDEX=0 HIINTERVAL_UI_SHARD_COUNT=3 python3 -m invoke ios-ui-e2e \
  --device-name="iPhone 17 Pro" --artifact-dir=e2e-artifacts/shard-0
```

Do not run multiple local shards against the same simulator simultaneously.
