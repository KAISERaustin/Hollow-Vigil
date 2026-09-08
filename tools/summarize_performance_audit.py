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
        'live': grouped(load('baseline_live.json').get('rows', []), ['mode'], ['frame_ms']),
        'fingerprints': {name: load(f'{name}_fingerprint.json') for name in ['baseline','instrumented','detailed']},
    }
    (DATA/'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(json.dumps({key:len(value) for key,value in summary.items() if isinstance(value,list)}, indent=2))
    if not simulations or not summary['render']: return
    import matplotlib
    matplotlib.use('Agg')
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
    fig.savefig(DATA/'performance_summary.svg')
    plt.close(fig)


if __name__ == '__main__': main()
