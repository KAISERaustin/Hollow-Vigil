extends "res://tests/test_runner.gd"

const Codec = preload("res://scripts/cloud/cloud_codec.gd")

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://cloud-restore-" + Codec.uuid() + ".save"
	root.add_child(app)
	app.set_process(false)
	app.game.set_balance_stat("enemies", "basic", "hp", 125.0)
	app.game.data.setup = {"name": "Local rules", "description": "Original"}
	app.persist()
	var original_path: String = app.game.save_path
	var donor := VigilState.new(424245)
	donor.set_balance_stat("enemies", "basic", "hp", 200.0)
	donor.data.mode = "survival"
	donor.data.setup = {"name": "Cloud rules", "description": "Restore these rules"}
	var wid := Codec.uuid()
	var snapshot := Codec.new().decode(Codec.new().encode(donor.snapshot(), wid))
	snapshot.cloud = {"player_id": Codec.uuid(), "world_id": wid, "revision": 3, "include_audio": false}
	app.restore_cloud_progress(snapshot, wid, 3)
	check(app.game.data.mode == "survival", "Actual app restore retains cloud Survival mode")
	check(app.game.tuning == donor.tuning, "Actual app restore retains cloud tuning instead of overwriting with local rules")
	check(app.game.data.setup == donor.data.setup, "Actual app restore retains cloud configuration")
	check(app.game.data.cloud.world_id == wid and app.game.data.cloud.revision == 3, "Restored world identity and revision retained")
	var disk := VigilSaveStore.new().read_candidate(original_path)
	check(disk.mode == "survival" and disk.settings.developer_balance == donor.tuning, "Restored mode and rules are durable")
	app.show_save_slots()
	app.slot_menu.slots.base_path = "user://cloud-switch-" + Codec.uuid()
	var next: VigilState = app.slot_menu.slots.create(0, "creative")
	app.cloud.player_id = snapshot.cloud.player_id
	app.cloud.refresh_token = "synthetic"
	app.cloud.status = "Saved to cloud · revision 3"
	app.activate_slot(next, 0)
	check(not app.cloud.linked() and app.cloud.status.contains("back up automatically") and not app.cloud.status.contains("revision 3"), "Switching saves clears the previous game's success message and describes automatic backups")
	var next_path: String = next.save_path
	app.show_save_slots()
	app.slot_active = false
	app.slot_menu.show_slots()
	var empty_button := app.slot_menu.find_child("NewGameSlot2", true, false) as Button
	check(empty_button != null and empty_button.text == "New game", "Empty restore destination initially offers New game")
	app.cloud.backup_slot = 1
	app.cloud.game = app.backup_game(1, true)
	app.restore_cloud_progress(snapshot.duplicate(true), wid, 3)
	var restored_button := app.slot_menu.find_child("ContinueGameSlot2", true, false) as Button
	check(restored_button != null and restored_button.text == "Continue game" and not restored_button.disabled, "Inactive cloud restore immediately refreshes the saved-game action")
	check(app.slot_menu.slots.summary(1).cloud.world_id == wid, "Refreshed restore action points to the durable cloud world")
	var restored_path: String = app.slot_menu.slots.path_for(1)
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
	# Delete only this runner's unique disposable files, including recovery copies.
	var directory := DirAccess.open("user://")
	for filename in directory.get_files():
		if filename.begins_with(original_path.trim_prefix("user://")) or filename.begins_with(next_path.trim_prefix("user://")) or filename.begins_with(restored_path.trim_prefix("user://")):
			DirAccess.remove_absolute("user://" + filename)
	print("Cloud app restore: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
