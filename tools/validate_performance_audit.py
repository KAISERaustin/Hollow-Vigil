"""Verify the completed audit's coverage and recorded correctness checks."""
import json
from pathlib import Path

DATA = Path(__file__).resolve().parents[1] / 'docs/performance/2026-09-08'


def read(name):
    return json.loads((DATA / name).read_text(encoding='utf-8'))


def main():
    s = read('summary.json')
    assert len(s['simulation']) == 6
    assert all(r['repeats'] == 3 and r['repeat_checksums_match'] and r['instrumentation_counts_match'] for r in s['simulation'])
    assert len(s['render']) == 34 and all(r['repeats'] == 3 for r in s['render'])
    for name in ['baseline_render_verified.json', 'baseline_visibility.json']:
        for r in read(name)['rows']:
            assert len(r['samples_ms']) == 179
            assert r['drawn_frame_gaps']['mean'] == 1 and r['drawn_frame_gaps']['max'] == 1
            assert r['before'] == r['after']
            if r['camera'] == 'hidden': assert r['visible_enemies']['max'] == 0
    assert len(s['campaign_all_waves']) == 30
    assert all(r['waves_completed'] == r['waves_total'] for r in s['campaign_all_waves'])
    assert sum(r['waves_completed'] for r in s['campaign_all_waves']) == 144
    assert s['camera']['failures'] == 0 and len(s['camera']['rows']) == 6
    assert all(r['matches'] for r in s['camera']['rows'])
    assert len({v['checksum'] for v in s['fingerprints'].values()}) == 1
    ui = read('baseline_ui.json')['rows']
    for mode in ['infinite', 'campaign']:
        members = [r for r in ui if r['mode'] == mode and r['variant'] != 'no_simulation']
        assert len(members) == 9 and len({r['checksum'] for r in members}) == 1
    assert len(s['live']) == 6 and all(r['repeats'] == 3 for r in s['live'])
    assert read('source_manifest.json')['commit'] == 'c5a0b284c74ad55cce6ca375bd14afc9e82fb0a2'
    print('PASS: 18 combat trials, 102 frozen render trials, 144 Campaign waves, '
          'camera/UI equivalence, profiler fingerprints, and 18 live playback trials.')


if __name__ == '__main__': main()
