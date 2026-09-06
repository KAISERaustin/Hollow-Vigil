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
	check(not app.cloud.linked() and app.cloud.status.contains("has not been uploaded"), "Switching to an unlinked save clears stale sync-success message")
	var next_path: String = next.save_path
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
		if filename.begins_with(original_path.trim_prefix("user://")) or filename.begins_with(next_path.trim_prefix("user://")):
			DirAccess.remove_absolute("user://" + filename)
	print("Cloud app restore: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
