extends RefCounted

const Configuration = preload("res://scripts/campaign/configuration.gd")
const Catalog = preload("res://scripts/campaign/catalog.gd")
signal changed
signal finished
signal wave_cleared(number: int, reward: float)

var mission: Dictionary
var game: VigilState
var phase := "planning"
var wave := 0
var health := Catalog.MAX_HEALTH
var wave_time := 0.0
var schedule: Array[Dictionary] = []
var next_spawn := 0
var finish_pending := false
var mode := "survival"
var spawned_counts := {}
var rules := {}
var wave_checkpoint := {}
const CHECKPOINT_FIELDS := ["towers", "next_tower", "relics", "balance", "reserve", "lifetime_earnings", "kills", "escapes", "active_seconds"]

func _init(index: int = 0, overrides: Dictionary = {}, game_mode: String = "survival") -> void:
	rules = overrides.duplicate(true)
	mode = game_mode if game_mode in ["creative", "survival"] else "survival"
	mission = Configuration.resolve(index, overrides)
	health = int(mission.flame)
	game = VigilState.new(81000 + index, mode)
	game.economy.set_sale_rules(Balance.Content.level(index))
	game.data.balance = float(mission.gold)
	game.data.settings.developer_balance = mission.tuning.duplicate(true)
	game.data.first_property_required = false
	game.data.automation = true
	# These regions only anchor tower sockets. Campaign roads are independent of
	# the expansion grid, seeded geography, and shortest-route reconstruction.
	for y in range(-2, 1):
		for x in range(-1, 2):
			var id := VigilWorld.key(Vector2i(x, y))
			if id == "0,0":
				continue
			game.data.regions[id] = VigilWorld.make_region(id, "0,0", game.data.seed)
	game.combat.scripted_spawns = true
	game.combat.authored_roads = mission.routes
	game.economy.placement_roads = mission.routes
	game.economy.placement_bounds = preload("res://scripts/content/nodes/ground_placement.gd").campaign_bounds(mission)
	game.combat.rng.seed = 91000 + index
	game.combat.enemy_escaped.connect(_escaped)

func start_wave() -> bool:
	if phase != "planning" or wave >= mission.waves.size():
		return false
	wave_checkpoint = _capture_checkpoint("wave")
	# This setup exception ends permanently for this run at the first wave start.
	game.economy.set_sale_rules(null)
	game.data.settings.developer_balance = mission.wave_rules[wave].tuning.duplicate(true)
	schedule = Configuration.schedule(mission, wave)
	next_spawn = 0
	spawned_counts.clear()
	wave_time = 0.0
	phase = "wave"
	changed.emit()
	return true

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	if phase != "wave":
		if phase == "planning": game.combat.prepare_defenses(delta)
		# Presentation may finish without advancing enemies, damage or rewards.
		game.combat.advance_effects(delta)
		_finish_when_effects_end()
		return
	wave_time += delta
	while next_spawn < schedule.size() and schedule[next_spawn].at <= wave_time:
		var spawn: Dictionary = schedule[next_spawn]
		var group_id := int(spawn.group)
		spawned_counts[group_id] = int(spawned_counts.get(group_id, 0)) + 1
		var route: Array[Vector2] = mission.routes[spawn.lane]
		if Balance.BOSSES.has(spawn.kind):
			game.combat.Bosses.create(game.combat, "0,0", spawn.kind, route)
		else:
			game.combat.spawn_on_path(spawn.kind, route, mission.style)
		next_spawn += 1
	game.combat.tick(delta)
	if health <= 0:
		phase = "defeat"
		changed.emit()
		finish_pending = true
		_finish_when_effects_end()
	elif next_spawn == schedule.size() and game.combat.enemies.is_empty():
		wave += 1
		# A single transition pays each cleared wave exactly once.
		game.data.balance += mission.wave_rules[wave - 1].reward
		phase = "victory" if wave == mission.waves.size() else "planning"
		game.combat.pending_shots.clear()
		game.combat.line_projectiles.clear()
		if phase == "victory": game.combat.TowerComponents.reset(game.combat)
		game.combat.burning_ground.clear()
		game.combat.effect_fields.clear()
		game.combat.curses.clear()
		game.combat.target_locks.clear()
		game.combat.relic_progress.clear()
		for tower in game.data.towers.values():
			tower.cooldown = 0.0
		wave_cleared.emit(wave, float(mission.wave_rules[wave - 1].reward))
		changed.emit()
		if phase == "victory":
			finish_pending = true
			_finish_when_effects_end()

func _finish_when_effects_end() -> void:
	if finish_pending and game.combat.effects.is_empty():
		finish_pending = false
		finished.emit()

func _escaped(enemy: Dictionary) -> void:
	var damage := Balance.Content.enemy(enemy.kind, enemy.get("boss", false)).escape_damage()
	health = maxi(0, health - damage)

func editable() -> bool:
	return phase in ["planning", "wave"]

func can_author() -> bool:
	return Balance.Content.catalog().get_node("level/campaign/" + mode).rule("developer_controls", false)

