extends SceneTree

# Opt-in live checks. Credentials come only from the environment, never files.
const Service = preload("res://scripts/cloud/cloud_service.gd")
const Codec = preload("res://scripts/cloud/cloud_codec.gd")
var checks := 0
var failures := 0
var s: Node
var restored_snapshot: Dictionary = {}

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 180.0)
	call_deferred("run")

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: " + message)
	return ok

func run() -> void:
	s = Service.new()
	s.game = VigilState.new(424242)
	s.game.save_path = "user://cloud-live-" + Codec.uuid() + ".save"
	s.enabled = false
	root.add_child(s)
	var address := OS.get_environment("HOLLOW_QA_EMAIL")
	if address.is_empty(): address = OS.get_environment("HOLLOW_CLOUD_EMAIL")
	if address.is_empty():
		push_error("Set HOLLOW_CLOUD_EMAIL and HOLLOW_CLOUD_CODE, or pass --send-code")
		quit(1)
		return
	if "--send-code" in OS.get_cmdline_user_args():
		await s.send_code(address)
		check(s.email == address, "Email code request: " + s.status)
		finish()
		return
	s.email = address
	var password := OS.get_environment("HOLLOW_QA_PASSWORD")
	if not password.is_empty():
		OS.set_environment("HOLLOW_QA_PASSWORD", "")
		var session: Dictionary = await s._request("/auth/v1/token?grant_type=password", {"email": address, "password": password}, false)
		password = ""
		if session.ok and s._accept_session(session.data): await s.refresh_worlds()
	else:
		await s.verify_link(OS.get_environment("HOLLOW_CLOUD_CODE"))
	if not check(s.signed_in() and s.status.begins_with("Signed in"), "Email verification and authenticated listing"):
		finish()
		return
	# A real save/load cycle before the first upload reproduces the reported bug.
	s.game.data.balance = 10000.0
	s.game.expand("1,0")
	var tower: String = s.game.economy.build("electric", "0,0", 0)
	s.game.data.regions["0,0"].history[tower] = 12.5
	s.game.data.regions["0,0"].history_time = 15.5
	s.game.data.settings.audio = {"master": 0.3, "muted": true}
	s.include_audio = true
	if not check(s.game.save(), "Write populated local fixture"):
		finish()
		return
	var loaded := VigilSaveStore.new().read_candidate(s.game.save_path)
	if not check(not loaded.is_empty(), "Reload durable fixture"):
		finish()
		return
	s.game.data = loaded
	await s.start_backup()
	if not check(s.game.data.cloud.revision == 1 and s.pending.is_empty(), "First backup after durable save/reload: " + s.status):
		finish()
		return
	var wid: String = s.game.data.cloud.world_id
	var read: Dictionary = await s._rpc("read_save", {"world": wid})
	if not check(read.ok and read.data is Dictionary, "Live readback"):
		finish()
		return
	var decoded := Codec.new().decode(read.data.payload, s.game.data.settings, s.game.data.camera, true)
	check(not decoded.is_empty() and decoded.balance == s.game.data.balance and decoded.towers.has(tower), "Cross-client restore preserves money and tower")
	check(not decoded.is_empty() and decoded.settings.audio.master == 0.3 and decoded.regions["0,0"].history[tower] == 12.5, "Sound preference and production restore")
	# Parsed REST data is all floats; this also covers legacy durable outboxes.
	var args := {"payload": read.data.payload, "expected_revision": 1, "mutation": Codec.uuid()}
	var reply: Dictionary = await s._rpc("publish_save", args)
	check(reply.ok and reply.data.get("revision") == 2, "Legacy float-valued outbox uploads")
	reply = await s._rpc("publish_save", args)
	check(reply.ok and reply.data.get("revision") == 2, "Lost-response retry is idempotent")
	s.game.data.balance += 17.25
	await s.sync_now()
	check(s.conflict.get("revision") == 2 and s.game.data.cloud.revision == 1, "Second-device revision produces conflict")
	await s.keep_local()
	check(s.conflict.is_empty() and s.game.data.cloud.revision == 3, "Keep-local conflict resolution")
	s.restore_requested.connect(func(snapshot: Dictionary, _world: String, _revision: int): restored_snapshot = snapshot)
	await s.restore_world(wid)
	check(not restored_snapshot.is_empty() and restored_snapshot.balance == s.game.data.balance, "Restore request returns validated latest snapshot")
	s.game.data = restored_snapshot
	s.restore_completed(true)
	check(s.pending.is_empty() and s.conflict.is_empty(), "Successful restore clears old outbox and conflict")
	# Exercise a real token refresh before the next RPC.
	s.expires_at = 0.0
	await s.refresh_worlds()
	check(s.signed_in() and s.expires_at > Time.get_unix_time_from_system() + 60, "Expired access token refreshes")
	var listed := false
	for world in s.worlds:
		if world.world_id == wid and int(world.revision) == 3: listed = true
	check(listed, "Refresh lists latest revision")
	# Network outage in this client only; retain the exact queued mutation.
	var base: String = s.url
	s.url = "http://127.0.0.1:1"
	await s.sync_now()
	check(not s.pending.is_empty() and s.game.data.cloud.revision == 3, "Offline failure preserves outbox and revision")
	var mutation: String = s.pending.mutation
	s._load_pending()
	check(s.pending.get("mutation") == mutation, "Durable outbox reload preserves mutation")
	s.url = base
	await s.sync_now()
	check(s.pending.is_empty() and s.game.data.cloud.revision == 4, "Network recovery delivers queued progress")
	s.enabled = true
	s.retry_after = 0.0
	s.sync_timer = 60.0
	s._process(0.0)
	while s.busy: await process_frame
	check(s.game.data.cloud.revision == 5, "Automatic minute sync")
	s.enabled = false
	s.game.set_balance_stat("enemies", "basic", "hp", 200.0)
	s.game.data.mode = "survival"
	s.game.data.setup = {"name": "Live custom rules", "description": "QA cloud round trip"}
	await s.sync_now()
	read = await s._rpc("read_save", {"world": wid})
	decoded = Codec.new().decode(read.data.payload)
	check(s.game.data.cloud.revision == 6 and not decoded.is_empty() and decoded.mode == "survival" and decoded.settings.developer_balance == s.game.tuning and decoded.setup == s.game.data.setup, "Custom Survival rules and configuration round trip through live API")
	s.sign_out()
	await s.sync_now()
	check(not s.signed_in() and s.game.save(), "Sign-out stops sync and local saving continues")
	print("Test world: " + wid)
	finish()

func finish() -> void:
	for suffix in ["", ".bak", ".tmp", ".cloud-outbox", ".cloud-outbox.tmp"]:
		if FileAccess.file_exists(s.game.save_path + suffix): DirAccess.remove_absolute(s.game.save_path + suffix)
	s.queue_free()
	print("Live cloud: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
