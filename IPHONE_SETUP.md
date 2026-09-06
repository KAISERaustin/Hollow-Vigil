# Hollow Vigil on iPhone

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
