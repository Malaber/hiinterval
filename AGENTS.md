# Working on HiInterval

This file applies to the whole repository. Follow the user's current scope and release instructions.
The user has authorized TestFlight delivery after Git pushes as described below; other delivery
commands describe available workflows, not automatic permission to deploy elsewhere.

## Agent workflow

Use the main agent as the orchestrator for non-trivial tasks. Its responsibility is to understand the
request and repository, make the important architectural and product decisions, divide the work into
well-defined units, review the implementation, and own the final result.

Use worker subagents for implementation work when delegation is useful. Workers should execute a
defined part of the plan rather than independently redesigning the solution.

### Planning and delegation

For non-trivial changes:

1. Inspect the relevant existing implementation, tests, documentation, Git state, and repository
   instructions before deciding on an approach.
2. Form a concrete implementation plan before making broad changes.
3. Identify work that can be delegated with a clear scope and acceptance criteria.
4. Delegate implementation, focused investigation, test additions, or mechanical refactors to worker
   subagents where this reduces main-agent work without sacrificing correctness.
5. Review all worker results before considering the task complete.
6. Resolve integration problems, architectural questions, conflicting changes, and ambiguous
   requirements in the main agent.
7. Run or delegate the required verification described elsewhere in this file and report the actual
   results.

Do not delegate merely to create activity. Small or tightly coupled changes may be implemented
directly by the main agent when delegation would add overhead.

### Main-agent responsibilities

The main agent owns:

- understanding the user's actual request and defining scope;
- repository and architecture discovery needed to make design decisions;
- choosing the implementation approach and identifying affected components;
- decisions that cross module, persistence, concurrency, UI, platform, security, release, or
  compatibility boundaries;
- decomposing work into independent worker assignments;
- resolving ambiguities that could materially affect behavior;
- reviewing worker diffs and test changes for correctness and consistency;
- integrating overlapping work;
- running or confirming the final required verification;
- checking the final diff for unintended changes;
- producing the final handoff, commit, PR, or release result.

The main agent must not blindly accept worker output. Read the resulting changes and verify that they
satisfy the plan, repository constraints, and user request.

### Worker responsibilities

Workers are implementation-focused. Give each worker a narrow, explicit task with enough context to
execute it without redefining the overall solution.

A worker assignment should normally specify:

- the concrete goal;
- the files or subsystem likely involved;
- relevant architectural constraints from this file;
- behavior that must remain unchanged;
- expected tests or verification;
- boundaries of the assignment.

Workers should:

- inspect existing code before editing it;
- follow the architecture, testing, UI, persistence, release, and Git rules in this file;
- prefer existing abstractions and patterns over introducing parallel mechanisms;
- keep changes focused on the assigned scope;
- add or update meaningful tests when behavior changes;
- report what changed, what was verified, and any unresolved issue.

Workers should not:

- make unrelated cleanup changes;
- change product behavior outside their assignment;
- invent new architecture when the assigned plan already defines one;
- weaken tests, coverage, validation, compatibility, or safety constraints;
- perform releases, uploads, pushes, destructive Git operations, or other externally consequential
  actions unless the main task explicitly requires them and the assignment explicitly delegates them;
- silently work around a design problem that invalidates the plan.

If a worker discovers that the planned approach is incorrect, unsafe, conflicts with existing
architecture, or requires a significant design decision, it should stop expanding scope and return
the finding to the main agent.

### Parallel work

Use parallel workers only for work that is genuinely independent, for example:

- implementation in separate modules with stable interfaces;
- implementation and independent test investigation;
- focused repository research in different subsystems;
- separate documentation or website work accompanying an app change.

Avoid assigning multiple workers overlapping ownership of the same files or tightly coupled code.
When overlap is unavoidable, sequence the work or let the main agent perform the integration.

Workers share responsibility for preserving unrelated user changes. Before editing, inspect the
relevant state and do not overwrite modifications made outside the assignment.

### Investigation workers

Workers may also be used for bounded investigation before implementation, such as:

- locating the implementation responsible for a behavior;
- tracing a persistence or state flow;
- finding existing tests and fixtures;
- investigating a reproducible test or build failure;
- comparing several existing repository patterns.

