# Android invited testing

The Android preset builds a signed Google Play Android App Bundle at
`exports/hollow-vigil-1.0.9.aab` with package ID `com.kaiser.hollowvigil`,
version name `1.0.9`, and version code `9`. It targets ARM64 Android phones.

## Upload to Google Play

1. Create the Hollow Vigil app in your Google Play Console account.
2. Open **Test and release > Testing > Internal testing**.
3. Create a release, configure Play App Signing when prompted, and upload the AAB.
4. Add release notes and resolve any requirements shown by the Console, then roll out the internal test.
5. In **Testers**, create/select your email list and save it. Share the opt-in link with those testers. They must use their invited Google accounts.

Internal testing supports up to 100 testers. Use a closed testing track for a larger invited group. The package ID becomes fixed after the first upload.

Official instructions: https://support.google.com/googleplay/android-developer/answer/9845334?hl=en

## Published build 1.0.9 — September 8, 2026

Google Play confirmed **Available to internal testers** for **1.0.9 (9)** at
6:25 AM CDT. This is an Internal testing release, not a production release.
No testers are configured, as requested. Google requires at least one email to
save a named list, so the proposed **Just for Testing** list could not be saved
empty. Add the list and testers from the Testers tab when ready.

[Internal testing](https://play.google.com/console/u/0/developers/8488140280625083251/app/4976066018708949593/tracks/4699447376683851190?tab=testers)

Google temporarily displays `com.kaiser.hollowvigil (unreviewed)` until app setup
and review are complete. Its release warnings concern the empty tester list,
missing deobfuscation mapping, and missing native debug symbols.

The uploaded bundle is saved locally at `exports/android/hollow-vigil-1.0.9.aab`.
SHA-256: `62bb4ab0239d52e09aa517e8f9c73c2c105b0252fe15f68ea2b9d950d474e187`.

## Keep the upload key

The key used for this Google Play release is on this Mac under
`~/.config/hollow-vigil/android-signing/`: `hollow-vigil-upload.jks` and
`upload-password.txt`. The alias is `hollow-vigil-upload`. Back up these files
securely; they are outside Git and the exported game. Never send them to testers
or regenerate the upload key for a routine update. Existing Windows signing
files must be replaced with this same upload key before uploading from Windows.

## Rebuild

This Mac uses Godot 4.7.2, Homebrew OpenJDK 21, and the Android SDK at
`/opt/homebrew/share/android-commandlinetools`, with platform 36 and build-tools
36.1.0. Official Android export templates are installed in Godot's user template
directory. The verified isolated build source is
`/private/tmp/hollow-vigil-android-build`.

Export with the Android preset and `--install-android-build-template`. Supply
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, and
`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` from the private signing directory.
The configured Gradle project location is `exports/android-tools/build` after
Godot installs the template under the preset's base directory.

`build-android.ps1` is the Windows helper and retains Windows SDK/runtime paths.
Before uploading an update, increase Android `version/code` and keep the visible
`version/name` synchronized with the Apple build label as requested. Update the
bundle filename in the preset and build script together.

## Verification

The app is locked to upright portrait through `display/window/handheld/orientation.android=1` in `project.godot`. The Android phone and tablet presets both inherit it. `display/window/size/resizable.android=false` disables activity resizing. Before releasing a new build, inspect its manifest for `android:screenOrientation="portrait"` (numeric value `1`) and `android:resizeableActivity="false"`, then confirm turning an Android phone leaves gameplay and menus upright. Rebuild and install the app to receive these settings.

The 1.0.9 signed AAB passed Google's bundletool validation and JAR signature
verification. Its actual bundle manifest confirms version code 9, version name
1.0.9, minimum API 24, target API 36, upright portrait (`1`), and a non-resizable
activity. Fresh Godot import and Gradle release build succeeded. The gameplay
suite passed **56,466 checks with zero failures**. Logs and manifest are retained
in ignored `artifacts/android-1.0.9/`.

No physical Android installation, launch, or rotation check was performed.
