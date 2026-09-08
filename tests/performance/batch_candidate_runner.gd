extends SceneTree

## Favorable, non-overlapping diagnostic for region-local texture groups.
## Production overlaps and interleaved indicators prohibit reordering by image.
const F = preload("res://tests/performance/fixtures.gd")
class Bodies extends Node2D:
	var grouped := false
	var actors := []
	var groups := []
	func configure(count: int, kinds: Array, overlap: bool = false) -> void:
		var by_region := {}
		for index in range(count):
			var kind: String = kinds[index % kinds.size()]
			var at := Vector2(9 + (index % 26) * 14, 14 + (index / 26) * 20)
			if overlap: at = Vector2(40,70)
			var texture: Texture2D = load("res://assets/artwork/enemy/" + kind + ".png")
			actors.append({"at": at, "texture": texture})
			var key := str(int(at.x / 130)) + "/" + str(int(at.y / 280)) + "/" + kind
			if not by_region.has(key): by_region[key] = []
			by_region[key].append(actors[-1])
		for members in by_region.values():
			var mesh := QuadMesh.new()
			mesh.size = Vector2(48,48) * 0.25
			var instances := MultiMesh.new()
			instances.transform_format = MultiMesh.TRANSFORM_2D
			instances.mesh = mesh
			instances.instance_count = members.size()
			for index in range(members.size()):
				# QuadMesh UVs use the 3D vertical axis; match CanvasItem's top-down image.
				instances.set_instance_transform_2d(index, Transform2D(Vector2.RIGHT, Vector2.UP, members[index].at + Vector2(0,-0.5)))
			groups.append({"instances": instances, "texture": members[0].texture})
	func _draw() -> void:
		if grouped:
			for group in groups: draw_multimesh(group.instances, group.texture)
		else:
			for actor in actors: draw_texture_rect(actor.texture, Rect2(actor.at + Vector2(-6,-6.5), Vector2(12,12)), false)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(390,844)
	root.content_scale_size = root.size
	var rows := []
	var image_matches := []
	for mode in ["infinite", "campaign"]:
		var bodies := Bodies.new()
		bodies.configure(980 if mode == "infinite" else 500, Balance.ENEMIES.keys() if mode == "infinite" else ["basic"])
		root.add_child(bodies)
		var reference_picture := PackedByteArray()
		for grouped in [false, true]:
			bodies.grouped = grouped
			for repeat in range(3):
				for warm in range(20):
					bodies.queue_redraw()
					await process_frame
				var samples := []
				var calls := []
				var last := Time.get_ticks_usec()
				for frame in range(180):
					bodies.queue_redraw()
					await process_frame
					var now := Time.get_ticks_usec()
					if frame > 0: samples.append((now-last)/1000.0)
					last = now
					calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				rows.append({"mode": mode, "grouped": grouped, "repeat": repeat, "frame_ms": F.stats(samples),
					"draw_calls": F.stats(calls), "groups": bodies.groups.size(), "actors": bodies.actors.size()})
				print("BATCH ", rows[-1])
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image().get_data()
			if grouped: image_matches.append({"mode": mode, "matches": picture == reference_picture})
			else: reference_picture = picture
		bodies.free()
	# Grouping A,B,A by image changes which body is on top when they overlap.
	var overlap := Bodies.new()
	overlap.configure(3, ["basic", "heavy", "basic"], true)
	overlap.scale = Vector2.ONE * 4.0
	root.add_child(overlap)
	var pictures := []
	for grouped in [false, true]:
		overlap.grouped = grouped
		overlap.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		pictures.append(picture.get_data())
		picture.save_png(OS.get_environment("PERF_CAPTURE") + "/batch-overlap-" + str(grouped) + ".png")
	var overlap_matches: bool = pictures[0] == pictures[1]
	overlap.free()
	var file := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"diagnostic_only": true, "overlapping_indicators_supported": false,
		"overlap_matches": overlap_matches, "nonoverlap_images": image_matches, "rows": rows}, "\t"))
	quit()
