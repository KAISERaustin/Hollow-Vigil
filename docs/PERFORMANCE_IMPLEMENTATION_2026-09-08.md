# Performance implementation, September 8, 2026

The shared Infinite and Campaign systems now use individually replaceable actor
images, shared immutable route lengths, cached content configuration and tower
statistics, a shared enemy identifier index, and selective HUD formatting/layout.
Gameplay still advances through the existing authoritative simulation. Camera
visibility never changes movement, targeting, damage, rewards or save processing.

The source and raw measurements are in
[the implementation evidence directory](performance/2026-09-08-implementation/).
[Comparison tables](performance/2026-09-08-implementation/comparison_tables.md)
are generated directly from those JSON files. The original September 8 audit and
its evidence remain separate.

At 390x844 on the desktop, frozen overview mean frame time fell from **64.18
to 20.13 ms in Infinite** and **65.33 to 9.35 ms in the overloaded Campaign
fixture**. The largest expanded Infinite simulation fixture fell from **31.61
to 12.67 ms per step**. These are medians of repeated means; the comparison
tables retain p95, p99 and worst samples. Each optimization was also measured
independently, and all 30 Campaign levels match the baseline outcomes in both
the route-only and configuration-only variants.

## What shipped

- **Artwork:** 63 separate transparent PNGs: 18 ordinary enemies, 40 tower
  tier/specialization bodies, and five independently rotating Ironspike bows.
  They are rendered from the original native drawings. Matching instances share
  textures. Health, afflictions, charges, curses, rebuilding, earnings, projectiles,
  effects and animated bosses remain with their existing dynamic owners. There
  is no shipped atlas. [Artwork maintenance](ARTWORK_IMAGES.md) explains swapping
  images, adding entries, anchors and preserving replacements during regeneration.
- **Routes:** one immutable waypoint/suffix-distance object per actual route,
  shared through a weak table owned by the combat. Current position and segment
  supply the moving part of remaining distance. Replacement, boss patrol changes,
  world expansion, knockback and restored bosses have explicit coverage. Very
  close target comparisons use the historical forward sum to preserve tie order.
- **Configuration:** content definitions and tower statistics are cached inside
  each combat. Deep value snapshots detect tuning/equipment replacement and
  in-place edits. Tower signatures include tier, branch and equipped relic.
  Mutable afflictions and component timers stay per instance. One identifier map
  serves target locks, arriving projectiles and following effects. Recycling
  removes references before enemy dictionaries are reused.
- **HUD:** a shared helper skips unchanged money formatting. Floating cards
  cache layout inputs and up to 64 text measurements, invalidating for value,
  safe-area, minimum-size, theme and locale changes. Existing refresh timing,
  animations and touch ownership are preserved.

[Shared ownership and extension rules](PERFORMANCE_SYSTEMS.md) describe these
boundaries. No optimization data is added to authoritative save payloads.

## Measurement method

The reproduced baseline is **ecea0ac6b36c548d80e293e238826feddfa05744**, newer
than the original audit's c5a0b28. The combined snapshot starts at
**4dbd0e0c7ecd9d4758cb68131fd560eb5a39c1ca**, overlaid with the working implementation
at snapshot creation. Source hashes, asset hashes and per-run harness hashes
identify the exact inputs. Later concurrent repository changes are preserved;
they are not silently substituted into these immutable measurements.

All desktop comparisons use Godot 4.7.2, Compatibility/OpenGL, the same fixtures,
seed 570 and fixed 0.05-second combat steps. Production costs have no timing
wrappers enabled. Independent snapshots apply only artwork, route, configuration
or interface changes to the baseline. Raw repeated samples remain available.

Frozen rendering covers both modes at upright 360x640, 390x844 and 540x960:
close, overview, offscreen and panning, plus the audit's diagnostic omissions.
Each case warms up, then captures 179 frame intervals, with three repetitions.
Renderer CPU/GPU counters overlap with frame time and must not be added to it.
The visibility query in the harness contributes work to the following frame in
both revisions. Campaign's 500-enemy rendering fixture is a deliberate overload,
separate from authored waves.

Simulation measurements use six expanded Infinite fixtures, three repetitions,
600 warm-up steps and 300 measured steps. The largest defended fixture has 161
regions and 160 towers. Five-second live application runs include normal
simulation scheduling, presentation, HUD and audio work at 1x, 2x and 4x. The
audio output bus is muted; audio event/voice work remains. A separate 60-second
desktop run records accumulated simulation delay and memory at 4x.

