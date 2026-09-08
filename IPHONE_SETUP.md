# Hollow Vigil on iPhone

## Portrait-only orientation

The app is locked to upright portrait through `display/window/handheld/orientation.ios=1` in `project.godot`. Godot generates both `UISupportedInterfaceOrientations` and `UISupportedInterfaceOrientations~ipad` with only `UIInterfaceOrientationPortrait`; its native template retains `UIRequiresFullScreen=true`. Verify those values in the newly exported Xcode project's Info.plist, and confirm turning an iPhone leaves gameplay and menus upright before releasing. Use a fresh export/archive to apply the settings; existing TestFlight installations are unchanged until a new build is installed. Historical build reports below retain their original test coverage.

## TestFlight build 1.0.8 — September 7, 2026

Version **0.1.0 (1.0.8)** contains the latest source from `6696e3ffad2a92b349f35d8053246aea29e2d957`, with the iOS build number updated to `1.0.8`. Xcode Organizer confirmed **Uploaded to Apple** at 2:39 PM CDT through **Distribute App → App Store Connect → Distribute** using the signed-in developer account. App Store Connect subsequently confirmed **Testing** in the internal **Just for Testing** group, with seven testers and eight available builds.

Validation: fresh Godot import and structure checks passed; the gameplay suite passed **52,029 checks with zero failures**; the current rendered mobile navigation suite passed **4,441 checks with zero failures** across four screen sizes. The older mobile scrolling runner is incompatible with redesigned controls (`field` on a generic fixture and missing `SaveSlot1`); its printed zero-failure result is invalid because script errors interrupted coverage. The current navigation runner completed with two ObjectDB instances reported at shutdown. The Release archive and deep, strict signature verification passed. Xcode reported existing generated-header, empty privacy usage description, and skipped App Intents extraction warnings. Physical-device validation of this build remains for TestFlight testers.

Archive: `~/Library/Developer/Xcode/Archives/2026-09-07/HollowVigil-1.0.8.xcarchive`. Isolated source: `/private/tmp/hollow-vigil-release-1.0.8-source`. Logs: ignored `artifacts/testflight-1.0.8/`. Exported PCK SHA-256: `a5e8cf5d15fa475b4c5808dc05ba66b1812b4bd54630a7edcd44cc039697cd79`.

