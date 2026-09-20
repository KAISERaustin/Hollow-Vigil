extends "res://tests/test_runner.gd"

const Placement = preload("res://scripts/content/nodes/ground_placement.gd")
const Collider = preload("res://scripts/content/nodes/placement_collider.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Build = preload("res://scripts/persistence/campaign_build.gd")

func fixture() -> VigilState:
	var game := VigilState.new(573)
	game.data.towers.clear()
	game.data.balance = 100000.0
	for x in range(-2, 3):
		for y in range(-2, 3):
			var key := "%d,%d" % [x, y]
			game.data.regions[key] = VigilWorld.make_region(key, "", 573)
	return game

func build_at(game: VigilState, kind: String, point: Vector2) -> String:
	var at := VigilWorld.ground_location(point)
	return game.economy.build(kind, at.region, at.pad)

func run() -> void:
	var seen := []
	for kind in Balance.TOWERS:
		var collider := Placement.collider(kind)
		check(collider != null and collider.valid(), kind + " registered collider")
		check(collider.shape is RectangleShape2D and collider.shape.size == Vector2(36, 36), kind + " square default")
		check(collider not in seen and collider.shape not in seen, kind + " independent resource and shape")
		seen.append(collider)
		seen.append(collider.shape)
		check(Balance.Content.catalog().find("towers", kind + ":2").rule("placement_collider") == collider, kind + " upgrades inherit same collider")
		var game := fixture()
		check(build_at(game, kind, Vector2(100, 100)) != "", kind + " builds")
		check(not game.economy.ground_allowed(Vector2(135.9, 100), kind), kind + " default overlap rejected")
		check(game.economy.ground_allowed(Vector2(136.1, 100), kind), kind + " default separated placement")
		check(not game.economy.ground_allowed(Vector2(130, 130), kind), kind + " square corners block diagonal overlap")
		game.data.towers.clear()
		game.economy.placement_roads = [[Vector2(-300, 0), Vector2(300, 0)]]
		check(not game.economy.ground_allowed(Vector2(100, 25.9), kind), kind + " road overlap")
		check(game.economy.ground_allowed(Vector2(100, 26.1), kind), kind + " legacy road clearance")
		check(not game.economy.ground_allowed(Vector2(-300, 47.9), kind), kind + " portal overlap")
		check(game.economy.ground_allowed(Vector2(-300, 48.1), kind), kind + " legacy portal clearance")
		var original: Shape2D = collider.shape
		var small := CircleShape2D.new()
		small.radius = 4.0
		collider.shape = small
		check(game.economy.ground_allowed(Vector2(100, 15), kind), kind + " edited collider drives road placement")
		for other in Balance.TOWERS:
			if other != kind: check(not game.economy.ground_allowed(Vector2(100, 15), other), kind + " edit leaves " + other + " unchanged")
		collider.shape = original

	var rapid := Placement.collider("rapid")
	var original: Shape2D = rapid.shape
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(60, 10)
	rapid.shape = rectangle
	var game := fixture()
	check(build_at(game, "heavy", Vector2(100, 100)) != "", "Mixed shape fixture")
	check(not game.economy.ground_allowed(Vector2(145, 100), "rapid"), "Rectangle long side collides with existing square")
	check(game.economy.ground_allowed(Vector2(100, 125), "rapid"), "Rectangle short side allows closer towers")
	rapid.rotation_degrees = 90.0
	check(not game.economy.ground_allowed(Vector2(100, 125), "rapid"), "Rotation used in pair collision")
	rapid.rotation_degrees = 0.0
	rapid.offset = Vector2(40, 0)
	check(not game.economy.ground_allowed(Vector2(50, 100), "rapid"), "Offset used for candidate")
	game = fixture()
	check(build_at(game, "rapid", Vector2(100, 100)) != "", "Offset existing tower fixture")
	check(not game.economy.ground_allowed(Vector2(180, 100), "heavy"), "Offset used for existing tower")
	game.economy.placement_bounds = Rect2(-200, -200, 400, 400)
	check(not game.economy.ground_allowed(Vector2(150, -100), "rapid"), "Full offset rectangle must fit bounds")
	rapid.offset = Vector2.ZERO
	rapid.shape = original
	game = fixture()
	var id := build_at(game, "rapid", Vector2(100, 100))
	var at := VigilWorld.ground_location(Vector2(105, 100))
	check(game.economy.relocate(id, at.region, at.pad), "Move excludes own previous collider")
	var before: float = game.data.balance
	check(not game.economy.relocate(id, at.region, at.pad), "Same location move rejected")
	check(game.data.balance == before, "Rejected move spends nothing")
	check(build_at(game, "heavy", Vector2(106, 100)) == "" and game.data.balance == before, "Overlap build spends nothing")
	var capsule := CapsuleShape2D.new()
	capsule.radius = 5.0
	capsule.height = 60.0
	rapid.shape = capsule
	check(rapid.valid(), "Capsule supported")
	check(not game.economy.ground_allowed(Vector2(105, 145), "heavy"), "Existing capsule long side blocks")
	check(game.economy.ground_allowed(Vector2(130, 100), "heavy"), "Existing capsule short side permits")
	check(rapid.fits_bounds(Vector2(100, 100), Rect2(94, 69, 12, 62)), "Capsule bounds use actual support")
	rapid.shape = null
	check(not game.economy.ground_allowed(Vector2(100, -100), "rapid"), "Missing collider fails closed")
	rapid.shape = original
	rapid.offset = Vector2(INF, 0)
	check(not game.economy.ground_allowed(Vector2(100, -100), "rapid"), "Invalid offset fails closed")
	rapid.offset = Vector2.ZERO
	check(not game.economy.ground_allowed(Vector2(100, -100), "unknown"), "Unknown tower fails closed")
	check(not game.economy.ground_allowed(Vector2(NAN, 0), "rapid"), "Invalid point fails closed")
	check(not game.economy.ground_allowed(Vector2(9000, 0), "rapid"), "Unowned region rejected")
	checkpoints()
	print("PLACEMENT COLLIDERS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func checkpoints() -> void:
	for mode in ["creative", "survival"]:
		var battle := Run.new(0, {}, mode)
		battle.game.data.balance = 100000.0
		var id := ""
		for y in range(-120, 121, 20):
			for x in range(-120, 121, 20):
				if id == "": id = build_at(battle.game, "rapid", Vector2(x, y))
		check(id != "", mode + " checkpoint fixture built")
		if id == "": continue
		var checkpoint: Dictionary = battle.checkpoint()
		var code := Build.encode(0, {}, battle.game, "Collider check", "", false)
		check(Run.valid_checkpoint(checkpoint) and not Build.decode(code).is_empty(), mode + " default save and build valid")
		var collider := Placement.collider("rapid")
		var original: Shape2D = collider.shape
		var large := CircleShape2D.new()
		large.radius = 1000.0
		collider.shape = large
		check(not Run.valid_checkpoint(checkpoint), mode + " checkpoint validates current tower collider")
		check(Build.decode(code).is_empty(), mode + " imported build validates current tower collider")
		collider.shape = original
		check(Run.from_checkpoint(checkpoint) != null, mode + " restore after resetting collider")
