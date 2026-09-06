extends SceneTree

const Effects = preload("res://scripts/rendering/attack_effects.gd")

class EffectSheet extends Node2D:
	var elapsed := 0.0
	var animated := false
	func _draw() -> void:
		for row in range(4):
			var kind: String = ["heavy", "rapid", "splash", "electric"][row]
			for column in range(3):
				var base := Vector2(45 + column * 320, 155 + row * 160)
				var target := base + Vector2(210, -28)
				VigilTerrainArt.sentinel(self, kind, base, 1.3, 1)
				draw_circle(target, 9.0, VigilTerrainArt.INK)
				draw_circle(target, 6.0, VigilTerrainArt.PAPER)
				var fx := Effects.shot(kind, Vector2.ZERO, Vector2(160, 0), Balance.stats(kind, 1))
				var age: float = [0.025, fx.flight * 0.68, fx.flight + (fx.max_life - fx.flight) * 0.35][column]
				if kind == "electric":
					age = [0.025, 0.12, 0.22][column]
				if animated:
					age = fposmod(elapsed, fx.max_life + 0.25)
				fx.life = fx.max_life - age
				Effects.draw(self, fx, base + Vector2(0, -25 if kind == "rapid" else (-22 if kind == "heavy" else -29)) * 1.3, target, 1.3)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(960, 760)
	root.content_scale_size = root.size
	var background := ColorRect.new()
	background.color = Color("546657")
	background.size = root.size
	root.add_child(background)
	var sheet := EffectSheet.new()
	root.add_child(sheet)
	for column in range(3):
		var label := Label.new()
		label.text = ["LAUNCH", "FLIGHT", "IMPACT / FADE"][column]
		label.position = Vector2(20 + column * 320, 18)
		root.add_child(label)
	for row in range(4):
		var label := Label.new()
		label.text = ["OBELISK", "ASH NEEDLE", "PYRE", "STORM SPIRE (REFERENCE)"][row]
		label.position = Vector2(20, 65 + row * 160)
		root.add_child(label)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/attack-effects-comparison.png")
	if result != OK:
		push_error("Could not save attack effect comparison")
		quit(1)
		return
	# Exercise continuous animation, including expiry and transform reset.
	sheet.animated = true
	for frame in range(75):
		sheet.elapsed = frame / 60.0
		sheet.queue_redraw()
		await process_frame
	print("ATTACK PREVIEW: four towers, three phases and 75 animation frames rendered")
	sheet.free()
	background.free()
	for child in root.get_children():
		if child is Label:
			child.free()
	await battlefield_preview()
	quit()

func battlefield_preview() -> void:
	var app = load("res://scripts/app/main.gd").new()
	app.load_saved_progress = false
	app.game.save_path = "user://attack-preview.save"
	root.add_child(app)
	app.set_process(false)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	app.game.data.balance = 10000.0
	app.game.expand("1,0")
	var source := VigilWorld.pad_position("0,0", 0)
	for width in [540, 360]:
		root.size = Vector2i(width, 960 if width == 540 else 640)
		root.content_scale_size = root.size
		await process_frame
		await process_frame
		for kind in ["heavy", "rapid", "splash"]:
			app.game.data.towers.clear()
			app.game.combat.enemies.clear()
			app.game.combat.effects.clear()
			app.game.economy.build(kind, "0,0", 0)
			var enemy: Dictionary = app.game.combat.spawn("1,0", "heavy")
			enemy.pos = source + Vector2(105, -40)
			enemy.path = [enemy.pos, enemy.pos + Vector2(1000, 0)]
			var fx := Effects.shot(kind, source, enemy.pos, Balance.stats(kind, 1))
			app.game.combat.effects.append(fx)
			app.field.camera = source + Vector2(45, 0)
			app.field.zoom = 1.0
			for phase in ["flight", "impact"]:
				var age: float = fx.flight * 0.68 if phase == "flight" else fx.flight + (fx.max_life - fx.flight) * 0.3
				fx.life = fx.max_life - age
				app.field.queue_redraw()
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var error := root.get_texture().get_image().save_png("res://artifacts/attack-%s-%s-%d.png" % [kind, phase, width])
				assert(error == OK, "Battlefield screenshot saved")
	app.free()
	print("ATTACK BATTLEFIELD: flight and impact captured at 540 and 360 pixels")
