extends SceneTree
const Slots = preload("res://scripts/persistence/campaign_slots.gd")
const Backup = preload("res://scripts/cloud/private_backups.gd")
const Build = preload("res://scripts/persistence/reusable_build.gd")
const Cloud = preload("res://tests/support/private_cloud_fixture.gd")
var watching := false
var previous_frame := 0
var frame_gaps := []

const Run = preload("res://scripts/campaign/run.gd")
## Diagnostic only: synthetic files, fake network, no player saves or live account.
## Timing output is machine-dependent; this is not a pass/fail FPS test.
func _initialize():
	process_frame.connect(record_frame)
	call_deferred("probe")
func record_frame():
	var now := Time.get_ticks_usec()
	if watching: frame_gaps.append((now - previous_frame) / 1000.0)
	previous_frame = now

func measure(label: String, action: Callable, count: int = 5):
	var samples := []
	for index in count:
		var start := Time.get_ticks_usec()
		action.call()
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	print(label, " ms=", samples)
func probe():
	var backup := Backup.new()
	var cloud := Cloud.new()
	cloud.player_id = Cloud.Codec.uuid()
	cloud.refresh_token = "fixture"
	root.add_child(cloud)
	backup.cloud = cloud
	backup.slots.base_path = "user://performance-probe-%d" % Time.get_ticks_usec()
	backup.campaign_slots.base_path = backup.slots.base_path
	backup.state_path = backup.slots.base_path + ".cfg"
	root.add_child(backup)
	var slots = backup.campaign_slots
	var values := []
	for index in 3:
		values.append(slots.create(index, "survival", "Performance fixture %d" % index))
	measure("save default 48-level slot", func(): slots.save_slot(0, values[0]))
	measure("read and hash three slots", func(): backup.local_games())
	var levels := {}
	for index in 48:
		levels[str(index)] = {"overrides": {"tuning": {"towers": {"rapid": {"damage": 12.0}}}}}
	var build := Build.capture("campaign", null, levels, "all", -1, Build.all_contents("campaign", "rules"), "Performance fixture", "")
	var code := Build.encode(build)
	print("library fixture bytes=", code.length())
	backup.slots.save_shared(code)
	measure("scan library one build", func(): backup.cloud_entries())
	for index in range(1, 5):
		build.setup.name = "Performance fixture %d" % index
		backup.slots.save_shared(Build.encode(build))
	measure("scan library five builds", func(): backup.cloud_entries(), 3)
	await process_frame
	watching = true
	var sync_start := Time.get_ticks_usec()
	await backup.sync_now()
	await process_frame
	watching = false
	frame_gaps.sort()
	print("full sync fake network ms=", (Time.get_ticks_usec() - sync_start) / 1000.0, " longest frame gaps=", frame_gaps.slice(maxi(0, frame_gaps.size()-5)), " status=", backup.status)
	var run = Run.new(0)
	run.game.data.balance = 100000
	for socket in run.mission.pads: run.build(socket, "rapid")
	run.start_wave()
	var times := []
	for index in 1200:
		if run.phase == "planning": run.start_wave()
		if run.phase != "wave": break
		var start := Time.get_ticks_usec()
		run.tick(Balance.STEP)
		times.append((Time.get_ticks_usec()-start)/1000.0)
	times.sort()
	print("combat ticks=", times.size(), " p50=", times[times.size()/2], " p99=", times[int(times.size()*0.99)], " max=", times.back(), " kills=", run.game.data.kills)
	for index in 3: slots.delete_slot(index)
	var directory := DirAccess.open(backup.slots.configurations_path())
	if directory != null:
		for file in directory.get_files(): DirAccess.remove_absolute(backup.slots.configurations_path().path_join(file))
		DirAccess.remove_absolute(backup.slots.configurations_path())
	DirAccess.remove_absolute(backup.state_path)
	backup.queue_free()
	cloud.queue_free()
	await process_frame
	quit()
