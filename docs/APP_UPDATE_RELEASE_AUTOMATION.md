# App Update Release Automation

The app update prompt reads `config/appUpdate.latestVersion` from Firestore. Release metadata is published automatically when a GitHub Release is marked **published**.

## One-time setup

1. Create a GitHub repository secret named `FIREBASE_SERVICE_ACCOUNT_JSON`.
2. Set its value to the Firebase service-account JSON for the production project.
3. Create a GitHub Release using a semantic version tag such as `v2.0.6`.
4. Publish the release only after the matching build is live in the App Store and Google Play.

The workflow in `.github/workflows/publish-app-update.yml` removes the `v` prefix, writes the tag version to `config/appUpdate.latestVersion`, and uses the release body as the change summary.

## Building without editing `pubspec.yaml`

The release build script accepts the same tag or CI version:

```bash
RELEASE_VERSION=2.0.6 BUILD_NUMBER=66 ./build_release.sh android
```

In CI, `GITHUB_REF_NAME` supplies the version and `GITHUB_RUN_NUMBER` supplies the numeric build number. A local build falls back to the version in `pubspec.yaml` and a timestamp build number.

Do not publish the Firestore metadata before the store release is available, or users may be sent to a store page that does not yet contain that version.
