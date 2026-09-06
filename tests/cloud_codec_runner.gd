extends SceneTree

const Codec = preload("res://scripts/cloud/cloud_codec.gd")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var c := Codec.new()
	var g := VigilState.new(42)
	g.data.balance = 100000.0
	g.expand("-1,0")
	var id := g.economy.build("rapid", "-1,0", 0)
	g.data.towers[id].target_mode = "most_hp"
	g.data.towers[id].rebuild_remaining = 10.0
	g.data.towers[id].earnings = 27.0
	g.data.regions["-1,0"].history[id] = 80.0
	g.data.regions["-1,0"].history_time = 100.0
	g.data.regions["0,0"].history_time = 90.0
	g.data.settings.audio = {"master": 0.3, "muted": true}
	g.data.settings.secret_extra = "MUST_NOT_UPLOAD"
	g.data.secret_extra = "MUST_NOT_UPLOAD"
	g.data.camera = [55.0, 20.0, 1.5]
	var wid := Codec.uuid()
	var p := c.encode(g.snapshot(1000), wid, true)
	check(not p.is_empty(), "Encode populated save: " + c.error)
	check(Codec.valid_uuid(wid) and Codec.valid_uuid(p.regions[0].id), "Entities use UUIDs")
	check(Codec.entity_id(wid,"tower",id) == p.towers[0].id, "Stable tower UUID")
	check(Codec.entity_id(Codec.uuid(),"tower",id) != p.towers[0].id, "Worlds have disjoint entity IDs")
	var text := JSON.stringify(p)
	check(not "MUST_NOT_UPLOAD" in text and not '"camera"' in text and not '"cooldown"' in text and not '"path"' in text, "Allowlist excludes arbitrary data, camera, combat and paths")
	var restored := c.decode(JSON.parse_string(text), {"low_power": true}, [1.0,2.0,0.8], true)
	check(not restored.is_empty(), "Decode round trip: " + c.error)
	if not restored.is_empty():
		check(restored.regions["0,0"].history_time == 90.0, "Empty production windows retain their duration")
		check(restored.seed == g.data.seed and restored.balance == g.data.balance, "Seed and money restore")
		check(restored.towers[id].target_mode == "most_hp" and restored.towers[id].earnings == 27.0, "Tower targeting and earnings restore")
		check(restored.settings.low_power and restored.camera == [1.0,2.0,0.8], "Device preferences preserved")
		check(restored.settings.audio.master == 0.3 and restored.settings.audio.muted, "Opted-in audio restores")
		check(restored.regions["-1,0"].history[id] == 80.0 and restored.regions["-1,0"].history_time == 100.0, "Production checkpoint restores")
	# Save files and REST responses decode JSON numbers as floats in Godot.
	var reloaded: Dictionary = JSON.parse_string(JSON.stringify(g.snapshot(1000), "", true, true))
	var wire := c.encode(reloaded, wid, true)
	check(wire.world.seed is int and wire.world.save_version is int and wire.progress[0].next_tower is int, "Reloaded world integer fields serialize for Postgres")
	check(wire.towers[0].pad is int and wire.towers[0].level is int and wire.regions[0].bend is int, "Reloaded entity integer fields serialize for Postgres")
	check(not c.decode(wire).is_empty() and wire.progress == p.progress and wire.checkpoints == p.checkpoints, "Integer normalization preserves progress and decodes successfully")
	var p2 := c.encode(g.snapshot(1000),wid,false)
	check(p2.preferences.is_empty(), "No preferences uploaded by default")
	p2.towers[0].region_id = Codec.uuid()
	check(c.decode(p2).is_empty(), "Broken entity links rejected")
	p2 = p.duplicate(true)
	p2.regions[0].extra = "secret"
	check(c.decode(p2).is_empty(), "Unknown cloud fields rejected")
	p2 = p.duplicate(true)
	p2.towers[0].earnings = -1
	check(c.decode(p2).is_empty(), "Invalid economy rejected")
	p2 = p.duplicate(true)
	p2.regions.append(p2.regions[0].duplicate())
	check(c.decode(p2).is_empty(), "Duplicate UUIDs rejected")
	for kind in ["warden", "cindermaw", "bell", "prior"]:
		var encounter := preload("res://tests/unit/boss_checks.gd").fixture(kind)
		var before := encounter.snapshot()
		var encoded := c.encode(before, Codec.uuid())
		var loaded_encounter: Dictionary = JSON.parse_string(JSON.stringify(before, "", true, true))
		var loaded_payload := c.encode(loaded_encounter, encoded.world.id)
		for row in loaded_payload.encounters:
			if row.status == "active":
				check(row.steps is int and row.wards is int and row.segment is int, "Reloaded boss counters serialize as integers")
		var decoded := c.decode(encoded)
		check(not decoded.is_empty(), "Active " + kind + " encounter restores: " + c.error)
		if not decoded.is_empty():
			for region in before.regions:
				if before.regions[region].has("boss"):
					check(decoded.regions[region].boss == before.regions[region].boss, "Boss path reconstructed exactly from compact checkpoint")
	var castle := preload("res://tests/unit/castle_checks.gd").fixture()
	var castle_data := castle.snapshot()
	var castle_restored := c.decode(c.encode(castle_data,Codec.uuid()))
	check(not castle_restored.is_empty(), "Castle emergence restores: " + c.error)
	if not castle_restored.is_empty():
		check(castle_restored.castles == castle_data.castles, "Castle gate routes reconstruct exactly")
	var relic_game := preload("res://tests/unit/boss_checks.gd").fixture("warden")
	var source: String = relic_game.combat.enemies[0].source
	relic_game.combat.enemies.clear()
	relic_game.data.regions[source].boss = {"kind":"warden","status":"defeated"}
	relic_game.data.relics[source] = "warden"
	var relic_tower := relic_game.economy.build("electric","0,0",0)
	relic_game.data.towers[relic_tower].relic = source
	var relic_restored := c.decode(c.encode(relic_game.snapshot(),Codec.uuid()))
	check(not relic_restored.is_empty(), "Relic and fourth tower type restore: " + c.error)
	if not relic_restored.is_empty():
		check(relic_restored.relics == relic_game.data.relics and relic_restored.towers[relic_tower].relic == source, "Equipped relic identity preserved")
	g.data.settings.developer_balance = {"towers":{"rapid":{"damage":20.0}}}
	g.data.mode = "survival"
	g.data.setup = {"name": "Custom survival", "description": "Harder opening"}
	var custom := c.decode(c.encode(g.snapshot(), wid))
	check(not custom.is_empty() and custom.settings.developer_balance == g.data.settings.developer_balance, "Custom balance survives cloud round trip")
	check(not custom.is_empty() and custom.mode == "survival" and custom.setup == g.data.setup, "Mode and configuration survive cloud round trip")
	var legacy := p.duplicate(true)
	legacy.format = 1
	legacy.erase("world_rules")
	check(not c.decode(legacy).is_empty(), "Legacy cloud saves still restore")
	var invalid := c.encode(g.snapshot(), wid)
	invalid.world_rules[0].mode = "invalid"
	check(c.decode(invalid).is_empty(), "Invalid cloud mode rejected")
	print("Cloud codec: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
