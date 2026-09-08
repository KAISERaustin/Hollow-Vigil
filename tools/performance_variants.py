"""Ablations of the implementation against the same immutable before snapshot.

These edits are confined to ignored benchmark copies, never the live checkout.
Each snapshot records every resulting production source hash.
"""
import hashlib
import json
import re
import shutil
import zipfile
import sys

import performance_audit as audit
from performance_compare import BASE, RESULTS


def function(source, name):
    return re.search(r'^func ' + name + r'\(.*?(?=^func |\Z)', source, re.M | re.S).group()


def prepare(name, group):
    dest = BASE / name
    if dest.exists(): raise SystemExit(f'Snapshot exists: {dest}')
    with zipfile.ZipFile(BASE / 'before.zip') as source: source.extractall(dest)

    def copy(relative):
        target = dest / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(audit.ROOT / relative, target)

    combat_path = 'scripts/gameplay/combat/combat.gd'
    before = (dest / combat_path).read_text(encoding='utf-8')
    current = (audit.ROOT / combat_path).read_text(encoding='utf-8')
    if group == 'artwork':
        for relative in ['scripts/rendering/battlefield.gd', 'scripts/rendering/terrain/terrain_art.gd', 'scripts/rendering/actors/actor_images.gd']:
            copy(relative)
        shutil.copytree(audit.ROOT / 'assets/artwork', dest / 'assets/artwork', dirs_exist_ok=True)
    elif group == 'route':
        for relative in ['scripts/gameplay/combat/route_cache.gd', 'scripts/gameplay/combat/route_geometry.gd', 'scripts/gameplay/combat/targeting.gd', 'scripts/gameplay/encounters/bosses.gd']:
            copy(relative)
        before = before.replace(function(before, '_create_enemy'), function(current, '_create_enemy'))
        before = before.replace('\t\telif enemy_pool.size() < 128:\n', '\t\telif enemy_pool.size() < 128:\n\t\t\te.erase("_route_geometry")\n\t\t\te.path = []\n')
        before = before.replace('\tenemies = live\n', '\tenemies = live\n\tif tick_count % 128 == 0: route_cache.prune()\n')
        before += '\nvar route_cache := preload("res://scripts/gameplay/combat/route_cache.gd").new()\n\n' + function(current, 'set_enemy_route')
        (dest / combat_path).write_text(before, encoding='utf-8')
    elif group == 'configuration':
        for relative in ['scripts/gameplay/game_state.gd', 'scripts/gameplay/combat/configuration_cache.gd', 'scripts/gameplay/combat/enemy_index.gd', 'scripts/gameplay/combat/projectiles.gd', 'scripts/gameplay/combat/tower_components.gd', 'scripts/gameplay/progression/relics.gd', 'scripts/content/nodes/boss_node.gd', 'scripts/content/nodes/bosses/cindermaw.gd']:
            copy(relative)
        current = current.replace(function(current, 'set_enemy_route'), '')
        current = current.replace('var route_cache := preload("res://scripts/gameplay/combat/route_cache.gd").new()\n', '')
        current = current.replace('\tset_enemy_route(e, route)\n', '')
        current = current.replace('\t\t\t\te.erase("_route_geometry")\n\t\t\t\te.path = []\n', '')
        current = current.replace('\tif tick_count % 128 == 0: route_cache.prune()\n', '')
        (dest / combat_path).write_text(current, encoding='utf-8')
    elif group == 'interface':
        for relative in ['scripts/ui/hud.gd', 'scripts/ui/shared/floating_game_hud.gd', 'scripts/ui/shared/value_refresh.gd']:
            copy(relative)
        screen = dest / 'scripts/campaign/screen.gd'
        source = screen.read_text(encoding='utf-8').replace('gold.text = "%s gold" % Balance.money(run.game.data.balance)', 'preload("res://scripts/ui/shared/value_refresh.gd").money(gold, run.game.data.balance, " gold")')
        screen.write_text(source, encoding='utf-8')
    else:
        raise SystemExit(f'Unknown group {group}')
    shutil.copytree(audit.ROOT / 'tests/performance', dest / 'tests/performance', dirs_exist_ok=True)
    manifest = {str(path.relative_to(dest)): hashlib.sha256(path.read_bytes()).hexdigest() for path in (dest / 'scripts').rglob('*.gd')}
    (RESULTS / f'{name}_source.json').write_text(json.dumps({'base': 'before', 'optimization': group, 'sha256': manifest}, indent=2))
    print(f'Prepared {name}: {group} only', flush=True)


if __name__ == '__main__': prepare(sys.argv[1], sys.argv[2])
