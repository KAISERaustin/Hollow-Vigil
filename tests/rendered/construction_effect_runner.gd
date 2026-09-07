extends SceneTree

const Effect = preload("res://scripts/rendering/effects/construction_effect.gd")
var checks := 0
var failures: Array[String] = []

class EffectImage extends Node2D:
	var age := 0.0
	var show_socket := false
	func _draw() -> void:
		if show_socket:
			draw_set_transform(Vector2(128,190), 0, Vector2.ONE * 2.0)
			VigilTerrainArt.socket(self, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO)
		Effect.draw(self, {"age": age}, Vector2(128,190), 2.0)

class Sheet extends Node2D:
	func _draw() -> void:
		for row in range(4):
			var kind: String = ["rapid", "heavy", "splash", "electric"][row]
			for column in range(5):
				var age: float = [0.0, 0.15, 0.32, 0.42, 0.5][column]
				var at := Vector2(110 + column * 210, 205 + row * 200)
				draw_set_transform(at, 0, Vector2.ONE * 1.8)
				VigilTerrainArt.socket(self, Vector2.ZERO)
				draw_set_transform(Vector2.ZERO)
				if age >= Effect.REVEAL_AT:
					VigilTerrainArt.sentinel(self, kind, at, 1.8, 3)
				Effect.draw(self, {"age": age}, at, 1.8)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var first := Effect.new()
	var second := Effect.new()
	first.play(Vector2.ZERO)
	first.advance(0.2)
	first.play(Vector2.ONE)
	check(is_equal_approx(first.instances[0].age, 0.2) and first.instances[1].age == 0.0, "Concurrent sockets keep independent clocks")
	check(second.instances.is_empty(), "Separate battlefields do not share effects")
	first.play(Vector2.ZERO)
	check(first.instances.size() == 2 and first.instances[1].age == 0.0, "Rapid repeat upgrade replaces the socket effect")
	first.remove(Vector2.ONE)
	check(first.instances.size() == 1 and first.conceals(Vector2.ZERO) and not first.conceals(Vector2.ONE), "Removal only affects the assigned socket")
	first.advance(0.5)
	check(first.instances.is_empty() and not first.conceals(Vector2.ZERO), "Effect and concealment end within half a second")
	var game := VigilState.new(123)
	game.data.erase("first_property_required")
	game.data.balance = 10000
	var field := Battlefield.new()
	field.state = game
	field.size = Vector2(360,640)
	root.add_child(field)
	field.set_process(false)
	var id := game.economy.build("rapid", "0,0", 0)
	var other := game.economy.build("heavy", "0,0", 1)
	for rate in [0.0, 1.0, 3.0]:
		field.simulation_rate = rate
		game.data.towers[id].level = 1
		check(game.economy.upgrade(id, 1), "Actual economy upgrade triggers presentation")
		check(not field.construction_effect.conceals(VigilWorld.pad_position("0,0",1)) and game.data.towers[other].level == 1, "Unassigned tower stays unchanged and visible")
		field._process(0.25)
		check(field.upgrade_poofs.size() == 1 and is_equal_approx(field.upgrade_poofs[0].age,0.25), "Cover phase survives pause and fast simulation")
		field._process(0.25)
		check(field.upgrade_poofs.is_empty(), "Presentation completes in 0.5 real seconds at every game speed")
	game.data.towers[id].level = 1
	game.economy.upgrade(id,1)
	check(game.economy.relocate(id,"0,0",2,2) and field.upgrade_poofs.is_empty(), "Relocation removes the old socket effect immediately")
	game.data.towers[id].rebuild_remaining = 0.0
	game.economy.upgrade(id,2)
	game.economy.sell(id,3)
	var replacement := game.economy.build("electric","0,0",2)
	check(replacement != "" and field.upgrade_poofs.is_empty(), "Sale and socket reuse never conceal a replacement tower")
	game.economy.upgrade(replacement,1)
	field.state = VigilState.new(124)
	field.bind_upgrade_effects()
	check(field.upgrade_poofs.is_empty() and not game.economy.tower_upgraded.is_connected(field.on_tower_upgraded), "World replacement clears animation and disconnects old owner")
	field.free()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var art := EffectImage.new()
	viewport.add_child(art)
	for age in [0.0, 0.15, 0.25, 0.32, 0.42, 0.5]:
		art.age = age
		art.queue_redraw()
		await frame()
		var img := viewport.get_texture().get_image()
		if age < Effect.REVEAL_AT:
			for y in range(90,180,10):
				for x in range(100,160,10):
					check(img.get_pixel(x,y).a == 1.0, "Dust core is fully opaque during tower swap")
			art.show_socket = true
			art.queue_redraw()
			await frame()
			check(img.get_data() == viewport.get_texture().get_image().get_data(), "Cloud fully masks the entire socket, including its lower rim")
			art.show_socket = false
		elif age >= Effect.DURATION:
			check(img.get_used_rect().size == Vector2i.ZERO, "No dust remains after expiry")
		elif age == 0.42:
			check(img.get_used_rect().size.x < 65, "Reveal contains only the shrinking central cloud")
	viewport.free()
	root.size = Vector2i(1050,900)
	root.content_scale_size = root.size
	var background := ColorRect.new()
	background.color = Color("7fa6aa")
	background.size = root.size
	root.add_child(background)
	root.add_child(Sheet.new())
	for column in range(5):
		var label := Label.new()
		label.text = ["Cover · 0.00s", "Cover · 0.15s", "Reveal · 0.32s", "Reveal · 0.42s", "Done · 0.50s"][column]
		label.position = Vector2(25 + column * 210, 20)
		label.add_theme_color_override("font_color", Color.BLACK)
		root.add_child(label)
	await frame()
	check(root.get_texture().get_image().save_png("res://artifacts/construction-effect-stages.png") == OK, "Rendered stage sheet saved")
	for child in root.get_children():
		child.queue_free()
	await process_frame
	await phone_previews()
	print("CONSTRUCTION EFFECT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func phone_previews() -> void:
	for width in [360,540]:
		root.size = Vector2i(width,640 if width == 360 else 960)
		root.content_scale_size = root.size
		var game := VigilState.new(125)
		game.data.erase("first_property_required")
		game.data.balance = 10000
		var field := Battlefield.new()
		field.state = game
		field.size = root.size
		root.add_child(field)
		field.set_process(false)
		var id := game.economy.build("rapid","0,0",0)
		field.selected_tower = id
		var actions := VigilTowerActions.new()
		actions.field = field
		field.add_child(actions)
		actions.set_process(false)
		for zoom in [0.65,1.0,1.65]:
			field.zoom = zoom
			field.camera = VigilWorld.pad_position("0,0",0)
			game.data.towers[id].level = 1
			game.economy.upgrade(id,1)
			field.construction_effect.advance(0.23)
			actions.refresh()
			field.queue_redraw()
			await frame()
			check(root.get_texture().get_image().save_png("res://artifacts/construction-phone-%d-%.2f.png" % [width,zoom]) == OK, "Phone preview rendered at multiple zoom levels")
		field.free()
