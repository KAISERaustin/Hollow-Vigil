extends "res://tests/test_runner.gd"
const Backup = preload("res://scripts/cloud/private_backups.gd")
const Cloud = preload("res://tests/support/private_cloud_fixture.gd")
const Build = preload("res://scripts/persistence/reusable_build.gd")

class ObservedBackup extends "res://scripts/cloud/private_backups.gd":
	var scans := 0
	func cloud_entries() -> Array:
		scans += 1
		return super.cloud_entries()

func idle(backup: Node) -> void:
	# Exercise former startup, save, periodic and retry deadlines if reintroduced.
	for seconds in [1.0, 3.0, 60.0, 300.0, 600.0]:
		if backup.has_method("_process"): backup.call("_process", seconds)
		for frame in 3: await process_frame

func run() -> void:
	var cloud := Cloud.new()
	cloud.player_id = Cloud.Codec.uuid()
	cloud.refresh_token = "fixture"
	root.add_child(cloud)
	var backup := ObservedBackup.new()
	backup.cloud = cloud
	backup.slots.base_path = "user://campaign-private-" + Cloud.Codec.uuid()
	backup.campaign_slots.base_path = backup.slots.base_path
	backup.state_path = backup.slots.base_path + ".cfg"
	root.add_child(backup)
	for slot in 3:
		check(not backup.campaign_slots.create(slot, "creative" if slot == 0 else "survival", "Campaign %d" % slot).is_empty(), "Create independent Campaign slot")
	var build := Build.capture("campaign", null, {}, "all", -1, Build.all_contents("campaign", "rules"), "Campaign rules", "")
	var code := Build.encode(build)
	check(backup.slots.save_shared(code), "Save compatible private build")
	await idle(backup)
	check(not backup.is_processing() and cloud.sent.is_empty() and backup.scans == 0, "Signed-in startup and elapsed deadlines never scan or back up")
	backup.library_status()
	check(backup.scans == 0, "Library status never scans saved builds")
	check(await backup.upload_build(code), "Explicit Upload build succeeds")
	check(cloud.sent.size() == 1 and cloud.sent[0].method == "put_private_build", "Upload build sends only the selected build")
	check(backup.scans == 0 and cloud.accounts[cloud.player_id].games.is_empty(), "Selected upload does not scan the library or upload game slots")
	cloud.fail_next = true
	check(not await backup.upload_build(code), "Failed explicit upload reports failure")
	var failed_count := cloud.sent.size()
	await idle(backup)
	check(cloud.sent.size() == failed_count, "Failed upload never retries automatically")
	await backup.sync_now()
	check(backup.local_games().size() == 3 and backup.remote_games.size() == 3, "All three Campaign slots back up")
	check(cloud.publications.is_empty(), "Private backup cannot publish Community content")
	var account: Dictionary = cloud.accounts[cloud.player_id]
	account.games["unsupported:0"] = {"snapshot": {"name": "Archived game", "mode": "creative"}, "revision": 1, "content_hash": "old"}
	var old_code := "unsupported archived library format"
	account.builds[old_code.sha256_text()] = old_code
	await backup.sync_now()
	check(backup.remote_games.size() == 3, "Remote games from unsupported modes stay outside the menu")
	check(account.games.has("unsupported:0") and account.builds.has(old_code.sha256_text()), "Filtering preserves remote records")
	check(backup.status == "Saved games and My builds are backed up.", "Unsupported remote library entries do not block backup")
	var remote := await backup.read_backup("campaign", 1)
	check(not remote.is_empty() and remote.snapshot.name == "Campaign 1", "Campaign restore reads validated snapshot")
	check(backup.campaign_slots.replace(2, remote.snapshot), "Reviewed restore writes destination Campaign slot")
	backup.accept_restored("campaign", 2, 1, int(remote.revision))
	var restored_count := cloud.sent.size()
	await idle(backup)
	check(cloud.sent.size() == restored_count, "Restoring into a different slot never queues an upload")
	check(backup.campaign_slots.summary(0).name == "Campaign 0", "Restore preserves another Campaign slot")
	check(backup.recovery_games().size() == 1, "Replacement preserves local recovery copy")
	var before := cloud.sent.size()
	check((await backup.read_backup("unsupported", 0)).is_empty() and cloud.sent.size() == before, "Unsupported restore never reaches the server")
	before = cloud.sent.size()
	await backup.keep_local("campaign", 1, int(remote.revision))
	await idle(backup)
	check(cloud.sent.size() == before, "Keeping the device version waits for an explicit upload")
	await backup.sync_now(false)
	for request in cloud.sent.slice(before):
		check(not request.method.begins_with("put_"), "Recovery cannot upload slots or library entries")
	var previous_account: String = cloud.player_id
	cloud.player_id = Cloud.Codec.uuid()
	cloud.generation += 1
	before = cloud.sent.size()
	await idle(backup)
	backup.refresh_account()
	check(cloud.sent.size() == before and backup.remote_games.is_empty() and backup.conflicts.is_empty(), "Changing accounts clears displayed backups without syncing")
	cloud.change_account_during_read = true
	check(not await backup.upload_build(code), "An account change during upload rejects the stale result")
	check(backup.state[previous_account].builds.has(code.sha256_text()), "Account change preserves earlier uploaded-build records")
	for request in cloud.sent:
		if request.method == "put_private_game": check(request.body.game_type == "campaign", "Only Campaign snapshots are uploaded")
	backup.queue_free()
	cloud.queue_free()
	await process_frame
	print("CAMPAIGN PRIVATE BACKUPS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
