"""Release-template benchmarks in a separate Android package and save sandbox.

Builds immutable before/after source copies. The generated SceneTree combines
the existing runners; only startup, report transport and device-size handling
differ. Results use logcat so the release APK need not be debuggable or rooted.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

import performance_audit as audit
from performance_compare import BASE, RESULTS

ADB = Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe'
JAVA = Path('C:/Program Files/Android/Android Studio/jbr/bin')
PACKAGE = 'com.kaiser.hollowvigil.performance'


def adb(*args, **kwargs):
    return subprocess.check_output([str(ADB), *args], **kwargs)


def package_pid():
    return subprocess.run([str(ADB), 'shell', 'pidof', PACKAGE], capture_output=True, text=True).stdout.strip()


def build(name):
    source = BASE / name
    dest = BASE / ('android_' + name)
    if not dest.exists():
        shutil.copytree(source, dest, ignore=shutil.ignore_patterns('.godot', 'docs', '.runtime', 'exports'))
    shutil.copytree(audit.ROOT / 'tests/performance', dest / 'tests/performance', dirs_exist_ok=True)
    (dest / 'tests/support').mkdir(exist_ok=True)
    shutil.copy2(audit.ROOT / 'tests/support/timeout.gd', dest / 'tests/support/timeout.gd')
    top = ['class_name VigilMobileBenchmark', 'extends SceneTree']
    bodies = []
    for suite in ['render', 'live', 'behavior']:
        text = (dest / f'tests/performance/{suite}_runner.gd').read_text(encoding='utf-8')
        declarations, body = text.split('func _initialize()', 1)
        for line in declarations.splitlines():
            if line and not line.startswith('extends ') and line not in top:
                top.append(line)
        body = body[body.index('\nfunc ') + 1:]
        body = body.replace('func run() -> void:', f'func run_{suite}() -> void:')
        body = re.sub(r'^\tquit\([^\n]*\)', '\treturn', body, flags=re.M)
        # The tablet's physical render surface stays native upright portrait.
        # A 390x844 logical canvas makes the crowded fixture comparable.
        body = re.sub(r'^\s*root.size = .*$', '', body, flags=re.M)
        body = body.replace('root.content_scale_size = root.size', 'root.content_scale_size = Vector2i(390,844)')
        bodies.append(body)
    bootstrap = '''
func _initialize() -> void:
    call_deferred("mobile_run")

func emit_report(suite: String) -> void:
    var report = JSON.parse_string(FileAccess.get_file_as_string("user://mobile-report.json"))
    if report == null:
        push_error("Missing mobile report " + suite)
        quit(1)
        return
    for row in report.rows:
        # Full authoritative snapshots are in desktop evidence; the same
        # cryptographic state digest is compared between Android releases.
        row.erase("state")
    var payload := JSON.stringify({"suite": suite, "report": report})
    for offset in range(0, payload.length(), 1800):
        print("HV_PERF_CHUNK ", suite, " ", offset, " ", payload.substr(offset, 1800))
    print("HV_PERF_END ", suite)

func mobile_run() -> void:
    Engine.max_fps = 0
    OS.set_environment("PERF_OUTPUT", "user://mobile-report.json")
    OS.set_environment("PERF_CAPTURE", "user://")
    OS.set_environment("PERF_INSTRUMENTED", "0")
    OS.set_environment("PERF_OVERVIEW_ONLY", "1")
    print("HV_PERF_ENV ", JSON.stringify({"engine": Engine.get_version_info(),
        "adapter": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
        "physical_viewport": [root.size.x, root.size.y], "template_debug": OS.is_debug_build()}))
    await run_render()
    emit_report("render")
    OS.set_environment("PERF_DURATION", "10")
    OS.set_environment("PERF_REPEATS", "1")
    for playback in ["1", "2", "4"]:
        OS.set_environment("PERF_PLAYBACK", playback)
        await run_live()
        emit_report("live_" + playback)
    OS.set_environment("PERF_DURATION", "180")
    OS.set_environment("PERF_MODE", "infinite")
    await run_live()
    emit_report("sustained_4x")
    OS.set_environment("PERF_RENDER_CAMERA", "1")
    await run_behavior()
    emit_report("behavior")
    print("HV_PERF_DONE ", failures)
    quit(1 if failures else 0)
'''
    runner = '\n'.join(top) + '\n\n' + '\n'.join(bodies) + bootstrap
    (dest / 'tests/performance/mobile_runner.gd').write_text(runner, encoding='utf-8')
    settings = (dest / 'project.godot').read_text(encoding='utf-8')
    settings = settings.replace('run/main_scene="res://scenes/main.tscn"', 'run/main_loop_type="VigilMobileBenchmark"')
    (dest / 'project.godot').write_text(settings, encoding='utf-8')
    profile = BASE / 'android-export-profile'
    (profile / 'Godot').mkdir(parents=True, exist_ok=True)
    sdk = (Path.home() / 'AppData/Local/Android/Sdk').as_posix()
    (profile / 'Godot/editor_settings-4.7.tres').write_text(
        '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
        f'export/android/android_sdk_path = "{sdk}"\nexport/android/java_sdk_path = "{JAVA.parent.as_posix()}"\n')
    key = profile / 'benchmark.keystore'
    if not key.exists():
        subprocess.run([str(JAVA/'keytool.exe'), '-genkeypair', '-keystore', str(key), '-storepass', 'benchmark',
                        '-alias', 'benchmark', '-keypass', 'benchmark', '-dname', 'CN=Local Benchmark',
                        '-keyalg', 'RSA', '-keysize', '2048', '-validity', '3650'], check=True, capture_output=True)
    template = audit.ROOT / 'exports/android-tools/android_release.apk'
    apk = BASE / f'android_{name}.apk'
    preset = f'''[preset.0]
name="Android Performance"
platform="Android"
runnable=true
export_filter="all_resources"
include_filter="assets/artwork/catalog.json,assets/fonts/*-OFL.txt"
exclude_filter="docs/*,artifacts/*,exports/*,tools/*,supabase/*,.runtime/*,*.md"
export_path="{apk.as_posix()}"
script_export_mode=2

[preset.0.options]
custom_template/release="{template.as_posix()}"
gradle_build/use_gradle_build=false
gradle_build/export_format=0
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="performance-{name}"
package/unique_name="{PACKAGE}"
package/name="Hollow Vigil Performance"
package/signed=true
keystore/release="{key.as_posix()}"
keystore/release_user="benchmark"
keystore/release_password="benchmark"
screen/immersive_mode=true
permissions/internet=false
'''
    (dest / 'export_presets.cfg').write_text(preset, encoding='utf-8')
    env = os.environ.copy()
    env['APPDATA'] = str(profile)
    log = BASE / f'android_{name}_export.log'
    with log.open('w', encoding='utf-8') as output:
        result = subprocess.run([str(audit.GODOT), '--headless', '--path', str(dest), '--editor', '--import'],
                                env=env, stdout=output, stderr=subprocess.STDOUT)
        if result.returncode: raise SystemExit(f'Import failed: {log}')
        result = subprocess.run([str(audit.GODOT), '--headless', '--path', str(dest), '--export-release', 'Android Performance', str(apk)],
                                env=env, stdout=output, stderr=subprocess.STDOUT)
    errors = re.findall(r'^(?:SCRIPT ERROR:|ERROR:(?! Failed to read the root certificate store\.)).*', log.read_text(encoding='utf-8'), re.M)
    if result.returncode or errors: raise SystemExit(f'Export failed: {errors[:8]}; {log}')
    (RESULTS / f'android_{name}_build.json').write_text(json.dumps({
        'source': name, 'package': PACKAGE, 'apk_sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
        'release_template_sha256': hashlib.sha256(template.read_bytes()).hexdigest(),
        'harness_sha256': hashlib.sha256(runner.encode()).hexdigest(),
        'production_sha256': {str(p.relative_to(dest)): hashlib.sha256(p.read_bytes()).hexdigest() for p in (dest/'scripts').rglob('*.gd')},
        'release_template': True, 'network_permission': False,
    }, indent=2))
    print(f'Built release-template benchmark: {apk}', flush=True)


def run(name):
    apk = BASE / f'android_{name}.apk'
    print(adb('install', '-r', str(apk)).decode(), flush=True)
    # Stop only our separate benchmark package; preserve application data.
    adb('shell', 'am', 'force-stop', PACKAGE)
    timestamp = adb('shell', 'date', '+%m-%d %H:%M:%S.000').decode().strip()
    components = adb('shell', 'cmd', 'package', 'resolve-activity', '--brief', PACKAGE).decode().strip().splitlines()
    component = next(line for line in reversed(components) if '/' in line)
    adb('shell', 'am', 'start', '-n', component)
    start = time.monotonic()
    log = BASE / f'android_{name}_logcat.txt'
    telemetry = []
    complete = False
    # No user data is collected: only our package's Godot output and public
    # device thermal/battery/memory telemetry are read.
    pid = ''
    for _ in range(20):
        pid = package_pid()
        if pid: break
        time.sleep(0.5)
    if not pid: raise SystemExit('Benchmark package did not start')
    while time.monotonic() - start < 1200:
        data = adb('logcat', '-d', '-v', 'brief', '-T', timestamp, '--pid='+pid, 'godot:I', '*:S').decode('utf-8', errors='replace')
        log.write_text(data, encoding='utf-8')
        telemetry.append({'seconds': time.monotonic()-start,
            'battery': adb('shell', 'dumpsys', 'battery').decode(),
            'thermal': adb('shell', 'dumpsys', 'thermalservice').decode(),
            'memory': adb('shell', 'dumpsys', 'meminfo', PACKAGE).decode()})
        ends = re.findall(r'HV_PERF_END (\S+)', data)
        print(f'ANDROID {name}: {time.monotonic()-start:.0f}s; completed {ends}', flush=True)
        if 'HV_PERF_DONE ' in data:
            complete = True
            break
        if not package_pid(): break
        time.sleep(20)
    chunks = {}
    for line in data.splitlines():
        match = re.search(r'HV_PERF_CHUNK (\S+) (\d+) (.*)$', line)
        if match: chunks.setdefault(match[1], {})[int(match[2])] = match[3]
    reports = {}
    for suite, parts in chunks.items():
        reports[suite] = json.loads(''.join(parts[offset] for offset in sorted(parts)))['report']
    env = re.search(r'HV_PERF_ENV (.*)', data)
    result = {'name': name, 'complete': complete, 'environment': json.loads(env[1]) if env else {},
              'reports': reports, 'telemetry': telemetry,
              'model': adb('shell', 'getprop', 'ro.product.model').decode().strip(),
              'android': adb('shell', 'getprop', 'ro.build.version.release').decode().strip()}
    (RESULTS / f'android_{name}.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    errors = re.findall(r'(?:SCRIPT ERROR:|ERROR:).*', data)
    if not complete or errors: raise SystemExit(f'Android incomplete/errors: {errors[:8]}; {log}')
    print(f'ANDROID {name} complete: {list(reports)}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['build', 'run'])
    parser.add_argument('name', choices=['before', 'after'])
    args = parser.parse_args()
    (build if args.action == 'build' else run)(args.name)
