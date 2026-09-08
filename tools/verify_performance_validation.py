"""Publish clean-log verification, including failures Godot exit codes can miss."""
import hashlib
import json
import re

from performance_compare import BASE, RESULTS


expected = {
    'performance_optimization_runner': r'PERFORMANCE OPTIMIZATION: (\d+) checks, 0 failures',
    'test_runner': r'RESULT: (\d+) checks, 0 failures',
    'actor_images_runner': r'ACTOR IMAGES: (\d+) individual images, 0 failures',
    'tower_depth_runner': r'TOWER_DEPTH: (\d+) checks, 0 failures',
    'campaign_hud_runner': r'CAMPAIGN HUD: (\d+) checks, 0 failures',
    'branch_visual_runner': r'BRANCH VISUAL: \[\]',
    'ground_build_runner': r'GROUND BUILD TOUCH: (\d+) checks, 0 failures',
    'tower_management_runner': r'TOWER MANAGEMENT: (\d+) checks, 0 failures',
}

rows = []
for name, pattern in expected.items():
    path = BASE / ('validation_' + name + '.log')
    contents = path.read_text(encoding='utf-8')
    match = re.search(pattern, contents)
    errors = re.findall(r'^(?:SCRIPT ERROR:|Parse Error:|ERROR:(?! Failed to read the root certificate store\.)).*', contents, re.M)
    if not match or errors: raise SystemExit(f'Incomplete or failed validation: {name}: {errors[:3]}')
    rows.append({'suite': name, 'summary': match[0], 'errors': errors,
                 'warnings': re.findall(r'^WARNING:.*', contents, re.M),
                 'log_sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
(RESULTS/'validation_complete.json').write_text(json.dumps({'complete': True, 'suites': rows}, indent=2))
print('Eight validation suites have clean error scans.', flush=True)
