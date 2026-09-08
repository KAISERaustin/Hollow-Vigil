# Android invited testing

The Android preset builds a signed Google Play Android App Bundle at
`exports/hollow-vigil-0.1.0.aab` with package ID `com.kaiser.hollowvigil`,
version name `0.1.0`, and version code `1`. It targets ARM64 Android phones.

## Upload to Google Play

1. Create the Hollow Vigil app in your Google Play Console account.
2. Open **Test and release > Testing > Internal testing**.
3. Create a release, configure Play App Signing when prompted, and upload the AAB.
4. Add release notes and resolve any requirements shown by the Console, then roll out the internal test.
5. In **Testers**, create/select your email list and save it. Share the opt-in link with those testers. They must use their invited Google accounts.

Internal testing supports up to 100 testers. Use a closed testing track for a larger invited group. The package ID becomes fixed after the first upload.

Official instructions: https://support.google.com/googleplay/android-developer/answer/9845334?hl=en

## Keep the upload key

Back up the entire `exports/android-signing` folder securely. It contains the
upload keystore and its generated password. The alias is `hollow-vigil-upload`.
These files are excluded from Git and the exported game. Do not send this folder
to testers. Retain the key for future uploads to this app.

## Rebuild on this computer

Run `./build-android.ps1` from PowerShell. This uses the installed Godot 4.7.2,
Android Studio Java runtime, Android SDK, and downloaded templates under
`exports/android-tools`. Dependencies may require network access.
The local build profile is isolated from your normal Godot settings.

Before uploading an update, increase `version/code` in `export_presets.cfg`.
Change `version/name` and the output filename in both the preset and build script
as appropriate. Never regenerate the upload key for a routine update.

## Verification

The app is locked to upright portrait through `display/window/handheld/orientation.android=1` in `project.godot`. The Android phone and tablet presets both inherit it. `display/window/size/resizable.android=false` disables activity resizing. Before releasing a new build, inspect its manifest for `android:screenOrientation="portrait"` (numeric value `1`) and `android:resizeableActivity="false"`, then confirm turning an Android phone leaves gameplay and menus upright. Rebuild and install the app to receive these settings.

The signed AAB passed Google's bundletool validation and JAR signature verification.
Its manifest confirms package `com.kaiser.hollowvigil`, version code 1, minimum
Android API 24 and target API 36. No signing files, local saves or tests are included.

The desktop headless suite passed 2,351 checks with zero failures on September 5,
2026. No Android device was connected for a physical installation/launch check.
Google Play processing and testing on a real Android phone are still required.
