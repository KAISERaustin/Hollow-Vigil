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
		check(restored.seed == g.data.seed and restored.balance == g.data.balance, "Seed and money restore")
		check(restored.towers[id].target_mode == "most_hp" and restored.towers[id].earnings == 27.0, "Tower targeting and earnings restore")
		check(restored.settings.low_power and restored.camera == [1.0,2.0,0.8], "Device preferences preserved")
		check(restored.settings.audio.master == 0.3 and restored.settings.audio.muted, "Opted-in audio restores")
		check(restored.regions["-1,0"].history[id] == 80.0 and restored.regions["-1,0"].history_time == 100.0, "Production checkpoint restores")
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
	g.data.settings.developer_balance = {"towers":{"rapid":{"damage":20.0}}}
	check(c.encode(g.snapshot(),wid).is_empty(), "Developer balance saves excluded")
	print("Cloud codec: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
