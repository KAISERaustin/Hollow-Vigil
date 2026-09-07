extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 120)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in range(8): await process_frame

func check_balance(screen: Control, context: String) -> void:
	var scroll := screen.dialog_body.get_parent() as ScrollContainer
	var details: Control = screen.dialog_body.get_node("WaveBalanceDetails")
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(screen.dialog_card.get_global_rect()), "Balancing dialog fits " + context)
	for child: Control in details.find_children("*", "Control", true, false):
		check(child.get_global_rect().position.x >= scroll.global_position.x - 1 and child.get_global_rect().end.x <= scroll.get_global_rect().end.x + 1, "Balancing content fits horizontally: %s in %s" % [child.name, context])
		if child is PanelContainer:
			var style: StyleBox = child.get_theme_stylebox("panel")
			check(style.border_width_left == 3 and style.border_width_top == 3 and style.border_width_right == 3 and style.border_width_bottom == 3, "Balancing cards share the standard outline " + context)
	var header: Rect2 = screen.dialog_header.get_global_rect()
	scroll.scroll_vertical = 100000
	await settle()
	check(details.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1, "Final balancing content is reachable " + context)
	check(screen.dialog_header.get_global_rect() == header, "Balancing navigation stays fixed while scrolling " + context)
	check(screen.dialog_header.get_node("BackButton").size.y >= 48 and screen.find_child("CloseCampaignDialog", true, false).size.y >= 48, "Balancing navigation keeps touch targets " + context)

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://wave-menu-%d.save" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var screen: Control = app.campaign
	screen.set_process(false)
	screen.progress.data.completed_levels = 20
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960), Vector2i(640, 360)]:
		root.size = viewport
		root.content_scale_size = viewport
		for mode in ["creative", "survival"]:
			screen.mode = mode
			for level in [0, 9, 19]:
				screen.start_mission(level)
				var before: Dictionary = screen.run.game.data.duplicate(true)
				screen.show_waves()
				await settle()
				var context := "%s level %d at %s" % [mode, level + 1, viewport]
				var scroll := screen.dialog_body.get_parent() as ScrollContainer
				var list: VBoxContainer = screen.dialog_body.get_node("WaveSummaries")
				check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(screen.dialog_card.get_global_rect()), "Dialog fits " + context)
				check(list.get_child_count() == screen.run.mission.waves.size(), "Every wave is present " + context)
				var previous: Control
				for card: Control in list.get_children():
					if previous != null:
						var gap := card.position.y - previous.get_rect().end.y
						check(gap >= 8 and gap <= 12, "Wave sections have compact, distinct gaps " + context)
					previous = card
					for child: Control in card.find_children("*", "Control", true, false):
						check(child.get_global_rect().position.x >= card.global_position.x and child.get_global_rect().end.x <= card.get_global_rect().end.x + 1, "Content fits horizontally: %s in %s" % [child.name, context])
					var actions := card.find_child("WaveActions", true, false)
					check(actions.get_child_count() == (2 if mode == "creative" else 1), "Authoring actions respect mode " + context)
					if mode == "creative":
						var details: Button = actions.get_child(0)
						var edit: Button = actions.get_child(1)
						check(is_equal_approx(details.global_position.y, edit.global_position.y) and edit.global_position.x - details.get_global_rect().end.x >= 12, "Wave actions share a spaced row " + context)
						check(details.size.y >= 48 and edit.size.y >= 48, "Action touch targets stay usable " + context)
				check(screen.run.game.data == before, "Reading waves leaves gameplay unchanged " + context)
				if mode == "creative" and level in [0, 19] and viewport.y > viewport.x:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://artifacts/wave-menu-%d-level-%d.png" % [viewport.x, level + 1])
				scroll.scroll_vertical = 100000
				await settle()
				var last: Button = list.get_child(-1).find_child("WaveBalancingDetails*", true, false)
				check(scroll.get_global_rect().grow(1).encloses(last.get_global_rect()), "Last wave action is reachable " + context)
				last.pressed.emit()
				await settle()
				check(screen.dialog_title.text == "Wave %d balancing" % screen.run.mission.waves.size(), "Details open the selected wave " + context)
				await check_balance(screen, context)
				check(screen.run.game.data == before, "Reading balancing leaves gameplay unchanged " + context)
				screen.dialog_header.get_node("BackButton").pressed.emit()
				await settle()
				check(screen.waves_dialog and screen.dialog_title.text == "Waves", "Details return to the wave list " + context)
	# Opening and second-wave reports cover the small card and scrolling comparison.
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960), Vector2i(640, 360)]:
		root.size = viewport
		root.content_scale_size = viewport
		screen.start_mission(15)
		for wave in [0, 1]:
			screen.show_wave_balance(wave)
			await settle()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/wave-balance-%dx%d-wave-%d.png" % [viewport.x, viewport.y, wave + 1])
			await check_balance(screen, "wave %d at %s" % [wave + 1, viewport])
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/wave-balance-%dx%d-wave-%d-bottom.png" % [viewport.x, viewport.y, wave + 1])
	# Editing still opens the selected scope through the existing authoring owner.
	screen.mode = "creative"
	screen.start_mission(0)
	screen.show_waves()
	await settle()
	screen.find_child("EditCampaignWave2", true, false).pressed.emit()
	await settle()
	check(screen.dialog_title.text == "Level configuration" and screen.dialog_body.get_child(0).initial_scope == 1, "Edit wave 2 selects the second wave")
	screen.start_mission(0)
	screen.run.wave = 1
	screen.run.phase = "wave"
	screen.show_waves()
	await settle()
	check(screen.find_child("WaveSummary1", true, false).find_child("WaveStatus", true, false).text == "Cleared", "Completed wave is marked cleared")
	check(screen.find_child("WaveSummary2", true, false).find_child("WaveStatus", true, false).text == "In progress", "Active wave is identified")
	print("WAVE_MENU: %d checks, %d failures" % [checks, failures.size()])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
