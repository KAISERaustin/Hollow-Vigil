extends "res://tests/test_runner.gd"

const Catalog = preload("res://scripts/campaign/catalog.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Progress = preload("res://scripts/campaign/progress.gd")

func run() -> void:
	check(Catalog.MISSIONS.size() == 20, "Campaign contains exactly 20 authored missions")
	var layouts := {}
	for index in range(20):
		var mission := Catalog.level(index)
		var fingerprint := str(mission.roads)
		check(not layouts.has(fingerprint), "Level %d has its own road layout" % (index+1))
		layouts[fingerprint] = true
		for route in mission.routes:
			check(route.size() >= 2 and route[-1] == Catalog.CORE, "Authored lane reaches sanctuary")
			for segment in range(1,route.size()):
				check(route[segment] != route[segment-1] and Catalog.BOARD.has_point(route[segment]), "Lane has finite in-world movement segments")
		var bosses := 0
		for wave in mission.waves:
			check(not wave.is_empty(), "Every wave has enemies")
			for group in wave:
				check(group[0] in Balance.NORMAL_KINDS + Balance.DUNGEON_KINDS or Balance.BOSSES.has(group[0]), "Authored enemy is supported")
				check(group[1] > 0 and group[2] >= 0 and group[2] < mission.routes.size() and group[3] >= 0 and group[4] > 0, "Wave timing and lane are valid")
				if Balance.BOSSES.has(group[0]):
					bosses += group[1]
		check(bosses == (1 if index % 5 == 4 else 0), "Each chapter ends in one boss")
		for socket in mission.sockets:
			check(Catalog.BOARD.has_point(socket.position), "Build socket lies in authored world")
	var battle := Run.new(0)
	battle.game.combat.tick(30)
	check(battle.game.combat.enemies.is_empty(), "Campaign does not receive idle rift spawns")
	check(not battle.build(0,"rapid"), "Unauthored sockets cannot be built on")
	check(battle.build(6,"rapid") and battle.upgrade(6), "Campaign tower transactions use mission gold")
	check(battle.game.data.balance == 120, "Build and upgrade deduct exact shared costs")
	check(battle.target(6,"most_hp"), "Campaign supports target priorities")
	var before := battle.checkpoint.duplicate(true)
	check(battle.start_wave() and not battle.start_wave(), "Wave start cannot be duplicated")
	check(battle.build(9,"rapid"), "Building is supported during a wave")
	check(battle.checkpoint == before, "Midwave purchases do not alter the preparation checkpoint")
	battle.tick(Balance.STEP)
	check(battle.game.combat.enemies.size() == 1 and battle.game.combat.enemies[0].path == battle.mission.routes[0], "Wave enemy follows the exact authored route")
	var resumed := Run.new(0)
	resumed.restore(before)
	check(resumed.checkpoint == before and resumed.game.combat.enemies.is_empty() and resumed.phase == "planning", "Checkpoint restores gold, towers, targeting and clean wave state")
	var lose := Run.new(0)
	for i in range(4000):
		if lose.phase == "planning": lose.start_wave()
		lose.tick(Balance.STEP)
		if lose.phase == "defeat": break
	check(lose.phase == "defeat" and lose.health == 0, "Undefended campaign loses when flame reaches zero")
	var frozen: float = lose.game.data.active_seconds
	lose.tick(5)
	check(lose.game.data.active_seconds == frozen and lose.medal() == 0, "Defeat freezes simulation and grants no medal")
	var bell_run := Run.new(14)
	var route: Array[Vector2] = bell_run.mission.routes[0]
	var bell := bell_run.game.combat.Bosses.create(bell_run.game.combat,"0,0","bell",route)
	bell.toll = 0.01
	bell_run.game.combat.tick(Balance.STEP)
	check(bell.path == route and bell.tile == "0,0", "Campaign boss does not enter sandbox patrol routing")
	check(bell_run.game.combat.enemies.size() == 4, "Drowned Bell summons campaign escorts")
	for enemy in bell_run.game.combat.enemies:
		check(enemy.path[-1] == Catalog.CORE, "Boss and summoned escorts reach the campaign sanctuary")
	bell.path = [Catalog.CORE - Vector2(0,0.1),Catalog.CORE]
	bell.pos = bell.path[0]
	bell.segment = 1
	bell_run.game.combat.tick(Balance.STEP)
	check(bell_run.health == 0, "An escaped boss extinguishes the flame")
	var progress := Progress.new()
	progress.path = "user://campaign-check-" + str(Time.get_ticks_usec()) + ".save"
	check(progress.unlocked(0) and not progress.unlocked(1), "Only the first campaign level starts unlocked")
	check(progress.save_run(resumed), "Preparation checkpoint writes with checksum")
	var reloaded := Progress.new()
	reloaded.path = progress.path
	reloaded.load_progress()
	check(reloaded.data.checkpoint == before, "Campaign checkpoint survives a disk round trip")
	resumed.phase = "victory"
	check(progress.save_run(resumed) and progress.unlocked(1) and not progress.unlocked(2), "Victory unlocks only the next mission")
	check(progress.data.medals[0] == 3, "Perfect health awards three medals")
	resumed.health = 5
	check(progress.save_run(resumed) and progress.data.medals[0] == 3, "Replays never downgrade an earned medal")
	var broken := FileAccess.open(progress.path,FileAccess.WRITE)
	broken.store_string("interrupted write")
	broken.close()
	reloaded.load_progress()
	check(not reloaded.blocked and reloaded.data.medals[0] == 3, "Damaged primary recovers the previous valid campaign copy")
	clean_test_save(progress.path)
	broken = FileAccess.open(progress.path,FileAccess.WRITE)
	broken.store_string("unknown data")
	broken.close()
	reloaded.load_progress()
	check(reloaded.blocked and not reloaded.save_run(resumed), "Unreadable campaign progress is preserved and blocks writes")
	check(FileAccess.get_file_as_string(progress.path) == "unknown data", "Blocked save is never overwritten")
	clean_test_save(progress.path)
	var sandbox := VigilState.new(42)
	check(not sandbox.combat.scripted_spawns and sandbox.combat.spawn_on_path("basic",route).is_empty(), "Sandbox does not accept campaign spawns")
	print("Campaign: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
