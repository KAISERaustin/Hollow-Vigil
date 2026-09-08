"""Isolated before/after runs using the September 8 audit fixtures.

Snapshots contain tracked source (or the current working files with --working).
Original audit results are never overwritten. Benchmarks run serially.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

import performance_audit as audit

BASE = audit.ROOT / '.runtime/performance-implementation-20260908'
RESULTS = audit.ROOT / 'docs/performance/2026-09-08-implementation'


def prepare(name, working):
    dest = BASE / name
    if dest.exists():
        raise SystemExit(f'Snapshot already exists: {dest}; choose a new name.')
    BASE.mkdir(parents=True, exist_ok=True)
    RESULTS.mkdir(parents=True, exist_ok=True)
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=audit.ROOT, text=True).strip()
    archive = BASE / f'{name}.zip'
    subprocess.run(['git', 'archive', 'HEAD', '--format=zip', '-o', str(archive)], cwd=audit.ROOT, check=True)
    with zipfile.ZipFile(archive) as source:
        source.extractall(dest)
    if working:
        paths = subprocess.check_output(['git', 'ls-files', '-co', '--exclude-standard', '-z'], cwd=audit.ROOT).decode().split('\0')
        for relative in set(paths):
            if not relative or relative.startswith('docs/performance/'):
                continue
            src = audit.ROOT / relative
            target = dest / relative
            if src.is_file():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, target)
            elif target.is_file():
                target.unlink()
    manifest = {str(p.relative_to(dest)): hashlib.sha256(p.read_bytes()).hexdigest()
                for folder in ['scripts', 'tests/performance'] for p in (dest / folder).rglob('*.gd')}
    (RESULTS / f'{name}_source.json').write_text(json.dumps({'commit': revision, 'working': working, 'sha256': manifest}, indent=2))
    print(f'Prepared {name}: {revision}, working={working}', flush=True)


def run(name, suites):
    audit.WORK = BASE
    audit.RESULTS = RESULTS
    # These are production-cost comparisons, with no instrumentation wrappers.
    os.environ['PERF_INSTRUMENTED'] = '0'
    for suite in suites:
        tag = ''
        os.environ.pop('PERF_RENDER_CAMERA', None)
        if suite == 'behavior_rendered':
            os.environ['PERF_RENDER_CAMERA'] = '1'
            suite, tag = 'behavior', '_rendered'
        if suite == 'costs_memory':
            suite, tag = 'costs', '_memory'
        if suite == 'campaign_all_waves':
            suite, tag = 'campaign', '_all_waves'
        if suite.startswith('live_'):
            os.environ['PERF_PLAYBACK'] = suite[-1]
            suite, tag = 'live', '_' + suite[-1] + 'x'
        else:
            os.environ.pop('PERF_PLAYBACK', None)
        audit.run(name, suite, tag, instrumented=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare', 'run'])
    parser.add_argument('name')
    parser.add_argument('suites', nargs='*')
    parser.add_argument('--working', action='store_true')
    args = parser.parse_args()
    if args.action == 'prepare':
        prepare(args.name, args.working)
    else:
        run(args.name, args.suites)
