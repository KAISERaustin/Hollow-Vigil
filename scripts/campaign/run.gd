extends RefCounted

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
var checkpoint: Dictionary = {}

func _init(index: int = 0) -> void:
	mission = Catalog.level(index)
	game = VigilState.new(81000 + index, "survival")
	game.data.balance = float(mission.gold)
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
	refresh_checkpoint()

func start_wave() -> bool:
	if phase != "planning" or wave >= mission.waves.size():
		return false
	refresh_checkpoint()
	schedule.clear()
	for group in mission.waves[wave]:
		for count in range(int(group[1])):
			schedule.append({"kind": group[0], "lane": int(group[2]), "at": float(group[3]) + count * float(group[4]), "order": schedule.size()})
	schedule.sort_custom(func(a, b): return a.at < b.at if a.at != b.at else a.order < b.order)
	next_spawn = 0
	wave_time = 0.0
	phase = "wave"
	changed.emit()
	return true

func tick(delta: float) -> void:
	if phase != "wave" or not is_finite(delta) or delta <= 0.0:
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
		finished.emit()
	elif next_spawn == schedule.size() and game.combat.enemies.is_empty():
		wave += 1
		# A single transition pays each cleared wave exactly once.
		game.data.balance += mission.reward
		phase = "victory" if wave == mission.waves.size() else "planning"
		game.combat.pending_shots.clear()
		game.combat.burning_ground.clear()
		game.combat.curses.clear()
		game.combat.target_locks.clear()
		game.combat.relic_progress.clear()
		for tower in game.data.towers.values():
			tower.cooldown = 0.0
		refresh_checkpoint()
		changed.emit()
		if phase == "victory":
			finished.emit()

func _escaped(enemy: Dictionary) -> void:
	var damage := 20 if enemy.get("boss", false) else (3 if enemy.kind == "sentinel" else (2 if enemy.kind in ["heavy", "shade"] else 1))
	health = maxi(0, health - damage)

func medal() -> int:
	if phase != "victory":
		return 0
	return 3 if health == Catalog.MAX_HEALTH else (2 if health >= 10 else 1)

func editable() -> bool:
	return phase in ["planning", "wave"]

func tower_at(socket: int) -> String:
	var pad := Catalog.socket(socket)
	return game.economy.tower_at(pad.region, pad.pad)

func build(socket: int, kind: String) -> bool:
	if not editable() or socket not in mission.pads:
		return false
	var pad := Catalog.socket(socket)
	if game.economy.build(kind, pad.region, pad.pad).is_empty():
		return false
	_after_edit()
	return true

func upgrade(socket: int, branch: String = "") -> bool:
	if not editable() or socket not in mission.pads or not game.economy.upgrade(tower_at(socket), -1, branch):
		return false
	_after_edit()
	return true

func sell(socket: int) -> bool:
	if not editable() or socket not in mission.pads or game.economy.sell(tower_at(socket)).is_empty():
		return false
	_after_edit()
	return true

func target(socket: int, mode: String) -> bool:
	if not editable() or socket not in mission.pads or not Balance.TARGET_MODES.has(mode):
		return false
	var id := tower_at(socket)
	if id.is_empty():
		return false
	game.data.towers[id].target_mode = mode
	game.combat.target_locks.erase(id)
	_after_edit()
	return true

func _after_edit() -> void:
	if phase == "planning":
		refresh_checkpoint()
	changed.emit()

func refresh_checkpoint() -> void:
	if phase != "planning":
		return
	var towers: Array = []
	for socket in mission.pads:
		var id := tower_at(socket)
		if not id.is_empty():
			var tower: Dictionary = game.data.towers[id]
			towers.append({"socket": socket, "kind": tower.kind, "level": tower.level, "branch": tower.get("branch", ""), "target_mode": tower.target_mode})
	checkpoint = {"level": mission.index, "wave": wave, "health": health, "gold": game.data.balance, "towers": towers}

func restore(saved: Dictionary) -> void:
	# The progress store validates this compact preparation snapshot first.
	wave = int(saved.wave)
	health = int(saved.health)
	for tower in saved.towers:
		var pad := Catalog.socket(int(tower.socket))
		var id := game.economy._add_tower(tower.kind, pad.region, pad.pad)
		game.data.towers[id].level = int(tower.level)
		game.data.towers[id].branch = tower.branch
		game.data.towers[id].target_mode = tower.target_mode
	game.data.balance = float(saved.gold)
	refresh_checkpoint()
