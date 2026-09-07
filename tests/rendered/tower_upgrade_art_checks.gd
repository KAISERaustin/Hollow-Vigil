extends SceneTree

var failures: Array[String] = []
var checks := 0

class TowerImage extends Node2D:
	var kind := "rapid"
	var level := 1
	func _draw() -> void:
		VigilTerrainArt.sentinel(self, kind, Vector2(128, 208), 3.0, level)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	root.size = Vector2i(1000, 850)
	root.content_scale_size = root.size
	var background := ColorRect.new()
	background.color = VigilTerrainArt.BACKDROP
	background.size = Vector2(1000,850)
	root.add_child(background)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var art := TowerImage.new()
	viewport.add_child(art)
	DirAccess.make_dir_recursive_absolute("res://assets/towers")
	var names := {"rapid":"ashneedle", "heavy":"obelisk", "splash":"pyre", "electric":"stormspire"}
	var row := 0
	for kind in ["rapid","heavy","splash","electric"]:
		var previous := PackedByteArray()
		for level in [1,2,3]:
			art.kind = kind
			art.level = level
			art.queue_redraw()
			await frame()
			var img := viewport.get_texture().get_image()
			check(img.get_pixel(0,0).a == 0, "%s tier %d has a transparent background" % [kind,level])
			check(img.get_used_rect().grow(4).intersection(Rect2i(0,0,256,256)) == img.get_used_rect().grow(4), "Artwork fits with transparent padding")
			check(img.get_data() != previous, "%s tier %d has distinct artwork" % [kind,level])
			previous = img.get_data()
			check(img.save_png("res://assets/towers/%s-level-%d.png" % [names[kind],level]) == OK, "PNG saved")
			var sprite := Sprite2D.new()
			sprite.texture = ImageTexture.create_from_image(img)
			sprite.centered = false
			sprite.position = Vector2(220+(level-1)*240,row*200)
			sprite.scale = Vector2.ONE * 0.75
			root.add_child(sprite)
		var label := Label.new()
		label.text = Balance.TOWERS[kind].name
		label.position = Vector2(25,row*200+100)
		label.add_theme_font_size_override("font_size",24)
		root.add_child(label)
		row += 1
	for level in [1,2,3]:
		var label := Label.new()
		label.text = "LEVEL %d" % level
		label.position = Vector2(270+(level-1)*240,810)
		root.add_child(label)
	await frame()
	root.get_texture().get_image().save_png("res://artifacts/tower-upgrade-stages.png")
	var game := VigilState.new(123)
	# Artwork fixture represents existing core-only progress.
	game.data.erase("first_property_required")
	game.data.balance = 10000
	var field := Battlefield.new()
	field.state = game
	field.size = Vector2(1000,850)
	root.add_child(field)
	field.set_process(false)
	for kind in names:
		var pad: int = names.keys().find(kind)
		var id := game.economy.build(kind,"0,0",pad)
		check(field.upgrade_poofs.is_empty(), "Building or loading does not fake an upgrade")
		for level in [1,2]:
			check(game.economy.upgrade(id,level), "Upgrade succeeds")
			check(field.upgrade_poofs.size() == 1, "One poof per successful upgrade")
			check(field.upgrade_poofs[0].pos == VigilWorld.pad_position("0,0",pad), "Poof follows the upgraded socket")
			check(not game.economy.upgrade(id,level), "Stale upgrade rejected")
			check(field.upgrade_poofs.size() == 1, "Rejected upgrade does not poof")
			field._process(0.2)
			field.queue_redraw()
			await frame()
			if kind == "rapid" and level == 1:
				root.get_texture().get_image().save_png("res://artifacts/tower-upgrade-poof.png")
			field._process(0.71)
			check(field.upgrade_poofs.is_empty(), "Poof expires in real time")
		check(not game.economy.upgrade(id) and field.upgrade_poofs.is_empty(), "Max level does not poof")
	var old_economy := game.economy
	field.state = VigilState.new(124)
	field._process(0.01)
	check(not old_economy.tower_upgraded.is_connected(field.on_tower_upgraded), "Reset disconnects the old economy")
	check(field.state.economy.tower_upgraded.is_connected(field.on_tower_upgraded), "Reset connects the new economy")
	print("TOWER UPGRADE ART: %d checks, %d failures" % [checks,failures.size()])
	FileAccess.open("res://artifacts/tower-upgrade-art-results.txt",FileAccess.WRITE).store_string("%d checks, %d failures\n%s" % [checks,failures.size(),"\n".join(failures)])
	quit(0 if failures.is_empty() else 1)