Investigation workers should return evidence and concrete findings, not make broad speculative
recommendations. Architectural decisions remain with the main agent.

### Verification and review

Delegating implementation does not delegate final responsibility.

Before handoff, the main agent should:

1. inspect the combined diff;
2. confirm that worker changes follow the agreed architecture;
3. check for duplicated logic, accidental scope expansion, and inconsistent assumptions between
   workers;
4. run the appropriate verification described in this file;
5. fix or delegate any failures caused by the change;
6. distinguish verified behavior from anything that still requires physical-device, external-service,
   App Store, or other environment-specific validation.

For substantial changes, prefer this flow:

**understand → plan → delegate → implement → verify → review → integrate → final verification → handoff**

For small changes, use the shortest version of that flow that preserves correctness.

## Product and repository map

HiInterval is a native, local-first iPhone/iPad interval-training app. It includes workout planning,
a shared exercise catalogue, tag-filtered workout generation, left/right splits, round overrides,
optional notes, audio/haptic cues, history, reminders, completion
celebrations, and an optional extra round. Apple Intelligence can create or revise workout plans on
supported devices. The separate `website/` directory is a static product/support/privacy site.

There is no application backend, user account, analytics, or cloud sync. The app is currently free;
`EntitlementPolicy` contains disabled future monetization logic. Do not enable purchases or infer
that its existing trial rules are approved product requirements.

| Path | Responsibility |
| --- | --- |
| `ios/HiIntervalIOS/Sources/HiIntervalCore/` | Portable Swift domain models, validation, timeline, timer, history, cue policies |
| `ios/HiIntervalIOS/Tests/HiIntervalCoreTests/` | XCTest unit tests for the core package |
| `ios/HiIntervalIOS/App/AppStore.swift` | Main-actor app state, mutations, persistence, deterministic UI fixtures |
| `ios/HiIntervalIOS/App/Features/` | SwiftUI Train, Plans, History, and Settings screens |
| `ios/HiIntervalIOS/App/DesignSystem/` | Shared `HITheme` tokens and `HIComponents` |
| `ios/HiIntervalIOS/App/Services/` | Apple platform services such as reminders |
| `ios/HiIntervalIOS/UITests/` | iPhone/iPad XCUITest flows and shared test helpers |
| `ios/HiIntervalIOS/project.yml` | Source of truth for the generated Xcode project |
| `ios/HiIntervalIOS/Scripts/` | Coverage gate, simulator runner, and local TestFlight upload |
| `tasks.py`, `pyproject.toml` | Python Invoke development commands and dependencies |
| `.github/workflows/` | CI, signed TestFlight delivery, and GitHub Pages |
| `website/` | Plain HTML/CSS, screenshots, and public site metadata |
| `docs/`, `TODO.md` | Architecture, delivery setup, and completed/requested product work |

## Setup and build

Run commands from the repository root unless stated otherwise. Native builds require macOS,
Xcode 26 with its iOS SDK/simulator runtime, XcodeGen, and Python 3.11+. Swift language mode is 6;
deployment target remains iOS 17. The core Swift package also runs on macOS and Linux.

```bash
python3 -m venv .venv
.venv/bin/pip install -e .
.venv/bin/inv install-xcodegen
.venv/bin/inv generate-ios-project
open ios/HiIntervalIOS/HiIntervalApp.xcodeproj

# Unsigned simulator build
.venv/bin/inv build-ios-simulator --device-name="iPhone 17 Pro"
```

If Invoke is already installed in the active Python environment, `python3 -m invoke` is equivalent
to `.venv/bin/inv`. Use `--list` or `--help TASK` to inspect available commands.

The project is `HiIntervalApp.xcodeproj`; app target and scheme are `HiInterval`; UI test target is
`HiIntervalUITests`. Bundle ID is `de.malaber.hiinterval`, Apple team is `VWKG94374J`. Preserve these
identities unless the task explicitly changes them.

Edit `project.yml`, then regenerate. Do not hand-edit or commit the ignored `.xcodeproj`. Keep build
caches, coverage, `.xcresult`, archives, IPAs, and UI screenshots/logs out of commits. Existing ignore
rules cover their standard locations.

## Architecture and behavior to preserve

