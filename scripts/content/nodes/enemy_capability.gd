extends "res://scripts/content/nodes/attribute_node.gd"

## Reusable enemy capabilities; all timers and defenses live on each recipient.
func initialize(enemy: Dictionary, stats: Dictionary) -> void:
	match rule("behavior"):
		"shield": enemy.shield = stats.shield
		"wards": enemy.wards = int(stats.wards)
		"regrowth": enemy.regen = stats.regen_period
		"summon":
			enemy.toll = stats.toll_period
			enemy.toll_delayed = false

func absorb(enemy: Dictionary, amount: float, tags: Array, fire: bool, bypass: bool, stats: Dictionary) -> float:
	match rule("behavior"):
		"rage":
			if "frostneedle" in tags: amount *= stats.frost_multiplier
			if not bypass and enemy.hp > enemy.max_hp * stats.rage_threshold / 100.0: amount *= 1.0 - stats.armor_reduction / 100.0
		"wards":
			if not bypass and enemy.get("wards", 0) > 0 and not ("doomstone" in tags and stats.doom_bypass > 0):
				enemy.wards -= 1
				return 0.0
		"shield":
			if not bypass and enemy.get("shield", 0.0) > 0.0:
				var multiplier: float = stats.fire_multiplier if fire else 1.0
				var absorbed := minf(enemy.shield, amount * multiplier)
				enemy.shield -= absorbed
				amount -= absorbed / maxf(0.0001, multiplier)
	return amount

func speed(enemy: Dictionary, now: float, stats: Dictionary, slow: float) -> float:
	if rule("behavior") != "rage" or enemy.hp > enemy.max_hp * stats.rage_threshold / 100.0: return 1.0
	var suppression: float = stats.quench / 100.0 if slow > 0 else 0.0
	return 1.0 + (stats.haste_multiplier - 1.0) * (1.0 - suppression)

func advance(combat, enemy: Dictionary, delta: float, stats: Dictionary) -> void:
	match rule("behavior"):
		"regrowth":
			var blocked := false
			for id in combat.curses:
				var curse: Dictionary = combat.curses[id]
				if curse.target != enemy.id or curse.stacks < stats.curse_threshold or not combat.data.towers.has(id): continue
				var tower: Dictionary = combat.data.towers[id]
				if tower.get("rebuild_remaining", 0.0) <= 0.0 and VigilWorld.pad_position(tower.region, tower.pad).distance_to(enemy.pos) <= combat.tower_stats(tower).range: blocked = true
			var rate: float = 1.0 - stats.regrowth_suppression / 100.0 if blocked else 1.0
			enemy.regen = maxf(0.0, enemy.get("regen", stats.regen_period) - delta * rate)
			if enemy.regen <= 0.0 and rate > 0.0:
				enemy.shield = stats.get("shield", 0.0) if combat.EnemyCapabilities.has(enemy, "shield", combat.tuning) else 0.0
				enemy.wards = int(stats.get("wards", 0)) if combat.EnemyCapabilities.has(enemy, "wards", combat.tuning) else 0
				enemy.regen = stats.regen_period
		"summon":
			# Summoned escorts never summon recursively, regardless of their type.
			if enemy.has("summoner"): return
			enemy.toll = enemy.get("toll", stats.toll_period) - delta
			if enemy.toll > 0.0: return
			enemy.toll = stats.toll_period
			enemy.toll_delayed = false
			combat.EnemyCapabilities.summon(combat, enemy, stats)
