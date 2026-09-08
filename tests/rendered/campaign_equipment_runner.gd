extends "res://tests/rendered/unified_menu_runner.gd"

const Run = preload("res://scripts/campaign/run.gd")
const Progress = preload("res://scripts/campaign/progress.gd")

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://campaign-equipment-" + str(Time.get_ticks_usec())
	root.add_child(app)
	app.set_process(false)
	app.show_game_menu()
	menu = app.slot_menu
	root.size = Vector2i(390, 844)
	var rules := {"waves": {"0": {"groups": [["warden", 2, 0, 0, 0.05]]}}}
	for mode in ["survival", "creative"]:
		menu.campaign_slots.base_path = app.game.save_path + mode
		var value: Dictionary = menu.campaign_slots.create(0, mode, "Equipment journey", {"0": {"overrides": rules}, "1": {"overrides": rules}})
		app.open_campaign_slot(0, value)
		var campaign = app.campaign
		campaign.set_process(false)
		campaign.start_mission(0)
		check(campaign.run.start_wave(), "Start boss wave")
		campaign.run.tick(0.1)
		campaign.run.build(int(campaign.run.mission.pads[0]), "rapid")
		for enemy in campaign.run.game.combat.enemies:
			campaign.run.game.combat.hit(enemy, 1e12, campaign.run.game.data.towers.keys()[0], "", false)
		var earned: Dictionary = campaign.run.game.data.relics.duplicate(true)
		check(earned.size() == 6, "Two boss encounters award distinct complete sets")
		campaign.run.phase = "victory"
		campaign.save_progress()
		campaign.start_mission(1)
		check(campaign.run.game.data.relics == earned, "Next level carries all equipment")
		check(campaign.run.build(int(campaign.run.mission.pads[0]), "rapid"), "Build a new level tower")
		check(campaign.run.game.economy.equip_relic(campaign.run.tower_at(int(campaign.run.mission.pads[0])), earned.keys()[0], ""), "Carried equipment equips on new towers")
		campaign.restart_mission(1)
		check(campaign.run.game.data.relics == earned and campaign.run.game.data.towers.is_empty(), "Restart keeps equipment with fresh towers")
		campaign.run.start_wave()
		campaign.run.tick(0.1)
		campaign.run.build(int(campaign.run.mission.pads[0]), "rapid")
		for enemy in campaign.run.game.combat.enemies:
			campaign.run.game.combat.hit(enemy, 1e12, campaign.run.game.data.towers.keys()[0], "", false)
		check(campaign.run.game.data.relics.size() == 12, "Later level awards its own equipment")
		campaign.save_progress()
		var saved: Dictionary = menu.campaign_slots.summary(0)
		check(saved.relics.size() == 12 and saved.checkpoint.is_empty(), "Disk save preserves equipment independently of attempts")
		campaign.queue_free()
		app.campaign = null
		await frames()
		app.open_campaign_slot(0, saved)
		campaign = app.campaign
		campaign.set_process(false)
		campaign.start_mission(0)
		check(campaign.run.game.data.relics.size() == 12, "Reopening restores the collection")
		campaign.run.start_wave()
		campaign.run.tick(0.1)
		campaign.run.build(int(campaign.run.mission.pads[0]), "rapid")
		for enemy in campaign.run.game.combat.enemies:
			campaign.run.game.combat.hit(enemy, 1e12, campaign.run.game.data.towers.keys()[0], "", false)
		check(campaign.run.game.data.relics.size() == 12, "Replaying encounters does not duplicate rewards")
		var collection: Dictionary = campaign.run.game.data.relics.duplicate(true)
		var item: String = earned.keys()[0]
		for level in Run.Catalog.COUNT:
			campaign.start_mission(level)
			var state: Dictionary = campaign.run.game.data
			check(state.relics == collection, "Entire collection carries into level %d in %s" % [level + 1, mode])
			check(campaign.run.game.combat.Relics.available(state).size() == collection.size(), "Previously equipped items become available in the new level")
			var socket := int(campaign.run.mission.pads[0])
			check(campaign.run.build(socket, "rapid" if level % 2 == 0 else "heavy"), "Build a different strategy's tower")
			check(campaign.run.game.economy.equip_relic(campaign.run.tower_at(socket), item, ""), "Reuse the same earned item on the new tower")
			campaign.run.phase = "victory"
			campaign.save_progress()
			check(menu.campaign_slots.summary(0).relics == collection, "Saving victory includes gear still equipped on towers")
		var isolated := Progress.new()
		var other := Run.new()
		isolated.apply_equipment(other)
		check(other.game.data.relics.is_empty(), "Separate campaigns keep independent collections")
		var invalid := saved.duplicate(true)
		invalid.relics = {"1,0": "unknown"}
		check(not menu.campaign_slots.valid(invalid), "Unknown saved equipment is rejected")
		invalid = saved.duplicate(true)
		invalid.erase("relics")
		check(menu.campaign_slots.valid(invalid), "Older saves remain compatible")
		campaign.queue_free()
		app.campaign = null
		await frames()
	print("CAMPAIGN_EQUIPMENT: %d checks, %d failures" % [checks, failures.size()])
	app.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