The desktop is shared with other work, including other Godot sessions. Android
export preparation overlapped portions of the final desktop render/live pass.
These are diagnostic comparisons, not isolated laboratory device guarantees.
The earlier render attempt had a transient Windows checkpoint-file open failure;
its samples were not selected. The complete pass was rerun after adding retries
outside measured intervals. An earlier pass also contained isolated 90-98 ms
panning outliers at different frame indices. No causal link to the optimization
was established; the successful repeated pass and its worst frames are reported.

## Artwork and terrain decisions

All 63 cached actor images match the native occupied bounds. Their largest mean
premultiplied channel difference is 0.001903 (0.19%); the comparison retains alpha
coverage and tests every current tier/branch. Lossless, mipmapped actor images
use **9,731,592 bytes (9.28 MiB)** when all are loaded. Canvas owners release
texture references when freed, and matching resources are shared. Native vector
fallback preserves unrestricted developer zoom above the generated resolution.
Custom images can remove that fallback flag so replacements remain visible there.

The per-region terrain-image experiment reduced the paired Infinite mean from
22.10 to 17.94 ms and Campaign from 8.88 to 5.92 ms, but added 27.46 MiB and
221.52 MiB respectively, with initial bake times of about 180 and 713 ms.
Campaign's terrain layer contains more chunks than the current visible view.
This unbounded eager raster strategy is not shipped. The existing retained
terrain commands, per-region culling, appearance revision checks and shared
overlays remain. A future terrain texture cache would need a visible-region
budget and incremental loading before it could justify its memory/latency cost.

Ordered image commands already allow the engine to batch compatible draws while
preserving actor/indicator and tower depth ordering. The separate region-group
experiment uses a favorable non-overlapping body-only layout; grouping by image
is unsuitable as a direct replacement when different actors overlap and each
body is interleaved with its own health/status indicators. The overlap comparison
explicitly demonstrates that grouping an A/B/A sequence by image changes the top
body. In the non-overlapping 500-identical-image case, the engine already batches
the ordered commands into one draw call; manual region groups require six. These
results support keeping ordered shared-image rendering.

## Correctness and limits

State comparisons include enemy positions, health, routes and statuses; tower
state, locks and component progress; pending and line projectiles; traps, fields,
burning ground, curses, relic progress and drops; balances, kills, escapes,
earnings, income events, spawn counts, RNG state and Campaign wave scheduling.
Watching, hidden and moving cameras must match exactly, including cryptographic
checkpoint digests across revisions. Infinite save continuation and Campaign
checkpoint replay use the existing save owners.

All 30 Campaign levels and all 144 waves are replayed with the same survival
guard used for audit coverage. Counts, health, phase, waves and tick counts are
compared. This does not claim that every reference strategy wins without the
guard. Fixed-step comparisons establish gameplay equivalence; different states
after a fixed wall-clock interval can reflect how far each build actually ran.

An initial synthetic camera position at (90000,90000) exposed triangulation
errors in tiny offscreen native portal polygons. The camera harness now uses a
view 12 tiles away and explicitly requires that no enemy is visible. All state
assertions remain unchanged. The artificial far-coordinate drawing issue is
outside ordinary constrained camera use; it is not presented as fixed here.

Memory monitors report retained bytes and live objects, not a native allocation
trace. Per-call retained-byte measurements include the benchmark sample arrays.
They must not be described as total allocation counts. Pooling tests verify that
route and identifier references are released; long-run timelines distinguish
growth in the live enemy population from a continuously growing cache.

The provisional minimum performance budget is **30 FPS / 33.3 ms per frame**,
with 60 FPS / 16.7 ms preferred where practical. The weakest supported phone
models have not been specified, so this work makes no weakest-device acceptance
claim. Expanded 4x Infinite remains a demanding workload even after these gains.

## Physical Android results and stopping point

The connected **Samsung SM-X510**, Android 16, Mali-G68 was measured with
separate release-template exports of both snapshots. Both reported Godot 4.7.2,
Compatibility rendering, a native **1440x2304** portrait surface, and the normal
application's **1.75 DPI scale**. The exports are not debuggable and have no
Internet permission. The normal game package and its saves were not touched.

