extends "res://tests/test_runner.gd"

class FakeCloud extends Node:
	var player_id := ""
	var display_name := "Builder"
	var busy := false
	var expires_at := 0.0
	var generation := 0
	var succeeds := false
	var sent: Array = []
	func signed_in() -> bool: return not player_id.is_empty()
	func _rpc(_method: String, body: Dictionary) -> Dictionary:
		sent.append(body.duplicate(true))
		return {"ok": succeeds}

func run() -> void:
	var cloud := FakeCloud.new()
	root.add_child(cloud)
	var service := preload("res://scripts/cloud/public_builds.gd").new()
	service.cloud = cloud
	service.outbox_path = "user://public-build-test-%d.cfg" % Time.get_ticks_usec()
	root.add_child(service)
	service.set_process(false)
	var slots := VigilSaveSlots.new()
	var game := VigilState.new()
	game.data.cloud = {"player_id": "private"}
	var code := slots.export_build(game, "Public title", "Description")
	check(service.queue_export(code), "Offline export queues durably")
	check(service.outbox.size() == 1, "One queued build")
	var id: String = service.outbox[0].id
	check(not slots.decode_build(code).has("cloud"), "Exports omit cloud identity")
	cloud.player_id = preload("res://scripts/cloud/cloud_codec.gd").uuid()
	cloud.display_name = ""
	await service.flush()
	check(cloud.sent.is_empty() and service.outbox.size() == 1, "Unnamed accounts retain exports until name is set")
	cloud.display_name = "Builder"
	service._process(3600.0)
	check(cloud.sent.is_empty(), "Signing in, naming an account and elapsed time never auto-publish")
	await service.flush()
	check(service.outbox.size() == 1 and service.outbox[0].owner == cloud.player_id, "Failure preserves export and account binding")
	var restored := preload("res://scripts/cloud/public_builds.gd").new()
	restored.cloud = cloud
	restored.outbox_path = service.outbox_path
	root.add_child(restored)
	restored.set_process(false)
	check(restored.outbox.size() == 1 and restored.outbox[0].id == id, "Queue survives restart with same ID")
	var owner: String = cloud.player_id
	cloud.player_id = preload("res://scripts/cloud/cloud_codec.gd").uuid()
	cloud.succeeds = true
	await restored.flush()
	check(restored.outbox.size() == 1 and cloud.sent.size() == 1, "Another account cannot publish bound exports")
	cloud.player_id = owner
	await restored.flush()
	check(restored.outbox.is_empty() and cloud.sent[1].build_id == id, "Retry reuses independent ID and clears confirmed export")
	check(not restored.queue_export("bad data"), "Invalid export rejected")
	DirAccess.remove_absolute(service.outbox_path)
	service.queue_free()
	restored.queue_free()
	cloud.queue_free()
	print("Public builds: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
