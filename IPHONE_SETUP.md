# Native iPhone setup

## Current status

- Windows detects the connected Apple iPhone and its USB device successfully.
- The project uses Godot **4.7.2**, GDScript, portrait orientation and the Compatibility renderer.
- `export_presets.cfg` now includes an **iOS** preset for an ARM64 device and an Xcode project export.
- The Apple Team ID is deliberately empty until the signing account is selected. No Apple credentials are stored in this project.
- **An iOS app has not been built, signed, installed or tested on the iPhone.** An export preset is not an installable app.

## Build and install using a Mac

1. Copy the project to a Mac. Keep `project.godot`, `export_presets.cfg`, `icon.svg`, `scenes` and `scripts` (artwork is drawn in code; the old `assets` and `shaders` folders were removed). Desktop saves in `.runtime` are separate from iPhone saves and are not needed to build the app.
2. Install Xcode, open it to complete its setup, and sign in to your Apple Account in Xcode Settings > Accounts.
3. Install Godot **4.7.2** and the matching **4.7.2** export templates. Earlier templates installed on the Windows computer do not match this engine.
4. Open `project.godot` in Godot. In Project > Export, select **iOS** and enter the Apple Team ID for the account that will sign the app. Use your actual team identifier, not your name. Change `org.prototype.hollowvigil` if Xcode reports that this bundle identifier is unavailable.
5. Leave **Export Project Only** enabled. Export to a new folder using the name `HollowVigil`, without spaces. Open the generated `HollowVigil.xcodeproj` in Xcode. This export step produces the Xcode project; it does not produce a signed app by itself.
6. Connect the iPhone to the Mac, unlock it and accept **Trust This Computer** if prompted. Enable Developer Mode on the iPhone if Xcode requests it.
7. In the app target's Signing & Capabilities settings, select your team and enable **Automatically manage signing**. Select the connected iPhone as the run destination and press **Run**.
8. Verify that the game launches, the controls avoid the notch and Home indicator, touch/pinch gestures work, and progress survives closing and reopening the app.

A free Apple Account supports personal device testing through Xcode. Its provisioning expires after seven days, requiring the app to be rebuilt and reinstalled. A paid membership is not required just to test your own app through Xcode.

## If only Windows is available

The native Godot iOS build still needs a Mac with Xcode, which can be a remote build machine. A cloud build also requires a place to upload the game source and a chosen signing/install workflow. Creating or uploading a repository, starting a cloud build, and configuring an installer have not been performed.

Sideloadly offers Windows installation and signing of an existing IPA using an Apple Account; it does not replace the Mac/Xcode step that builds this Godot game. A cloud-built unsigned IPA would still need signing before installation. Account sign-in and any two-factor authentication should be performed by the account owner in the chosen tool.

## References

- [Godot: Exporting for iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
- [Godot: iOS export options](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformios.html)
- [Apple: Developer account and Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Sideloadly: Supported platforms and installation workflow](https://sideloadly.io/)