[Build 1.0.8 in App Store Connect](https://appstoreconnect.apple.com/teams/9e8e8295-c906-4d21-8e40-988d2e1a8075/apps/6809097281/testflight/ios/600838ff-3ef1-4311-95a8-05fb94e1d44b).

## TestFlight build 1.0.7 — September 6, 2026

Version **0.1.0 (1.0.7)** includes the latest parchment menu backgrounds, mobile scrolling changes, and campaign speed behavior from commit `6c6949a91ab16a486a46d11f9420e9d1b60c7583`, with the iOS export preset's build number updated to `1.0.7`. Xcode Organizer confirmed **Uploaded to Apple** at 6:31 PM CDT through **Distribute App → App Store Connect → Distribute**, using the existing developer account. App Store Connect confirmed **Testing** in the internal **Just for Testing** group, with six testers and seven available builds.

Validation: the release source snapshot was checked against Git blob hashes; a fresh Godot import and structure checks passed; the headless gameplay suite passed **51,002 checks with zero failures**. The native-rendered mobile scrolling suite passed with **zero failures**, covering touch scrolling, safe actions, numeric controls, and full-screen menus at three portrait sizes and short landscape. The Release archive succeeded and its signature passed deep, strict verification. Xcode emitted the same generated-header, empty privacy-usage-description, and skipped App Intents extraction warnings as 1.0.6. Physical-device testing of this specific build remains for TestFlight testers.

The Organizer archive is at `~/Library/Developer/Xcode/Archives/2026-09-06/HollowVigil-1.0.7.xcarchive`. The isolated build source is at `/private/tmp/hollow-vigil-release-1.0.7-source`; temporary files may be cleared by macOS. Logs are under ignored `artifacts/testflight-1.0.7/`, including `tests.log`, `mobile-scroll.log`, `import.log`, `export.log`, and `archive.log`. The exported PCK SHA-256 is `5714865d9c5e5f3c65be7eaf38328214b9f7021723969d4d3baca45f85e44ea8`.

[Build 1.0.7 in App Store Connect](https://appstoreconnect.apple.com/teams/9e8e8295-c906-4d21-8e40-988d2e1a8075/apps/6809097281/testflight/ios/20038dba-56bf-41bb-ab01-579b5d97f85f).

## TestFlight build 1.0.6 — September 6, 2026

Version **0.1.0 (1.0.6)** was built from commit `269180be8be5dd09438eb44d1b87ca1f7af3cf5f` with the iOS export preset's build number updated to `1.0.6`. Xcode Organizer confirmed **Uploaded to Apple** at 6:11 PM CDT through **Distribute App → App Store Connect → Distribute**, using the existing signed-in developer account. App Store Connect subsequently confirmed **Testing** in the internal **Just for Testing** group, with six testers.

Validation: a fresh Godot import completed without script errors; structure checks passed; the headless gameplay suite passed **51,002 checks with zero failures**; the Release archive succeeded and its signature passed deep, strict verification. The initial working-folder test attempt encountered missing imported textures and was stopped; the successful suite ran from the freshly imported release copy. Xcode emitted the same empty camera, microphone and photo-library usage-description warnings, generated-header pragma warning, and skipped App Intents extraction warning seen in the previous release. Physical-device testing of this build remains for TestFlight testers.

The Organizer archive is at `~/Library/Developer/Xcode/Archives/2026-09-06/HollowVigil-1.0.6.xcarchive`. The isolated build source is at `/private/tmp/hollow-vigil-release-1.0.6-source`; temporary files may be cleared by macOS. Logs are under ignored `artifacts/testflight-1.0.6/`, including `release-tests.log`, `import.log`, `export.log`, and `archive.log`. The exported PCK SHA-256 is `77cb11f0e4fe006aadc6f05aff126cc3170fe03bc370819c827496d3e667a43d`.

## TestFlight release — September 6, 2026

Version **0.1.0 (1.0.5)** was built from commit `eb8c25d1545e3b2d6f16d0a2332a261a5e8696b3`, uploaded through **Xcode Organizer → Distribute App → App Store Connect**, processed successfully by Apple, and assigned to the internal **Just for Testing** group. App Store Connect confirmed six testers have access. Gameplay source was unchanged; the archive build number was overridden to `1.0.5`.

Validation: structure checks passed; the headless gameplay suite passed **30,562 checks with zero failures**; the Release archive succeeded and its signature passed deep, strict verification. Xcode emitted warnings for empty camera, microphone and photo-library usage descriptions, a generated header pragma, and skipped App Intents extraction. Apple accepted the upload. Physical-device testing of this specific build remains for TestFlight testers.

Prefer Organizer for future uploads: command-line archive creation succeeded, but command-line upload returned an App Store Connect credentials error. Organizer succeeded using the signed-in account. Build in an isolated local directory if iCloud-backed source reads stall. This archive is at `/private/tmp/hollow-vigil-release-1.0.5-eb8c25d/HollowVigil.xcarchive`; temporary files may be cleared by macOS. Build and test logs are under ignored `artifacts/testflight-20260906/`.

[Build in App Store Connect](https://appstoreconnect.apple.com/teams/9e8e8295-c906-4d21-8e40-988d2e1a8075/apps/6809097281/testflight/ios/aba5907a-8ecf-4f7b-aa43-7f871fd4d5ac).

## Installed build — September 4, 2026

Hollow Vigil 0.1.0 (build 1.0.0), bundle identifier `com.kaiser.hollowvigil`, was built in Release mode and installed on Austin's iPhone 16 Pro running iOS 27.0 beta. The build uses Godot 4.7.2, its matching official iOS templates, and Xcode 26.6.

Open **Hollow Vigil** on the phone to play. The engine and game are bundled in the app. No connection to this Mac, server, Wi-Fi or cellular service is needed for gameplay. Progress is saved in the app's own Documents directory. Offline earnings use the existing game rules: 80% of demonstrated production, capped at seven days.

Start by buying a territory with a large **+** button for 100 gold, then buying an Ashneedle in an empty tower socket for 60 gold.

## Signing expiration

The installed build uses the existing paid developer team's development signing identity. Its certificate expires **December 17, 2026 at 16:14 UTC**, earlier than the embedded provisioning profile's June 20, 2027 expiration. Arrange a renewed certificate and rebuild/reinstall before December 17. This is a development installation, not a permanent App Store installation; signing can also stop working if the account or certificate is revoked.

Reinstall over the existing app using the same bundle identifier and Apple team to retain its data. Do not delete the app to renew it: deleting it removes local progress. Back up the app container through Xcode's Devices window before future signing changes.

## Verification

- Official export-template SHA-256 matched the Godot release metadata.
- Headless gameplay and persistence suite: **2,351 checks, zero failures**.
- Rendered UI suite: **zero failures**, including simulated touch, pinch/pan, tower controls, transactions and camera-independent combat.
- Xcode Release build succeeded; the finished signature passed strict verification.
- Apple device tools confirmed installation and launch without an attached debugger.
- A screenshot from the physical phone confirmed the game renders with visible header/footer controls and space around the Dynamic Island and Home indicator.
- Local `Documents/vigil.save` and backup files were created; the downloaded save's checksum was valid.
- After a fresh process launch, the same world, both purchased territories and the tower were retained. Saving continued with a higher sequence number, and another phone screenshot showed live combat and earnings.

Desktop-generated gestures are not physical multitouch testing. Airplane Mode, prolonged battery use and large worlds have not been exercised on this phone.

Build logs, install receipts and the phone screenshot are in `artifacts/` (ignored by Git). A signed installable backup is in `exports/ios/HollowVigil.ipa` (also ignored).

## Rebuild on this Mac

The iOS preset now enables mobile texture imports, sets the Apple team and bundle identifier, disables push notifications correctly, and exports a release engine with development signing. Export templates are installed at `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`.

From the repository directory:

```bash
GODOT_BIN="$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --export-release iOS exports/ios/HollowVigil.ipa

xcodebuild \
  -project exports/ios/HollowVigil.xcodeproj \
  -scheme HollowVigil -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/hollow-vigil-ios-build \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=WQDR97B55W CODE_SIGN_STYLE=Automatic \
  'CODE_SIGN_IDENTITY=Apple Development' build

xcrun devicectl device install app --device 'Austin’s iPhone (2)' \
  /private/tmp/hollow-vigil-ios-build/Build/Products/Release-iphoneos/HollowVigil.app
xcrun devicectl device process launch --device 'Austin’s iPhone (2)' \
  com.kaiser.hollowvigil
```

If the phone is renamed, use its current name from `xcrun devicectl list devices`. Xcode must have a valid signing account and certificate. The generated project uses automatic signing because the existing profile is managed by Xcode.

Keep DerivedData outside the synced Documents folder: its file-provider metadata caused code signing to fail. `/private/tmp` avoids that issue and can be regenerated if macOS clears it. The Godot export creates an Xcode project and PCK; it does not itself regenerate the signed backup IPA when **Export Project Only** is enabled.

## References

- [Godot: Exporting for iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
- [Apple: Developer account and Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Apple: Distribution to registered devices](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices)
