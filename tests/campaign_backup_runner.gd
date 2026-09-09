extends "res://tests/test_runner.gd"

const Progress = preload("res://scripts/campaign/progress.gd")
const Backup = preload("res://scripts/cloud/campaign_backup.gd")
const Cloud = preload("res://scripts/cloud/cloud_service.gd")
const Codec = preload("res://scripts/cloud/cloud_codec.gd")

class FakeCloud extends Cloud:
	var sent: Array = []
	var response := {}
	func _rpc(method: String, body: Dictionary) -> Dictionary:
		sent.append({"method": method, "body": body.duplicate(true)})
		return response.duplicate(true)

func run() -> void:
	var progress := Progress.new()
	progress.path = "user://campaign-backup-test-" + Codec.uuid()
	progress.data.completed_levels = 4
	var cloud := FakeCloud.new()
	cloud.game = VigilState.new()
	root.add_child(cloud)
	var backup := Backup.new()
	backup.cloud = cloud
	backup.progress = progress
	root.add_child(backup)
	await backup.upload()
	check(cloud.sent.is_empty(), "Signed-out upload cannot create a cloud backup")
	cloud.player_id = Codec.uuid()
	cloud.refresh_token = "fake"
	await process_frame
	check(cloud.sent.is_empty(), "Signing in and elapsed time never create a campaign backup")
	cloud.response = {"ok": false}
	await backup.upload()
	var first: Dictionary = cloud.sent[-1].body
	check(first.payload == {"format": 1, "catalog_version": 1, "completed_levels": 4}, "Upload contains only campaign completion and format fields")
	progress.data.completed_levels = 5
	check(cloud.sent.size() == 1, "Failed upload is never retried in the background")
	var restored := Backup.new()
	restored.progress = progress
	restored.cloud = cloud
	root.add_child(restored)
	await process_frame
	check(cloud.sent.size() == 1, "Reopening with a saved attempt cannot upload")
	cloud.response = {"ok": true, "data": {"status": "ok", "revision": 1}}
	await restored.upload()
	check(cloud.sent[-1].body == first, "Explicit retry uses the identical mutation and snapshot")
	check(progress.data.completed_levels == 5, "Upload acknowledgement preserves later local victories")
	check(not restored.state.has("pending"), "Acknowledgement clears the pending manual attempt")
	cloud.response = {"ok": true, "data": {"status": "conflict", "revision": 2}}
	await restored.upload()
	check(restored.conflict.revision == 2, "A stale revision requires a choice")
	var count := cloud.sent.size()
	await restored.upload()
	check(cloud.sent.size() == count, "An unresolved conflict cannot overwrite the cloud")
	cloud.response = {"ok": true, "data": {"status": "ok", "revision": 3}}
	await restored.upload(true)
	check(cloud.sent[-1].body.expected_revision == 2 and cloud.sent[-1].body.payload.completed_levels == 5, "Explicit replacement uploads current completion with a revision check")
	cloud.response = {"ok": true, "data": {"format": 1, "catalog_version": 1, "completed_levels": 2, "revision": 4}}
	await restored.restore()
	check(progress.data.completed_levels == 2 and not progress.data.has("checkpoint"), "Restore replaces only completed levels")
	check(cloud.sent[-1].method == "read_campaign_backup", "Restoring never publishes a backup")
	cloud.response = {"ok": false}
	progress.data.completed_levels = 6
	await restored.restore()
	check(progress.data.completed_levels == 6, "Failed refresh cannot restore stale cached cloud progress")
	cloud.response = {"ok": true, "data": {"format": 1, "catalog_version": 1, "completed_levels": Progress.Catalog.COUNT + 1, "revision": 5}}
	await restored.restore()
	check(progress.data.completed_levels == 6, "Invalid cloud completion is rejected")
	cloud.player_id = Codec.uuid()
	cloud.response = {"ok": true, "data": {"status": "ok", "revision": 1}}
	await restored.upload()
	check(cloud.sent[-1].body.expected_revision == 0 and restored.state.player_id == cloud.player_id, "A new account does not reuse another account's upload or revision")
	# Clean only this fixture's files, including migration/restore archives.
	var dir := DirAccess.open("user://")
	for filename in dir.get_files():
		if filename.begins_with(progress.path.trim_prefix("user://")):
			DirAccess.remove_absolute("user://" + filename)
	backup.queue_free()
	restored.queue_free()
	cloud.queue_free()
	print("Campaign backup: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
