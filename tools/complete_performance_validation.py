"""Finish serial ablations, long-run checks and regression validation."""
import json
import time

import performance_compare as compare
import performance_variants as variants
from run_performance_comparison import equivalent
from validate_performance_changes import godot


if __name__ == '__main__':
    while not (compare.RESULTS / 'after_live_sustained_4x.json').exists():
        time.sleep(10)
    for name, suites in [
        ('artwork', ['import', 'behavior', 'render_overview']),
        ('route', ['import', 'behavior', 'simulation', 'costs']),
        ('configuration', ['import', 'behavior', 'simulation', 'costs']),
        ('interface', ['import', 'behavior', 'hud_costs']),
    ]:
        if not (compare.BASE / name).exists(): variants.prepare(name, name)
        compare.run(name, suites[:2])
        equivalent('before', name)
        compare.run(name, suites[2:])
    compare.run('before', ['behavior_rendered', 'sustained'])
    equivalent('before', 'after', '_rendered')
    for script in ['tests/performance_optimization_runner.gd', 'tests/test_runner.gd',
                   'tests/rendered/actor_images_runner.gd', 'tests/rendered/tower_depth_runner.gd',
                   'tests/rendered/campaign_hud_runner.gd', 'tests/rendered/branch_visual_runner.gd']:
        godot(script, rendered=script.startswith('tests/rendered/'))
    (compare.RESULTS / 'validation_complete.json').write_text(json.dumps({'complete': True, 'suites': 6}, indent=2))
