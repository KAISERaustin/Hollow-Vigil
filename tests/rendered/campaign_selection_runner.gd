extends "res://tests/rendered/campaign_runner.gd"

func cleared(screen: Control, context: String) -> void:
	screen.refresh()
	check(screen.board.selected == -1 and screen.board.selected_pad == -1 and screen.board.selected_region == "" and screen.board.selected_tower == "", context + ": all range sources cleared")
	check(not screen.tower_actions.visible and not screen.tower_dialog.visible and screen.board.moving_tower == "", context + ": controls cleared")

func run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://campaign-selection-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var screen: Control = app.campaign
	screen.set_process(false)
	screen.start_mission(0)
	await frame()
	screen.game.data.balance = 10000.0
	var sockets: Array = screen.run.mission.sockets
	var first: int = sockets[0].index
	var second: int = sockets[1].index
	screen.run.build(first, "rapid")
	screen.run.build(second, "heavy")
	screen.show_socket(first)
	screen.tower_dialog.open_action("info")
	screen.show_socket(second)
	check(screen.board.selected == second and screen.board.selected_tower == screen.run.tower_at(second), "Selecting another tower replaces battlefield selection")
	check(screen.tower_dialog.visible and screen.tower_dialog.mode == "preview" and screen.tower_dialog.tower_id == screen.run.tower_at(second), "Selecting another tower replaces the previous dialog with its upgrade preview")
	screen.board.empty_picked.emit()
	cleared(screen, "Tap away")
	screen.show_socket(first)
	screen.show_waves()
	cleared(screen, "Opening waves")
	screen.close_dialog()
	cleared(screen, "Closing other interface")
	screen.show_socket(first)
	screen.tower_dialog.open_action("sell")
	screen.tower_dialog.confirm.pressed.emit()
	cleared(screen, "Sell")
	screen.show_socket(first)
	screen.close_dialog()
	cleared(screen, "Dismiss placement")
	screen.show_socket(second)
	screen.run.sell(second)
	cleared(screen, "External removal")
	screen.run.build(first, "rapid")
	screen.show_socket(first)
	screen.tower_dialog.open_action("move")
	screen.tower_dialog.confirm.pressed.emit()
	screen.show_socket(second)
	check(screen.board.selected == second and screen.board.selected_pad == sockets[1].pad and screen.board.selected_tower == screen.run.tower_at(second), "Relocation transfers interaction to new socket")
	screen.board.empty_picked.emit()
	cleared(screen, "Dismiss moved tower")
	screen.show_socket(second)
	screen.begin_wave()
	cleared(screen, "Wave starts")
	screen.show_socket(second)
	screen.run.next_spawn = screen.run.schedule.size()
	screen.run.tick(Balance.STEP)
	cleared(screen, "Wave completes")
	screen.show_socket(second)
	screen.run.phase = "victory"
	screen.run.changed.emit()
	cleared(screen, "Level completes")
	screen.show_map()
	check(screen.board == null and screen.tower_actions == null, "Leaving battle frees interaction owner")
	screen.start_mission(0)
	cleared(screen, "New mission")
	var prefix: String = app.game.save_path.get_file()
	screen.close()
	for filename in DirAccess.get_files_at("user://"):
		if filename.begins_with(prefix): DirAccess.remove_absolute("user://" + filename)
	app.audio.set_suspended(true)
	app.audio.music.stop()
	app.audio.music.stream = null
	for pool in app.audio.voices.values():
		for voice in pool:
			voice.stop()
			voice.stream = null
	await create_timer(0.1).timeout
	app.queue_free()
	await process_frame
	print("CAMPAIGN SELECTION UI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
