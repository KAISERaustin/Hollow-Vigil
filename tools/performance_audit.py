"""Prepare isolated, reproducible performance snapshots; production scripts stay untouched.

Usage: python tools/performance_audit.py prepare [--revision COMMIT]
       python tools/performance_audit.py run baseline simulation
       python tools/performance_audit.py run instrumented render
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile
import ctypes

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / '.runtime/performance-audit-20260908'
RESULTS = ROOT / 'docs/performance/2026-09-08'
GODOT = Path(os.environ.get('GODOT_PATH', str(Path.home() / 'Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe')))


def wrap(text, name, label):
    pattern = re.compile(r'^(static )?func ' + re.escape(name) + r'\((.*)\)(\s*->\s*[^:]+)?:\s*$', re.M)
    match = pattern.search(text)
    if not match:
        raise ValueError(f'Missing single-line function {name}')
    static, params, returns = match.groups()
    args, depth, current = [], 0, ''
    for char in params + ',':
        if char in '([{': depth += 1
        if char in ')]}': depth -= 1
        if char == ',' and depth == 0:
            if current.strip(): args.append(re.split(r'[:=]', current)[0].strip())
            current = ''
        else: current += char
    call = f'_perf_original_{name}({", ".join(args)})'
    body = '\n\tvar perf_started := Time.get_ticks_usec()\n'
    if returns and 'void' in returns:
        body += f'\t{call}\n\t_Perf.record("{label}", Time.get_ticks_usec() - perf_started)\n'
    else:
        body += f'\tvar perf_result = {call}\n\t_Perf.record("{label}", Time.get_ticks_usec() - perf_started)\n\treturn perf_result\n'
    wrapper = match.group(0) + body + '\n' + match.group(0).replace('func ' + name, 'func _perf_original_' + name)
    return text[:match.start()] + wrapper + text[match.end():]


def instrument(directory):
    owners = {
        'scripts/rendering/battlefield.gd': ['_draw', 'draw_map', 'draw_enemy', 'draw_tower', '_process', 'enforce_camera_limits'],
        'scripts/rendering/terrain/terrain_layer.gd': ['synchronize'],
        'scripts/campaign/board.gd': ['draw_map'],
        'scripts/campaign/screen.gd': ['refresh'],
        'scripts/app/main.gd': ['update_hud'],
        'scripts/ui/shared/floating_game_hud.gd': ['fit'],
    }
    if directory.name == 'detailed':
        owners.update({
            'scripts/gameplay/balance.gd': ['tower_stats', 'tuned_value'],
            'scripts/gameplay/combat/targeting.gd': ['distance_remaining', 'select_target'],
            'scripts/gameplay/combat/road_traps.gd': ['positions'],
            'scripts/gameplay/combat/line_projectiles.gd': ['aim_point'],
            'scripts/gameplay/combat/tower_components.gd': ['snapshot', 'ensure'],
            'scripts/gameplay/combat/enemy_index.gd': ['query_rect'],
        })
    for path, funcs in owners.items():
        target = directory / path
        source = (WORK / 'baseline' / path).read_text(encoding='utf-8')
        # Constants can be declared after class_name/extends; append at EOF.
        if path != 'scripts/campaign/board.gd':
            source += '\nconst _Perf = preload("res://tests/performance/probe.gd")\n'
        for func in funcs: source = wrap(source, func, f'{path}:{func}')
        target.write_text(source, encoding='utf-8')
    target = directory / 'scripts/gameplay/combat/combat.gd'
    source = (WORK / 'baseline/scripts/gameplay/combat/combat.gd').read_text(encoding='utf-8')
    start, end = source.index('func tick('), source.index('\nfunc launch_shot(')
    tick = source[start:end]
    boundaries = [
        ('\tadvance_effects(delta)', 'cosmetic_aging'),
        ('\tTowerComponents.sync(self)', 'component_sync'),
        ('\tfor r in data.regions.values():', 'portal_spawning'),
        ('\tBosses.advance(self, delta)', 'bosses_and_relic_status'),
        ('\tfor e in enemies:', 'movement'),
        ('\trebuild_enemy_index()', 'index_rebuild'),
        ('\tticking = true', 'distance_cache_reset'),
        ('\tEffectFields.advance(self, delta)', 'effect_fields'),
        ('\tTowerComponents.advance(self, delta)', 'components_projectiles_traps'),
        ('\tadvance_shots(delta)', 'projectile_arrivals'),
        ('\tadvance_fire(delta)', 'burning_ground'),
        ('\tvar live_targets := {}', 'target_map_and_locks'),
        ('\tfor t in data.towers.values():', 'tower_attacks'),
        ('\trecycle_dead_enemies()', 'recycle_and_effect_follow'),
        ('\twhile not income_events.is_empty()', 'income_and_collection'),
    ]
    # First occurrence of each boundary is intentional (movement precedes cache reset).
    positions = [(tick.index(needle), label) for needle, label in boundaries]
    positions.sort()
    additions = []
    for i, (pos, label) in enumerate(positions):
        if i == 0: insertion = '\tvar perf_mark := Time.get_ticks_usec()\n'
        else:
            previous = positions[i-1][1]
            insertion = f'\t_Perf.record("tick.{previous}", Time.get_ticks_usec() - perf_mark)\n\tperf_mark = Time.get_ticks_usec()\n'
        additions.append((pos, insertion))
    for pos, insertion in reversed(additions): tick = tick[:pos] + insertion + tick[pos:]
    tick = tick.rstrip() + f'\n\t_Perf.record("tick.{positions[-1][1]}", Time.get_ticks_usec() - perf_mark)\n'
    source = source[:start] + tick + source[end:] + '\nconst _Perf = preload("res://tests/performance/probe.gd")\n'
    target.write_text(source, encoding='utf-8')


def prepare(revision):
    WORK.mkdir(parents=True, exist_ok=True)
    RESULTS.mkdir(parents=True, exist_ok=True)
    resolved = subprocess.check_output(['git', 'rev-parse', revision], cwd=ROOT, text=True).strip()
    archive = WORK / 'source.zip'
    if archive.exists():
        with zipfile.ZipFile(archive) as z:
            if z.comment.decode('ascii').strip() != resolved:
                raise SystemExit('Existing audit snapshot uses another commit. Choose a separate audit directory to preserve it.')
    if not (WORK / 'baseline').exists():
        subprocess.run(['git', 'archive', resolved, '--format=zip', '-o', str(archive)], cwd=ROOT, check=True)
        with zipfile.ZipFile(archive) as z: z.extractall(WORK / 'baseline')
    for name in ['baseline', 'instrumented', 'detailed']:
        dest = WORK / name
        if not dest.exists():
            with zipfile.ZipFile(archive) as z: z.extractall(dest)
        shutil.copytree(ROOT / 'tests/performance', dest / 'tests/performance', dirs_exist_ok=True)
    instrument(WORK / 'instrumented')
    instrument(WORK / 'detailed')
    manifest = {str(p.relative_to(WORK/'baseline')): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (WORK/'baseline/scripts').rglob('*.gd')}
    (RESULTS/'source_manifest.json').write_text(json.dumps({'commit': resolved, 'sha256': manifest}, indent=2), encoding='utf-8')
    print(f'Prepared {resolved} at {WORK}', flush=True)


def run(name, suite, tag, instrumented=None):
    dest = WORK / name
    shutil.copytree(ROOT / 'tests/performance', dest / 'tests/performance', dirs_exist_ok=True)
    env = os.environ.copy()
    env['APPDATA'] = str(WORK/'userdata'/name/'Roaming')
    env['LOCALAPPDATA'] = str(WORK/'userdata'/name/'Local')
    Path(env['APPDATA']).mkdir(parents=True, exist_ok=True)
    Path(env['LOCALAPPDATA']).mkdir(parents=True, exist_ok=True)
    env['PERF_OUTPUT'] = str(RESULTS/f'{name}_{suite}{tag}.json')
    capture = RESULTS if instrumented is None else RESULTS / name
    capture.mkdir(parents=True, exist_ok=True)
    env['PERF_CAPTURE'] = str(capture)
    env['PERF_INSTRUMENTED'] = str(int(name != 'baseline' if instrumented is None else instrumented))
    env['PERF_SAVE_INPUT'] = str(WORK / 'vigil.save')
    env['PERF_SURVIVAL_GUARD'] = '1' if tag == '_all_waves' else '0'
    run_manifest = {str(p.relative_to(dest)): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in (dest/'tests/performance').glob('*.gd')}
    (RESULTS/f'{name}_{suite}{tag}_harness.json').write_text(json.dumps(run_manifest, indent=2), encoding='utf-8')
    command = [str(GODOT), '--path', str(dest)]
    if suite not in ['render', 'ui', 'visibility', 'live']: command += ['--headless']
    else: command += ['--resolution', '390x844', '--disable-vsync']
    if suite == 'import': command += ['--editor', '--import']
    else: command += ['--script', f'res://tests/performance/{suite}_runner.gd']
    log = WORK/f'{name}_{suite}{tag}.log'
    with log.open('w', encoding='utf-8') as output:
        process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace')
        for line in process.stdout:
            output.write(line)
            output.flush()
            if not line.startswith('[ '): print(line.rstrip(), flush=True)
        status = process.wait()
    errors = re.findall(r'^(?:SCRIPT ERROR:|Parse Error:|ERROR:(?! Failed to read the root certificate store\.)).*', log.read_text(encoding='utf-8'), re.M)
    if status or errors: raise SystemExit(f'Benchmark failed: exit={status}, errors={errors[:8]} (see {log})')


def wait_for_process(pid):
    if not pid: return
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenProcess.restype = ctypes.c_void_p
    kernel.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
    kernel.CloseHandle.argtypes = [ctypes.c_void_p]
    handle = kernel.OpenProcess(0x00100000, False, pid)
    if handle:
        print(f'Waiting for audit process {pid} before serial benchmarks.', flush=True)
        while kernel.WaitForSingleObject(handle, 60000) == 258:
            print('Rendered benchmark still running; remaining suites stay queued.', flush=True)
        kernel.CloseHandle(handle)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare', 'run', 'batch', 'completion'])
    parser.add_argument('name', nargs='?', default='baseline')
    parser.add_argument('suite', nargs='?', default='simulation')
    parser.add_argument('--revision', default='c5a0b28')
    parser.add_argument('--tag', default='')
    parser.add_argument('--wait-pid', type=int)
    args = parser.parse_args()
    if args.action == 'prepare': prepare(args.revision)
    elif args.action == 'run': run(args.name, args.suite, args.tag)
    elif args.action == 'completion':
        wait_for_process(args.wait_pid)
        for name, suite, tag in [('baseline','campaign','_all_waves'), ('baseline','visibility',''), ('baseline','live',''),
                                  ('baseline','fingerprint',''), ('instrumented','fingerprint',''), ('detailed','fingerprint','')]:
            print(f'START {name} {suite} {tag}', flush=True)
            run(name, suite, tag)
    else:
        wait_for_process(args.wait_pid)
        for name, suite in [('baseline', 'campaign'), ('detailed', 'import'), ('detailed', 'deep'),
                            ('baseline', 'costs'), ('baseline', 'camera'), ('baseline', 'ui'), ('instrumented', 'render')]:
            print(f'START {name} {suite}', flush=True)
            run(name, suite, '')
