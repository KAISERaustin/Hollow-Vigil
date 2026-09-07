extends "res://tests/public_builds_runner.gd"

const CampaignBuild = preload("res://scripts/persistence/campaign_build.gd")

func run() -> void:
	var slots := VigilSaveSlots.new()
	slots.base_path = "user://shared-config-test-%d" % Time.get_ticks_usec()
	var rules := {"gold": 1234.0, "tuning": {"enemies": {"basic": {"hp": 444.0}}}, "waves": {"1": {"reward": 432.0, "tuning": {"enemies": {"basic": {"hp": 555.0}}}}}}
	var run := CampaignBuild.Run.new(0, rules)
	check(run.build(6, "rapid"), "Campaign source places a tower")
	var stats_code := CampaignBuild.encode(0, rules, run.game, "Wave rules", "A new challenge", true)
	var build_code := CampaignBuild.encode(0, rules, run.game, "Tower opening", "A prepared defense", false)
	check(not stats_code.is_empty() and not build_code.is_empty(), "Campaign supports both share choices")
	var stats := CampaignBuild.decode(stats_code)
	var build := CampaignBuild.decode(build_code)
	check(not stats.has("loadout") and stats.overrides.waves["1"].tuning.enemies.basic.hp == 555.0, "Stats retain wave changes without towers")
	check(build.loadout.towers.size() == 1 and not build.has("cloud"), "Build includes towers without account identity")
	var fresh := CampaignBuild.Run.new(0, stats.overrides)
	CampaignBuild.apply_loadout(fresh, stats)
	check(fresh.game.data.towers.is_empty() and fresh.wave == 0 and fresh.game.data.balance == 1234.0, "Stats create a fresh campaign mission")
	var prepared := CampaignBuild.Run.new(0, build.overrides)
	CampaignBuild.apply_loadout(prepared, build)
	check(prepared.game.data.towers.size() == 1 and prepared.wave == 0, "Build starts campaign with towers and no completed waves")
	prepared.game.data.towers.values()[0].level = 2
	check(run.game.data.towers.values()[0].level == 1 and build.loadout.towers.values()[0].level == 1, "Imported tower state is independent")
	var invalid := build.duplicate(true)
	invalid.loadout.towers.values()[0].region = "99,99"
	check(not CampaignBuild.valid(invalid), "Invalid campaign tower placement rejected")
	check(CampaignBuild.decode("bad").is_empty(), "Malformed campaign code rejected quietly")
	check(slots.save_shared(stats_code) and slots.save_shared(build_code), "Both campaign kinds save locally")
	check(slots.shared_configurations("campaign_stats").size() == 1 and slots.shared_configurations("campaign_build").size() == 1 and slots.configurations().is_empty(), "Libraries separate campaign builds, stats and Infinite Worlds")
	var cloud := FakeCloud.new()
	cloud.player_id = preload("res://scripts/cloud/cloud_codec.gd").uuid()
	cloud.succeeds = true
	root.add_child(cloud)
	var service := preload("res://scripts/cloud/public_builds.gd").new()
	service.cloud = cloud
	service.outbox_path = slots.base_path + ".cfg"
	root.add_child(service)
	var infinite := VigilState.new(42, "survival", {"enemies": {"basic": {"hp": 333.0}}})
	var infinite_code := slots.export_build(infinite, "Survival configuration")
	check(not infinite_code.is_empty(), "Infinite Survival can share a complete configuration")
	for code in [stats_code, build_code, infinite_code, VigilSaveSlots.Stats.encode(infinite.tuning, "Stats only")]:
		check(service.queue_export(code), "Shared upload accepts validated configuration")
	await service.flush()
	check(service.outbox.is_empty() and cloud.sent.size() == 4, "All share kinds use the existing durable publication service")
	for file in DirAccess.open(slots.configurations_path()).get_files(): DirAccess.remove_absolute(slots.configurations_path().path_join(file))
	DirAccess.remove_absolute(slots.configurations_path())
	DirAccess.remove_absolute(service.outbox_path)
	service.queue_free()
	cloud.queue_free()
	print("Shared configurations: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
