"""Aggregate completed audit evidence without changing or extrapolating measurements."""
import json
from pathlib import Path
from statistics import median
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'docs/performance/2026-09-08'


def load(name):
    path = DATA / name
    return json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}


def grouped(rows, keys, metrics):
    groups = defaultdict(list)
    for row in rows:
        key = tuple(tuple(row[k]) if isinstance(row[k], list) else row[k] for k in keys)
        groups[key].append(row)
    result = []
    for key, members in groups.items():
        row = dict(zip(keys, key))
        row['repeats'] = len(members)
        for metric in metrics:
            valid = [r[metric] for r in members if r.get(metric)]
            if valid:
                row[metric] = {stat: median(r[stat] for r in valid) for stat in ['mean', 'p50', 'p95', 'p99', 'max']}
                row[metric]['mean_min'] = min(r['mean'] for r in valid)
                row[metric]['mean_max'] = max(r['mean'] for r in valid)
                row[metric]['worst_observed'] = max(r['max'] for r in valid)
        for extra in ['before', 'after', 'counts']:
            if extra in members[0]: row[extra] = members[0][extra]
        if 'checksum' in members[0]: row['repeat_checksums_match'] = len({r['checksum'] for r in members}) == 1
        result.append(row)
    return result


def main():
    baseline = load('baseline_simulation.json').get('rows', [])
    profile = load('instrumented_simulation.json').get('rows', [])
    profile_by_case = {r['case']: r for r in profile}
    simulations = grouped(baseline, ['case'], ['tick_ms'])
    for row in simulations:
        p = profile_by_case.get(row['case'])
        if p:
            total = sum(v for k, v in p['profile']['inclusive_usec'].items() if k.startswith('tick.'))
            row['profile_phases'] = {k: {'ms_per_tick': v/300000, 'percent': 100*v/total}
                for k,v in sorted(p['profile']['inclusive_usec'].items(), key=lambda item: -item[1])}
            ref = next(r for r in baseline if r['case'] == row['case'])
            row['instrumentation_counts_match'] = ref['before'] == p['before'] and ref['after'] == p['after']
    render = load('baseline_render_verified.json').get('rows', [])
    render += load('baseline_visibility.json').get('rows', [])
    render = list({(r['case'], tuple(r['viewport']), r['camera'], r['variant'], r['repeat']): r for r in render}.values())
    live_rows = load('baseline_live.json').get('rows', []) + load('baseline_live_2x.json').get('rows', []) + load('baseline_live_4x.json').get('rows', [])
    for row in live_rows: row.setdefault('playback', 1.0)
    summary = {
        'summary_statistic': 'Median across repeated runs; percentiles are medians of per-run percentiles, not pooled percentiles.',
        'simulation': simulations,
        'render': grouped(render, ['case','viewport','camera','variant'], ['frame_ms','renderer_cpu_ms','renderer_gpu_ms','draw_calls','primitives','visible_enemies']),
        'ui': grouped(load('baseline_ui.json').get('rows', []), ['mode','variant'], ['frame_ms','tick_ms','refresh_ms','view_maintenance_ms']),
        'campaign': load('baseline_campaign.json').get('rows', []),
        'costs': load('baseline_costs.json').get('rows', []),
        'camera': load('baseline_camera.json'),
        'deep': load('detailed_deep.json').get('rows', []),
        'render_instrumentation': load('instrumented_render.json').get('rows', []),
        'campaign_all_waves': load('baseline_campaign_all_waves.json').get('rows', []),
        'live': grouped(live_rows, ['mode', 'playback'], ['frame_ms']),
        'fingerprints': {name: load(f'{name}_fingerprint.json') for name in ['baseline','instrumented','detailed']},
    }
    (DATA/'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(json.dumps({key:len(value) for key,value in summary.items() if isinstance(value,list)}, indent=2))
    if not simulations or not summary['render']: return
    import matplotlib
    matplotlib.use('Agg')
    matplotlib.rcParams['svg.hashsalt'] = 'hollow-vigil-performance-audit'
    import matplotlib.pyplot as plt
    fig, axes = plt.subplots(1, 2, figsize=(13, 5.5), layout='constrained')
    labels = ['9 regions\nno towers','41 regions\n40 towers','81 regions\nno towers','81 regions\n80 towers','161 regions\n160 towers','81 regions\ncompact map']
    ax = axes[0]
    positions = list(range(len(simulations)))
    ax.barh(positions, [r['tick_ms']['mean'] for r in simulations], color='#347c8e', label='Mean step')
    ax.scatter([r['tick_ms']['p95'] for r in simulations], positions, marker='D', color='#bb683b', label='95th percentile')
    ax.set_yticks(positions, labels)
    ax.invert_yaxis()
    ax.set_xlabel('Milliseconds per 50 ms combat step (lower is better)')
    ax.set_title('Sustained Infinite combat — drawing disabled')
    ax.legend(loc='lower right', frameon=False)
    chosen = [r for r in summary['render'] if r['case']=='infinite' and r['viewport']==(390,844) and r['camera']=='overview']
    names = {'full':'Current rendering', 'no_actors':'Actor art omitted', 'markers':'Enemy markers only', 'no_map':'Terrain omitted', 'no_cosmetics':'Cosmetic effects omitted'}
    ax = axes[1]
    ax.barh([names[r['variant']] for r in chosen], [r['frame_ms']['mean'] for r in chosen], color=['#bb683b' if r['variant']=='full' else '#347c8e' for r in chosen])
    ax.axvline(1000/60, color='#555555', linestyle='--', linewidth=1, label='60 FPS budget (16.7 ms)')
    ax.invert_yaxis()
    ax.set_xlabel('Milliseconds per rendered frame (lower is better)')
    ax.set_title('Same frozen battle at 390 × 844 — no combat')
    ax.legend(frameon=False)
    for ax in axes:
        ax.spines[['top','right']].set_visible(False)
        ax.grid(axis='x', alpha=0.15)
        ax.set_axisbelow(True)
    fig.suptitle('Hollow Vigil performance audit • Windows / RX 7800 XT\nDesktop diagnostic measurements; not physical-phone FPS', fontsize=13)
    fig.savefig(DATA/'performance_summary.png', dpi=160)
    svg = DATA/'performance_summary.svg'
    fig.savefig(svg, metadata={'Date': None})
    svg.write_text('\n'.join(line.rstrip() for line in svg.read_text(encoding='utf-8').splitlines())+'\n', encoding='utf-8')
    plt.close(fig)
    if summary['campaign_all_waves'] and summary['live'] and all(summary['fingerprints'].values()) and load('baseline_visibility.json'):
        write_report(summary)


def write_report(s):
    def find_render(mode, variant='full', camera='overview', width=390):
        return next(r for r in s['render'] if r['case']==mode and r['variant']==variant and r['camera']==camera and r['viewport'][0]==width)
    def ms(value): return f'{value:.2f}'
    def table(headers, records):
        return '\n'.join(['| '+' | '.join(headers)+' |', '| '+' | '.join(['---']*len(headers))+' |'] + ['| '+' | '.join(map(str,row))+' |' for row in records])
    sim_names = ['9 regions, no towers', '41 regions, 40 towers', '81 regions, no towers', '81 regions, 80 towers', '161 regions, 160 towers', '81 regions, 80 towers, compact layout']
    sim_table = table(['Infinite fixture', 'Enemies at 45 s', 'Mean step (ms)', 'p95 step (ms)', 'Worst observed step (ms)'],
        [[name,r['after']['enemies'],ms(r['tick_ms']['mean']),ms(r['tick_ms']['p95']),ms(r['tick_ms']['worst_observed'])] for name,r in zip(sim_names,s['simulation'])])
    render_table = table(['Fixture / portrait viewport','Frame mean (ms)','Frame p95 (ms)','Renderer CPU mean (ms)','GPU mean (ms)','Draw calls','Enemy drawing candidates'],
        [[f'{mode.title()} / {w}×{h}',ms(r['frame_ms']['mean']),ms(r['frame_ms']['p95']),ms(r['renderer_cpu_ms']['mean']),ms(r['renderer_gpu_ms']['mean']),f"{r['draw_calls']['mean']:,.0f}",f"{r['visible_enemies']['mean']:,.0f}"]
         for mode in ['infinite','campaign'] for w,h in [(360,640),(390,844),(540,960)] for r in [find_render(mode,width=w)]])
    variants = [('full','Current rendering'),('markers','Enemy drawings replaced by markers'),('no_actors','Enemy and tower drawings omitted'),('no_map','Map layer omitted'),('no_cosmetics','Transient cosmetic list omitted')]
    ablations = table(['390×844 frozen overview', 'Infinite mean (ms)', 'Campaign mean (ms)'],
        [[label,ms(find_render('infinite',variant)['frame_ms']['mean']),ms(find_render('campaign',variant)['frame_ms']['mean'])] for variant,label in variants])
    ui_table = table(['Mode / full app fixture','Frame mean (ms)','HUD refresh per call (ms)','View maintenance per call (ms)','Battlefield hidden frame mean (ms)'],
        [[mode.title(),ms(full['frame_ms']['mean']),ms(full['refresh_ms']['mean']),ms(full['view_maintenance_ms']['mean']),ms(hidden['frame_ms']['mean'])]
         for mode in ['infinite','campaign'] for full in [next(r for r in s['ui'] if r['mode']==mode and r['variant']=='full')]
         for hidden in [next(r for r in s['ui'] if r['mode']==mode and r['variant']=='no_render')]])
    live_raw = load('baseline_live.json')['rows']
    live_raw += load('baseline_live_2x.json').get('rows', [])
    live_raw += load('baseline_live_4x.json').get('rows', [])
    live_speeds = sorted({r.get('playback', 1.0) for r in live_raw})
    live_table = table(['Normal game loop, 390×844','Median actual desktop FPS','Frame p95 (ms)','Median simulated / wall seconds'],
        [[f'{mode.title()} / {speed:g}×',f"{median(r['actual_fps'] for r in members):.1f}",ms(median(r['frame_ms']['p95'] for r in members)),
          f"{median(r['simulation_seconds'] for r in members):.2f} / {median(r['elapsed_seconds'] for r in members):.2f}"]
         for mode in ['infinite','campaign'] for speed in live_speeds
         for members in [[r for r in live_raw if r['mode']==mode and r.get('playback', 1.0)==speed]] if members])
    all_waves = s['campaign_all_waves']
    losses = [str(r['level']) for r in s['campaign'] if r['phase']!='victory']
    completed = sum(r['waves_completed'] for r in all_waves)
    authored = sum(r['waves_total'] for r in all_waves)
    campaign_table = table(['Level','Authored waves measured','Peak live enemies','Mean combat step (ms)','p95 (ms)'],
        [[r['level'],f"{r['waves_completed']}/{r['waves_total']}",r['peak_enemies'],ms(r['tick_ms']['mean']),ms(r['tick_ms']['p95'])] for r in all_waves])
    costs = {r['label']:r for r in s['costs'] if 'label' in r}
    route_old = costs['defended.all_remaining_distances']['ms']['mean']
    route_new = costs['defended.experimental_remaining_distance_suffix_lookup']['ms']['mean']
    deep = next(r for r in s['deep'] if r['radius']==80)
    route_tick = deep['profile']['inclusive_usec']['scripts/gameplay/combat/targeting.gd:distance_remaining']/300000
    fingerprints = s['fingerprints']
    equivalent = len({r['checksum'] for r in fingerprints.values()}) == 1
    report = f'''# Hollow Vigil performance audit — September 8, 2026

The measurements identify two substantial costs: drawing large numbers of small pieces of artwork, and repeatedly calculating enemies' remaining route distances during targeting. Keep combat independent of the camera. Optimize those shared systems so both Campaign and Infinite benefit while offscreen kills and rewards remain real.

Physical-phone measurements remain outstanding. No Android device was listed by `adb devices -l`; this Windows host has no Xcode/iOS profiling tools or supplied Mac connection. The results below are desktop measurements, not iPhone or Android performance claims.

![Measured performance](performance/2026-09-08/performance_summary.png)

## What was measured

| Recommendation | Work performed | Status |
| --- | --- | --- |
| Separate combat from drawing | Six Infinite workloads, three baseline repeats each; coarse phase profiling and deeper function attribution | Completed |
| Measure drawing and GPU work | Both modes at 360×640, 390×844 and 540×960; close, overview, edge and moving cameras; CPU/GPU timers and draw-call counts | Completed |
| Measure visual alternatives | Same frozen state with actor art omitted, enemy markers, map omitted, and transient cosmetics omitted; fully hidden view supplement | Completed |
| Measure interface cost | Full application shells, HUD calls and view maintenance; simulation/render/HUD ablations, three repeats | Completed |
| Test normal and faster playback | Five-second normal-loop samples at 1×, 2× and 4×, three repeats per mode at 390×844, elapsed time and audio-event work | Completed |
| Check the available save | Read-only source inspection; benchmarked a private copy of the local 3-region / 2-tower Infinite save | Completed; large reported save was not present locally |
| Inspect repeated calculations | Route distances, speed resolution, enemy index and ID maps, tower stats, component synchronization, visibility queries and atomic save writing | Completed |
| Check camera-independent outcomes | Both modes watching, away and moving; additional rendered full/hidden/HUD-disabled state comparisons | Completed |
| Cover Campaign content | All 30 levels attempted with existing reference strategies; separate sweep measured {completed}/{authored} authored waves | Completed |
| Measure real iOS and Android devices | Device/tool availability checked | Blocked by device and Mac access |

## Environment and method

The fixed source baseline is `c5a0b284c74ad55cce6ca375bd14afc9e82fb0a2`, the committed version at the start of this audit. Other tasks were changing the shared checkout, so benchmark copies under `.runtime/performance-audit-20260908/` isolated the measurements. Later ground-placement, level-indicator and menu changes are not included in these numbers. The source-file hashes are saved in [source_manifest.json](performance/2026-09-08/source_manifest.json).

Hardware: AMD Ryzen 7 9700X, 8 reported logical processors, approximately 32 GB installed RAM, AMD Radeon RX 7800 XT. Windows 11 Pro 10.0.26200; discrete GPU driver 32.0.31041.1004. Godot 4.7.2 official desktop executable, OpenGL Compatibility renderer. These are development-executable results, not mobile release builds.

The sustained Infinite tests warm up for 30 simulated seconds and measure the next 15 seconds: 300 steps of 0.05 seconds per repeat. Every region uses maximum configured traffic. Defended fixtures use all eight tower families at level 4; the straight layouts deliberately create long routes. The compact layout contains 81 regions in a 9×9 grid. These are controlled load fixtures, not claims about typical player builds.

The rendered matrix freezes simulation, warms each view for 20 frames, then records 179 consecutive frame intervals. Frame-counter gaps were checked to be one rendered frame per interval. V-Sync and the frame cap are disabled for these diagnostics. CPU/GPU values come from Godot's viewport rendering timers; they can overlap and must not be added to total frame time. Viewport counters are reported as returned by Godot. Drawing-candidate counts include the renderer's 100-pixel margin.

The Campaign rendering stress fixture is level 20 with 500 manually distributed basic enemies and funded maximum-level defenses. It is intentionally separate from authored Campaign wave measurements. The `offscreen` key in the original matrix means a four-tile camera shift; in Infinite it still includes edge enemies. The supplemental `hidden` case moves twelve tiles and verifies zero enemy candidates.

The render harness issues an additional visibility query each frame to record candidate counts. This adds diagnostic work to the following interval; total frame timings include that work. They are useful controlled comparisons, while the separate normal-loop test avoids this query.

Tables use the median of repeated run means and the median of repeated per-run percentiles. The raw samples retain outliers. Other Godot sessions were active on this shared desktop: a recorded background process used about 86 CPU seconds during a 148-second interval. Only this audit's benchmarks were run serially; other tasks were preserved. Treat the timings as evidence for bottlenecks and relative priorities, not certified hardware limits.

## Sustained Infinite combat

{sim_table}

A 60 FPS frame has about 16.7 ms available for all work. Combat runs every 50 ms, but a long combat step still blocks a rendered frame. The largest defended fixture averages roughly 32 ms per step and has much longer spikes. At 2× playback, the same average workload would require more than one second of main-thread combat work per wall second, before rendering. This is a workload estimate, not a measured 2× device result.

The earlier short stress result was not a steady-state limit: it averaged the initial population ramp. Here, 81 undefended regions reach 3,202 live enemies at 45 simulated seconds. The longer measurement window explains much of the difference.

## Rendering is a major bottleneck in both modes

{render_table}

{ablations}

The marker experiment removes detailed enemy bodies and their per-enemy indicators, replacing each with one circle; tower drawing stays enabled. The actor-removal experiment omits both enemy and tower drawing. Map removal includes terrain and map decorations/controls such as portals and pads. Cosmetic removal clears only the transient `combat.effects` list; gameplay fields, traps and traveling projectiles retain their independent owners.

The fully hidden views measured {find_render('infinite', camera='hidden')['frame_ms']['mean']:.2f} ms per frame in Infinite and {find_render('campaign', camera='hidden')['frame_ms']['mean']:.2f} ms in Campaign, with zero enemy candidates in both. Existing visibility culling is effective when the battle is entirely outside the view. Removing transient cosmetics did not produce a clear improvement; the higher measured times do not establish that removing effects causes a slowdown because these supplements ran later on a shared machine.

Separate instrumented overview samples attributed about 17.6 ms to enemy drawing within 29.2 ms of total draw-script work in Infinite, and 23.6 ms within 29.4 ms in Campaign. These are inclusive, instrumented scripting times; do not add them to the uninstrumented frame measurements or GPU times.

These experiments are diagnostic ceilings, not implemented visual designs or promised speedups. Their savings overlap and cannot be added together. They show why camera culling alone is insufficient: the visible area can still issue thousands of small drawing commands. Godot's [GPU optimization guide](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html) explains the cost of many draw calls and the benefit of batching compatible drawing work.

## The strongest combat improvement: cached route lengths

The detailed 161-region profile spends about **{route_tick:.2f} ms per combat step** in `Targeting.distance_remaining()`. This function walks every remaining route segment whenever a target's distance cache is invalidated. Longer expansion routes make this more expensive even when a tower checks only nearby enemies.

For the 980-enemy defended snapshot, calculating every remaining distance took **{route_old:.2f} ms**. An isolated precomputed-suffix lookup took **{route_new:.2f} ms**, approximately **{route_old/route_new:.0f}× faster for that calculation**. Maximum observed difference was zero in both tested snapshots. This is not a whole-game speedup and has not been integrated into combat.

Store cumulative remaining lengths with each actual route and combine the cached suffix with the enemy's distance to its next point. Preserve existing routes when the world expands. Validate exact targeting order, ties, knockback, boss route changes and save restoration before adopting it.

Movement is the other large simulation cost. Resolving speeds for 3,202 enemies alone measured about {costs['undefended.all_enemy_speed_resolution']['ms']['mean']:.2f} ms per full pass. Cache immutable base values by content type and tuning revision, while retaining each enemy's live slow, stun, root and other modifier state. Follow the reusable content/component boundaries rather than putting special cases into individual enemy types.

Secondary measured costs include approximately {costs['defended.rebuild_enemy_index']['ms']['mean']:.2f} ms to rebuild the 980-enemy spatial index, {costs['defended.all_tower_stats']['ms']['mean']:.2f} ms to resolve all 80 tower stat dictionaries, and {costs['defended.all_tower_component_sync']['ms']['mean']:.2f} ms to synchronize those tower components. Reuse lookups and invalidate configuration caches on upgrades, equipment changes, live tuning and Campaign wave-rule changes.

## Interface, real-time playback and saving

{ui_table}

HUD refresh cost is small relative to crowded drawing. Suppressing refresh did not provide a clear frame-time improvement in these trials. Event-driven HUD layout is sensible cleanup, but it is not the first remedy for this lag. The UI diagnostic loop applies a fixed 60 Hz workload; its frame timings are service-cost measurements, not real-time gameplay FPS.

The following separate test uses the normal application `_process(delta)` loop, its 60 FPS cap, and real elapsed time. Infinite starts from the warmed compact world. Campaign plays level 30's final authored wave with the funded defense fixture. Audio processing remains active; only the test application's output bus is muted.

{live_table}

These are brief samples, not sustained thermal tests. The Campaign 1× sample spawned only one enemy during its five seconds; its 60 FPS result does not establish that every Campaign battle maintains 60 FPS. Authored-wave CPU coverage and the 500-enemy rendering stress test address different workloads. Fast playback should advance approximately 10 or 20 simulated seconds in five wall seconds; compare the measured simulation progress with that target.

The crowded Infinite 4× run advanced a median 14.35 simulated seconds in 5.12 wall seconds, around 2.8× effective progress, while rendering at about 5.5 FPS. This demonstrates simulation falling behind the requested speed in this fixture. The short test does not isolate every source of lost progress or predict sustained device behavior.

The copied local save averaged {costs['copied_local_save.tick']['ms']['mean']:.3f} ms per combat step. It is too small to reproduce the reported expanded-world lag.

Snapshot validation plus atomic local saving averaged {costs['undefended.save_snapshot_validation_write']['ms']['mean']:.2f} ms for the undefended 81-region fixture and {costs['defended.save_snapshot_validation_write']['ms']['mean']:.2f} ms with 80 towers. This can contribute occasional save-time hitches, but not the continuous drawing cost. A later improvement could serialize and write an immutable snapshot off the main thread while preserving validation, atomic replacement and shutdown guarantees.

## Campaign coverage and correctness

The existing reference strategies were attempted on all 30 levels. They lost on levels {', '.join(losses)} in this baseline; those results are retained rather than reported as successful playthroughs. To cover the omitted later waves, the separate performance sweep raises only the fixture's core health to 1,000,000, keeps the actual authored schedules, and uses the same purchasing strategy. It measured **{completed}/{authored} waves**. Its completion is not a balance or player-victory assertion.

{campaign_table}

The six watching/away/moving camera cases matched for both modes, including live enemy positions and health, pending shots, tower earnings, kills, escapes and balances; Campaign health and phase were also included. Full rendering, a hidden battlefield and suppressed HUD refresh produced the same state in the application fixtures. Stable-content fingerprints across the baseline, coarse profiler and detailed profiler {'matched' if equivalent else 'DID NOT MATCH'} for the 81-region, 80-tower, 900-step validation case.

## Recommended implementation order

1. **Reduce the drawing commands needed for the existing art.** Bake reusable enemy/tower body artwork into textures or cached meshes and cache static terrain chunks as rendered images where appropriate. Preserve the current silhouettes, colors and outlines; keep dynamic attacks and status indicators separate. Use shared render owners for both modes, and invalidate terrain caches when their appearance changes. Budget texture memory and verify zoom quality. Grouping compatible sprites or region-local instance batches is worth testing; Godot documents the visibility tradeoff of [MultiMesh batching](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html).
2. **Replace repeated full-route distance walks with cached cumulative route lengths.** This is the strongest directly isolated combat opportunity and should particularly help expanded Infinite worlds and attack-time spikes.
3. **Reduce per-enemy speed/configuration work.** Cache immutable resolved values, keep runtime status state local to each enemy, and avoid checking inactive effect families unnecessarily. Continue simulating offscreen movement and combat on the same authoritative clock.
4. **Reuse shared lookup tables and tower configuration.** Avoid rebuilding multiple enemy-ID maps in one step; maintain or efficiently rebuild spatial buckets, preserving deterministic ordering. Cache tower stats and component configuration with explicit invalidation.
5. **Address smaller recurring costs after the above.** Refresh HUD layout on changes, cache unchanged camera bounds, and smooth save-time work. Retain the existing bounded cosmetic pool. The current measurements do not justify replacing exact offscreen battles with estimated income.

Threading or scheduled fast-forward of uneventful travel can be evaluated if these changes still miss the device budget. They introduce ordering and event-boundary complexity, so they should follow the lower-risk measured opportunities. Keep cross-tile attacks, projectile travel, status ticks and rewards authoritative.

## Remaining acceptance work

Connect an Android phone with USB debugging and provide an accessible Mac/iPhone profiling setup. On each device, run the same saved fixtures in a release build, record CPU/GPU frame times and p95/p99 stalls at normal and faster playback, pan and zoom in upright portrait, and repeat after sustained play to expose thermal throttling. Record device model, OS, resolution and power mode. These measurements have not been performed.

After implementing optimizations, repeat the same desktop and device workloads and require unchanged seeded combat outcomes. A useful acceptance target is p95 frame time within the chosen 60 FPS or 30 FPS budget on the weakest supported device, with no sustained simulation lag. That is a target to verify, not a result of this audit.

## Evidence and reproducibility

- [Aggregated measurements](performance/2026-09-08/summary.json), [raw combat samples](performance/2026-09-08/baseline_simulation.json), [render matrix](performance/2026-09-08/baseline_render_verified.json), [hidden/cosmetic supplement](performance/2026-09-08/baseline_visibility.json).
- [Detailed combat attribution](performance/2026-09-08/detailed_deep.json), [isolated calculation costs](performance/2026-09-08/baseline_costs.json), [UI measurements](performance/2026-09-08/baseline_ui.json), [normal-loop measurements](performance/2026-09-08/baseline_live.json).
- [Campaign reference attempts](performance/2026-09-08/baseline_campaign.json), [all-wave sweep](performance/2026-09-08/baseline_campaign_all_waves.json), [camera comparisons](performance/2026-09-08/baseline_camera.json).
- Runners: `tests/performance/`. Orchestration: `tools/performance_audit.py`. Aggregation and charts: `tools/summarize_performance_audit.py`. Production game scripts are changed only inside ignored profiling snapshots by the instrumentation tool.

Use Python 3 to run `tools/performance_audit.py prepare`, then `run baseline render --tag _verified`, `run baseline simulation`, `run instrumented simulation`, `batch`, and `completion`. Finally run `tools/summarize_performance_audit.py`. Set `GODOT_PATH` if needed. A different source revision needs a separate snapshot directory; the tool rejects reusing an archive from another commit. Saves and credentials are not copied into the public report.

The chart generator requires `matplotlib`. For the additional playback runs, set `PERF_PLAYBACK=2` and run `tools/performance_audit.py run baseline live --tag _2x`, then repeat with `PERF_PLAYBACK=4` and tag `_4x`. Unset the variable before normal-speed runs. The corresponding [2× raw samples](performance/2026-09-08/baseline_live_2x.json) and [4× raw samples](performance/2026-09-08/baseline_live_4x.json) retain elapsed time, simulation progress and enemy counts.

One early rendering attempt was discarded while checking sampling. The main matrix later hit a typed-array assignment error only in its six cosmetic-removal cases; those cases were rerun after correcting the harness and are supplied by the supplement. The other 90 matrix cases completed. Initial raw state hashes encoded process-local content-object IDs; separate cross-process validation now uses stable content identities. These were measurement-harness corrections, not production gameplay fixes. All resulting comparisons and limitations are reported explicitly.
'''
    (ROOT/'docs/PERFORMANCE_AUDIT_2026-09-08.md').write_text(report, encoding='utf-8')
    import csv
    with (DATA/'campaign_all_waves.csv').open('w', newline='', encoding='utf-8') as output:
        writer = csv.writer(output)
        writer.writerow(['level','name','waves_completed','waves_total','peak_enemies','mean_tick_ms','p95_tick_ms'])
        for r in all_waves: writer.writerow([r['level'],r['name'],r['waves_completed'],r['waves_total'],r['peak_enemies'],r['tick_ms']['mean'],r['tick_ms']['p95']])


if __name__ == '__main__': main()
