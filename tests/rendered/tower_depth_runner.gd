extends SceneTree

class DepthField extends Battlefield:
	var drawn: Array[String] = []
	func draw_map() -> void:
		drawn.clear()
	func draw_tower(t: Dictionary) -> void:
		drawn.append(t.id)
		super.draw_tower(t)

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := VigilState.new(771)
	game.data.towers.clear()
	# Deliberately insert southern towers first, opposite the required draw order.
	var positions := [Vector2(-25, 45), Vector2(25, 45), Vector2(-25, 5), Vector2(25, 5), Vector2(-25, -35), Vector2(25, -35)]
	for i in range(positions.size()):
		var location := VigilWorld.ground_location(positions[i])
		var id := str(i + 1)
		game.data.towers[id] = {"id": id, "region": location.region, "pad": location.pad, "kind": "hex_lantern" if i < 4 else "rapid", "level": 1, "angle": 0.0, "earnings": 0.0}
	var field := DepthField.new()
	field.state = game
	field.unrestricted_camera = true
	root.add_child(field)
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		field.size = viewport
		field.zoom = 2.0
		field.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if field.drawn != ["6", "5", "4", "3", "2", "1"]:
			failures += 1
			push_error("Tower draw order: " + str(field.drawn))
		root.get_texture().get_image().save_png("res://artifacts/tower-depth-%dx%d.png" % [viewport.x, viewport.y])
	# World coordinates, not region-local positions or tower IDs, govern depth.
	var west := VigilWorld.ground_location(Vector2(-170, 45))
	west.id = "99"
	var east := VigilWorld.ground_location(Vector2(170, 45))
	east.id = "1"
	if not Battlefield.tower_draws_before(east, west):
		failures += 1
	# Relocation immediately changes ordering without changing the tower ID.
	var moved := VigilWorld.ground_location(Vector2(25, 85))
	game.data.towers["6"].merge(moved, true)
	field.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if field.drawn.back() != "6":
		failures += 1
	print("TOWER_DEPTH: 5 checks, %d failures" % failures)
	field.queue_free()
	await process_frame
	quit(1 if failures else 0)
