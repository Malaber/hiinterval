# App Store Connect and TestFlight setup

The delivery workflow is implemented, but deliberately disabled until Apple and GitHub are
provisioned. Pull requests never upload. A successful `main` build uploads only after
`TESTFLIGHT_UPLOAD_ENABLED` is set to `true`; a manual upload always reruns the complete CI gate.

## One-time Apple setup

1. In the Apple Developer account, accept any current agreements. App Store Connect will not let
   you create an app record until the Account Holder has accepted the latest agreement.
2. Under **Certificates, Identifiers & Profiles → Identifiers**, register an explicit App ID:
   - description: `HiInterval`
   - bundle ID: `de.malaber.hiinterval`
   - capabilities: none beyond Apple's defaults for now; In-App Purchase is enabled by default on
     an explicit App ID and can remain unused.
3. Under **App Store Connect → Apps**, choose **+ → New App**:
   - platform: iOS
   - name: `HiInterval`
   - primary language: English (U.S.)
   - bundle ID: `de.malaber.hiinterval`
   - SKU: `hiinterval-ios` (internal and not customer-visible)
   - user access: Full Access
4. Open the new app's **App Information** and copy its numeric Apple ID. This becomes the GitHub
   variable `APP_STORE_CONNECT_APP_ID`.
5. Create an **App Store Connect** distribution provisioning profile for the explicit HiInterval
   App ID and an Apple Distribution certificate, then download the profile. The Apple Distribution
   certificate is team-wide: the valid certificate and `.p12` already used by Planini can be reused.
   The provisioning profile cannot be reused because it is bound to HiInterval's App ID.
6. Reuse Planini's active App Store Connect team API key if it has Developer or App Manager access.
   A team key applies to every app in the account. Otherwise, under **Users and Access →
   Integrations → Team Keys**, generate a least-privilege key and download the `.p8` immediately;
   Apple permits that download only once.

Apple references: [register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id/),
[create the app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/),
[create the App Store provisioning profile](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile),
and [create an API key](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/).

## GitHub configuration

Create or open the GitHub Actions environment named `testflight`. Put signing credentials in that
environment's secrets and optionally require deployment approval.

Repository variables:

- `APP_STORE_CONNECT_APP_ID`: the numeric Apple ID copied from App Store Connect.
- `IOS_MARKETING_VERSION`: `0.1.0` initially.
- `APPLE_TEAM_ID`: optional; defaults to `VWKG94374J`.
- `IOS_BUNDLE_IDENTIFIER`: optional; defaults to `de.malaber.hiinterval`.
- `TESTFLIGHT_UPLOAD_ENABLED`: leave unset for initial setup.

Environment secrets:

- `KEYCHAIN_PASSWORD`: a random password used only for the runner's temporary keychain.
- `BUILD_CERTIFICATE_BASE64`: base64 of the Apple Distribution `.p12`; reuse Planini's value when
  the same valid team certificate is used.
- `P12_PASSWORD`: password used when the `.p12` was exported.
- `BUILD_PROVISION_PROFILE_BASE64`: base64 of the new HiInterval App Store Connect provisioning
  profile.
- `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, and
  `APP_STORE_CONNECT_PRIVATE_KEY`: reuse the active Planini team-key values or supply the new key.
  The private-key secret contains the complete `.p8` text, including its header and footer.

On macOS, copy binary credentials as single-line base64 with:

```bash
base64 -i HiInterval_AppStore.mobileprovision | pbcopy
base64 -i AppleDistribution.p12 | pbcopy
```

## First delivery

1. Merge the green pull request into `main` after the Apple and GitHub setup is complete.
2. In **Actions → TestFlight → Run workflow**, choose `main`, set
   `upload_to_testflight = true`, and run it.
3. After Apple processes the build, open the app's **TestFlight** tab, complete any requested export
   compliance information, add the build to an internal testing group, and enable automatic
   distribution for that group if desired.
4. Install the build through TestFlight and run one physical-device smoke test.
5. Set repository variable `TESTFLIGHT_UPLOAD_ENABLED=true`. From then on, every successful,
   current `main` CI run archives and uploads automatically. A superseded commit is refused before
   upload.

Apple creates the TestFlight beta after the first processed upload. Internal testers can be up to
100 App Store Connect users; external testers require beta metadata and the first build may require
Beta App Review. See Apple's [build upload](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
and [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

Tax and banking setup, paid-app agreements, StoreKit products, and the paywall are not needed for
the free TestFlight phase. Configure those only when monetization is implemented.