- Keep interval arithmetic, validation, timeline expansion, and other deterministic policies in
  `HiIntervalCore`. It must compile in Linux Swift CI; UIKit, SwiftUI, AVFoundation, UserNotifications,
  FoundationModels, and other Apple-only integrations belong in `App/`.
- `WorkoutTimeline` expands a validated plan; `IntervalTimerEngine` consumes explicit timestamps.
  `WorkoutSessionController` connects this logic to real time and platform effects. Do not implement
  an independent countdown in a view. Cover delayed ticks, pause/resume, skip/restart, and completion
  without elapsed-time drift or duplicate history entries.
- `AppStore` is the main-actor persistence boundary. The sorted-key JSON payload lives in
  `UserDefaults` under `io.malaber.hiinterval.app-data.v1` (deliberately different from the bundle ID).
  Preserve backward decoding and missing-field defaults. Add codec regression tests when models
  change; retain corrupt bytes in the `.recovery` key and the existing user-facing recovery behavior.
- Catalogue records provide shared identity, canonical names, planning labels, and defaults for new
  uses. Saved steps keep their own timing, recovery, side configuration, and notes. Merge live-plan
  references atomically; never rewrite history snapshots. Generation randomizes once into a normal
  plan, so order stays fixed across rounds. Body areas and tags stay out of workout presentation.
- `AppData.exerciseLabels` owns shared body-area/tag records; exercises attach stable `labelIDs`.
  Migrate old string arrays without losing associations. Detaching a label retains it for suggestions;
  saving an exercise commits draft labels atomically, while cancelling must create no records.
  Use removable pills and existing/general suggestions rather than comma-separated entry fields.
- Global workout phase colors live in `UserPreferences.workoutTheme`, edited in Settings; never
  attach themes to individual plans. `WorkoutPlan.logo` is per plan. Use the system photo picker;
  keep photo drafts memory-only until Save and retain assets referenced by history or recovery data.
- Deleted catalogue IDs remain tombstoned in `AppData.deletedCatalogueExerciseIDs` so retained plan
  steps cannot recreate removed entries. Saved `generationOptions` support exercise-only reshuffling.
- History includes a plan snapshot so editing a saved plan does not rewrite completed workouts.
  Preserve selected-plan normalization, history ordering, and CSV escaping/formula protections.
- Notes start empty and appear during relevant phases only when nonblank. New exercise entry should
  focus the name field. The current exercise heading must remain more prominent than the next one.
- Enabled audio uses the playback session category so it works in Silent Mode. Preserve the app's
  audio-off control and mix/duck preference. Every app-triggered vibration must honor
  `hapticsEnabled` through the haptic policy/player, including pause, resume, countdown, and completion.
- Completion fireworks transition from foreground to background. Respect accessibility settings
  and keep completion actions usable. “One More Round” uses the core continuation builder, at least
  ten seconds of recovery through `OneMoreRoundRecovery`, and a full extra exercise round without
  repeating warm-up/cool-down.
- `NaturalLanguagePlanEditorView.swift` contains the FoundationModels integration. Gate it on iOS 26
  and actual model availability; explain unsupported/disabled/not-ready states. Validate generated
  plans before applying them. Keep ordinary editing available on iOS 17 and devices without the
  model; do not add a network AI fallback by default.
- Reuse the design system, accessibility identifiers, and semantic labels. Check light/dark mode,
  large Dynamic Type, VoiceOver, iPhone portrait, and iPad rotations/multitasking widths. Settings
  scrolling and the iOS 26 floating tab bar have prior layout/contrast regressions: use shared soft
  scroll-edge fades, never reserve a fixed opaque strip below Settings, and verify visible
  rows, content insets, and shared scroll-edge treatment on both device families.
- `App/PrivacyInfo.xcprivacy` declares no tracking/collected data and the app-only UserDefaults
  required-reason API use. Keep the manifest and public privacy page consistent with actual behavior.

## Verification and UI test stability

