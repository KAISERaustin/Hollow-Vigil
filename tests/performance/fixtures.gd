extends RefCounted

const Run = preload("res://scripts/campaign/run.gd")
const KINDS := ["rapid", "heavy", "splash", "electric", "ironspike", "moonwheel", "hex_lantern", "caltrop_keep"]

static func infinite(radius: int, defended: bool, compact: bool = false) -> VigilState:
	var game := VigilState.new(570)
	game.data.first_property_required = false
	game.data.towers.clear()
	game.data.balance = 1.0e12
	game.combat.rng.seed = 570
	if compact:
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if x == 0 and y == 0: continue
				var id := "%d,%d" % [x, y]
				var parent := "%d,%d" % [x - signi(x), y] if x != 0 else "0,%d" % (y - signi(y))
				game.data.regions[id] = VigilWorld.make_region(id, parent, 570)
				game.data.regions[id].style = "forest"
	else:
		for side in [-1, 1]:
			for index in range(1, radius + 1):
				var id := "%d,0" % (side * index)
				game.data.regions[id] = VigilWorld.make_region(id, "%d,0" % (side * (index - 1)), 570)
				game.data.regions[id].style = "forest"
	game.refresh_paths()
	var serial := 0
	for id in game.data.regions:
		var region: Dictionary = game.data.regions[id]
		region.traffic = Balance.MAX_TRAFFIC_LEVEL
		region.unlocks = Balance.UNLOCK_COSTS.keys()
		if not defended or id == "0,0": continue
		var kind: String = KINDS[serial % KINDS.size()]
		var tid := game.economy.build(kind, id, 1 if VigilWorld.center(id).x < 0 else 0)
		if not tid.is_empty():
			for level in range(1, 4):
				game.economy.upgrade(tid, level, Balance.BRANCHES[kind].keys()[serial % 2] if level == 3 else "")
		serial += 1
	return game

static func campaign(index: int = 19):
	var battle = Run.new(index)
	battle.game.data.balance = 1.0e12
	for socket in battle.mission.sockets:
		var kind: String = KINDS[int(socket.index) % KINDS.size()]
		if not battle.build(socket.index, kind): continue
		for level in range(1, 4):
			battle.upgrade(socket.index, Balance.BRANCHES[kind].keys()[int(socket.index) % 2] if level == 3 else "")
	return battle

static func populate_campaign(battle, count: int) -> void:
	# Controlled overload, not an authored wave or a balance assertion.
	for i in range(count):
		var path: Array[Vector2] = battle.mission.routes[i % battle.mission.routes.size()]
		var enemy: Dictionary = battle.game.combat.spawn_on_path("basic", path, "forest")
		if enemy.is_empty(): continue
		var segment := 1 + i % (path.size() - 1)
		enemy.segment = segment
		enemy.pos = path[segment - 1].lerp(path[segment], float((i * 37) % 100) / 100.0)
	battle.game.combat.rebuild_enemy_index()

static func checksum(game: VigilState) -> String:
	var actors := []
	for e in game.combat.enemies:
		actors.append([e.id, e.kind, e.pos, e.hp, e.segment, e.dead, e.get("gear_status", {})])
	var towers := []
	for t in game.data.towers.values(): towers.append([t.id, t.earnings, t.cooldown])
	return var_to_bytes(canonical([game.data.balance, game.data.kills, game.data.escapes,
		game.data.lifetime_earnings, game.economy.unclaimed(), actors, towers,
		game.combat.rng.state, game.combat.pending_shots])).hex_encode().sha256_text()

static func canonical(value: Variant) -> Variant:
	# Content objects have process-local instance IDs. Compare their stable content
	# identity instead when checking separate baseline and profiling processes.
	if value is VigilContentNode: return {"content_node": value.id}
	if value is Object: return {"script": value.get_script().resource_path if value.get_script() != null else value.get_class()}
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = canonical(value[key])
		return result
	if value is Array:
		var result := []
		for child in value: result.append(canonical(child))
		return result
	return value

static func stats(samples: Array) -> Dictionary:
	if samples.is_empty(): return {}
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for value in samples: total += float(value)
	return {"n": samples.size(), "mean": total / samples.size(), "p50": sorted[int((sorted.size() - 1) * 0.50)],
		"p95": sorted[int((sorted.size() - 1) * 0.95)], "p99": sorted[int((sorted.size() - 1) * 0.99)], "max": sorted[-1]}

static func counts(game: VigilState) -> Dictionary:
	return {"regions": game.data.regions.size(), "towers": game.data.towers.size(), "enemies": game.combat.enemies.size(),
		"spawned": game.combat.enemy_serial, "kills": game.data.kills, "escapes": game.data.escapes,
		"earnings": game.data.lifetime_earnings, "effects": game.combat.effects.size(), "shots": game.combat.pending_shots.size(),
		"traps": game.combat.traps.size(), "line_projectiles": game.combat.line_projectiles.size(), "fields": game.combat.effect_fields.size()}