All three frozen overview repetitions finished for each mode in both releases:

| Mode | Before mean frame ms | After mean frame ms | Before / after draw calls |
|---|---:|---:|---:|
| Infinite | 138.63 | 53.13 | 8417 / 3455 |
| Campaign overload | 202.99 | 35.11 | 12609 / 2755 |

These correspond to roughly **7.2 to 18.8 FPS** and **4.9 to 28.5 FPS**. The
optimized workloads still miss the provisional 30 FPS target on this tablet.
The captured optimized tablet artwork was visually inspected. GPU timing
returned zero throughout and is unavailable, not evidence of zero GPU cost.
CPU renderer means fell from 39.96 to 19.04 ms and 56.32 to 13.40 ms respectively.

The baseline also completed live 1x/2x/4x, a three-minute 4x run and its camera/save
checks. The user then requested that testing wrap up. The optimized package was
stopped after its complete frozen-render pass, before completion of its live,
sustained and behavior suites. `android_after.json` deliberately records
`complete: false` and only its finished rendering report. No paired Android
live/sustained or authoritative-state success is claimed. The desktop paired
camera/save and sustained tests completed before this stop request.

The tablet was USB-powered with a low battery: 8-10% during the baseline and
10% during the optimized pass. Android thermal status ranged from 0 to 1 during
the baseline and remained 1 during the optimized pass. Battery temperature was
32.2 to 32.1 C across the baseline and 32.1 to 32.6 C across the shorter optimized
run. These sequential runs were not a cooled, randomized thermal comparison.
Release engine memory counters were unavailable. Android process PSS telemetry
was collected (baseline range 262-802 MiB, shorter optimized range 260-569 MiB),
but the unequal completed workloads make those ranges unsuitable as a memory
improvement claim. Raw readings and source/APK hashes are preserved.

No iPhone release environment was available. Physical touch/rotation acceptance
and a matched optimized Android sustained run remain unverified. The test
package is stopped; the user's regular installation remains available.

## Remaining bottlenecks

Actor drawing and repeated route walks are substantially cheaper, but terrain
commands, dynamic indicators/effects and the remaining combat work still cost
time. Ordered images intentionally retain correct overlapping artwork and
indicator layering. The terrain candidate's memory and initial bake cost ruled
out shipping that eager cache. The one-minute desktop 4x workload improved from
4.73 to 16.00 FPS and advanced 239.75 simulated seconds in 60.01 real seconds,
but still misses the frame budget. The largest fixture retains a 71.59 ms worst
combat step. Further work should profile these remaining costs on the actual
minimum supported devices; these changes are improvements, not a claim that
every stress fixture meets a mobile frame-rate target.

## Regression validation

The full gameplay runner passed **56,466 checks**, and dedicated optimization
coverage passed **9,084 checks**, including all six bosses' changed/restored
routes. Error scans accompany the exit codes. Rendered checks passed for all
63 actor images, tower depth ordering, 1,443 Campaign HUD checks, 294 ground-build
touch checks and 236 shared tower-management checks. Branch visuals exercise
all 16 specializations and 48 portrait purchase confirmations.

These are completed validation runs, with their logs and hashes preserved in
`validation_complete.json`. Concurrent tower-management layout/input edits that
arrived afterward are included under the repository's preservation policy.
Testing was not restarted for those later edits after the user's wrap-up request.

Older rendered tests assumed a screen-height battlefield, instant Campaign exit
and the retired inline branch controls. They were updated to the current build
tray, explicit exit confirmation and shared management card. Their original
invalid level-three/branch combination was corrected before rendering branch
combat. These fixture errors did not require production gameplay changes.

## Reproduction

Use `tools/performance_compare.py prepare NAME [--working]` to create a new
immutable source copy; never overwrite an existing comparison snapshot.
`tools/performance_variants.py` creates the independent variants from the recorded
before/after copies. `tools/complete_performance_validation.py` finishes the
serial comparisons and regression checks. `tools/android_performance.py build`
and `run` prepare and measure a separate, locally signed Android release-template
package. Its network permission is disabled and it never replaces the normal
game package or accesses its saves.

Rebuild the tables with `tools/summarize_performance_changes.py`. The original
audit's instrumentation and marker experiments remain diagnostic tools, not
production behavior.