```bash
# Unit tests and the 99% HiIntervalCore line-coverage gate
.venv/bin/inv check-ios-package

# Full UI suites, serial within each device
.venv/bin/inv ios-ui-e2e --device-name="iPhone 17 Pro"
.venv/bin/inv ios-ui-e2e --device-name="iPad Pro 13-inch (M5)" \
  --artifact-dir=e2e-artifacts/ios-ipad

# Focused UI class while iterating
.venv/bin/inv ios-ui-e2e --device-name="iPhone 17 Pro" \
  --artifact-dir=e2e-artifacts/ios-focused \
  --only-testing=HiIntervalUITests/TrainSessionUITests

# Complete native gate: core coverage, iPhone, then iPad
.venv/bin/inv check

# Fast unit iteration; this alone does not enforce coverage
swift test --package-path ios/HiIntervalIOS --filter OneMoreRoundTests
```

For behavior changes, add meaningful core tests and UI regression coverage where applicable.
Run affected tests while iterating and the complete native gate for app changes before delivery.
For documentation-only work, verify referenced paths/commands and `git diff --check`; a native
rebuild is unnecessary. Report exactly what ran and any unverified physical-device behavior.
Do not lower `HIINTERVAL_COVERAGE_MINIMUM` or remove assertions to make a change pass.

Use `HiIntervalUITestCase` helpers and stable identifiers instead of coordinates or localized text
where possible. Initial `--ui-testing` launches reset app data to fixtures; use
`relaunchPreservingData()` specifically for persistence checks. Default tests use English,
`en_US_POSIX`, UTC, and a 60x timer. Use the existing real-time/glanceable fixture approach for
transient phase assertions rather than racing the accelerated short workout. AI tests must not
require live nondeterministic model generation on a simulator.

Wait for observable state and reuse the existing launch/hittability helpers. Avoid arbitrary sleeps
and aggressive accessibility polling. Successful waits should not fetch extra snapshots just to
format failure messages. Focus tests type without refocusing and complete any interrupted prefix.
The foreground/background completion test uses `HIINTERVAL_UI_TEST_MANUAL_CELEBRATION=1` together
with `--ui-testing` to pause cosmetic fireworks animation and advance the existing timeline boundary
on demand: continuous rendering can starve hosted iPad accessibility snapshots, and wall-clock waits
can miss the five-second foreground window. Automatic transition
uses a deterministic test duration while core tests retain and verify the five-second default.
Switch helpers must reveal the entire row within its containing Form's visible bounds; requiring a
fixed central band of the application window fails for short sheets with no remaining scroll range.
Catalogue plan-editor tests scroll within the sheet list’s leading gutter, avoiding text-entry targets.
Whole-window swipes across multiline notes triggered an iPadOS 26 UIKit focus-guide assertion
(`parentEnvironment != nil`) with a simulated hardware keyboard. This gesture constraint does not
verify physical iPad keyboard behavior; retain that limitation in device validation.
Tests run once; any assertion or infrastructure failure fails the suite. Do not add automatic reruns
or accept a later pass as evidence of correctness.

`run_ui_e2e.sh` builds once without signing, uses one simulator at a time, disables slow verbose
test-diagnostic collection, and uninstalls the app before its single test run. Logs, screenshots,
and the result bundle remain available. With `CI=true`, it also erases the selected simulator: do
not set this on a simulator containing data you need. Do not run two
suites against the same simulator or derived-data/artifact directory concurrently.

Artifacts must be in a child of `e2e-artifacts/`; the runner replaces that selected directory on
each invocation. Inspect `build-for-testing.log`, `test.log`, `summary.md`, screenshots,
and `TestResults*.xcresult` to distinguish app assertions from simulator/launch failures. Coverage
reports live in `ios/HiIntervalIOS/coverage/`. Read current test sources/results rather than relying
on fixed test counts in older documentation. Simulator tests cannot prove actual vibration,
hardware Silent Mode audio, or on-device Apple Intelligence availability; those need device checks.

## CI and releases

- `ci.yml` runs on PRs, `main` pushes, and manual dispatch. `ios-checks.yml` runs core coverage in
  Linux `swift:6.2` and UI suites on macOS 26 with `iPhone 17 Pro` and `iPad Pro 13-inch (M5)`.
  Coverage/UI artifacts are retained for 14 days. Use actual job logs when diagnosing failures.
