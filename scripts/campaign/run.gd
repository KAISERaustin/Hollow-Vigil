extends RefCounted

const Configuration = preload("res://scripts/campaign/configuration.gd")
const Catalog = preload("res://scripts/campaign/catalog.gd")
signal changed
signal finished

var mission: Dictionary
var game: VigilState
var phase := "planning"
var wave := 0
var health := Catalog.MAX_HEALTH
var wave_time := 0.0
var schedule: Array[Dictionary] = []
var next_spawn := 0
var finish_pending := false

func _init(index: int = 0, overrides: Dictionary = {}) -> void:
	mission = Configuration.resolve(index, overrides)
	health = int(mission.flame)
	game = VigilState.new(81000 + index, "survival")
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
	game.combat.rng.seed = 91000 + index
	game.combat.enemy_escaped.connect(_escaped)

func start_wave() -> bool:
	if phase != "planning" or wave >= mission.waves.size():
		return false
	game.data.settings.developer_balance = mission.wave_rules[wave].tuning.duplicate(true)
	schedule = Configuration.schedule(mission, wave)
	next_spawn = 0
	wave_time = 0.0
	phase = "wave"
	changed.emit()
	return true

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	if phase != "wave":
		# Presentation may finish without advancing enemies, damage or rewards.
		game.combat.advance_effects(delta)
		_finish_when_effects_end()
		return
	wave_time += delta
	while next_spawn < schedule.size() and schedule[next_spawn].at <= wave_time:
		var spawn: Dictionary = schedule[next_spawn]
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
		game.combat.burning_ground.clear()
		game.combat.curses.clear()
		game.combat.target_locks.clear()
		game.combat.relic_progress.clear()
		for tower in game.data.towers.values():
			tower.cooldown = 0.0
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

func target(socket: int, mode: String) -> bool:
	if not editable() or not Balance.Content.level(mission.index).allows_socket(socket):
		return false
	var id := tower_at(socket)
	if not game.set_tower_target(id, mode):
		return false
	_after_edit()
	return true

func _after_edit() -> void:
	changed.emit()
