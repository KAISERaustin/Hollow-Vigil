extends SceneTree

const Catalog = preload("res://scripts/campaign/catalog.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Progress = preload("res://scripts/campaign/progress.gd")
const STRATEGIES := [0,0,0,0,1,0,0,0,0,8,0,1,0,2,0,1,4,1,1,4]
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func coverage(at: Vector2, mission: Dictionary) -> float:
	var result := 0.0
	for road in mission.routes:
		var length := 0.0
		var covered := 0.0
		for i in range(1,road.size()):
			var distance: float = road[i-1].distance_to(road[i])
			length += distance
			for sample in range(20):
				var point: Vector2 = road[i-1].lerp(road[i], (sample+0.5)/20.0)
				if point.distance_to(at) <= 155:
					covered += distance/20
		result += covered/maxf(1,length)
	return result

func ranked_sockets(mission: Dictionary) -> Array:
	var remaining: Array = mission.sockets.duplicate()
	var selected: Array = []
	var defended: Array = []
	defended.resize(mission.routes.size())
	defended.fill(0.0)
	while not remaining.is_empty():
		var best: Dictionary = remaining[0]
		var best_score := -1.0
		for socket in remaining:
			var score := 0.0
			for lane in range(mission.routes.size()):
				score += coverage(socket.position, {"routes": [mission.routes[lane]]}) / (1.0 + 4.0 * defended[lane])
			if score > best_score:
				best_score = score
				best = socket
		selected.append(best)
		remaining.erase(best)
		for lane in range(mission.routes.size()):
			defended[lane] += coverage(best.position,{"routes": [mission.routes[lane]]})
	return selected

func invest(battle: RefCounted, strategy: int) -> void:
	var sockets := ranked_sockets(battle.mission)
	if strategy >= 32:
		sockets = battle.mission.sockets.duplicate()
		sockets.sort_custom(func(a,b): return coverage(a.position,battle.mission) > coverage(b.position,battle.mission))
	strategy %= 32
	var kinds: Array = [
		["rapid","heavy","splash","electric","heavy","rapid","heavy","electric"],
		["rapid","rapid","heavy","electric","splash","heavy","rapid","electric"],
		["electric","rapid","heavy","rapid","splash","heavy","electric","rapid"],
		["splash","heavy","rapid","electric","heavy","rapid","heavy","electric"],
		["heavy","electric","electric","rapid","heavy","splash","rapid","electric"],
		["electric","heavy","electric","heavy","rapid","splash","rapid","electric"],
		["rapid","electric","electric","heavy","splash","heavy","rapid","electric"],
		["heavy","heavy","electric","rapid","splash","heavy","rapid","electric"]
	][strategy % 8]
	var branches := {"rapid":"frostneedle","heavy":"doomstone","splash":"cinderfield","electric":"thunderseal"}
	# A deterministic reference strategy spends actual mission earnings only.
	# A pair of early towers, followed by upgrades and a broader mixed defense.
	var targets: Array = [[2,2,2,2,2,2,2,2,3,3,3,3,4,4], [2,2,3,3,4,4,2,3,4,2,3,4], [3,3,3,3,4,4,4,4], [4,3,2,3,4,4]][strategy / 8]
	var order: Array = [[0,1,2,3,4,5,6,7,0,1,2,3,0,1], [0,1,0,1,0,1,2,2,2,3,3,3], [0,1,2,3,0,1,2,3], [0,1,2,2,1,2]][strategy / 8]
	for step in range(targets.size()):
		var tier: int = targets[step]
		var selected_rank: int = order[step]
		for rank in range(mini(sockets.size(),8)):
			if rank != selected_rank:
				continue
			var socket: int = sockets[rank].index
			var id: String = battle.tower_at(socket)
			var kind: String = kinds[rank]
			if id.is_empty():
				if not battle.build(socket,kind):
					return
				id = battle.tower_at(socket)
			while battle.game.data.towers[id].level < tier:
				var branch: String = branches[kind] if battle.game.data.towers[id].level == 3 else ""
				if not battle.upgrade(socket,branch):
					return

func run() -> void:
	var report := "level,name,result,flame,gold,seconds\n"
	var progress := Progress.new()
	progress.path = "user://campaign-playthrough-" + str(Time.get_ticks_usec()) + ".save"
	for index in range(20):
		if not progress.unlocked(index):
			failures += 1
			push_error("Previous victory did not unlock level %d" % (index+1))
		var battle := Run.new(index)
		var steps := 0
		var chosen: int = STRATEGIES[index]
		while battle.phase in ["planning","wave"] and steps < 20000:
			if battle.phase == "planning":
				invest(battle,chosen)
				battle.start_wave()
			battle.tick(Balance.STEP)
			steps += 1
		if battle.phase == "victory" and not progress.save_run(battle):
			failures += 1
			push_error(progress.last_error)
		var line := "%d,%s,%s,%d,%d,%.1f" % [index+1,battle.mission.name,battle.phase,battle.health,battle.game.data.balance,steps*Balance.STEP]
		print(line)
		report += line + "\n"
		if battle.phase != "victory":
			failures += 1
		await process_frame
	var output := FileAccess.open("res://artifacts/campaign-balance.csv",FileAccess.WRITE)
	output.store_string(report)
	output.close()
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(progress.path+suffix)
	print("Campaign reference strategies and progression: %d / 20 passed" % (20-failures))
	quit(0 if failures == 0 else 1)
