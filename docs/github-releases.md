# GitHub releases and App Store screenshots

After a PR merges to `main`, the normal CI workflow runs. On successful **main push**
CI only, `release.yml` checks out that exact tested commit and publishes
`v<MARKETING_VERSION>` from `ios/HiIntervalIOS/project.yml`. PR runs and fork runs
cannot publish. A failed/cancelled CI run produces no release.

## PR metadata

The PR template provides:

```markdown
## Release

Release title: Build your next workout faster

## Release notes

- Reuse exercises from your catalogue.
- Generate balanced workouts with your preferred tags.

## Validation

Internal review details stay out of the release description.
```

The release title becomes `v0.5.4: Build your next workout faster`. An empty title
falls back to the PR title, matching Planini. An empty release-notes section uses
GitHub-generated notes. The description also links the screenshot ZIP and records
the source commit/PR. Text is handled as data, never interpolated into shell code.

Only a new marketing version creates a new release. Published releases are immutable:
a later documentation/CI merge with the same version does not replace notes or assets.
An existing tag pointing elsewhere is never moved. Failed upload leaves a draft that
can be resumed by rerunning the release workflow for the same commit.

This automates GitHub releases, not App Store submission or TestFlight upload.
It does not bump the app version. This infrastructure PR can create the initial
GitHub release for the current version if no release exists yet.

## Screenshots

`MarketingScreenshotsUITests` captures clean, deterministic demo screens during the
existing iPhone 17 Pro Max / iPad Pro 13-inch (M5) CI shards. Each device runs the class once. Marketing PNGs are
uploaded separately as `app-store-screenshots-<device>-<shard>`, retained for 14 days.
Ordinary test evidence remains in its existing artifacts.

The release job downloads only artifacts from the exact successful CI run, validates
both device sets, removes PNG alpha, and attaches
`hiinterval-app-store-screenshots-vVERSION.zip`. It contains iPhone/iPad English
screenshots and a manifest identifying source version, commit, and dimensions.
Images are never resized. The ZIP is a durable GitHub Release asset.

Unzip, review screenshots, then upload the PNGs into the matching device sections
of App Store Connect. These are clean in-app screenshots, without promotional text
or device frames. Other languages require localized capture fixtures first.

Native portrait dimensions accepted by the packager:
- iPhone: 1260×2736, 1290×2796, or 1320×2868.
- iPad: 2064×2752 or 2048×2732.

Apple requirements: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
