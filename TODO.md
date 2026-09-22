# Workout improvements TODO

Implementation for **0.5.0**, based on merged PR #9. Each feature gets a separate commit; full
validation runs after all features are implemented, before Git and TestFlight delivery.

- [x] **Prefer catalogue exercises when adding to a workout.**
  Make catalogue search/selection the primary add flow, with an explicit option to create an
  exercise. While entering a name, suggest matching catalogue records using the existing name
  normalization; selecting one attaches its stable ID and initializes its defaults.
  Verify that reuse creates no duplicate record, plan-specific edits remain independent, and
  cancelling leaves both the plan and catalogue unchanged.

- [x] **Offer “Shuffle new exercises” in the workout plan's exercise overview.**
  Reuse the generator's exercise count, required/excluded tags, and body-area alternation options.
  Persist those options with backward-compatible defaults so a generated workout can reuse its
  previous choices; manual plans start with their current exercise count. Draw a new selection
  from the eligible catalogue, not just a new order for the current selection.
  Preview changes and replace only the exercise list on confirmation. Keep the workout's identity,
  name, warm-up/cool-down, timing defaults, recoveries, notes, rounds, round overrides, and logo. Make treatment of replaced exercises' individual overrides clear in the preview.
  Verify cancellation, insufficient matches, unique exercises, preserved settings, and one fixed
  order across all rounds. Reuse `WorkoutGenerator` rather than creating another selection engine.

- [x] **Allow catalogue deletion, warning when an exercise is used.**
  Add a delete action and confirmation listing affected saved workouts. Proposed behavior:
  delete the catalogue record while retaining affected workout steps, names, and configuration as
  detached copies; completed history remains intact. Keep unused shared tags available.
  Represent intentional detachment explicitly so `synchronizeExerciseCatalogue()` does not recreate
  deleted records on reload. Verify unused/in-use deletion, cancellation, reload, and generation
  after deletion. Do not silently remove steps from workouts.

- [x] **Choose workout logos: symbol and colors, or a selected photo.**
  Add a symbol picker plus separate symbol/background color pickers and a live logo preview.
  Offer Apple's system photo picker (`PhotosPicker`) for user-selected images, without requesting
  broad photo-library access. Support replacing/removing the image and restoring a default logo.
  Store a portable logo descriptor on the plan and selected image files in app-managed storage;
  define image sizing and cleanup while retaining assets referenced by plans/history snapshots.
  Verify cancel/save/relaunch, old-plan defaults, readable colors, and selected-photo privacy.

- [x] **Choose global workout background themes in Settings, with preview and custom colors.**
  Add preset themes and a custom color picker, with previews of work, recovery, and other phases
  before applying. Keep preview changes local until Save and provide a reset to the default theme.
  Store theme data in global user preferences with backward-compatible defaults and use the shared design system for
  consistent rendering. Check text/control contrast, light/dark appearance, and distinguishable
  phase colors; coordinate this with the phase-label cleanup below.

- [x] **Announce the exercise halfway point when audio is enabled.**
  Add a localized spoken halfway cue through the existing cue player, respecting audio settings,
  session mute, mixing/ducking, and Silent Mode behavior. Announce once per exercise occurrence
  per round at half its active work time; left/right exercises combine both work phases and exclude
  switch/recovery time. Keep threshold decisions in deterministic core logic using engine time.
  Test delayed ticks, odd/short durations, pause/resume, restart, skip, and split exercises; avoid
  duplicate or stale announcements and collisions with side-switch/countdown cues.

- [x] **Remove the redundant phase icon and visible “Work”/“Recover” labels.**
  Simplify the running-workout header around phase color, exercise name, timer, and progress.
  Retain phase descriptions for VoiceOver and useful context such as warm-up, cool-down, and
  left/right sides. Verify that recovery remains understandable with custom themes and accessibility
  settings, without adding the removed labels back into the normal visual layout.

- [ ] **Float “Paused” above the workout without shifting its layout.**
  Move pause status into an overlay above session content; timer, headings, and controls retain
  their positions. Keep Resume and other essential controls reachable beneath the overlay.
  Prioritize a running-workout layout that fits the available screen without scrolling, including
  narrow iPad windows and long names/notes. Keep essential content visible at large Dynamic Type;
  define an accessible fallback where everything cannot fit instead of clipping it.
  Verify unchanged element positions across pause/resume, hit targets, rotations, and compact widths.

- [x] **Enter plan durations directly by tapping the displayed time.**
  Extend `PlanDurationStepper` so tapping its value opens a focused time-entry field with clear
  units, Done, and Cancel. Retain plus/minus controls and use the same validation/ranges for both
  input methods. Reuse it for plan, exercise, and round-override duration controls where applicable.
  Verify exact non-step-multiple values, zero where allowed, invalid/empty input, keyboard dismissal,
  cancellation, saved values after relaunch, and accessible labels.

## Implementation order and verification

Start with catalogue reuse/deletion and saved generation options, then exercise replacement.
Coordinate logo/theme persistence before session presentation changes. Direct time entry can be
implemented independently. Each feature should remain a focused, reviewable change.

Preserve legacy JSON decoding and immutable history snapshots. Add meaningful core/codec tests and
deterministic UI regressions as implementation lands; retain the 99% core coverage gate and complete
iPhone/iPad suites before delivery. Check VoiceOver, large text, light/dark mode, and iPad widths;
verify spoken cues and photo selection on a physical device. Follow `AGENTS.md` for push/TestFlight
delivery and fresh marketing versions. Theme selection applies globally to every workout, not to individual plans.
