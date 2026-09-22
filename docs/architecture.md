# Architecture

## Boundaries

`ios/HiIntervalIOS/Sources/HiIntervalCore` contains platform-light domain code:

- `WorkoutPlan`: plan, exercise, round override, duration/recovery, left/right configuration, validation.
- `ExerciseCatalogue`: shared identity, plan-reference migration, normalized planning labels, and merges preserving per-plan configuration and history.
- `WorkoutGenerator`: local filtered selection without replacement and optional body-area alternation with injectable randomness.
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

## Exercise catalogue (0.4.1)

`AppData.exerciseCatalogue` owns exercise names and defaults. `AppData.exerciseLabels` stores shared
`ExerciseLabel` records with stable IDs and a body-area/tag kind; exercises attach `labelIDs` rather
than copying label strings. Legacy string arrays migrate into this catalogue, deduplicated by kind
and normalized name. Detaching the last exercise retains the label for reuse. Editor drafts commit
new labels and exercise attachments together on Save; cancelling creates no catalogue records.
The editor displays removable pills and filtered existing/general suggestions. Workout references
use small pills with a stable tint derived from each plan's ID and semantic, readable text.

`ExerciseStep.catalogueExerciseID` links a saved-plan occurrence to shared identity while retaining
its own timing, recovery, side configuration, and notes. Old saved plans migrate on decoding, one
record per existing occurrence; missing links are repaired. Repeated decoding is idempotent. The
store persists migration immediately. History snapshots are never migrated or rewritten.

Catalogue edits propagate the canonical name to saved plans; merges union labels and redirect
references while retaining occurrence IDs and configuration. Renaming an exercise inside a plan
creates a separate catalogue entry. Mutations commit a complete `AppData` value through `AppStore`.

Generation filters shared tag IDs and resolves body-area IDs through the label catalogue. It requires
all included tags and excludes any forbidden tags. It samples unique entries
and can prefer nonoverlapping known body areas at each step. Alternation is best effort for uneven
or unlabelled pools. The result is an ordinary editable workout plan: randomness is used only at
generation, never between rounds or in the timer. Planning labels are not part of session cues.


## Workout editing and presentation (0.5.0)

Adding an exercise searches the shared catalogue first; typed names can reuse suggested records.
Deleting a catalogue entry records its ID in `deletedCatalogueExerciseIDs`. Saved steps keep their
payload and tombstoned link; synchronization does not recreate deleted entries. Labels and history
remain unchanged. Explicitly saving that catalogue ID restores it.

`WorkoutPlan.generationOptions` retains generation filters. Reshuffling prefers unused eligible
exercises, previews the result, and replaces only exercises/options after confirmation. Catalogue
defaults initialize replacement steps; plan timing, round overrides, identity, notes, and logo stay.

`WorkoutPlan.logo` describes a symbol/colors or an app-managed JPEG filename. Photos arrive through
`PhotosPicker` without broad library permission, stay in an in-memory draft until Save, and are
resized to at most 1,024 pixels. Cleanup retains files referenced by live plans and history snapshots;
recovery data suppresses cleanup. `UserPreferences.workoutTheme` holds global phase colors, edited
with previews in Settings. Text switches between black and white for contrast.

`HalfwayExerciseCueTracker` derives one cue per round/exercise from active work time across both
sides. The controller emits it only while running, after higher-priority phase speech, and honors
mute/audio settings. The session keeps phase context accessible without visual Work/Recover labels.
Pause status overlays the layout; a single measured layout enables scrolling only when content exceeds the available height.
