extends "res://tests/rendered/campaign_runner.gd"

func run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://campaign-reset-ui-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_process(false)
	app.show_campaign()
	var screen: Control = app.campaign
	screen.set_process(false)
	screen.progress.path = app.game.save_path + ".progress"
	screen.progress.restore_completed_levels(7)
	screen.configuration.save_level(6, {"gold": 1234.0})
	var world: Dictionary = app.game.data.duplicate(true)
	var config: String = FileAccess.get_file_as_string(screen.configuration.path)
	screen.start_mission(6)
	screen.run.phase = "victory"
	screen.show_map()
	await frame()
	screen.find_child("ResetCampaignProgress", true, false).pressed.emit()
	var popup: PopupPanel = screen.get_node("CampaignResetConfirmation")
	popup.find_child("CancelConfirmation", true, false).pressed.emit()
	await frame()
	check(screen.progress.data.completed_levels == 7, "Cancel preserves campaign progression")
	screen.confirm_progress_reset()
	popup = screen.get_node("CampaignResetConfirmation")
	popup.confirm.pressed.emit()
	await frame()
	check(screen.progress.data.completed_levels == 0 and screen.run == null, "Confirmed reset removes progression and stale victorious run")
	screen.save_progress()
	screen.show_map()
	var reloaded := preload("res://scripts/campaign/progress.gd").new()
	reloaded.path = screen.progress.path
	reloaded.load_progress()
	check(reloaded.data.completed_levels == 0 and reloaded.unlocked(0) and not reloaded.unlocked(1), "Reset persists and only level 1 is unlocked")
	# Desktop focus notifications can save the paused world while a popup opens.
	# Ignore only save bookkeeping; every gameplay and settings field must match.
	var after: Dictionary = app.game.data.duplicate(true)
	for key in ["sequence", "last_accounted"]:
		world.erase(key)
		after.erase(key)
	check(after == world, "Reset preserves Infinite Worlds settings, equipment and world state")
	check(FileAccess.get_file_as_string(screen.configuration.path) == config, "Reset preserves campaign balancing configuration")
	check(not screen.find_child("CampaignLevel1", true, false).disabled and screen.find_child("CampaignLevel7", true, false).disabled, "Reset updates world map locks")
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
	print("CAMPAIGN RESET UI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
