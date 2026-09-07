# Hollow Vigil audio

Original synthesis-only audio, authored for this game. No third-party recordings,
voice models, sample packs, or music licenses are required. Rebuild the cue catalog
and the score with `python3 tools/generate_audio.py` (Python standard library).
Run `python3 tools/validate_audio.py` to check uniqueness, peaks and loop continuity.
`catalog.json` records each cue's texture, envelope duration, pitch, category and
cooldown. Godot imports the committed mono 22,050 Hz / 16-bit WAV files.

## Event coverage

| Family | Sound and trigger |
| --- | --- |
| Menus | Dry click, rising open, falling close, selection and slider ticks; mouse, touch and keyboard use the same button signals. |
| Transactions | Separate build, upgrade, sale, relocation, reconstruction-complete, territory purchase, rift traffic, enemy unlock, automation, gold collection, return earnings, reset and notice cues. Automatic collection stays silent. |
| Ashneedle | Muted 260 Hz bowstring and wooden limb release with a short filtered arrow rush; soft 170 Hz arrow impact. Reusable bow and arrow-impact textures keep rapid fire dry without a high whistle. |
| Pyre | Low filtered flame launch and burst. |
| Obelisk | Resonant orb launch and impact. |
| Stormspire | Brief modulated electrical crackle, once per volley rather than once per target. |
| Frostneedle | Lower 380 Hz bow attack and 239.4 Hz impact replace the piercing chime; the specialization purchase cue is unchanged. |
| Poison Arrow | Woody rush and a single aimed-arrow impact, using the stable thorn_volley audio IDs. |
| Cinderfield | Smoldering flame launch, impact and separate ground ignition. |
| Rupture Pyre | Deeper pressure burst and heavy impact accompanying knockback. |
| Grave Echo | Rising spectral orb, impact and fragment scatter. |
| Doomstone | Low beating resonance and curse impact. |
| Tempest Web | Higher, longer electrical weave for its chain volley. |
| Thunderseal | Rising electrical charge and separate fifth-hit seal detonation. |
| Specialization purchase | Eight individual confirmation cues, matching each specialization's material. |
| Enemies | Six distinct 130 ms death cues: Hollow wood tap, Wraith air, Revenant low thud, Lantern Keeper chime, Abyss Shade whisper, Crypt Sentinel resonance. Core escapes have a separate soft descending cue. |
| Briarbound Warden | Wooden footfalls, awakening, root regrowth, shield break, death and escape. |
| Cindermaw | Smoldering footfalls, awakening, rage transition, death and escape. |
| Drowned Bell | Metallic footfalls, awakening, escort-summoning toll, death and escape. |
| Eclipse Prior | Spectral footfalls, awakening, ward regrowth, final ward break, death and escape. |
| Music | **The Lantern Watch**, an original 64-second D-minor ambient score, suspended harmonies and sparse bells; circular overlap-add preserves reverb across the loop boundary. |

## Mix and preferences

Settings contains Master, Menu, Towers, Enemies, Bosses and Music sliders,
percentage readouts, category previews, mute-all and restore-defaults controls.
Zero is true silence. Changes update active voices immediately and use the app's
existing debounced save mechanism. Muting preserves slider values; resetting game
progress preserves sound preferences. Older saves receive defaults without a
schema-version migration. Invalid stored volumes fail normal save validation.
Music plays continuously while focused and pauses in the background.

A dedicated per-app director owns pools of 6 tower, 2 enemy, 3 boss and 3 menu
voices plus one music player. It never steals playing voices or queues overflow.
Per-cue cooldowns coalesce repeated shots; enemy deaths additionally share a
220 ms minimum interval. Boss abilities and branch detonations bypass the category
gap, but retain their own cooldown and pool limit. Footfalls pause during stuns.
World cues fade over 180 screen pixels outside the battlefield and disappear
when it is hidden. Global menu feedback and music remain camera-independent.
All assets peak at .22. Enemy, menu and music trims keep the score and incidental
sounds below combat. A private mix bus uses a smooth look-ahead limiter at -1 dB
to prevent clipping at maximum slider settings; the bus is removed on app exit.

Audio signals are independent of the cosmetic effect pool and never use combat
RNG. Repeated shots, impacts, enemy deaths and boss footsteps receive an independent playback pitch ratio from 0.9 to 1.1. Music, UI and other boss cues retain their assigned pitch. Missing streams are skipped. The audio director rebinds after progress reset. There is no ambient rift
spawn noise or per-damage-tick sound: those would dominate a developed idle map.

## Verification

`tests/audio_runner.gd` loads all assets, exercises weapon and boss events,
checks crowd limits, spatial rejection, live category silence, mute, pause,
legacy/invalid saves, persistence, reset rebinding, and settings at 540×960,
360×640 and 390×844. It is part of `launch.ps1 -Tests` / `-Check`; it can also be
run directly with Godot `--script res://tests/audio_runner.gd` (add `--headless`
for the non-rendered run). Test saves use the disposable `audio-check.save` name.
Rendered runs write `artifacts/audio-settings-*.png`.
