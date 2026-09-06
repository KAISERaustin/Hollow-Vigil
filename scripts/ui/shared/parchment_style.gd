extends StyleBoxFlat
## Reusable textured fill; retain StyleBoxFlat's layout and border API.

const PAPER = preload("res://assets/ui/welcome-parchment.png")

func _draw(canvas_item: RID, rect: Rect2) -> void:
	if draw_center and bg_color.a > 0.0:
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		var radii := [corner_radius_top_left, corner_radius_top_right, corner_radius_bottom_right, corner_radius_bottom_left]
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		var directions := [Vector2.ONE, Vector2(-1, 1), -Vector2.ONE, Vector2(1, -1)]
		# Cover instead of stretching: paper grain keeps the same proportions.
		var texture_size := Vector2(PAPER.get_size())
		var scale_factor := maxf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
		var covered_size := texture_size * scale_factor
		for corner in range(4):
			var radius := minf(radii[corner], minf(rect.size.x, rect.size.y) * 0.5)
			var center: Vector2 = corners[corner] + directions[corner] * radius
			for step in range(9):
				var angle := PI + corner * PI * 0.5 + step * PI / 16.0
				var point := center + Vector2(cos(angle), sin(angle)) * radius
				points.append(point)
				uvs.append((point - rect.position + (covered_size - rect.size) * 0.5) / covered_size)
		var tint := Color.WHITE
		# Preserve darker tan roles while using the reference paper for panels.
		var base := VigilTerrainArt.PAPER
		tint = Color(bg_color.r / base.r, bg_color.g / base.g, bg_color.b / base.b, bg_color.a)
		RenderingServer.canvas_item_add_polygon(canvas_item, points, PackedColorArray([tint]), uvs, PAPER.get_rid())
	var rim := StyleBoxFlat.new()
	rim.draw_center = false
	rim.border_color = border_color
	rim.border_width_left = border_width_left
	rim.border_width_top = border_width_top
	rim.border_width_right = border_width_right
	rim.border_width_bottom = border_width_bottom
	rim.corner_radius_top_left = corner_radius_top_left
	rim.corner_radius_top_right = corner_radius_top_right
	rim.corner_radius_bottom_right = corner_radius_bottom_right
	rim.corner_radius_bottom_left = corner_radius_bottom_left
	rim.draw(canvas_item, rect)
