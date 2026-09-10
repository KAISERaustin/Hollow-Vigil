extends SceneTree

const HexArt = preload("res://scripts/rendering/effects/hex_art.gd")
const Afflictions = preload("res://scripts/rendering/effects/affliction_art.gd")
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")

class Preview extends Battlefield:
	var phase := 0.4
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("95aa83"))
		var font_face := VigilInterface.font(600)
		draw_string(font_face, Vector2(16, 28), "Enemy afflictions", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.BLACK)
		for i in range(3):
			var at := Vector2(size.x * (i + 0.5) / 3.0, 104)
			var enemy := {"id": i, "gear_status": {}}
			if i == 0: enemy.gear_status.p = {"type": "dot", "damage": 5.0, "until": 10.0}
			if i == 1: enemy.slow_until = 10.0
			if i == 2: enemy.gear_status.h = {"type": "expose", "strength": 75.0, "until": 10.0}
			Art.enemy(self, "basic", at, 1.5)
			Afflictions.draw(self, enemy, at, 1.5, phase)
			draw_string(font_face, at + Vector2(-25, 48), ["Poison", "Ice", "Hex"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		draw_string(font_face, Vector2(16, 192), "Boosted tower bases", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.BLACK)
		for tower in state.data.towers.values():
			if tower.id == "source": continue
			draw_tower(tower)
		draw_string(font_face, Vector2(16, size.y - 100), "Hex + poison + ice", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
		var at := Vector2(size.x * 0.5, size.y - 52)
		var enemy := {"id": 5, "slow_until": 10.0, "gear_status": {"h": {"type": "expose", "strength": 75.0, "until": 10.0}, "p": {"type": "dot", "damage": 5.0, "until": 10.0}}}
		Art.enemy(self, "heavy", at, 1.4)
		Afflictions.draw(self, enemy, at, 1.4, phase)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func run() -> void:
	var field := Preview.new()
	field.state = VigilState.new(51)
	field.unrestricted_camera = true
	root.add_child(field)
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		field.size = dimensions
		field.zoom = 1.25
		field.state.data.towers.clear()
		var source := {"id": "source", "kind": "hex_lantern", "level": 1, "region": "0,0", "pad": 0, "angle": 0.0}
		field.state.data.towers.source = source
		field.state.data.settings.developer_balance = {"towers": {"hex_lantern": {"range": 1000.0}}}
		var index := 0
		for kind in Balance.TOWERS:
			var screen_at := Vector2(dimensions.x * (0.22 + (index % 2) * 0.56), 250 + (index / 2) * 65)
			var location := VigilWorld.ground_location(field.world(screen_at))
			var tower := {"id": str(index), "kind": kind, "level": 1, "region": location.region, "pad": location.pad, "angle": -PI / 2.0}
			field.state.data.towers[tower.id] = tower
			index += 1
		for phase in [0.4, 1.2]:
			field.phase = phase
			field.state.combat.simulation_time = phase
			field.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/hex-effects-%d-%.1f.png" % [dimensions.x, phase])
	field.queue_free()
	await process_frame
	print("HEX EFFECTS: eight tower families, combined afflictions, two animation phases at three portrait sizes")
	quit()
