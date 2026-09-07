extends "res://tests/public_builds_runner.gd"
const Playthrough = preload("res://scripts/persistence/campaign_playthrough.gd")
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Session = preload("res://scripts/campaign/session.gd")

func run() -> void:
	var rules := {"gold": 1000.0, "waves": {"0": {"groups": [["basic", 4, 0, 0.0, 5.0]], "tuning": {"enemies": {"basic": {"hp": 234.0}}}}}}
	var source := Run.new(0, rules, "creative")
	check(source.build(6, "rapid"), "Creative shares the actual campaign economy")
	var loadout := {}
	for key in ["towers", "next_tower", "relics", "balance"]: loadout[key] = source.game.data[key]
	var code := Playthrough.encode({"0": {"overrides": rules, "loadout": loadout}, "19": {"overrides": {"gold": 9876.0}}}, "My campaign", "Exact schedules")
	check(not code.is_empty(), "Complete playthrough serializes")
	if code.is_empty(): quit(1); return
	var value := Playthrough.decode(code)
	check(value.levels.size() == 20 and value.levels["19"].overrides.gold == 9876, "One build carries all levels")
	for index in 20:
		var level := Playthrough.level_build(value, index)
		var survival := Run.new(index, level.overrides, "survival")
		check(not survival.can_author() and not survival.apply_configuration({"gold": 99999}), "Survival rejects authoring at service boundary")
		var baseline := Configuration.resolve(index, rules if index == 0 else {"gold": 9876.0} if index == 19 else {})
		check(Configuration.gameplay_values(survival.mission.tuning) == Configuration.gameplay_values(baseline.tuning), "All level stats match exported source")
		for wave in survival.mission.waves.size():
			check(Configuration.schedule(survival.mission, wave) == Configuration.schedule(baseline, wave), "Exact wave timing and composition survives")
	Playthrough.LevelBuild.apply_loadout(source, Playthrough.level_build(value, 0))
	check(source.game.data.towers.size() == 1, "Optional tower loadout survives")
	var invalid := value.duplicate(true)
	invalid.levels["0"].overrides.waves["0"].groups[0][2] = 99
	check(not Playthrough.valid(invalid), "Reject invalid lane")
	invalid = value.duplicate(true)
	invalid.levels.erase("19")
	check(not Playthrough.valid(invalid), "Reject incomplete playthrough")
	var stats := Playthrough.decode(Playthrough.encode(value.levels, "Rules", "", true))
	check(not stats.levels["0"].has("loadout"), "Rules-only omits loadouts")
	var battle := Run.new(0, rules, "creative")
	check(battle.start_wave(), "Creative can start waves")
	battle.tick(0.1)
	var enemy: Dictionary = battle.game.combat.enemies.values()[0] if battle.game.combat.enemies is Dictionary else battle.game.combat.enemies[0]
	var hp: float = enemy.hp
	var changed := rules.duplicate(true)
	changed.waves["0"].groups[0] = ["fast", 6, 0, 0.0, 1.0]
	check(battle.apply_configuration(changed), "Active wave can change enemy kind, count and timing")
	check(battle.schedule.size() == 5 and battle.schedule[0].at == 1.0 and enemy.hp == hp, "Existing spawn preserved and remaining group regenerated")
	battle.tick(1.0)
	check(battle.spawned_counts[0] == 2, "Updated pending spawn runs on original wave clock")
	check(battle.apply_configuration(changed) and battle.schedule.size() == 4, "Repeated save never duplicates prior spawns")
	check(Run.new(0).mission.waves != battle.mission.waves and source.spawned_counts.is_empty(), "Definitions and other instances unchanged")
	var session := Session.new()
	session.path = "user://campaign-session-test-%d.save" % Time.get_ticks_usec()
	check(session.select_build("survival", code), "Selected campaign persists")
	var reread := Session.new()
	reread.path = session.path
	reread.load_session()
	check(reread.data.selections.survival == code and reread.identity("survival") != "default", "Reopen restores exact downloaded rules and progress identity")
	check(reread.data.selections.creative == "", "Creative selection isolated from Survival")
	var slots := VigilSaveSlots.new()
	slots.base_path = session.path + ".slots"
	check(slots.save_shared(code) and slots.shared_configurations("campaign").size() == 1, "Shared local library roundtrip")
	check(slots.shared_configurations("campaign_build").is_empty() and slots.configurations().is_empty(), "Full campaigns do not contaminate level or Infinite catalogs")
	var cloud := FakeCloud.new()
	cloud.player_id = preload("res://scripts/cloud/cloud_codec.gd").uuid()
	cloud.succeeds = true
	root.add_child(cloud)
	var service := preload("res://scripts/cloud/public_builds.gd").new()
	service.cloud = cloud
	service.outbox_path = session.path + ".outbox"
	root.add_child(service)
	check(service.queue_export(code), "Whole campaign uses existing durable upload queue")
	await service.flush()
	check(service.outbox.is_empty() and cloud.sent.size() == 1, "Whole campaign publishes through shared service")
	var fixture := FileAccess.open("res://artifacts/campaign-playthrough-fixture.json", FileAccess.WRITE)
	fixture.store_string(code)
	fixture.close()
	for file in DirAccess.open(slots.configurations_path()).get_files(): DirAccess.remove_absolute(slots.configurations_path().path_join(file))
	DirAccess.remove_absolute(slots.configurations_path())
	for suffix in ["", ".tmp", ".bak", ".outbox"]: DirAccess.remove_absolute(session.path + suffix)
	service.queue_free()
	cloud.queue_free()
	print("CAMPAIGN PLAYTHROUGH: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
