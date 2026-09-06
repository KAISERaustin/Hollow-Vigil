extends "res://tests/test_runner.gd"

const Service = preload("res://scripts/cloud/cloud_service.gd")
const Codec = preload("res://scripts/cloud/cloud_codec.gd")

func run() -> void:
	var game := VigilState.new(879)
	var gate := preload("res://tests/support/orchard_fixture.gd").populate(game)
	game.save_path = "user://orchard-live-" + Codec.uuid() + ".save"
	for kind in Balance.ORCHARD_KINDS:
		for stat in ["hp","speed","payout","push_resistance"]:
			check(game.set_balance_stat("enemies",kind,stat,{"hp":333.0,"speed":51.0,"payout":37.0,"push_resistance":62.0}[stat]),"Prepare Orchard tuning")
	check(game.save(),"Durable Orchard save before upload")
	var s := Service.new()
	s.game = game
	s.enabled = false
	root.add_child(s)
	var password := OS.get_environment("HOLLOW_QA_PASSWORD")
	OS.set_environment("HOLLOW_QA_PASSWORD","")
	var session: Dictionary = await s._request("/auth/v1/token?grant_type=password", {"email":OS.get_environment("HOLLOW_QA_EMAIL"),"password":password},false)
	password = ""
	if not session.ok or not s._accept_session(session.data):
		check(false,"QA authentication failed (HTTP %s)" % session.get("code",0))
		quit(1)
		return
	await s.start_backup()
	check(s.game.data.get("cloud",{}).get("revision",0) == 1 and s.pending.is_empty(),"Orchard cloud upload: " + s.status)
	if not s.game.data.has("cloud"):
		quit(1)
		return
	var wid: String = s.game.data.cloud.world_id
	var evidence := {"world_id":wid,"player_id":s.player_id,"public_build_id":""}
	var result: Dictionary = await s._rpc("read_save",{"world":wid})
	var restored := Codec.new().decode(result.get("data",{}).get("payload",{}))
	check(not restored.is_empty() and restored.settings.developer_balance == game.tuning and restored.regions[gate].style == "mourning_orchard","Authenticated readback preserves Orchard terrain and every edited stat")
	game.set_balance_stat("enemies","coffinbound","hp",901.0)
	await s.sync_now()
	check(game.data.cloud.revision == 2 and s.pending.is_empty(),"Subsequent developer edit syncs")
	result = await s._rpc("read_save",{"world":wid})
	restored = Codec.new().decode(result.get("data",{}).get("payload",{}))
	check(not restored.is_empty() and restored.settings.developer_balance.enemies.coffinbound.hp == 901.0,"Updated stat survives backend readback")
	var builds := preload("res://scripts/cloud/public_builds.gd").new()
	builds.cloud = s
	builds.outbox_path = game.save_path + ".public-outbox"
	root.add_child(builds)
	builds.set_process(false)
	var code := VigilSaveSlots.new().export_build(game,"QA Mourning Orchard verification","Temporary automated configuration roundtrip")
	check(builds.queue_export(code),"Config queues through production Public Builds service")
	if not builds.outbox.is_empty():
		evidence.public_build_id = builds.outbox[0].id
		await builds.flush()
		check(builds.outbox.is_empty(),"Public configuration uploaded: " + builds.status)
		var published := await builds.read_build(evidence.public_build_id)
		check(not published.is_empty() and published.code == code,"Public configuration reads back without losing enemy tuning")
		if not published.is_empty():
			var slots := VigilSaveSlots.new()
			slots.base_path = game.save_path + ".survival"
			var survival := slots.create(0,"survival",published.code)
			check(survival != null and survival.tuning == game.tuning and survival.data.regions[gate].style == "mourning_orchard","Published setup imports into Survival with all Orchard rules")
			if survival != null:
				check(not survival.set_balance_stat("enemies","coffinbound","hp",1.0),"Imported Survival rules remain locked")
			clean_test_save(slots.path_for(0))
	evidence.checks = checks
	evidence.failures = failures
	FileAccess.open("res://artifacts/orchard-live-evidence.json",FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
	# Keep exact payloads for transactional table-level verification / regression.
	FileAccess.open("res://artifacts/orchard-cloud-payload.json",FileAccess.WRITE).store_string(JSON.stringify(Codec.new().encode(game.snapshot(),wid)))
	print("ORCHARD LIVE: %d checks, %d failures; IDs in artifacts/orchard-live-evidence.json" % [checks,failures.size()])
	clean_test_save(game.save_path)
	for suffix in [".cloud-outbox",".public-outbox"]:
		if FileAccess.file_exists(game.save_path + suffix): DirAccess.remove_absolute(game.save_path + suffix)
	quit(0 if failures.is_empty() else 1)
