extends SceneTree

const Relics = preload("res://scripts/gameplay/progression/relics.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")
var failures: Array[String] = []
var checks := 0
var ids := {}

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 180)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in range(8): await process_frame

func exercise(host: Control, tower: Dictionary, mode: String) -> void:
	var index := 0
	for kind in Relics.DEFINITIONS:
		var id := str(90 + index) + ",90"
		Relics.award(host.game.data, id, kind)
		ids[kind] = id
		index += 1
	host.field.selected_tower = tower.id
	for dimensions in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		for kind in Relics.DEFINITIONS:
			host.tower_dialog.open_action("equipment")
			host.tower_dialog.show_equipment_details(ids[kind])
			await settle()
			var dialog: VigilTowerDialog = host.tower_dialog
			check(dialog.mode == "equipment_detail" and dialog.heading.text == Relics.DEFINITIONS[kind].name, "Named illustration opens in " + mode + ": " + kind)
			check(Rect2(Vector2.ZERO, Vector2(dimensions)).grow(1).encloses(dialog.card.get_global_rect()), "Gear details fit " + mode + " " + str(dimensions) + ": " + kind)
			if kind in ["warden", "cinder_censer", "matriarch_lantern"] and dimensions.x == 390:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/gear-detail-%s-%s.png" % [mode, kind])
		host.tower_dialog.dismiss()
		host.game.economy.equip_relic(tower.id, ids.matriarch_lantern, tower.get("relic", ""))
		check(is_equal_approx(host.field.selected_range(), 168.0), "Lantern range circle includes twenty percent in " + mode)
		host.tower_dialog.open_action("preview")
		await settle()
		var range_label: Label = host.tower_dialog.find_child("Stat_range", true, false)
		check(range_label != null and range_label.text == UI.exact_money(154.0 * 1.2) + " units", "Upgrade details show equipped reach in " + mode)
		var change: Label = host.tower_dialog.find_child("Change_range", true, false)
		check(change != null and change.text == "+" + UI.exact_money(14.0 * 1.2) + " units", "Upgrade comparison uses equipped reach on both sides")
		host.tower_dialog.dismiss()
		host.game.economy.equip_relic(tower.id, "", ids.matriarch_lantern)
		check(is_equal_approx(host.field.selected_range(), 140.0), "Removing Lantern restores displayed range in " + mode)

func run() -> void:
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://gear-gameplay.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.game.data.first_property_required = false
	app.game.data.balance = 100000.0
	var id := app.game.economy.build("rapid", "0,0", 0)
	app.panels.close_sheet()
	await exercise(app, app.game.data.towers[id], "infinite")
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.start_mission(0)
	await settle()
	var socket: int = campaign.run.mission.sockets[0].index
	campaign.run.build(socket, "rapid")
	id = campaign.run.tower_at(socket)
	await exercise(campaign, campaign.game.data.towers[id], "campaign")
	app.audio.set_suspended(true)
	app.queue_free()
	await process_frame
	print("GEAR_GAMEPLAY: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
