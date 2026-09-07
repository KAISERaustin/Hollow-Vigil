extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func frame() -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw

func initial_preview(host: Control, select: Callable, close: Callable, label: String) -> void:
	var field: Battlefield = host.field
	field.set_process(false)
	var funds: float = host.game.data.balance
	var towers: int = host.game.data.towers.size()
	# The initial marker also appears when the first tower is unaffordable.
	host.game.data.balance = 0
	select.call()
	await frame()
	var cards: Node = host.find_child("TowerCards", true, false).get_node("Cards")
	var first_kind: String = cards.get_child(0).get_meta("tower_kind")
	var portrait: Node2D = field.build_preview.portrait
	check(field.preview_kind == first_kind, label + " immediately previews the first listed tower")
	check(is_instance_valid(portrait) and portrait.is_visible_in_tree(), label + " renders preview before choosing a card")
	check(is_equal_approx(portrait.self_modulate.a, 0.7), label + " renders at 70 percent opacity")
	var position := VigilWorld.pad_position(field.selected_region, field.selected_pad)
	check(portrait.position.is_equal_approx(field.screen(position)), label + " places preview at the clicked socket")
	check(portrait.scale.is_equal_approx(Vector2.ONE * field.zoom), label + " scales preview with the battlefield")
	check(host.game.data.balance == 0 and host.game.data.towers.size() == towers, label + " initial preview never builds or spends")
	var menu: Control = field.build_preview.menu
	check(menu.find_child("TowerDetails", true, false) == null, label + " leaves the icon picker open")
	if label.ends_with("390"):
		for step in range(40):
			field._process(1.0 / 60.0)
			await frame()
		root.get_texture().get_image().save_png("res://artifacts/initial-build-preview-%s.png" % label)
	close.call()
	check(not portrait.visible and field.preview_kind.is_empty(), label + " closing clears the preview")
	host.game.data.balance = funds

func exercise(host: Control, select: Callable, close: Callable, menu: Control, label: String) -> void:
	var field: Battlefield = host.field
	field.set_process(false)
	var funds: float = host.game.data.balance
	var towers: int = host.game.data.towers.size()
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		await frame()
		for edge in [Vector2(0.05, 0.05), Vector2(0.95, 0.95)]:
			select.call()
			await frame()
			var pos := VigilWorld.pad_position(field.selected_region, field.selected_pad)
			field.set_zoom(1.65, field.size * 0.5)
			field.camera = pos - (field.size * edge - field.size * 0.5) / field.zoom
			field.enforce_camera_limits()
			field.build_preview.signature.clear()
			for kind in Balance.TOWERS:
				var button: Button = host.find_child(("Build_" if label == "infinite" else "CampaignBuild_") + kind, true, false)
				button.pressed.emit()
				await frame()
				var before := field.camera
				field.build_preview.refresh(field)
				check(field.camera == before, label + " preview begins without jumping")
				for step in range(40):
					field._process(1.0 / 60.0)
					host.tower_actions.refresh()
				await frame()
				var available := Rect2(field.global_position + Vector2(9, 9), field.size - Vector2(18, 18))
				available.size.y = menu.global_position.y - 9 - available.position.y
				var radius: float = field.selected_range() * field.zoom
				var center := field.global_position + field.screen(pos)
				var context := "%s %s %s %s" % [label, viewport, edge, kind]
				check(available.encloses(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2)), context + " fits full range")
				check(available.encloses(Rect2(center + Vector2(-30, -55) * field.zoom, Vector2(60, 75) * field.zoom)), context + " fits tower art")
				check(field.preview_kind == kind and not field.camera_framing.active, context + " displays selected preview and settles")
				check(host.game.data.balance == funds and host.game.data.towers.size() == towers, context + " preview never spends or builds")
				check(field.camera_bounds().grow(0.1).encloses(Rect2(field.world(Vector2.ZERO), field.size / field.zoom)), context + " respects camera bounds")
				if edge.x > 0.5 and kind == "heavy":
					root.get_texture().get_image().save_png("res://artifacts/build-preview-%s-%d.png" % [label, viewport.x])
			# Manual camera input must not be undone by the next menu refresh.
			field.set_zoom(field.zoom * 1.1, field.size * 0.5)
			var manual := field.camera
			field._process(1.0)
			check(field.camera == manual and not field.camera_framing.active, label + " yields to manual zoom")
			close.call()
			field._process(1.0)
			check(field.preview_kind.is_empty() and field.selected_range() == 0.0, label + " closing removes preview and ring")

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://build-preview-test.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.game.data.balance = 100000
	app.game.expand("1,0")
	await frame()
	for mode in ["creative", "survival"]:
		app.game.data.mode = mode
		for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
			root.size = viewport
			root.content_scale_size = viewport
			await frame()
			app.panels.selection_kind = "heavy"
			await initial_preview(app, func(): app.panels.select_pad("0,0", 1), app.panels.close_sheet, "infinite-%s-%d" % [mode, viewport.x])
			await initial_preview(app, func(): app.panels.select_pad("1,0", 2), app.panels.close_sheet, "infinite-%s-other-%d" % [mode, viewport.x])
	await exercise(app, func(): app.panels.select_pad("0,0", 1), app.panels.close_sheet, app.panels, "infinite")
	app.panels.select_pad("0,0", 1)
	await frame()
	app.find_child("Build_rapid", true, false).pressed.emit()
	app.panels.action_button.pressed.emit()
	for step in range(40):
		app.field._process(1.0 / 60.0)
		app.tower_actions.refresh()
	check(app.game.data.towers.size() == 1 and app.field.preview_kind.is_empty(), "Infinite confirmation replaces preview with one real tower")
	check(app.tower_actions.visible and not app.field.camera_framing.active, "Infinite confirmation hands camera framing to tower actions")
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	for mode in ["creative", "survival"]:
		campaign.mode = mode
		campaign.start_mission(0)
		for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
			root.size = viewport
			root.content_scale_size = viewport
			await frame()
			await initial_preview(campaign, func(): campaign.show_socket(campaign.run.mission.sockets[1].index), campaign.close_dialog, "campaign-%s-%d" % [mode, viewport.x])
			await initial_preview(campaign, func(): campaign.show_socket(campaign.run.mission.sockets[2].index), campaign.close_dialog, "campaign-%s-other-%d" % [mode, viewport.x])
	campaign.start_mission(0)
	await frame()
	var socket: int = campaign.run.mission.sockets[1].index
	await exercise(campaign, func(): campaign.show_socket(socket), campaign.close_dialog, campaign.dialog_card, "campaign")
	campaign.show_socket(socket)
	await frame()
	campaign.find_child("CampaignBuild_heavy", true, false).pressed.emit()
	var before: float = campaign.game.data.balance
	var cost: float = Balance.definition("towers", "heavy", campaign.game.tuning).cost
	campaign.find_child("CampaignBuildConfirm", true, false).pressed.emit()
	check(campaign.game.data.balance == before - cost and campaign.game.data.towers.size() == 1, "Confirmation builds and spends exactly once")
	check(campaign.field.preview_kind == "" and not campaign.dialog.visible, "Confirmation clears preview")
	app.free()
	print("BUILD PREVIEW: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
