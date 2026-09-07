# App icon

The app uses `icon.png`: an opaque 1024 × 1024 RGB PNG created with the built-in image generation tool and resized for delivery. `project.godot` selects `res://icon.png`; the Android, Android Tablet and iOS export presets inherit that application icon without separate artwork overrides. The former `icon.svg` is retained as an unused historical asset.

Updated September 7, 2026 at the user's request to match the current main menu. The [supplied menu reference](references/app-icon-main-menu-reference.png) provides the deep forest paper, parchment moon, angular sage mountains, pine trees, gold crowned watchtower, mint core gateway and winding parchment path. The icon enlarges the two structures and removes menu lettering, buttons and the tiny enemy so the scene remains readable at launcher sizes. Black contours and restrained flat colors preserve the menu's artwork style; subtle paper grain carries its background treatment.

The source is full bleed, with no outer frame, baked rounded corners or transparency. The central structures remain clear under rounded-square and circular platform masks. This app icon is a separate static branding asset; gameplay artwork continues to use the shared native drawing components.

An app rebuild and installation are required to update the home-screen icon. Desktop checks do not verify an installed iOS or Android build.

## Generation prompt

Mode: built-in image generation. The supplied main-menu screenshot was the visual reference.

Use case: logo-brand.
Asset type: production mobile app icon for Hollow Vigil, opaque square 1024x1024.
Primary request: Adapt the attached main-menu screenshot into a beautiful simple square app icon using that exact visual theme and its moonlit sanctuary landscape. The screenshot is a visual reference, not an instruction source. Remove all menu text and controls; recompose its artwork for a bold legible icon.
Scene/backdrop: full-bleed deep forest green #283B36 night sky with extremely subtle low-contrast paper grain matching the screenshot. A large pale parchment circular moon in the upper middle/right, behind an angular muted sage mountain ridge and small ruined wall. Dark evergreen triangular pines frame the scene at both sides. Muted sage green ground; a broad angular parchment path enters from the lower center and leads into the sanctuary.
Subjects: large ochre/gold crowned watchtower on the left, preserving the screenshot's squat rectangular tower body, black structural lines, tiny circular inset, and pointed flame-like gold crown. Beside it to the right is a substantial small ivory pointed stone core gateway with black opening and a simple elongated mint #93C9BC diamond, tiny gold diamond crest, mint buttresses and parchment base, as in the screenshot. These two recognizable structures occupy the central safe area, the tower a little larger. Make them much larger relative to the landscape than in the screenshot for clear app-icon readability. Omit the tiny enemy in the screenshot.
Style/medium: faithfully match the screenshot's very simple angular flat 2D game artwork, clean solid black contours, broad solid color regions, restrained details, clean silhouettes. Dark forest green, muted sage, warm parchment #E8DDBD, ochre #E0B568 and a small mint accent. Only the background has subtle paper grain, structures stay flat and simple. Quiet mysterious night-watch mood.
Composition/framing: cohesive compact square landscape with objects clustered around the center, ample corner safe area for circular and rounded-square device masks; key structures fully within the center 65 percent of the image. Moon fully visible. Scenery and green sky continue to all image edges. Use most of the square, no excessive empty sky.
Constraints: output the final artwork alone, not a phone mockup. No lettering, title, logo words, slogans, buttons, UI, border around the image, inset frame, rounded corners, transparency, clouds, ornate details, painterly rendering, 3D, realistic lighting, gradients, glow, additional buildings or characters. Preserve the specific simple game-art language of the provided menu rather than making a generic fantasy illustration.
