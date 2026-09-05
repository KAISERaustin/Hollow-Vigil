# Code and organization review

Reviewed September 4, 2026 with Godot 4.7.2 on Windows.

## Result

The project is organized for continued development. The existing simulation, transaction and save boundaries were retained; avoid a wholesale framework rewrite at this size. All completed automated suites pass. This review does not certify a production mobile release.

## Findings addressed

| Finding | Change |
| --- | --- |
| Unreadable existing saves looked like a new game and could be overwritten by autosave | Preserve the existing candidates, report the error, and block automatic writes until recovery or explicit reset |
| Invalid new state could truncate the temporary recovery file before validation | Validate the snapshot before opening the temporary file; verify preservation with a newer interrupted-save fixture |
| Invalid damage could produce a false defeat, and unknown enemy kinds could partially enter spawning | Reject invalid damage, missing payout owners, unknown enemy kinds and invalid tick intervals without mutation |
| Save validation accepted noncanonical tower IDs and duplicate unlocks | Reject these malformed records and retain compatibility with legitimate version 1 saves |
| Runtime entry point knew about excluded test scripts | Dedicated rendered test entry point; production startup has no test resource dependency |
| Launcher relied on one machine path and modified its caller's environment | Explicit engine path, environment/PATH discovery, original local fallback, mutually exclusive modes and environment restoration |
| Fresh checkout depended on generated script-class/import caches | Launcher imports before running; confirmed in an isolated copy with no pre-existing engine cache |
| Engine exit status alone could hide script failures | Script preflight, log inspection and automated-test timeouts |
| Rift text and branching logic copied gameplay values | Shared spawn distribution, unlock tables, displayed statistics and tower-level limit |
| UI construction and all headless tests accumulated in large files | Separate HUD component and focused unit suites, with typed application references in panels/dialogs |
| Retired terrain blending still built unused adjacency data | Remove topology cache, shader, old image atlases and obsolete implementation tests; retain GPU appearance checks |
| Reconfiguring a terrain tile appended duplicate roads/props | Clear derived geometry before rebuilding |
| Old names, source history and generated review output obscured active files | Domain folders, current README and architecture/art/testing documentation, consistent entry-scene name and source-control rules |

## Removed and retained

Removed four unused PNG atlases and import sidecars, the retired blend shader, blending topology code, a compatibility-only test alias, redundant territory preview, unused drawing helpers/font setup, loose source backups, and obsolete screenshots/concept material/logs that were not locked.

The prior source and artwork are recoverable from `.runtime/review/before-cleanup.zip`. This is one intentional recovery archive created before this folder had Git history. Player save locations were retained. Test runs now use `.runtime/tests/`.

Legacy road reconstruction, serialized side/angle fields, and saved automation support remain intentional compatibility code. New attack-animation files arrived concurrently during this review; they were preserved and included in verification. Concurrent setup work also initialized Git, configured the Hollow-Vigil GitHub remote and added an iOS preset and iPhone guide.

Four old logs were locked by already-open Godot processes: `artifacts/editor.log`, `playable.log`, `rift-start-smoke.log`, and `rift-start-smoke-errors.log`. They remain ignored and excluded from exports. Close those processes before removing their logs. The original player save files also changed during the review while Godot was open, so byte-for-byte preservation cannot be asserted; this cleanup did not delete or relocate those files.

## Verification evidence

| Check | Result |
| --- | --- |
| Original headless baseline | 2,407 assertions; 0 failures |
| Reorganized headless suite, new guards and concurrent attack-effect checks | 2,351 assertions; 0 failures |
| Full rendered UI suite | 0 failures; mouse/touch, purchase/sale, dialogs, lifecycle, scrolling and camera-independent combat |
| Terrain palette | 256 cases; 17,152 pixel checks; 0 failures |
| Terrain boundaries | 48 cases; 47,360 pixel samples; 0 failures |
| World grid | 48 cases; 214,881 pixel samples; 0 failures |
| Artwork interactions | 540x960 and 360x640; 0 failures |
| Clean source copy, no pre-existing caches | Import and all 2,351 headless assertions pass |
| Export contents | 48 entries; no tests, generated artifacts, runtime data, docs or retired artwork |
| Exported main scene | Starts successfully from the package with test scripts excluded |
| Rendered screenshot inspection | Compact battlefield and tower upgrade dialog inspected |
| Conflicting launcher modes | Rejected before environment changes |

The lower assertion count reflects removal of obsolete blending-mask tests, plus addition of boundary and regression checks; gameplay test groups were retained. Current detailed reports are generated in `artifacts/`. The exported package was checked against the current runtime source files.

## Remaining release work

- Git and a remote were configured concurrently. Add CI if desired; this review did not publish changes or configure a CI provider.
- Install matching export templates and finish Android build-tools/signing setup before making distributable releases. Export package validation is not an APK or standalone executable build.
- Test on actual phones: safe areas, touch, suspend/resume, OS termination, frame pacing, heat and battery use.
- Profile genuinely large worlds on target hardware. Full-world simulation is intentional and must not become camera dependent.
- If progression grows beyond this prototype, revisit exact currency representation and introduce typed saved records incrementally. See `ARCHITECTURE.md` for extension points and existing tradeoffs.

The sandbox emits a known Windows root-certificate-store error and lacks a configured Android build-tools directory. Neither blocked the local simulation, rendering or package checks; both are documented rather than treated as proof of release readiness.
