extends SceneTree

const Codec = preload("res://scripts/cloud/cloud_codec.gd")

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func run() -> void:
	var fixtures: Array = []
	var games: Array = [VigilState.new(424242)]
	for kind in ["warden", "cindermaw", "bell", "prior"]:
		games.append(preload("res://tests/unit/boss_checks.gd").fixture(kind))
	games.append(preload("res://tests/unit/castle_checks.gd").fixture())
	var equipped := preload("res://tests/unit/boss_checks.gd").fixture("warden")
	var source: String = equipped.combat.enemies[0].source
	equipped.combat.enemies.clear()
	equipped.data.regions[source].boss = {"kind": "warden", "status": "defeated"}
	equipped.data.relics[source] = "warden"
	var tower := equipped.economy.build("electric", "0,0", 0)
	equipped.data.towers[tower].relic = source
	equipped.data.regions["0,0"].history[tower] = 12.5
	equipped.data.regions["0,0"].history_time = 15.5
	equipped.data.settings.audio = {"master": 0.3, "muted": true}
	games.append(equipped)
	var codec := Codec.new()
	for game in games:
		# Use the real durable save format before projecting anything to the wire.
		game.save_path = "user://cloud-fixture-" + Codec.uuid() + ".save"
		if not game.save():
			push_error("Fixture save failed")
			quit(1)
			return
		var loaded := VigilSaveStore.new().read_candidate(game.save_path)
		var payload := codec.encode(loaded, Codec.uuid(), true)
		if payload.is_empty() or codec.decode(payload).is_empty():
			push_error("Fixture codec failed: " + codec.error)
			quit(1)
			return
		fixtures.append(payload)
		DirAccess.remove_absolute(game.save_path)
	var file := FileAccess.open("res://artifacts/cloud-payload-fixtures.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(fixtures, "", true, true))
	print("Generated %d real save/reload cloud fixtures" % fixtures.size())
	quit()
