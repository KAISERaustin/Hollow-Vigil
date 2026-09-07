extends "res://tests/test_runner.gd"
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Run = preload("res://scripts/campaign/run.gd")

func run() -> void:
	for index in range(Configuration.Catalog.COUNT):
		var authored := Configuration.Catalog.level(index)
		var mission := Configuration.resolve(index)
		check(mission.gold == authored.gold and mission.reward == authored.reward and mission.waves == authored.waves and mission.tuning == authored.tuning and mission.flame == 20, "Level %d defaults preserved" % (index + 1))
		for wave in range(mission.waves.size()):
			check(Configuration.schedule(mission, wave) == Balance.Content.wave(index, wave).schedule(), "Default wave schedule preserved")
	var custom := {"gold": 999.0, "flame": 30, "reward": 50.0, "tuning": {"towers": {"rapid": {"cost": 120.0}}}, "waves": {"0": {"groups": [["basic", 3, 1, 2.0, 0.5]], "reward": 77.0, "tuning": {"enemies": {"basic": {"hp": 222.0}}, "towers": {"rapid:2": {"cost": 33.0}}}}}}
	check(Configuration.valid_level(6, custom), "Per-level and per-wave overrides validate")
	var store := Configuration.new()
	store.path = "user://campaign-config-test-" + str(Time.get_ticks_usec()) + ".save"
	check(store.save_level(6, custom), "Campaign configuration persists separately")
	var reloaded := Configuration.new()
	reloaded.path = store.path
	reloaded.load_configuration()
	check(not reloaded.blocked and reloaded.overrides(6) == JSON.parse_string(JSON.stringify(custom)), "Per-level configuration survives reload")
	var battle := Run.new(6, reloaded.overrides(6))
	check(battle.game.data.balance == 999.0 and battle.health == 30 and battle.game.tuning.towers.rapid.cost == 120.0, "Mission applies starting level stats")
	check(Run.new(5).game.data.balance == Configuration.Catalog.level(5).gold, "Unassigned level unchanged")
	check(battle.start_wave() and battle.schedule.size() == 3 and battle.schedule[0].at == 2.0 and battle.schedule[-1].at == 3.0 and battle.schedule[0].lane == 1, "Wave uses authored-node schedule with overrides")
	check(battle.game.tuning.enemies.basic.hp == 222.0 and Balance.upgrade_cost({"kind": "rapid", "level": 1}, battle.game.tuning) == 33.0, "Wave stats use shared enemy and upgrade calculations")
	battle.next_spawn = battle.schedule.size()
	var balance: float = battle.game.data.balance
	battle.tick(Balance.STEP)
	check(battle.phase == "planning" and battle.game.data.balance == balance + 77.0, "Wave pays configured reward once")
	battle.tick(Balance.STEP)
	check(battle.game.data.balance == balance + 77.0, "Reward cannot repeat")
	battle.start_wave()
	check(not battle.game.tuning.has("enemies") and Balance.upgrade_cost({"kind": "rapid", "level": 1}, battle.game.tuning) == 120.0, "Next wave restores level rules without leaking prior overrides")
	var difference := Configuration.tuning_difference({"towers": {"rapid": {"cost": 120.0}}}, {"towers": {"rapid": {"cost": 120.0}, "rapid:2": {"cost": 60.0}}})
	check(difference.towers["rapid:2"].cost == 60.0, "Override comparison uses scaled upgrade prices")
	for bad in [{"gold": -1}, {"flame": 0}, {"reward": INF}, {"tuning": {"session": {"start": {"starting_gold": 1}}}}, {"waves": {"99": {}}}, {"waves": {"0": {"groups": []}}}, {"waves": {"0": {"groups": [["bad", 1, 0, 0, 1]]}}}, {"waves": {"0": {"groups": [["basic", 1, 9, 0, 1]]}}}, {"towers": {}}]:
		check(not Configuration.valid_level(6, bad), "Malformed campaign configuration rejected")
		check(Run.new(6, bad).game.data.balance == Configuration.Catalog.level(6).gold, "Malformed overrides safely retain defaults")
	check(store.save_level(6, {}) and store.overrides(6).is_empty(), "Reset configuration restores authored values only")
	check(store.data.keys().size() == 3 and not store.data.has("completed_levels"), "Configuration schema excludes progression")
	clean_test_save(store.path)
	print("CAMPAIGN CONFIGURATION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
