# Deployment Guide

This project uses GitHub Actions + Fastlane to build the Flutter iOS app and ship it to TestFlight automatically on every push to `main` (mirrors the pipeline already working in SongStone).

## How the pipeline works

```
Push to main (or manual "Run workflow")
      │
      ▼
  build-and-deploy job (self-hosted runner)
  ├── flutter pub get
  ├── flutter build ios --release --no-codesign
  ├── decode .p12 cert + .mobileprovision from secrets
  ├── fastlane beta lane
  │   ├── setup_ci          → isolated keychain
  │   ├── import_certificate
  │   ├── install_provisioning_profile
  │   ├── gym               → archives + exports EarTrainer.ipa
  │   └── pilot              → uploads to TestFlight
  └── done (Apple processes the build asynchronously, 10-30 min)
```

## One-time setup checklist

### 1. Confirm the self-hosted runner

The workflow runs on `self-hosted`, same as SongStone's. If SongStone's runner is registered at the **repository** level, it won't automatically pick up jobs for this repo — you'll need either:
- a runner registered specifically for `musicPrototype`, or
- an **organization-level** runner both repos share.

Check under this repo's **Settings → Actions → Runners**. If none shows up, either register one (the same Mac SongStone uses is fine — it already has Xcode/Ruby) or change `runs-on: self-hosted` to `runs-on: macos-latest` in `.github/workflows/deploy.yml` to use GitHub-hosted macOS runners instead (no setup, but costs Actions minutes at the macOS multiplier).

The runner machine needs: Xcode, Ruby + bundler, and the Flutter SDK on `PATH` (the workflow installs Flutter itself via `subosito/flutter-action`, but Xcode/Ruby must already be present, same as for SongStone).

### 2. App Store Connect API key

If you don't already have one from your manual deploys:

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Users and Access → Integrations → App Store Connect API**
2. Generate a new key with **App Manager** access (or reuse an existing one)
3. Note the **Key ID** and **Issuer ID** shown on that page
4. Download the `.p8` file — **it can only be downloaded once**, keep it safe

### 3. Distribution certificate + provisioning profile

Since you've been signing manually, you likely already have these in Keychain Access / the Apple Developer portal:

- **Certificate:** Keychain Access → My Certificates → find your "Apple Distribution" cert → right-click → Export → save as `distribution.p12` with a password
- **Profile:** [developer.apple.com/account/resources/profiles](https://developer.apple.com/account/resources/profiles/list) → find (or create) an **App Store** distribution profile for `com.eartrainer.earTrainer` → download the `.mobileprovision` file, and note its exact **name** (you'll need it for the `APPLE_PROVISIONING_PROFILE_NAME` secret below)

### 4. Add GitHub Secrets

Go to this repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret name | How to get it |
|---|---|
| `APPLE_DISTRIBUTION_CERTIFICATE` | `base64 -i distribution.p12 \| pbcopy`, paste |
| `APPLE_CERTIFICATE_PASSWORD` | The password you set exporting the `.p12` |
| `APPLE_PROVISIONING_PROFILE` | `base64 -i YourProfile.mobileprovision \| pbcopy`, paste |
| `APPLE_PROVISIONING_PROFILE_NAME` | The exact profile name (e.g. `Ear Trainer App Store`) — must match what Xcode shows for it |
| `APP_STORE_CONNECT_API_KEY_ID` | From step 2 |
| `APP_STORE_CONNECT_API_ISSUER_ID` | From step 2 |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | `base64 -i AuthKey_XXXX.p8 \| pbcopy`, paste |
| `MATCH_KEYCHAIN_PASSWORD` | Any password you choose — used only for the temporary CI keychain |

### 5. Confirm the App Store Connect app record

Since you've deployed manually already, the app record for `com.eartrainer.earTrainer` should already exist in App Store Connect — `pilot` will find it automatically via the bundle ID. Nothing to do here unless it's missing.

### 6. First run

Push to `main`, or trigger manually from **Actions → Deploy to TestFlight → Run workflow**. Check the job logs if it fails — signing issues (wrong profile name, expired cert) are the most common first-run problem.

## Notes

- **Trigger:** currently runs on every push to `main`. If you'd rather gate deploys behind a manual click (like SongStone currently does), remove the `push` trigger in `.github/workflows/deploy.yml` and keep only `workflow_dispatch`.
- **Build time:** Flutter iOS builds are much faster than Unity's (minutes, not 25-50 min).
- **TestFlight processing:** Apple processes the uploaded build asynchronously; the job exits right after upload (`skip_waiting_for_build_processing: true`).
