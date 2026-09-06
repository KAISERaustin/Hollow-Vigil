extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1000, 760)
	root.content_scale_size = root.size
	var game := preload("res://tests/unit/castle_checks.gd").fixture()
	var gate := preload("res://scripts/world/hidden_areas.gd").gate(Vector2i.ZERO, 879)
	game.expand(gate.id)
	for pad in range(3):
		game.economy.build(Balance.TOWERS.keys()[pad], gate.id, pad)
	for i in range(4):
		var mob := game.combat.spawn(gate.id, Balance.DUNGEON_KINDS[i % 2])
		mob.pos += Vector2(-15 + 24 * i, 36)
	var field := Battlefield.new()
	field.state = game
	field.size = root.size
	field.camera = VigilWorld.center(gate.id)
	field.zoom = 1.55
	root.add_child(field)
	field.set_process(false)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/castle-ruin-tile.png")
	quit()