func apply_configuration(overrides: Dictionary) -> bool:
	if not can_author() or not editable() or not Configuration.valid_level(mission.index, overrides): return false
	var next := Configuration.resolve(mission.index, overrides)
	if phase == "wave" and next.waves[wave].size() < mission.waves[wave].size(): return false
	# Already spawned enemies keep their health/effects. Only outstanding group members change.
	if phase == "wave":
		var pending: Array[Dictionary] = []
		for spawn in Configuration.schedule(next, wave):
			if int(spawn.member) >= int(spawned_counts.get(int(spawn.group), 0)):
				pending.append(spawn)
		schedule = pending
		next_spawn = 0
	else:
		if wave == 0:
			game.data.balance = maxf(0.0, game.data.balance + next.gold - mission.gold)
			health = int(next.flame)
	mission = next
	game.combat.authored_roads = mission.routes
	game.economy.placement_roads = mission.routes
	game.economy.placement_bounds = preload("res://scripts/content/nodes/ground_placement.gd").campaign_bounds(mission)
	rules = overrides.duplicate(true)
	game.data.settings.developer_balance = (mission.wave_rules[wave].tuning if phase == "wave" else mission.tuning).duplicate(true)
	changed.emit()
	return true

func tower_at(socket: int) -> String:
	var pad := Catalog.socket(socket)
	return game.economy.tower_at(pad.region, pad.pad)

func build(socket: int, kind: String) -> bool:
	if not editable() or not Balance.Content.level(mission.index).allows_socket(socket):
		return false
	var pad := Catalog.socket(socket)
	if game.economy.build(kind, pad.region, pad.pad).is_empty():
		return false
	_after_edit()
	return true

func upgrade(socket: int, branch: String = "") -> bool:
	if not editable() or not Balance.Content.level(mission.index).allows_socket(socket) or not game.economy.upgrade(tower_at(socket), -1, branch):
		return false
	_after_edit()
	return true

func sell(socket: int) -> bool:
	if not editable() or not Balance.Content.level(mission.index).allows_socket(socket) or game.economy.sell(tower_at(socket)).is_empty():
		return false
	_after_edit()
	return true

func target(socket: int, target_mode: String) -> bool:
	if not editable() or not Balance.Content.level(mission.index).allows_socket(socket):
		return false
	var id := tower_at(socket)
	if not game.set_tower_target(id, target_mode):
		return false
	_after_edit()
	return true

func _after_edit() -> void:
	changed.emit()

func _capture_checkpoint(saved_phase: String) -> Dictionary:
	var state := {}
	for key in CHECKPOINT_FIELDS:
		var value: Variant = game.data.get(key, {})
		state[key] = value.duplicate(true) if value is Dictionary else value
	return {"level": int(mission.index), "wave": wave, "health": health, "phase": saved_phase,
		"mode": mode, "rules": rules.duplicate(true), "state": state, "random_state": str(game.combat.rng.state)}

func checkpoint() -> Dictionary:
	# Every mid-wave save contains the same starting economy. No later rewards,
	# purchases or live enemies can leak into a replay of that wave.
	if phase in ["wave", "defeat"] and not wave_checkpoint.is_empty():
		return wave_checkpoint.duplicate(true)
	return _capture_checkpoint(phase)

static func valid_checkpoint(value: Dictionary) -> bool:
	if value.size() != 8 or value.get("phase") not in ["planning", "wave", "victory"]: return false
	if value.get("mode") not in ["creative", "survival"]: return false
	if not Configuration._number(value.get("level"), 0, Catalog.COUNT - 1, true): return false
	var index := int(value.level)
	if not Configuration.valid_level(index, value.get("rules")): return false
	var checkpoint_mission := Configuration.resolve(index, value.rules)
	if not Configuration._number(value.get("wave"), 0, checkpoint_mission.waves.size(), true): return false
	if (value.phase == "victory") != (int(value.wave) == checkpoint_mission.waves.size()): return false
	if not Configuration._number(value.get("health"), 1, Configuration.Fields.CONFIGURATION_FIELDS.flame.max, true): return false
	if not value.get("random_state") is String or not value.random_state.is_valid_int(): return false
	if not value.get("state") is Dictionary or value.state.size() != CHECKPOINT_FIELDS.size(): return false
	for key in CHECKPOINT_FIELDS:
		if not value.state.has(key): return false
		if key not in ["towers", "relics"] and not Configuration._number(value.state[key]): return false
	var snapshot := VigilState.new(81000 + index).data
	for socket in checkpoint_mission.sockets:
		if not snapshot.regions.has(socket.region):
			snapshot.regions[socket.region] = {}
	snapshot.merge(value.state, true)
	if not VigilSaveStore.new().valid_loadout(snapshot): return false
	for tower in snapshot.towers.values():
		var allowed := int(tower.pad) >= 4 and preload("res://scripts/content/nodes/ground_placement.gd").allowed(snapshot, VigilWorld.pad_position(tower.region, tower.pad), checkpoint_mission.routes, preload("res://scripts/content/nodes/ground_placement.gd").campaign_bounds(checkpoint_mission), tower.id)
		for socket in checkpoint_mission.sockets:
			if socket.region == tower.region and socket.pad == tower.pad: allowed = true
		if not allowed: return false
	return true

static func from_checkpoint(value: Dictionary) -> RefCounted:
	if not valid_checkpoint(value): return null
	var restored: RefCounted = load("res://scripts/campaign/run.gd").new(int(value.level), value.rules, value.mode)
	for key in CHECKPOINT_FIELDS:
		restored.game.data[key] = value.state[key].duplicate(true) if value.state[key] is Dictionary else value.state[key]
	restored.game.data.next_tower = int(restored.game.data.next_tower)
	restored.wave = int(value.wave)
	restored.health = int(value.health)
	restored.game.combat.rng.state = int(value.random_state)
	if restored.wave > 0: restored.game.economy.set_sale_rules(null)
	if value.phase == "wave":
		restored.start_wave()
	else:
		restored.phase = value.phase
	return restored
