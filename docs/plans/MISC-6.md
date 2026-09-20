# MISC-6: exercise catalogue and generated workouts

## Product decisions

- Add a local exercise catalogue shared by every saved plan. Existing exercise occurrences
  migrate separately; users decide which duplicates are the same exercise by merging them.
- Catalogue records own the shared name, body areas, custom tags, and defaults for new uses.
  Each plan occurrence retains its own duration, recovery, side split, and notes.
- Merge into an explicitly chosen record: use its name/defaults, combine labels, and redirect
  all saved-plan references. Historical snapshots remain immutable. Catalogue renaming updates
  saved plans; renaming inside one plan creates a separate catalogue exercise.
- Body areas and custom tags are separate. Labels such as “Achilles recovery” are user-defined
  planning filters, not medical guidance. None are shown or spoken during a workout.
- Generate a requested number of unique exercises. Require all selected inclusion tags and
  reject any selected exclusion tags. Optional alternation prefers a different known body area
  at each selection; an unbalanced or unlabelled pool may still repeat areas.
- Randomize once when generating. Save a normal editable plan, so every round repeats the same
  order and timing, history, extra rounds, and existing playback controls use the existing engine.
- Generation is fully local and works on iOS 17 without Apple Intelligence.

## Implementation sequence

1. Extend the Codable schema with optional catalogue references and a backwards-compatible
   catalogue array. Migrate deterministically and persist immediately on loading old data.
2. Implement catalogue normalization/merging and injectable-randomness generation in
   `HiIntervalCore`, with migration, history, filtering, alternation, and timeline tests.
3. Integrate atomic mutations in `AppStore`. Add catalogue management, shared exercise picking,
   and generated-plan preview/save flows using existing SwiftUI/design-system patterns.
4. Add UI regression tests for migration, editing, merging, generation, and persistence; review
   iPhone/iPad presentation and accessibility. Preserve existing training UI and recovery behavior.
5. Run the complete native gate (99% core coverage, full iPhone and iPad suites), review the diff,
   open a PR, and wait for passing CI on the final source commit.
6. Upload that verified source through the local Xcode release workflow as version 0.4.0 with
   a fresh build number. Report upload acceptance separately from Apple processing/tester access.

## Acceptance cases

- Existing data loads without losing plans, settings, history, exercise configuration, or notes;
  repeated loads do not create more catalogue entries.
- Four occurrences of “Liegestützen” can merge into one record referenced by all four plans.
- Ten arm and ten leg exercises can generate six unique, alternating exercises; tag filters can
  narrow that pool, and insufficient matches produce a clear error instead of repeats.
- Generated rounds use the same exercise order. Session presentation contains no planning tags.
- Cancelling catalogue edits or a generated-plan preview does not save draft changes.
