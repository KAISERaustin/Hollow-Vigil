extends "res://tests/test_runner.gd"
const Backup = preload("res://scripts/cloud/private_backups.gd")
const FakeCloud = preload("res://tests/support/private_cloud_fixture.gd")
const Build = preload("res://scripts/persistence/reusable_build.gd")
const Codec = preload("res://scripts/cloud/cloud_codec.gd")

func service(cloud: Node) -> Node:
	var backup := Backup.new()
	backup.cloud = cloud
	backup.enabled = false
	backup.slots.base_path = "user://private-fixture-" + Codec.uuid()
	backup.campaign_slots.base_path = backup.slots.base_path
	backup.state_path = backup.slots.base_path + ".cfg"
	root.add_child(backup)
	return backup

func run() -> void:
	var cloud := FakeCloud.new()
	root.add_child(cloud)
	var first := service(cloud)
	var owner := Codec.uuid()
	for slot in 3:
		check(not first.campaign_slots.create(slot, "survival", "Campaign " + str(slot + 1)).is_empty(), "Create complete Campaign backup fixture")
		var world := VigilState.new(600 + slot, "creative")
		world.data.setup = {"name": "Infinite " + str(slot + 1), "description": ""}
		check(first.slots.storage.write(first.slots.path_for(slot), world.data), "Create complete Infinite backup fixture")
	var code := Build.encode(Build.capture("infinite", VigilState.new(), {}, "all", -1, {"enemies": ["basic"]}, "Private rules", ""))
	check(first.slots.save_shared(code), "Save offline private build")
	await first.sync_now()
	check(cloud.sent.is_empty(), "Offline local saving never attempts cloud writes")
	cloud.player_id = owner
	cloud.refresh_token = "fixture"
	cloud.display_name = "Fixture player"
	cloud.fail_next = true
	await first.sync_now()
	check(first.due == 15 and first.retry_delay == 30, "Connection failure schedules bounded automatic retry")
	check(first.game_status("campaign", 0).contains("pending"), "Offline progress is visibly pending")
	await first.sync_now()
	check(cloud.accounts[owner].games.size() == 6, "One sync protects exactly six active game slots")
	check(cloud.accounts[owner].builds.size() == 1 and first.library_status().contains("up to date"), "Private library is backed up independently")
	check(cloud.publications.is_empty(), "Automatic private backups never publish Community content")
	var sent := cloud.sent.size()
	await first.sync_now()
	var changes: Array = cloud.sent.slice(sent).filter(func(item): return item.method.begins_with("put_"))
	check(changes.is_empty(), "Unchanged acknowledged files do not repeatedly upload")
	var second := service(cloud)
	await second.sync_now()
	check(second.local_games().is_empty() and second.remote_games.size() == 6, "Another device lists backups without consuming local slots")
	check(second.slots.shared_configurations("all").size() == 1, "Another device automatically recovers My builds")
	var saved: Dictionary = await second.read_backup("campaign", 0)
	check(not saved.is_empty(), "Validated complete Campaign backup is readable")
	check(second.campaign_slots.replace(0, saved.snapshot), "Explicit destination restore writes complete record")
	second.accept_restored("campaign", 0, 0, saved.revision)
	var local: Dictionary = second.campaign_slots.summary(0)
	local.completed = 2
	check(second.campaign_slots.save_slot(0, local), "Second device progresses independently")
	await second.sync_now()
	check(cloud.accounts[owner].games["campaign:0"].revision == 2, "Second device advances known revision")
	await first.sync_now()
	check(first.conflicts.has("campaign:0"), "Unchanged first device detects a newer cloud version")
	local = first.campaign_slots.summary(0)
	local.completed = 1
	first.campaign_slots.save_slot(0, local)
	await first.sync_now()
	check(cloud.accounts[owner].games["campaign:0"].snapshot.completed == 2, "Diverged local progress cannot silently overwrite cloud")
	await first.keep_local("campaign", 0, 1)
	check(first.conflicts.has("campaign:0"), "A stale reviewed revision conflicts again")
	await first.keep_local("campaign", 0, 2)
	check(first.campaign_slots.summary(0).completed == 1 and cloud.accounts[owner].games["campaign:0"].snapshot.completed == 1, "Keep device uploads chosen local version without restoring")
	check(second.campaign_slots.summary(0).completed == 2, "Choosing local on one device leaves the other device untouched")
	DirAccess.remove_absolute(second.slots.configurations_path().path_join(code.sha256_text() + ".hvshared"))
	await second.sync_now()
	check(second.slots.shared_configurations("all").size() == 1, "Library loss recovers even if prior acknowledgement survives")
	cloud.change_account_during_read = true
	check((await second.read_backup("campaign", 0)).is_empty(), "Account switch discards an in-flight backup read")
	await second.sync_now()
	check(second.remote_games.size() == 1 and not second.conflicts.has("campaign:0"), "New account uses independent acknowledgement and conflict state")
	check(cloud.accounts[owner].games.size() == 6, "Account switch preserves former account's six backups")
	first.queue_free()
	second.queue_free()
	cloud.queue_free()
	await process_frame
	print("PRIVATE_BACKUPS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
