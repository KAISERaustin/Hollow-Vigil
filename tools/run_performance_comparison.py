"""Run the combined change only after strict cross-revision state comparison."""
import json
import sys

import performance_compare as compare


def equivalent(before_name, after_name, suffix=''):
    first = json.loads((compare.RESULTS / f'{before_name}_behavior{suffix}.json').read_text())
    second = json.loads((compare.RESULTS / f'{after_name}_behavior{suffix}.json').read_text())
    differences = []
    for before, after in zip(first['rows'], second['rows'], strict=True):
        keys = ['checkpoints'] if 'checkpoints' in before else ['checksum']
        if any(before[key] != after[key] for key in keys):
            differences.append({'mode': before['mode'], 'camera': before.get('camera', 'restored')})
    result = {'before': before_name, 'after': after_name, 'differences': differences,
              'within_run_failures': [first['failures'], second['failures']]}
    (compare.RESULTS / f'{after_name}_equivalence{suffix}.json').write_text(json.dumps(result, indent=2))
    print('STATE EQUIVALENCE', result, flush=True)
    if differences or first['failures'] or second['failures']:
        raise SystemExit('Authoritative state mismatch; investigate before measuring.')


if __name__ == '__main__':
    name = sys.argv[1]
    if not (compare.BASE / name).exists(): compare.prepare(name, working=True)
    compare.run('before', ['behavior', 'costs_memory', 'hud_costs'])
    compare.run(name, ['import', 'behavior'])
    equivalent('before', name)
    compare.run(name, ['simulation', 'costs', 'render', 'live_1', 'live_2', 'live_4',
                       'campaign_all_waves', 'camera', 'hud_costs', 'terrain_candidate', 'behavior_rendered'])
