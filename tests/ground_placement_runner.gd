extends SceneTree
const Placement = preload("res://scripts/content/nodes/ground_placement.gd")
const Run = preload("res://scripts/campaign/run.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func find_ground(game: VigilState) -> Vector2:
	for region in game.data.regions:
		for y in range(-130, 131, 20):
			for x in range(-130, 131, 20):
				var point := VigilWorld.center(region) + Vector2(x, y)
				if game.economy.ground_allowed(point): return point
	return Vector2.INF

func run() -> void:
	for point in [Vector2(-150, -150), Vector2(-150.1, 450.2), Vector2(123.4, -98.7), Vector2(149.9, 149.9)]:
		var location := VigilWorld.ground_location(point)
		check(VigilWorld.pad_position(location.region, location.pad).distance_to(point) < 0.11, "Ground coordinate round trip")
	for index in range(20):
		var session := Run.new(index)
		session.game.data.balance = 100000
		for road in session.mission.routes:
			check(not session.game.economy.ground_allowed(road[0]), "Campaign portal blocked")
			for i in range(road.size() - 1):
				check(not session.game.economy.ground_allowed((road[i] + road[i + 1]) / 2), "Campaign road blocked")
		var point := find_ground(session.game)
		check(point.is_finite(), "Campaign has buildable ground")
		var location := VigilWorld.ground_location(point)
		var id := session.game.economy.build("rapid", location.region, location.pad)
		check(not id.is_empty(), "Campaign builds on ground")
		check(not session.game.economy.ground_allowed(point + Vector2(10, 0)), "Overlapping footprint blocked")
		check(Run.valid_checkpoint(session.checkpoint()), "Ground tower checkpoint validates")
		var restored := Run.from_checkpoint(session.checkpoint())
		check(restored != null and restored.game.data.towers == session.game.data.towers, "Ground checkpoint restores exact towers")
		var code := VigilSaveSlots.CampaignBuild.encode(index, {}, session.game, "Ground", "", false)
		check(not code.is_empty() and not VigilSaveSlots.CampaignBuild.decode(code).is_empty(), "Ground layout export round trip")
	var game := VigilState.new(771)
	game.data.first_property_required = false
	game.data.balance = 100000
	var point := find_ground(game)
	var location := VigilWorld.ground_location(point)
	var id := game.economy.build("rapid", location.region, location.pad)
	check(not id.is_empty(), "Infinite ground build")
	var balance: float = game.data.balance
	check(game.economy.build("rapid", location.region, location.pad).is_empty() and game.data.balance == balance, "Invalid build spends nothing")
	check(not game.economy.ground_allowed(Vector2.ZERO), "Infinite core blocked")
	check(not game.economy.ground_allowed(Vector2(90000, 90000)), "Unowned land blocked")
	check(VigilSaveStore.new().valid_data(game.snapshot()), "Infinite ground save validates")
	var invalid := game.snapshot()
	invalid.towers[id].pad = VigilWorld.ground_location(Vector2.ZERO).pad
	invalid.towers[id].region = "0,0"
	check(not VigilSaveStore.new().valid_data(invalid), "Saved ground placement on portal rejected")
	game.save_path = "user://ground-placement-roundtrip.save"
	check(game.save(1000), "Infinite ground save writes")
	var loaded := VigilState.new(999)
	loaded.save_path = game.save_path
	check(loaded.load_save(1000), "Infinite ground save loads")
	check(loaded.data.towers[id].pad == location.pad and VigilWorld.pad_position(loaded.data.towers[id].region, loaded.data.towers[id].pad).distance_to(point) < 0.11, "Loaded ground position preserved")
	var destination := VigilWorld.ground_location(find_ground(game))
	check(game.economy.relocate(id, destination.region, destination.pad), "Ground tower relocates using shared economy")
	check(game.economy.upgrade(id) == false, "Ground relocation retains rebuilding guard")
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(game.save_path + suffix)
	var other := VigilState.new(771)
	check(other.economy.ground_allowed(point), "Placement state isolated between games")
	print("GROUND PLACEMENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
