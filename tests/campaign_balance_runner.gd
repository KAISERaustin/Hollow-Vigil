extends SceneTree

const Catalog = preload("res://scripts/campaign/catalog.gd")
const Run = preload("res://scripts/campaign/run.gd")
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

func invest(battle: RefCounted) -> void:
	var sockets: Array = battle.mission.sockets.duplicate()
	sockets.sort_custom(func(a,b): return coverage(a.position,battle.mission) > coverage(b.position,battle.mission))
	var kinds := ["rapid","heavy","splash","electric","heavy","rapid","heavy","electric"]
	var branches := {"rapid":"frostneedle","heavy":"doomstone","splash":"cinderfield","electric":"thunderseal"}
	# A deterministic reference strategy spends actual mission earnings only.
	# A pair of early towers, followed by upgrades and a broader mixed defense.
	for tier in range(1,5):
		for rank in range(mini(sockets.size(),8)):
			if tier == 1 and rank > 1:
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
	for index in range(20):
		var battle := Run.new(index)
		var steps := 0
		while battle.phase in ["planning","wave"] and steps < 20000:
			if battle.phase == "planning":
				invest(battle)
				battle.start_wave()
			battle.tick(Balance.STEP)
			steps += 1
		var line := "%d,%s,%s,%d,%d,%.1f" % [index+1,battle.mission.name,battle.phase,battle.health,battle.game.data.balance,steps*Balance.STEP]
		print(line)
		report += line + "\n"
		if battle.phase != "victory":
			failures += 1
		await process_frame
	var output := FileAccess.open("res://artifacts/campaign-balance.csv",FileAccess.WRITE)
	output.store_string(report)
	output.close()
	print("Campaign reference strategy: %d victories / 20" % (20-failures))
	quit(0 if failures == 0 else 1)
