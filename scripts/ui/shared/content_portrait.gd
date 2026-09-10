extends RefCounted
## Shared native content artwork for identities and illustrated choice rows.
static func draw(canvas: Control, category: String, kind: String, level: int = 1, branch: String = "") -> void:
	var center := canvas.size * 0.5
	var art_scale := minf(canvas.size.y, canvas.size.x) / 144.0
	match category:
		"session": preload("res://scripts/ui/shared/choice_portrait.gd").draw(canvas, "gold")
		"enemies": VigilEnemyArt.draw(canvas, kind, center + Vector2(0, 10) * art_scale, 3.0 * art_scale)
		"bosses": preload("res://scripts/rendering/actors/boss_art.gd").portrait(canvas, kind, center + Vector2(0, 5) * art_scale, 1.1 * art_scale)
		"rifts": preload("res://scripts/rendering/actors/rift_art.gd").draw(canvas, kind, center + Vector2(0, 20) * art_scale, 1.8 * art_scale)
		"gear": preload("res://scripts/rendering/actors/relic_art.gd").draw(canvas, kind, center, 3.6 * art_scale)
		"towers": VigilTerrainArt.sentinel_portrait(canvas, kind, center + Vector2(0, 46) * art_scale, 1.7 * art_scale, Rect2(Vector2.ZERO, canvas.size).grow(-2), level, branch)

static func preview(category: String, kind: String, level: int = 1, branch: String = "") -> Control:
	var art := Control.new()
	art.custom_minimum_size = Vector2(64, 64)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(draw.bind(art, category, kind, level, branch))
	art.resized.connect(art.queue_redraw)
	return art

## Circular tower identity, centered on visible pixels rather than the world pivot.
static func tower_circle(kind: String) -> Control:
	const UI = preload("res://scripts/ui/shared/interface.gd")
	var art := Control.new()
	art.custom_minimum_size = Vector2(64, 64)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var images = preload("res://scripts/rendering/actors/actor_images.gd").for_canvas(art)
	var bounds := Rect2()
	for family in ["tower", "bow"]:
		var key := "%s/%s/1/" % [family, kind]
		if not images.entries.has(key): continue
		var entry: Dictionary = images.entries[key]
		var texture: Texture2D = load(entry.image)
		var pixels := texture.get_image().get_used_rect()
		var b: Array = entry.bounds
		var scale := Vector2(b[2], b[3]) / texture.get_size()
		var visible := Rect2(Vector2(b[0], b[1]) + Vector2(pixels.position) * scale, Vector2(pixels.size) * scale)
		bounds = bounds.merge(visible) if bounds.has_area() else visible
	art.draw.connect(func():
		var center := art.size * 0.5
		var radius := minf(art.size.x, art.size.y) * 0.5 - UI.OUTLINE * 0.5
		art.draw_circle(center, radius, UI.SURFACE, true, -1, true)
		art.draw_arc(center, radius, 0, TAU, 96, UI.BORDER, UI.OUTLINE, true)
		if bounds.has_area():
			# Fit the bounding rectangle's diagonal inside the inset circle.
			var zoom := (radius - 8) * 2 / bounds.size.length()
			VigilTerrainArt.sentinel(art, kind, center - bounds.get_center() * zoom, zoom)
	)
	art.resized.connect(art.queue_redraw)
	return art

## Framed identity portrait; callers supply catalog color, never per-type UI rules.
static func profile(category: String, kind: String, tint: Color, level: int = 1, branch: String = "") -> Control:
	var art := Control.new()
	art.custom_minimum_size = Vector2(64, 64)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(func():
		var center := art.size * 0.5
		var radius := minf(art.size.x, art.size.y) * 0.5 - 2.0
		var ink := VigilTerrainArt.INK
		var paper := VigilTerrainArt.PAPER
		# The offset silhouette, inset rim and compass marks make a small portrait
		# read as a collectible medallion using the battlefield's flat ink style.
		art.draw_circle(center + Vector2(0, 2), radius, ink)
		art.draw_circle(center, radius, paper.lerp(tint, 0.65))
		art.draw_arc(center, radius, 0, TAU, 64, ink, 2, true)
		art.draw_arc(center, radius - 5, 0, TAU, 64, paper.lerp(tint, 0.25), 1, true)
		for index in range(8):
			var direction := Vector2.from_angle(index * TAU / 8.0)
			art.draw_line(center + direction * (radius - 8), center + direction * (radius - 4), tint.darkened(0.3), 1, true)
		if category == "towers":
			# Preserve the classic anchor; taller artwork supplies its own bounds.
			var scale := minf(art.size.x, art.size.y) / 144.0
			var frame := Rect2(center - Vector2.ONE * radius * 0.86, Vector2.ONE * radius * 1.72)
			VigilTerrainArt.sentinel_portrait(art, kind, center + Vector2(0, 25.5) * scale, 1.7 * scale, frame, level, branch)
		else:
			draw(art, category, kind, level, branch)
	)
	art.resized.connect(art.queue_redraw)
	return art
