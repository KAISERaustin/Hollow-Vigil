extends "res://tests/test_runner.gd"
const Backup = preload("res://scripts/cloud/private_backups.gd")
const FakeCloud = preload("res://tests/support/private_cloud_fixture.gd")
const Build = preload("res://scripts/persistence/reusable_build.gd")
const Codec = preload("res://scripts/cloud/cloud_codec.gd")

func run() -> void:
	var cloud := FakeCloud.new()
	root.add_child(cloud)
	cloud.player_id = Codec.uuid()
	cloud.refresh_token = "fixture"
	var backup := Backup.new()
	backup.cloud = cloud
	backup.enabled = false
	backup.slots.base_path = "user://delete-test-" + Codec.uuid()
	backup.campaign_slots.base_path = backup.slots.base_path
	backup.state_path = backup.slots.base_path + ".cfg"
	root.add_child(backup)
	var world := VigilState.new(42)
	var active := backup.slots.path_for(0)
	check(backup.slots.storage.write(active, world.data), "Write active fixture")
	var recovery := active + ".recovery-test"
	var other := active + ".recovery-other"
	check(backup.slots.storage.write(recovery, world.data) and backup.slots.storage.write(other, world.data), "Write individual recovery copies")
	check(not backup.delete_recovery(active), "Delete refuses active game paths")
	check(backup.delete_recovery(recovery), "Delete selected recovery copy")
	check(not FileAccess.file_exists(recovery) and FileAccess.file_exists(other) and FileAccess.file_exists(active), "Other backups and active game survive")
	var code := Build.encode(Build.capture("infinite", world, {}, "all", -1, {"enemies": ["basic"]}, "Delete me", ""))
	check(backup.slots.save_shared(code), "Write private build")
	await backup.sync_now()
	var remote: Dictionary = backup.remote_games[0].duplicate(true)
	var stale := remote.duplicate(true)
	stale.revision = 50
	check(not await backup.delete_game(stale, cloud.player_id), "Stale confirmation cannot delete changed cloud revision")
	check(not await backup.delete_game(remote, Codec.uuid()), "Changed account cannot delete reviewed backup")
	cloud.fail_next = true
	check(not await backup.delete_build(code, cloud.player_id), "Network failure preserves local build")
	check(backup.slots.shared_configurations("all").size() == 1, "Failed deletion leaves build available")
	check(await backup.delete_build(code, cloud.player_id), "Delete account private build")
	check(backup.slots.shared_configurations("all").is_empty(), "Deleted build removed locally")
	check(await backup.delete_game(remote, cloud.player_id), "Delete reviewed cloud game")
	await backup.sync_now()
	check(backup.remote_games.is_empty() and FileAccess.file_exists(active), "Unchanged local game does not recreate deleted cloud backup")
	check(backup.slots.save_shared(code), "Simulate stale device build copy")
	await backup.sync_now()
	check(backup.slots.shared_configurations("all").is_empty() and cloud.accounts[cloud.player_id].builds.is_empty(), "Account tombstone removes stale copy instead of reuploading")
	backup.queue_free()
	cloud.queue_free()
	print("BACKUP DELETION: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
