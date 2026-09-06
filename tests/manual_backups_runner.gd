extends "res://tests/test_runner.gd"
const Service = preload("res://scripts/cloud/cloud_service.gd")
const Codec = preload("res://scripts/cloud/cloud_codec.gd")

class Fixture extends Service:
	var requests: Array = []
	func _rpc(method: String, body: Dictionary) -> Dictionary:
		requests.append({"method": method, "body": body.duplicate(true)})
		if method == "publish_save": return {"ok": true, "data": {"status": "ok", "revision": 1}}
		return {"ok": false}

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://manual-slots-" + Codec.uuid()
	var service := Fixture.new()
	service.game = app.game
	root.add_child(service)
	app.cloud = service
	service.player_id = Codec.uuid()
	service.refresh_token = "fixture"
	var slots := VigilSaveSlots.new()
	slots.base_path = app.game.save_path + ".slots"
	var other := VigilState.new(6543)
	other.data.balance = 777.0
	other.data.last_accounted = 100.0
	check(other.storage.write(slots.path_for(1), other.data), "Inactive slot fixture saved")
	var untouched := VigilState.new(9876)
	check(untouched.storage.write(slots.path_for(2), untouched.data), "Third slot fixture saved")
	var third_before := FileAccess.get_file_as_string(slots.path_for(2))
	var active_before := app.game.snapshot()
	await app.upload_infinite_backup(1)
	check(service.requests.size() == 1 and service.requests[0].body.payload.world.seed == 6543, "Explicit upload selects only the requested Infinite slot")
	check(service.requests[0].body.payload.progress[0].gold == 777 and service.requests[0].body.payload.checkpoints[0].last_accounted == 100, "Inactive upload preserves resources and offline timestamp")
	check(app.game.data.balance == active_before.balance and not app.game.data.has("cloud"), "Uploading inactive slot cannot link or change active world")
	check(FileAccess.get_file_as_string(slots.path_for(2)) == third_before, "Third slot is byte-for-byte unchanged")
	check(service.game == app.game, "Upload restores service's active-world reference")
	service._process(36000)
	check(service.requests.size() == 1, "Elapsed time does not upload remaining slots")
	app.campaign_progress.data.completed_levels = 3
	check(service.requests.size() == 1, "Campaign progression does not upload")
	var directory := DirAccess.open("user://")
	for filename in directory.get_files():
		if filename.begins_with(app.game.save_path.trim_prefix("user://")):
			DirAccess.remove_absolute("user://" + filename)
	service.queue_free()
	app.free()
	print("Manual backups: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
