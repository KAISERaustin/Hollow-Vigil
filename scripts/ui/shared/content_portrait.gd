extends RefCounted
## Shared native content artwork for identities and illustrated choice rows.
static func draw(canvas: Control, category: String, kind: String, level: int = 1, branch: String = "") -> void:
	var center := canvas.size * 0.5
	var art_scale := minf(canvas.size.y, canvas.size.x) / 144.0
	match category:
		"enemies": VigilEnemyArt.draw(canvas, kind, center + Vector2(0, 10) * art_scale, 3.0 * art_scale)
		"bosses": preload("res://scripts/rendering/actors/boss_art.gd").portrait(canvas, kind, center + Vector2(0, 5) * art_scale, 1.1 * art_scale)
		"rifts": preload("res://scripts/rendering/actors/rift_art.gd").draw(canvas, kind, center + Vector2(0, 20) * art_scale, 1.8 * art_scale)
		"gear": preload("res://scripts/rendering/actors/relic_art.gd").draw(canvas, kind, center, 3.6 * art_scale)
		"towers": VigilTerrainArt.sentinel(canvas, kind, center + Vector2(0, 46) * art_scale, 1.7 * art_scale, level, branch)

static func preview(category: String, kind: String, level: int = 1, branch: String = "") -> Control:
	var art := Control.new()
	art.custom_minimum_size = Vector2(64, 64)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(draw.bind(art, category, kind, level, branch))
	art.resized.connect(art.queue_redraw)
	return art
