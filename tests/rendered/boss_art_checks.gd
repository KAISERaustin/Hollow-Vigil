extends SceneTree

const Bosses = preload("res://scripts/model/bosses.gd")
const Art = preload("res://scripts/rendering/boss_art.gd")
var failures := 0

class Board extends Node2D:
	func _draw() -> void:
		Art.begin_frame(self)
		for i in range(4):
			var kind: String = Bosses.TYPES[i]
			var e := {"kind":kind,"hp":Bosses.DEFINITIONS[kind].hp,"max_hp":Bosses.DEFINITIONS[kind].hp,"shield":600.0 if i==0 else 0.0,"wards":3}
			Art.draw(self,e,Vector2(225+(i%2)*450,235+(i/2)*390),2.3)

		Art.end_frame(self)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	root.size = Vector2i(900,800)
	root.content_scale_size = root.size
	var background := ColorRect.new()
	background.color = Color("e8ddbd")
	background.size = root.size
	root.add_child(background)
	var board := Board.new()
	root.add_child(board)
	await frame()
	var img := root.get_texture().get_image()
	if not img.get_pixel(90,120).is_equal_approx(background.color):
		push_error("Boss matte must reveal the backdrop, not a checkerboard")
		failures += 1
	if img.save_png("res://artifacts/boss-lineup.png") != OK:
		failures += 1
	board.queue_free()
	background.queue_free()
	await process_frame
	var game := preload("res://tests/unit/boss_checks.gd").fixture("warden")
	game.combat.enemies.clear()
	var source: String = game.data.regions.keys()[-1]
	for i in range(4):
		var e := Bosses.create(game.combat,source,Bosses.TYPES[i])
		e.pos = Vector2((i%2)*220-110,(i/2)*260-80)
	var field := Battlefield.new()
	field.state = game
	root.add_child(field)
	field.set_process(false)
	for size in [Vector2i(360,640),Vector2i(540,960)]:
		root.size = size
		root.content_scale_size = size
		field.size = size
		for z in [0.42,1.0,1.65]:
			field.zoom = z
			field.queue_redraw()
			await frame()
			img = root.get_texture().get_image()
			if img.is_empty():
				failures += 1
			img.save_png("res://artifacts/bosses-%d-%.2f.png" % [size.x,z])
	game.combat.enemies.clear()
	field.queue_redraw()
	await frame()
	if not field.get_meta("boss_sprites",{}).is_empty():
		push_error("Defeated or culled boss sprites must be released")
		failures += 1
	print("BOSS_ART: lineup and six battlefield views, %d failures" % failures)
	quit(0 if failures == 0 else 1)
