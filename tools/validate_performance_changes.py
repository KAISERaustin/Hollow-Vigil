"""Serial local validation, with optional wait for the original comparison run."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import time

import performance_audit as audit
from performance_compare import BASE, RESULTS


def godot(script, rendered=False, import_assets=False):
    env = os.environ.copy()
    for key, folder in [('APPDATA', 'Roaming'), ('LOCALAPPDATA', 'Local')]:
        env[key] = str(BASE / 'validation-userdata' / folder)
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    command = [str(audit.GODOT), '--path', str(audit.ROOT)]
    if not rendered:
        command.append('--headless')
    if import_assets:
        command += ['--editor', '--import']
    else:
        command += ['--script', 'res://' + script]
    log = BASE / ('validation_' + Path(script).stem + '.log')
    with log.open('w', encoding='utf-8') as output:
        process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace')
        for line in process.stdout:
            output.write(line)
            output.flush()
            if not line.startswith('[ '): print(line.rstrip(), flush=True)
        status = process.wait()
    errors = re.findall(r'^(?:SCRIPT ERROR:|Parse Error:|ERROR:(?! Failed to read the root certificate store\.)).*', log.read_text(encoding='utf-8'), re.M)
    if status or errors:
        raise SystemExit(f'Validation failed: {script}, exit={status}, {errors[:5]}; {log}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--wait-baseline', action='store_true')
    parser.add_argument('--bake', action='store_true')
    parser.add_argument('scripts', nargs='*')
    args = parser.parse_args()
    if args.wait_baseline:
        while not (RESULTS / 'before_camera.json').exists():
            time.sleep(5)
    if args.bake:
        godot('tools/bake_actor_images.gd', rendered=True)
        godot('import', import_assets=True)
    for script in args.scripts:
        godot(script, rendered=script.startswith('tests/rendered/'))
