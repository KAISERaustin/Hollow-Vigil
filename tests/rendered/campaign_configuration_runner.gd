extends "res://tests/rendered/unified_menu_runner.gd"

const Configuration = preload("res://scripts/campaign/configuration.gd")
const Run = preload("res://scripts/campaign/run.gd")

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://campaign-global-%d.save" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_game_menu()
	menu = app.slot_menu
	menu.resume_game()
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960), Vector2i(844, 390)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		menu.campaign_slots.base_path = app.game.save_path + str(dimensions.x)
		var old_rules := {"gold": 987.0, "waves": {"0": {"reward": 103.0, "groups": [["basic", 12, 0, 2.0, 0.5]], "tuning": {"enemies": {"basic": {"hp": 999.0, "speed": 27.0}}}}}}
		var levels := {"7": {"overrides": old_rules}}
		var saved: Dictionary = menu.campaign_slots.create(0, "creative", "Global campaign", levels)
		var other: Dictionary = menu.campaign_slots.create(1, "creative", "Independent campaign")
		var checkpoint_run := Run.new(7, old_rules, "creative")
		checkpoint_run.start_wave()
		saved.checkpoint = checkpoint_run.checkpoint()
		check(menu.campaign_slots.save_slot(0, saved), "Save a wave-start checkpoint before editing from the map")
		app.open_campaign_slot(0, saved)
		var campaign: Control = app.campaign
		campaign.set_process(false)
		await press("CampaignMapMenu")
		await press("EditRules")
		check(menu.screen == "rules" and button("EditLevel1") == null, "Edit rules opens content categories without levels")
		check(button("SessionCategory") == null, "Campaign rules do not expose level starting resources")
		await capture("campaign-global-home-%d" % dimensions.x)
		var edited := {}
		for category in Build.STAT_GROUPS:
			await press(category.capitalize() + "Category")
			var controls: Control = menu.rules_editor
			var definitions: Dictionary = Balance.TOWERS if category == "towers" else Balance.definitions(category)
			check(controls.selector.item_count == definitions.size(), "Every %s type is available" % category)
			for item in controls.selector.item_count:
				check(controls.selector.get_item_metadata(item) == definitions.keys()[item], "Selector contains the registered %s identity" % category)
			var kind: String = controls.editing_kind()
			var stat: String = "damage" if category == "towers" else "hp" if category in ["enemies", "bosses"] else controls.inputs.keys()[0]
			var number: SpinBox = controls.inputs[stat]
			var next := minf(number.max_value, number.value + number.step * 3)
			edited[category] = {kind: {stat: next}}
			# Apply commits typed values even when the field has not lost focus.
			number.get_line_edit().text = str(next)
			await capture("campaign-global-%s-%d" % [category, dimensions.x])
			await press("BackButton")
			check(menu.rules_editor.category_list.visible and menu.scroll.scroll_vertical == 0, "Category Back retains the draft and resets scrolling")
		check(campaign.level_setup(7).overrides == old_rules, "Draft leaves live and saved campaign rules unchanged")
		await press("ApplyRules")
		check(menu.screen == "game_menu" and campaign.run == null, "Global apply returns to Menu without starting a level")
		verify_all_levels(campaign, edited)
		var updated: Dictionary = campaign.level_setup(7).overrides
		check(updated.gold == 987.0 and updated.waves["0"].reward == 103.0 and updated.waves["0"].groups == old_rules.waves["0"].groups, "Global edits preserve starting resources, wave rewards and spawn settings")
		check(updated.waves["0"].tuning.enemies.basic.speed == 27.0, "Unedited legacy statistics stay intact")
		check(menu.campaign_slots.summary(1) == other and app.game.tuning.is_empty(), "Other Campaign slots and Infinite remain independent")
		var persisted: Dictionary = menu.campaign_slots.summary(0)
		check(persisted.levels == campaign.campaign_save.levels, "All levels persist in one complete save")
		var resumed := Run.from_checkpoint(persisted.checkpoint)
		check(resumed.game.tuning.enemies.basic.hp == edited.enemies.basic.hp, "Map edits reach the stored wave checkpoint")
		var exported := Build.capture("campaign", null, campaign.session_levels(), "all", -1, Build.all_contents("campaign"), "Global export", "")
		for entry in exported.data.levels.values():
			check(entry.stats.enemies.basic.hp == edited.enemies.basic.hp, "Export includes the global enemy rule on every level")
		await press("EditRules")
		await press("EnemiesCategory")
		menu.rules_editor.inputs.hp.value = 456
		await press("CancelRules")
		await press("ConfirmAction")
		check(menu.campaign_slots.summary(0) == persisted, "Discard leaves every level and checkpoint unchanged")
		menu.resume_game()
		campaign.show_briefing(7)
		check(campaign.page == "battle", "Choosing the checkpoint level resumes its battle")
		campaign.run.tick(2.1)
		var held_run: RefCounted = campaign.run
		var enemies: Array = held_run.game.combat.enemies.duplicate(true)
		var wave_time: float = held_run.wave_time
		var prior_paused: bool = campaign.paused
		app.show_game_menu()
		await press("EditRules")
		await press("EnemiesCategory")
		menu.rules_editor.inputs.hp.get_line_edit().text = "321"
		await press("ApplyRules")
		check(campaign.run == held_run and held_run.wave_time == wave_time and held_run.game.combat.enemies == enemies, "Global live edits preserve enemies and wave progress")
		check(held_run.game.tuning.enemies.basic.hp == 321 and Run.from_checkpoint(held_run.checkpoint()).game.tuning.enemies.basic.hp == 321, "Live and recovery rules both receive the global change")
		await press("EditRules")
		await press("EnemiesCategory")
		await press("ResetSelectedBalance")
		await press("ApplyRules")
		verify_all_levels(campaign, {"enemies": {"basic": {"hp": Balance.ENEMIES.basic.hp}}})
		menu.resume_game()
		check(campaign.paused == prior_paused, "Resume restores the earlier pause state")
		campaign.close()
		await frames()
		app.open_campaign_slot(0, menu.campaign_slots.summary(0))
		app.campaign.set_process(false)
		check(app.campaign.level_setup(29).overrides.tuning.enemies.basic.hp == Balance.ENEMIES.basic.hp, "Reset survives closing and reopening the campaign")
		app.campaign.close()
		await frames()
	# Legacy authoring storage uses the same all-level composition and atomic write.
	app.show_campaign()
	var legacy: Control = app.campaign
	legacy.set_process(false)
	legacy.select_campaign("creative", "")
	legacy.configuration.blocked = true
	var before: Dictionary = legacy.session_levels()
	check(not legacy.save_campaign_tuning({"enemies": {"basic": {"hp": 222.0}}}) and legacy.session_levels() == before, "Failed save keeps all prior rules intact")
	legacy.configuration.blocked = false
	check(legacy.save_campaign_tuning({"enemies": {"basic": {"hp": 222.0}}}), "Legacy campaign saves all levels atomically")
	verify_all_levels(legacy, {"enemies": {"basic": {"hp": 222.0}}})
	legacy.select_campaign("survival", "")
	check(not legacy.save_campaign_tuning({"enemies": {"basic": {"hp": 333.0}}}), "Survival rejects global editing")
	app.queue_free()
	await frames()
	print("CAMPAIGN GLOBAL RULES: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func verify_all_levels(campaign: Control, edited: Dictionary) -> void:
	for index in Configuration.Catalog.COUNT:
		var mission := Configuration.resolve(index, campaign.level_setup(index).overrides)
		for wave in mission.wave_rules:
			for category in edited:
				for kind in edited[category]:
					for stat in edited[category][kind]:
						check(is_equal_approx(Balance.configuration_value(category, kind, stat, wave.tuning), edited[category][kind][stat]), "Level %d wave rules use global %s %s %s" % [index + 1, category, kind, stat])
