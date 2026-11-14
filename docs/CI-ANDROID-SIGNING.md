# CI Android signing and preview releases

The `Build & Release` workflow runs analysis and tests, builds one APK, and keeps the APK in the Actions run artifacts.

## One-time signing secret

Create one repository Actions secret:

- Name: `ANDROID_SIGNING_CONFIG_JSON`
- Value: the complete one-line JSON in the private signing bundle generated for this repository.

GitHub path: **Settings → Secrets and variables → Actions → New repository secret**.

The JSON contains the base64-encoded keystore plus its store password, alias, and key password. The workflow writes the keystore and `android/key.properties` only on the temporary Actions runner. Those files are ignored by Git and are never committed.

Do not paste the JSON or keystore into source code, issues, pull requests, logs, or a public file. Keep a private backup of the signing bundle. Never rotate or regenerate the key after distributing APKs signed with it.

## Release behavior

- Every same-repository pull request targeting `main` updates its own prerelease: `pr-<number>-preview`.
- A push to `main` updates the rolling `minimal-mode-preview` prerelease.
- A manual workflow run updates the selected tag (default: `minimal-mode-preview`).
- A release is published when the APK build succeeds and the signing secret is present. The Actions check still reports analysis/test failures; preview publication does not turn a failing check green.
- Fork PRs and runs without the signing secret still upload an Actions artifact, but do not publish a Release. Fork PRs cannot safely receive this repository's signing secret or write to its Releases.

## Install-over-update behavior

Every CI build receives a higher Android version code based on the workflow run number and attempt. This prevents Android from rejecting a newer APK as a downgrade. The workflow caches Gradle dependencies, wrapper downloads, Dart packages, and cacheable Gradle task outputs between runs. The APK is built for `android-arm64` only to avoid compiling and packaging unused architectures.

The Android application ID remains `com.gymmane.app`. After switching from an older APK signed with a different temporary key to this persistent key, Android may require one final uninstall/reinstall. Back up app data before that one-time switch. All later APKs signed with the same key can install as updates without deleting the app.

## Key loss

The signing keystore is the app's long-term update identity. Losing it means Android will reject future APKs signed with a replacement key as updates to existing installs. Keep the private bundle backed up somewhere safe.
