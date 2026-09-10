extends "res://tests/test_runner.gd"
const Backup = preload("res://scripts/cloud/private_backups.gd")
const Cloud = preload("res://tests/support/private_cloud_fixture.gd")
const Build = preload("res://scripts/persistence/reusable_build.gd")

func run() -> void:
	var cloud := Cloud.new()
	cloud.player_id = Cloud.Codec.uuid()
	cloud.refresh_token = "fixture"
	root.add_child(cloud)
	var backup := Backup.new()
	backup.cloud = cloud
	backup.enabled = false
	backup.slots.base_path = "user://campaign-private-" + Cloud.Codec.uuid()
	backup.campaign_slots.base_path = backup.slots.base_path
	backup.state_path = backup.slots.base_path + ".cfg"
	root.add_child(backup)
	for slot in 3:
		check(not backup.campaign_slots.create(slot, "creative" if slot == 0 else "survival", "Campaign %d" % slot).is_empty(), "Create independent Campaign slot")
	var build := Build.capture("campaign", null, {}, "all", -1, Build.all_contents("campaign", "rules"), "Campaign rules", "")
	var code := Build.encode(build)
	check(backup.slots.save_shared(code), "Save compatible private build")
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
	check(backup.campaign_slots.summary(0).name == "Campaign 0", "Restore preserves another Campaign slot")
	check(backup.recovery_games().size() == 1, "Replacement preserves local recovery copy")
	var before := cloud.sent.size()
	check((await backup.read_backup("unsupported", 0)).is_empty() and cloud.sent.size() == before, "Unsupported restore never reaches the server")
	for request in cloud.sent:
		if request.method == "put_private_game": check(request.body.game_type == "campaign", "Only Campaign snapshots are uploaded")
	backup.queue_free()
	cloud.queue_free()
	await process_frame
	print("CAMPAIGN PRIVATE BACKUPS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
