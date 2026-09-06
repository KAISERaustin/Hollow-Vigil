extends RefCounted

static func run(app: Control, failures: Array[String]) -> void:
	app.set_process(false)
	var original: VigilState = app.game
	var game := preload("res://tests/rendered/visual_smoke.gd").camera_test_world()
	game.data.towers.clear()
	var reference := preload("res://tests/rendered/visual_smoke.gd").camera_test_world()
	reference.data.towers.clear()
	app.game = game
	app.field.state = game
	app.field.set_unrestricted_camera(true)
	app.field.camera = Vector2(100000, 100000)
	app.field.zoom = 1.0
	app.accumulator = 0.0
	app.save_timer = -1000.0
	var sources := {}
	# Never visit a portal. Draw empty space, then hide the battlefield entirely.
	for frame in range(240):
		if frame == 120:
			app.field.hide()
		var before: int = game.combat.tick_count
		app._process(0.25)
		for tick in range(game.combat.tick_count - before):
			reference.combat.tick(Balance.STEP)
		for enemy in game.combat.enemies:
			sources[enemy.source] = true
		if frame % 20 == 0:
			await app.get_tree().process_frame
	if sources.size() != 32:
		failures.append("Portals never shown on screen failed to spawn: %d of 32" % sources.size())
	if game.combat.enemy_serial < 32 * 12 or game.data.escapes <= 0:
		failures.append("Offscreen portals did not sustain spawning and movement to the core")
	if game.combat.enemies != reference.combat.enemies or game.data.regions != reference.data.regions or game.combat.enemy_serial != reference.combat.enemy_serial or game.data.escapes != reference.data.escapes:
		failures.append("An empty or hidden battlefield changed world simulation")
	print("OFFSCREEN_PORTALS: %d sources, %d spawns, %d escapes; empty and hidden battlefield match simulation reference" % [sources.size(), game.combat.enemy_serial, game.data.escapes])
	app.field.show()
	app.game = original
	app.field.state = original
	app.field.set_unrestricted_camera(false)
	app.panels.return_to_core()
	app.save_timer = 0.0
	app.accumulator = 0.0
	app.set_process(true)
