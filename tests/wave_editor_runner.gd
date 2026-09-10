extends "res://tests/test_runner.gd"
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Editor = preload("res://scripts/campaign/wave_editor.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Build = preload("res://scripts/persistence/reusable_build.gd")
const Playthrough = preload("res://scripts/persistence/campaign_playthrough.gd")

func run() -> void:
	check(Configuration.spawn_kinds().size() == 24, "Picker includes 18 enemies and six bosses")
	for index in Configuration.Catalog.COUNT:
		var original := Configuration.resolve(index)
		var custom := Editor.append_wave(index, {})
		var mission := Configuration.resolve(index, custom)
		var last: int = mission.waves.size() - 1
		check(Configuration.valid_level(index, custom) and mission.waves.size() == original.waves.size() + 1, "Every level accepts added waves")
		check(mission.waves[last].is_empty() and mission.wave_rules[last] == mission.wave_rules[0], "New wave is empty with first-wave settings")
		check(Configuration.schedule(mission, last).is_empty(), "Added waves reuse the wave-node scheduler")
		custom.waves[str(last)].groups = [[Configuration.spawn_kinds()[-1], 2, original.routes.size() - 1, 3.0, 0.5]]
		mission = Configuration.resolve(index, custom)
		var schedule := Configuration.schedule(mission, last)
		check(schedule.size() == 2 and schedule[0].lane == original.routes.size() - 1 and schedule[-1].at == 3.5, "Bosses use chosen portal and spawn timing on every level")
		var reduced := Editor.remove_wave(index, custom, 0)
		check(Configuration.resolve(index, reduced).waves[-1] == mission.waves[-1], "Removing waves preserves later composition during renumbering")
		check(Configuration.resolve(index).waves == original.waves, "Editor leaves shared authored nodes unchanged")
	var rules := {"wave_count": 3, "waves": {"0": {"groups": []}, "1": {"groups": [["basic", 2, 0, 0.0, 0.5], ["basic", 4, 1, 2.0, 0.2]], "reward": 17.0}, "2": {"groups": [], "reward": 999.0}}}
	check(Configuration.valid_level(6, rules), "Populated level can retain empty placeholders")
	var resized := Editor.set_count(6, rules, 1, "basic", 15)
	var groups: Array = resized.waves["1"].groups
	check(groups[0][1] == 5 and groups[1][1] == 10 and groups[1][2] == 1 and groups[1][3] == 2.0, "Quick count apportions totals without changing timing and portals")
	check(not Configuration.valid_level(6, Editor.set_count(6, rules, 1, "basic", 0)), "Cannot remove last enemy from level")
	check(not Configuration.valid_level(6, Editor.remove_wave(6, rules, 1)), "Cannot remove last populated wave")
	for mode in ["creative", "survival"]:
		var battle := Run.new(6, rules, mode)
		check(battle.start_wave() and battle.wave == 1 and battle.schedule.size() == 6, "Both modes skip opening empty waves")
		var unchanged := battle.rules.duplicate(true)
		check(not battle.apply_configuration(resized) and battle.rules == unchanged, "Active wave changes are rejected without mutation")
		battle.next_spawn = battle.schedule.size()
		var gold: float = battle.game.data.balance
		battle.tick(Balance.STEP)
		check(battle.phase == "victory" and battle.wave == 3 and battle.game.data.balance == gold + 17.0, "Trailing empty waves give no reward in either mode")
		check(Run.valid_checkpoint(battle.checkpoint()), "Custom victory checkpoint remains valid")
	var battle := Run.new(6, {}, "creative")
	battle.wave = 2
	check(battle.apply_configuration(Editor.remove_wave(6, {}, 0), 0) and battle.wave == 1, "Deleting cleared wave remaps live progress without replay")
	var many := {}
	for wave in 40: many = Editor.append_wave(0, many)
	check(Configuration.resolve(0, many).waves.size() == Configuration.Catalog.level(0).waves.size() + 40, "Wave count is independent of authored count")
	var store := Configuration.new()
	store.path = "user://wave-editor-%d.save" % Time.get_ticks_usec()
	check(store.save_level(6, resized), "Custom composition persists")
	var reload := Configuration.new()
	reload.path = store.path
	reload.load_configuration()
	check(reload.overrides(6) == JSON.parse_string(JSON.stringify(resized)), "Custom waves survive reload")
	var build := Build.capture("campaign", battle.game, {"6": {"overrides": resized}}, "level", 6, {"timing": true, "composition": true, "rewards": true}, "Wave editor", "")
	check(not build.is_empty() and not Build.decode(Build.encode(build)).is_empty(), "Reusable build shares custom count and empty waves")
	if not build.is_empty():
		var restored := Build.campaign_level(build, 6)
		check(restored.ok and Configuration.resolve(6, restored.level.overrides).waves == Configuration.resolve(6, resized).waves, "Imported build reproduces exact composition")
	var frozen := Playthrough.freeze_level(6, resized)
	check(Configuration.valid_level(6, frozen) and frozen.wave_count == 3 and frozen.waves["0"].groups.is_empty(), "Full campaign freeze preserves custom shape")
	var paid := {"wave_count": 1, "waves": {"0": {"groups": [["basic", 1, 0, 0.0, 1.0, 11.0], ["basic", 1, 0, 0.0, 1.0, 29.0], ["warden", 1, 0, 0.0, 1.0, 43.0]], "reward": 17.0}}}
	var combat := Run.new(0, paid, "survival")
	check(combat.build(int(combat.mission.pads[0]), "rapid"), "Reward test builds a real tower")
	var owner: String = combat.game.data.towers.keys()[0]
	combat.start_wave()
	combat.tick(Balance.STEP)
	var rewards := []
	for enemy in combat.game.combat.enemies.duplicate():
		var before: float = combat.game.data.towers[owner].earnings
		combat.game.combat.hit(enemy, 1e12, owner, "", true, true)
		rewards.append(combat.game.data.towers[owner].earnings - before)
	check(rewards == [11.0, 29.0, 43.0], "Enemy and boss kills pay each group's own gold without shared-state leaks")
	var paid_build := Build.capture("campaign", combat.game, {"0": {"overrides": paid}}, "level", 0, {"timing": true, "composition": true, "rewards": true}, "Paid waves", "")
	check(not paid_build.is_empty(), "Group reward builds validate")
	if not paid_build.is_empty():
		var imported := Build.campaign_level(Build.decode(Build.encode(paid_build)), 0)
		check(imported.ok and Configuration.schedule(Configuration.resolve(0, imported.level.overrides), 0)[2].payout == 43, "Shared Survival build preserves per-group defeat gold")
	var reset := Editor.reset_wave(0, paid, 0)
	check(reset.waves["0"].groups == Configuration.Catalog.level(0).waves[0], "Wave reset restores authored enemies and removes custom defeat gold")
	clean_test_save(store.path)
	print("WAVE EDITOR: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
