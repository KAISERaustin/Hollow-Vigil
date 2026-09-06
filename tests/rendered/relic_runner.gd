extends SceneTree

const Harness = preload("res://tests/rendered/visual_smoke.gd")
const Relics = preload("res://scripts/gameplay/progression/relics.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://relic-ui-test.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.game.data.balance = 100000.0
	app.game.expand("-1,0")
	var towers: Array[String] = []
	for index in range(4):
		towers.append(app.game.economy.build(Balance.TOWERS.keys()[index], "0,0", index))
	app.field.set_unrestricted_camera(true)
	app.field.camera = Vector2.ZERO
	app.field.zoom = 1.0
	app.panels.close_sheet()
	app.field.selected_tower = towers[0]
	app.tower_actions.blocked = false
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	await frame()
	await Harness.tap(app, app.tower_actions.buttons.equipment.get_global_rect().get_center())
	check(app.tower_dialog.visible and app.tower_dialog.mode == "equipment", "Equipment action opens collection with no drops")
	check(app.tower_dialog.find_child("Relic_empty", true, false) == null and app.tower_dialog.find_child("RemoveEquipment", true, false) == null, "Empty slot offers no removal action")
	check(not app.tower_dialog.confirm.visible, "Inventory has no redundant apply button")
	check(app.tower_dialog.find_child("EquipmentGrid", true, false).get_child_count() == 16, "Empty inventory displays sixteen blank slots")
	check(app.tower_dialog.find_child("EquippedRelicName", true, false).text == "No equipment equipped", "Empty slot is explicit at the top of the menu")
	await Harness.capture(app, "relic-empty-collection")
	app.tower_dialog.dismiss()
	for index in range(4):
		Relics.award(app.game.data, str(90 + index) + ",90", Relics.DEFINITIONS.keys()[index])
	for touch in [false, true]:
		app.field.selected_tower = towers[0]
		await frame()
		await Harness.tap(app, app.tower_actions.buttons.equipment.get_global_rect().get_center(), touch)
		var dialog := app.tower_dialog
		var before := app.game.data.duplicate(true)
		var choice := dialog.find_child("Relic_90,90", true, false) as Button
		check(choice.text == "" and choice.tooltip_text == "Warden’s Rootheart", "Inventory uses named icons without descriptions")
		dialog.scroll.ensure_control_visible(choice)
		await frame()
		await Harness.tap(app, choice.get_global_rect().get_center(), touch)
		check(app.game.data == before and dialog.relic_choice == "90,90", "Selecting relic waits for Apply")
		await Harness.tap(app, dialog.confirm.get_global_rect().get_center(), touch)
		check(app.game.data.towers[towers[0]].get("relic", "") == "90,90", "Mouse/touch equips selected piece")
		check(app.game.storage.read_candidate(app.game.save_path).get("towers", {}).get(towers[0], {}).get("relic") == "90,90", "Equipment UI persists the transaction: " + app.game.save_error)
		app.field.selected_tower = towers[1]
		await frame()
		await Harness.tap(app, app.tower_actions.buttons.equipment.get_global_rect().get_center(), touch)
		choice = dialog.find_child("Relic_90,90", true, false)
		dialog.scroll.ensure_control_visible(choice)
		await frame()
		await Harness.tap(app, choice.get_global_rect().get_center(), touch)
		check(dialog.confirm.text == "Transfer equipment", "Details offer transfer for an owned piece")
		await Harness.tap(app, dialog.confirm.get_global_rect().get_center(), touch)
		check(not app.game.data.towers[towers[0]].has("relic") and app.game.data.towers[towers[1]].relic == "90,90", "Transfer moves one piece without duplication")
		dialog.open_action("equipment")
		await frame()
		await Harness.tap(app, dialog.find_child("RemoveEquipment", true, false).get_global_rect().get_center(), touch)
		check(dialog.mode == "equipment_remove" and app.game.data.towers[towers[1]].relic == "90,90", "X requests confirmation without removing equipment")
		await Harness.capture(app, "relic-remove-confirmation")
		await Harness.tap(app, dialog.cancel.get_global_rect().get_center(), touch)
		check(dialog.mode == "equipment" and app.game.data.towers[towers[1]].relic == "90,90", "Cancel retains equipment and returns to picker")
		await Harness.tap(app, dialog.find_child("RemoveEquipment", true, false).get_global_rect().get_center(), touch)
		await Harness.tap(app, dialog.confirm.get_global_rect().get_center(), touch)
		check(not app.game.data.towers[towers[1]].has("relic") and app.game.data.relics.has("90,90"), "Confirmed removal returns equipment to inventory")
		check(not app.game.storage.read_candidate(app.game.save_path).towers[towers[1]].has("relic"), "Removal persists")
	for index in range(4):
		app.game.economy.equip_relic(towers[index], str(90 + index) + ",90", "")
	app.field.selected_tower = ""
	await Harness.capture(app, "relic-equipped-towers")
	app.field.selected_tower = towers[3]
	for dimensions in [Vector2i(360,640), Vector2i(390,844), Vector2i(768,1024)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for zoom in [0.42, 1.0, 1.65]:
			app.field.zoom = zoom
			await frame()
			check(app.tower_actions.buttons.size() == 6, "Six tower actions exist")
			var bounds: Rect2 = app.tower_actions.buttons.equipment.get_global_rect()
			for action in ["info", "move", "target", "upgrade", "sell"]:
				check(not bounds.intersects(app.tower_actions.buttons[action].get_global_rect()), "Equipment button does not overlap " + action)
		app.field.zoom = 1.0
		await frame()
		app.tower_dialog.open_action("equipment")
		await frame()
		var viewport := Rect2(Vector2.ZERO, app.size)
		check(viewport.encloses(app.tower_dialog.card.get_global_rect()), "Equipment card fits viewport " + str(dimensions))
		var equipped_name := app.tower_dialog.find_child("EquippedRelicName", true, false) as Label
		check(equipped_name.text == "Eclipse Shard", "Header identifies the equipped Eclipse Shard")
		check(equipped_name.get_global_rect().end.y <= app.tower_dialog.scroll.get_global_rect().position.y, "Equipped summary stays above the scrolling collection")
		await Harness.capture(app, "relic-grid-" + str(dimensions.x))
		var replacement := app.tower_dialog.find_child("Relic_90,90", true, false) as Button
		app.tower_dialog.scroll.ensure_control_visible(replacement)
		await frame()
		await Harness.tap(app, replacement.get_global_rect().get_center())
		check(app.tower_dialog.relic_choice == "90,90" and equipped_name.text == "Eclipse Shard", "Pending replacement does not change the currently equipped summary")
		app.tower_dialog.scroll.scroll_vertical = 0
		await frame()
		check(app.tower_dialog.mode == "equipment_detail", "Clicking an inventory icon opens its explanation")
		await Harness.capture(app, "relic-picker-" + str(dimensions.x))
		app.tower_dialog.dismiss()
		await Harness.capture(app, "relic-actions-" + str(dimensions.x))
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(app.game.save_path + suffix):
			DirAccess.remove_absolute(app.game.save_path + suffix)
	app.queue_free()
	await process_frame
	await process_frame
	print("RELIC UI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
