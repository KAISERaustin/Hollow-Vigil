extends "res://tests/test_runner.gd"

const Catalog = preload("res://scripts/campaign/catalog.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Progress = preload("res://scripts/campaign/progress.gd")

func run() -> void:
	check_biome_portals()
	check_setup_refunds()
	check_effect_cleanup()
	check(Catalog.MISSIONS.size() == Catalog.COUNT, "Campaign contains six complete authored chapters")
	var layouts := {}
	for index in range(Catalog.COUNT):
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
				check(group[0] in preload("res://scripts/campaign/configuration.gd").spawn_kinds(), "Authored enemy is supported")
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
	check(battle.start_wave() and not battle.start_wave(), "Wave start cannot be duplicated")
	check(battle.build(9,"rapid"), "Building is supported during a wave")
	battle.tick(Balance.STEP)
	check(battle.game.combat.enemies.size() == 1 and battle.game.combat.enemies[0].path == battle.mission.routes[0], "Wave enemy follows the exact authored route")
	var resumed := Run.new(0)
	check(resumed.game.combat.enemies.is_empty() and resumed.game.data.towers.is_empty() and resumed.phase == "planning", "An unfinished level starts fresh")
	var lose := Run.new(0)
	check(lose.health == 3, "New campaign run starts with 3 core integrity")
	for i in range(4000):
		if lose.phase == "planning": lose.start_wave()
		lose.tick(Balance.STEP)
		if lose.phase == "defeat": break
	check(lose.phase == "defeat" and lose.health == 0 and lose.game.data.escapes == 3, "Three escaped Hollows deplete default core integrity and lose the level")
	var frozen: float = lose.game.data.active_seconds
	lose.tick(5)
	check(lose.game.data.active_seconds == frozen, "Defeat freezes simulation")
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
	check(bell_run.health == 0, "An escaped boss depletes core integrity")
	var progress := Progress.new()
	progress.path = "user://campaign-check-" + str(Time.get_ticks_usec()) + ".save"
	check(progress.unlocked(0) and not progress.unlocked(1), "Only the first campaign level starts unlocked")
	check(progress.save_run(resumed) and not FileAccess.file_exists(progress.path), "Unfinished levels are never written to disk")
	resumed.phase = "victory"
	check(progress.save_run(resumed) and progress.unlocked(1) and not progress.unlocked(2), "Victory saves one completed level and unlocks the next")
	var reloaded := Progress.new()
	reloaded.path = progress.path
	reloaded.load_progress()
	check(reloaded.data.completed_levels == 1 and reloaded.data.size() == 3, "Only version, sequence and completed count survive reload")
	resumed.health = 5
	check(progress.save_run(resumed) and progress.data.completed_levels == 1, "Replays do not count a completed level twice")
	var skipped := Run.new(2)
	skipped.phase = "victory"
	check(not progress.save_run(skipped), "Progress cannot skip an unbeaten level")
	var partial := Run.new(1)
	partial.start_wave()
	check(progress.save_run(partial) and progress.data.completed_levels == 1, "Partial next level cannot advance saved progress")
	var broken := FileAccess.open(progress.path,FileAccess.WRITE)
	broken.store_string("interrupted write")
	broken.close()
	reloaded.load_progress()
	check(not reloaded.blocked and reloaded.data.completed_levels == 1, "Damaged primary recovers the previous valid campaign copy")
	clean_test_save(progress.path)
	broken = FileAccess.open(progress.path,FileAccess.WRITE)
	broken.store_string("unknown data")
	broken.close()
	reloaded.load_progress()
	check(reloaded.blocked and not reloaded.save_run(resumed), "Unreadable campaign progress is preserved and blocks writes")
	check(FileAccess.get_file_as_string(progress.path) == "unknown data", "Blocked save is never overwritten")
	clean_test_save(progress.path)
	var legacy := {"version": 1, "sequence": 9, "medals": [3,1,2], "checkpoint": {"level": 3, "wave": 2}}
	while legacy.medals.size() < Catalog.COUNT: legacy.medals.append(0)
	var payload := JSON.stringify(legacy)
	var file := FileAccess.open(progress.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload": payload, "checksum": payload.sha256_text()}))
	file.close()
	reloaded.load_progress()
	check(not reloaded.blocked and reloaded.data.completed_levels == 3 and not reloaded.data.has("checkpoint") and not reloaded.data.has("medals"), "Legacy medals migrate to completed levels; active progress is removed")
	var migrated_sequence: int = int(reloaded.data.sequence)
	reloaded.load_progress()
	check(reloaded.data.sequence == migrated_sequence, "Migration is committed once")
	check(reloaded.restore_completed_levels(2) and reloaded.data.completed_levels == 2, "Explicit cloud restore can replace progress with an older count")
	check(not reloaded.restore_completed_levels(Catalog.COUNT + 1), "Out-of-range cloud progress cannot replace local data")
	clean_test_save(progress.path)
	var sandbox := VigilState.new(42)
	check(not sandbox.combat.scripted_spawns and sandbox.combat.spawn_on_path("basic",route).is_empty(), "Sandbox does not accept campaign spawns")
	print("Campaign: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func check_setup_refunds() -> void:
	for index in [0, 2, 19]:
		var setup := Run.new(index)
		var socket: int = setup.mission.sockets[0].index
		for kind in Balance.TOWERS:
			for level in range(1, Balance.MAX_TOWER_LEVEL + 1):
				setup.game.data.balance = 100000.0
				check(setup.build(socket, kind), "Setup builds every tower family")
				for tier in range(1, level):
					check(setup.upgrade(socket, Balance.BRANCHES[kind].keys()[0] if tier == 3 else ""), "Setup upgrades use shared transactions")
				var id := setup.tower_at(socket)
				var tower: Dictionary = setup.game.data.towers[id]
				var spent: float = 100000.0 - setup.game.data.balance
				check(setup.game.economy.sell_refund(tower) == spent, "Initial campaign quote refunds build and upgrade investment")
				check(setup.game.economy.sell(id, level + 1).is_empty(), "Setup refund still rejects a stale tower level")
				check(setup.sell(socket) and setup.game.data.balance == 100000.0, "Initial campaign sale returns every gold spent")
				check(setup.game.economy.sell(id).is_empty(), "Setup sale cannot pay twice")
	var battle := Run.new(0)
	var other := Run.new(0)
	check(battle.build(6, "rapid") and other.build(6, "rapid"), "Concurrent campaign runs build independently")
	var tower: Dictionary = battle.game.data.towers[battle.tower_at(6)]
	var other_tower: Dictionary = other.game.data.towers[other.tower_at(6)]
	check(battle.start_wave(), "First wave starts for refund boundary test")
	check(battle.wave == 0 and battle.wave_time == 0.0 and battle.game.economy.sell_refund(tower) == Balance.sell_refund(tower), "Normal refund starts immediately before any first-wave tick")
	check(other.game.economy.sell_refund(other_tower) == Balance.invested_cost(other_tower), "Starting one run leaves another run's setup refund intact")
	tower.earnings = 7.0
	var sale := battle.game.economy.sell(tower.id)
	check(sale.refund == Balance.sell_refund(tower) and sale.earnings == 7.0, "During-wave sale keeps normal refund and pays earnings separately")
	battle.next_spawn = battle.schedule.size()
	battle.tick(Balance.STEP)
	check(battle.wave == 1 and battle.phase == "planning", "Run reaches the next planning phase")
	check(battle.build(6, "rapid"), "Tower can be built between waves")
	tower = battle.game.data.towers[battle.tower_at(6)]
	check(battle.game.economy.sell_refund(tower) == Balance.sell_refund(tower), "Later planning never reopens full refunds")
	sale = battle.game.economy.sell(tower.id)
	check(sale.refund == Balance.sell_refund(tower), "Between-wave sale uses normal refund")
	for mode in ["creative", "survival"]:
		var world := VigilState.new(42, mode)
		world.data.first_property_required = false
		world.data.balance = 1000.0
		var id := world.economy.build("rapid", "0,0", 0)
		check(not id.is_empty(), "Open-world refund fixture builds")
		var world_tower: Dictionary = world.data.towers[id]
		check(world.economy.sell(id).refund == Balance.sell_refund(world_tower), "Open-world modes keep normal refunds")
	var definition := Balance.Content.level(0)
	other.game.economy.set_sale_rules(definition.without_component("test/no_refund", "setup_refund"))
	check(other.game.economy.sell_refund(other_tower) == Balance.sell_refund(other_tower), "Removing the attached component restores normal refunds")
	var component: VigilContentNode = Balance.Content.catalog().get_node("attribute/investment_refund")
	other.game.economy.set_sale_rules(definition.with_component("test/half_refund", "setup_refund", component, {"ratio": 0.5}))
	check(other.game.economy.sell_refund(other_tower) == Balance.invested_cost(other_tower) * 0.5, "Replacing a component uses its own refund configuration")
	var fresh := Run.new(0)
	check(fresh.build(6, "rapid"), "Restarted campaign starts a fresh setup")
	var fresh_tower: Dictionary = fresh.game.data.towers[fresh.tower_at(6)]
	check(fresh.game.economy.sell_refund(fresh_tower) == Balance.invested_cost(fresh_tower), "Component replacement never mutates shared campaign definitions")

func check_biome_portals() -> void:
	var definitions := Balance.portal_definitions()
	check(definitions.keys() == VigilWorld.ALL_STYLES, "All six biome portals are discoverable in biome order")
	var names: Array = []
	for style in definitions:
		var portal := Balance.Content.portal(style)
		check(portal != null and portal.id == Balance.Content.region(style).rule("portal"), "Biome resolves its own registered portal: " + style)
		check(definitions[style].name not in names, "Each biome has a distinct portal name")
		names.append(definitions[style].name)
		var description := Balance.rift_description(style, {}, true)
		check(description.contains("campaign entrance") and not description.contains("Attune") and not description.contains("Summons only"), "Campaign portal descriptions explain authored spawns: " + style)
		if style not in Balance.RIFTS:
			check(Balance.rift_strength(style) == 0 and not Balance.valid_tuning({"rifts": {style: {"strength": 1.0}}}), "Neutral portal discovery cannot introduce an effect: " + style)
	definitions.forest.name = "Changed preview"
	check(Balance.portal_definitions().forest.name == "Forest Rift", "Portal discovery returns independent presentation data")
	var frozen: Dictionary = preload("res://scripts/campaign/configuration.gd").gameplay_values({})
	check(frozen.rifts.keys() == Balance.RIFTS.keys(), "Campaign exports retain only the existing tunable portal kinds")
	for index in range(Catalog.COUNT):
		var mission := Catalog.level(index)
		var style: String = Catalog.CHAPTERS[index / Catalog.LEVELS_PER_CHAPTER].style
		check(mission.style == style, "Every campaign level uses its chapter biome")
		var groups: Array = []
		# Exercise the real wave scheduler at every entrance, including authored
		# cross-family enemies, which must still use the entrance biome's effect.
		for lane in range(mission.routes.size()):
			groups.append(["basic", 1, lane, 0.0, 1.0])
		var battle := Run.new(index, {"waves": {"0": {"groups": groups}}})
		check(battle.start_wave(), "Every campaign biome starts its entrance wave")
		battle.tick(0.001)
		check(battle.game.combat.enemies.size() == mission.routes.size(), "Every campaign entrance spawns its assigned group")
		for enemy in battle.game.combat.enemies:
			check(enemy.rift_style == style and enemy.path in mission.routes, "Campaign spawn retains its biome portal and authored route")
			check(is_equal_approx(enemy.max_hp, Balance.ENEMIES.basic.hp * Balance.rift_health_multiplier(style)), "Campaign portal applies its own health effect")
		var restored: RefCounted = Run.from_checkpoint(JSON.parse_string(JSON.stringify(battle.checkpoint())))
		check(restored != null and restored.mission.style == style, "Saved campaign restores its biome portal")
		if restored != null:
			restored.tick(0.001)
			for enemy in restored.game.combat.enemies:
				check(enemy.rift_style == style, "Restored campaign entrance keeps its portal kind")
	print("PASS GROUP: six campaign portals, all level entrances, effects and checkpoint identity")

func check_effect_cleanup() -> void:
	for outcome in ["planning", "victory", "defeat"]:
		var battle := Run.new(0)
		battle.start_wave()
		battle.next_spawn = battle.schedule.size()
		if outcome == "victory":
			battle.wave = battle.mission.waves.size() - 1
		elif outcome == "defeat":
			battle.health = 0
		var finished_count := [0]
		battle.finished.connect(func(): finished_count[0] += 1)
		for kind in ["shot", "death", "relic_drop"]:
			battle.game.combat.add_effect({"kind": kind, "life": 0.5, "max_life": 0.5})
		battle.tick(Balance.STEP)
		check(battle.phase == outcome, "Wave reaches %s with effects still visible" % outcome)
		check(finished_count[0] == 0, "Result waits for lingering effects")
		var active: float = battle.game.data.active_seconds
		var balance: float = battle.game.data.balance
		var life: float = battle.game.combat.effects[0].life
		battle.tick(0.1)
		check(battle.game.combat.effects[0].life < life, "Effects keep fading during %s" % outcome)
		battle.tick(1.0)
		battle.tick(1.0)
		check(battle.game.combat.effects.is_empty(), "All transient effects expire during %s" % outcome)
		check(battle.game.data.active_seconds == active and battle.game.data.balance == balance, "Effect cleanup cannot advance combat or repay rewards")
		check(finished_count[0] == (0 if outcome == "planning" else 1), "Result appears exactly once after cleanup")