- App versions belong in `project.yml`; keep the TestFlight workflow fallback and release examples
  consistent when bumping versions. The Python package version in `pyproject.toml` is separate.
  Before each Git push containing app changes, check the latest version actually uploaded to App
  Store Connect and ensure the next TestFlight version is at least one SemVer patch higher. Never
  upload a marketing version twice, even with a different build number; do not blindly reuse examples.
- Documentation/planning-only pushes, including TODO updates, require neither an app version bump
  nor a TestFlight upload. Including already released app code as a planning branch's base does not
  count as a new app change. Resume version bumps and uploads when implementation changes the app.
- Run required local checks before every Git push of app changes. Immediately after each push,
  upload that exact pushed source to TestFlight through the local CLI; do not wait for or poll remote
  CI unless the user specifically asks. If local checks fail, fix them before pushing. If later CI
  fails, fix it in a new commit and upload that new push with a new marketing version. Verify source
  commit, version, build number, and prior uploads first; report any release blocker rather than
  silently skipping the upload. This is a standing user release instruction.
- For a local TestFlight release, run the following with the chosen values and an Xcode
  account configured for the team. This command **uploads**, not merely archives:

  ```bash
  .venv/bin/inv upload-testflight --marketing-version=VERSION --build-number=BUILD
  ```

  It regenerates the project, archives with automatic signing, and uses
  `ios/HiIntervalIOS/ExportOptions.TestFlight.plist` to upload and manage the build number. It does
  not run tests or restrict the checkout to `main`; verify the intended source and checks first.
  Archive remains in the printed temporary directory. To open an archive in Organizer, use
  `open -a Xcode /absolute/path/to/HiInterval.xcarchive`.
- Preserve `env PATH=/usr/bin:/bin:/usr/sbin:/sbin /usr/bin/xcodebuild` in release commands. Homebrew
  `rsync` can be selected by Apple's packaging subprocess and reject its extended-attribute flags,
  producing `exportArchive Copy failed`. System-only PATH fixed the real upload failure.
- GitHub TestFlight delivery is separate: automatic upload requires successful `main` push CI and
  `TESTFLIGHT_UPLOAD_ENABLED=true`. Manual dispatch with `upload_to_testflight=true` reruns all CI
  checks. Both refuse a checkout that is not current `origin/main`, including a second check after
  export. Keep those guards and temporary credential cleanup intact.
- GitHub uses environment `testflight` and App Store Connect/signing configuration documented in
  `docs/app-store-connect-setup.md`. Check actual configuration before relying on it; a workflow
  file does not mean its secrets are provisioned. Never commit certificates, API keys, passwords,
  provisioning profiles, or distribution logs containing account data.
- Distinguish upload acceptance from Apple processing and tester availability. Report only the
  state actually verified; retain the requested version, build number, and source commit in handoff.

## Website

`website/` is deployed directly with no build step or package manager. Preview from the repository
root with `python3 -m http.server 8080 --directory website`. Keep shared styling in
`website/assets/site.css`; check responsive layouts and local links/assets after edits. Preserve
the static, dependency-free approach unless the task calls for a change.

Production domain is `hiinterval.malaber.de`, recorded in `website/CNAME`. Product, capabilities,
support, and privacy pages must agree with current app behavior. Keep canonical URLs, `sitemap.xml`,
`robots.txt`, `llms.txt`, and support contact `hiinterval@schaedler.rocks` consistent when relevant.
`.github/workflows/pages.yml` publishes `website/` when website/workflow changes reach `main`, or
on manual dispatch. See `website/README.md` for DNS and Pages setup.

## Git and handoff

Inspect status and worktrees before switching branches; preserve unrelated edits and stage only
task files. Fetch before building on remote changes; use fast-forward pulls instead of resetting
user work. Use `codex/` feature branches and PRs by default, following explicit user instructions
when they request a direct push to `main`. If `main` is checked out in another worktree, a detached
`origin/main` checkout can be committed and pushed with `git push origin HEAD:main` without moving
that other worktree. Never force-push to resolve a stale main push; fetch and integrate first.

Use focused conventional commits. Summarize the change, verification, remaining limitations, and
commit/PR or upload result. Keep this file current when architecture or commands change. For more
context, read `README.md`, `docs/architecture.md`, `docs/delivery.md`, and
`docs/app-store-connect-setup.md`, checking implementation when older prose disagrees.
