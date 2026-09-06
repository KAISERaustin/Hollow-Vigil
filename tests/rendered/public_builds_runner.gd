extends "res://tests/test_runner.gd"

class Catalog extends Node:
	signal changed
	var configuration: Dictionary
	var fail := false
	func list_page(page: int) -> Dictionary:
		if fail: return {"ok": false}
		var rows := []
		for i in range(20 if page == 0 else 1):
			rows.append({"id": "10000000-0000-4000-8000-000000000001", "title": "A challenging night", "description": "Stronger enemies and a carefully tuned opening world.", "author_name": "Moonlit Builder", "created_at": "2026-09-06T15:00:00+00:00"})
		return {"ok": true, "data": rows}
	func read_build(_id: String) -> Dictionary:
		return {} if fail else configuration

func frame() -> void:
	await process_frame
	await process_frame

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://public-build-ui-placeholder.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.public_builds.queue_free()
	var catalog := Catalog.new()
	root.add_child(catalog)
	app.public_builds = catalog
	app.panels.show_settings()
	var open := app.panels.find_child("OpenPublicBuilds", true, false)
	check(open != null, "Settings exposes Public Builds")
	open.pressed.emit()
	var menu: Control = app.slot_menu
	menu.slots.base_path = "user://public-build-ui-%d" % Time.get_ticks_usec()
	var source := VigilState.new()
	source.set_balance_stat("enemies", "basic", "hp", 200.0)
	catalog.configuration = {"name": "A challenging night", "description": "Stronger enemies", "code": menu.slots.export_build(source, "A challenging night", "Stronger enemies")}
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		menu.show_public_builds(0)
		await frame()
		check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(menu.card.get_global_rect()), "Public browser fits " + str(viewport))
		check(menu.find_child("SelectPublicBuild0", true, false) != null, "Public selection available")
		var back: Button = menu.header.get_child(0)
		check(back.text == "←" and back.accessibility_name == "Back to new game", "Public browser uses accessible header back arrow")
		var header_position: Vector2 = back.global_position
		menu.scroll.scroll_vertical = 100
		await frame()
		check(back.global_position == header_position, "Back arrow stays visible while builds scroll")
		menu.scroll.scroll_vertical = 0
		if not DisplayServer.get_name() == "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/public-builds-%d.png" % viewport.x)
	menu.find_child("SelectPublicBuild0", true, false).pressed.emit()
	await frame()
	check(menu.selected_configuration.name == "A challenging night", "Selecting public build returns to world configuration")
	menu.creation_mode = "survival"
	menu.show_creation(0, false)
	menu.find_child("CreateSave", true, false).pressed.emit()
	await frame()
	check(not app.game.is_creative() and app.game.tuning == source.tuning, "Public build creates Survival with shared rules")
	app.show_save_slots()
	catalog.fail = true
	menu.show_public_builds()
	await frame()
	check(menu.message.text.contains("Couldn't load"), "Network failure offers actionable state")
	catalog.fail = false
	menu.show_public_builds()
	await frame()
	menu.find_child("SelectPublicBuild0", true, false).pressed.emit()
	await frame()
	check(menu.header.find_child("ScreenTitle", true, false).text == "Choose a game slot", "Global browser offers empty save slots")
	for slot in range(3):
		for suffix in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(menu.slots.path_for(slot) + suffix)
	app.queue_free()
	catalog.queue_free()
	await frame()
	print("Public builds UI: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
