# CI Android signing and preview releases

The `Build & Release` workflow runs analysis and tests, builds one APK, uploads the Actions artifact, and publishes signed preview APKs.

## Repository signing keystore

This follows the same fixed-keystore approach used in Life Tracker:

- Keystore: `android/keystore/lifetracker.p12`
- Store password: `lifetracker`
- Key alias: `lifetracker`
- Key password: `lifetracker`

Gradle reads this file directly through `rootProject.file("keystore/lifetracker.p12")`. The workflow verifies the keystore before building. There is no Actions signing secret and no generated `key.properties` file.

The keystore is the APK's long-term Android update identity. The same signing file and values are used by the Life Tracker repository.

## Release behavior

- Every same-repository pull request targeting `main` updates its own prerelease: `pr-<number>-preview`.
- A push to `main` updates the rolling `minimal-mode-preview` prerelease.
- A manual workflow run updates the selected tag (default: `minimal-mode-preview`).
- A release is published when the APK build succeeds and repository signing verification succeeds. The Actions check still reports analysis/test failures; preview publication does not turn a failing check green.
- Fork PRs still upload an Actions artifact, but cannot publish a Release because GitHub does not grant them write access to this repository.

## Install-over-update behavior

Every CI build receives a higher Android version code based on the workflow run number and attempt. This prevents Android from rejecting a newer APK as a downgrade. The workflow caches Gradle dependencies, wrapper downloads, Dart packages, and cacheable Gradle task outputs between runs. The APK is built for `android-arm64` only to avoid compiling and packaging unused architectures.

The Android application ID remains `com.gymmane.app`. After switching from an older APK signed with a different key to this keystore, Android may require one final uninstall/reinstall. Back up app data before that one-time switch. All later APKs signed with this same key can install as updates without deleting the app.
