extends "res://tests/rendered/save_slots_runner.gd"

class Community extends Node:
	signal changed
	signal respond
	var entry: Dictionary = {}
	var fail := false
	var delay := false
	var status := ""
	var outbox: Array = []
	var sent: Array = []
	func list_configurations(_page: int, _kind: String, _level: int = -1) -> Dictionary:
		if delay: await respond
		if fail: return {"ok": false}
		return {"ok": true, "data": [{"title": entry.name, "description": entry.description, "author_name": "Builder", "id": "fixture"}]}
	func read_build(_id: String) -> Dictionary: return entry
	func queue_export(code: String) -> bool:
		sent.append(VigilSaveSlots.new().shared_entry(code))
		return true
	func flush() -> void:
		status = "Configuration published to Community."
		changed.emit()

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://shared-ui-%d.save" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.public_builds.queue_free()
	var community := Community.new()
	app.add_child(community)
	app.public_builds = community
	app.show_save_slots()
	var menu: Control = app.slot_menu
	menu.slots.base_path = app.game.save_path + "-library"
	var code := VigilSaveSlots.Stats.encode({"enemies": {"basic": {"hp": 222.0}}}, "Community challenge", "Stronger enemies, fresh start")
	community.entry = menu.slots.shared_entry(code)
	menu.show_creation(0)
	menu.show_stat_configurations(0)
	menu.find_child("CommunityConfigurations", true, false).pressed.emit()
	await frame()
	check(menu.find_child("UseStatConfiguration", true, false) != null, "Community stats show selectable metadata cards")
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await frame()
		await Harness.capture(app, "community-stats-" + str(dimensions.x))
		check(menu.card.get_global_rect().encloses(menu.find_child("UseStatConfiguration", true, false).get_global_rect()), "Community stat selection fits " + str(dimensions.x))
	menu.find_child("UseStatConfiguration", true, false).pressed.emit()
	await frame()
	check(menu.selected_configuration.name == "Community challenge", "Community stats return to new game")
	menu.find_child("ModeSurvival", true, false).pressed.emit()
	menu.find_child("CreateSave", true, false).pressed.emit()
	await frame()
	check(app.game.tuning.enemies.basic.hp == 222.0 and app.game.data.towers.is_empty(), "Community stats create a fresh Survival world")
	app.show_save_slots(true)
	var includes: OptionButton = menu.find_child("ShareConfigurationContents", true, false)
	check(includes.item_count == 2, "Sharing offers exactly towers plus stats or stats only")
	includes.select(1)
	includes.item_selected.emit(1)
	menu.find_child("SetupName", true, false).text = "Shared rules"
	menu.find_child("SaveConfiguration", true, false).pressed.emit()
	check(community.sent.size() == 1 and community.sent[0].kind == "stats", "Stats upload sends only a stat configuration")
	menu.show_stat_configurations(1)
	community.fail = true
	menu.find_child("CommunityConfigurations", true, false).pressed.emit()
	await frame()
	check(menu.message.text.contains("Couldn't load"), "Offline failure keeps local selection available")
	menu.find_child("OfflineConfigurations", true, false).pressed.emit()
	check(menu.find_child("UseStatConfiguration", true, false) != null, "Saved stats remain usable offline")
	community.fail = false
	community.delay = true
	menu.find_child("CommunityConfigurations", true, false).pressed.emit()
	menu.find_child("OfflineConfigurations", true, false).pressed.emit()
	community.respond.emit()
	await frame()
	check(menu.header.find_child("ScreenTitle", true, false).text == "Choose stats", "Late community responses do not replace local selection")
	community.delay = false
	menu.hide()
	app.show_campaign()
	var screen: Control = app.campaign
	screen.set_process(false)
	screen.progress.path = app.game.save_path + ".campaign-test"
	screen.progress.data.completed_levels = 0
	screen.start_mission(0)
	check(screen.run.build(6, "rapid"), "Campaign has a tower to share")
	screen.show_campaign_share(0)
	menu.find_child("SetupName", true, false).text = "Campaign opening"
	menu.find_child("SaveConfiguration", true, false).pressed.emit()
	check(community.sent[-1].kind == "campaign_build", "Campaign shares a full tower configuration")
	var full_code: String = community.sent[-1].code
	menu.find_child("BackButton", true, false).pressed.emit()
	screen.show_configuration_picker(0, "campaign_build")
	menu.find_child("UseCampaignBuild", true, false).pressed.emit()
	screen.start_mission(0)
	check(screen.run.game.data.towers.size() == 1 and screen.run.wave == 0, "Campaign picker applies a build to a fresh mission")
	screen.show_campaign_share(0)
	includes = menu.find_child("ShareConfigurationContents", true, false)
	includes.select(1)
	includes.item_selected.emit(1)
	menu.find_child("SetupName", true, false).text = "Campaign stats"
	menu.find_child("SaveConfiguration", true, false).pressed.emit()
	check(community.sent[-1].kind == "campaign_stats" and not VigilSaveSlots.CampaignBuild.decode(community.sent[-1].code).has("loadout"), "Campaign stats upload omits the placed tower")
	menu.find_child("BackButton", true, false).pressed.emit()
	screen.show_configuration_picker(0, "campaign_stats")
	menu.find_child("UseStatConfiguration", true, false).pressed.emit()
	screen.start_mission(0)
	check(screen.run.game.data.towers.is_empty(), "Campaign stats selection starts without towers")
	check(VigilSaveSlots.CampaignBuild.decode(full_code).loadout.towers.size() == 1, "Selecting stats preserves the full build copy")
	for slot in range(3):
		for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(menu.slots.path_for(slot) + suffix)
	for file in DirAccess.open(menu.slots.configurations_path()).get_files(): DirAccess.remove_absolute(menu.slots.configurations_path().path_join(file))
	DirAccess.remove_absolute(menu.slots.configurations_path())
	app.queue_free()
	await process_frame
	print("Shared configuration UI: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
