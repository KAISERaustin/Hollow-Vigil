extends StyleBox
## Reusable textured fill; retain StyleBoxFlat's layout and border API.

const PAPER = preload("res://assets/ui/welcome-parchment.png")
const YELLOW_PAPER = preload("res://assets/ui/yellow-parchment.png")
const RED_PAPER = preload("res://assets/ui/red-parchment.png")

var paper: Texture2D = PAPER
var base_color := VigilTerrainArt.PAPER

var bg_color := Color.WHITE
var border_color := Color.BLACK
var draw_center := true
var border_width_left := 0
var border_width_top := 0
var border_width_right := 0
var border_width_bottom := 0
var corner_radius_top_left := 0
var corner_radius_top_right := 0
var corner_radius_bottom_right := 0
var corner_radius_bottom_left := 0
var shadow_color := Color.TRANSPARENT
var shadow_offset := Vector2.ZERO
var shadow_size := 0

func set_border_width_all(width: int) -> void:
	border_width_left = width
	border_width_top = width
	border_width_right = width
	border_width_bottom = width

func set_corner_radius_all(radius: int) -> void:
	corner_radius_top_left = radius
	corner_radius_top_right = radius
	corner_radius_bottom_right = radius
	corner_radius_bottom_left = radius

func _draw(canvas_item: RID, rect: Rect2) -> void:
	# Match the rim's fully opaque edge, including its antialiasing radius.
	# Paper must cover the inner edge even on a one-pixel rim, without reaching
	# the softened outer edge where it would show through the rounded corners.
	var fill_rect := rect
	var radii := [corner_radius_top_left, corner_radius_top_right, corner_radius_bottom_right, corner_radius_bottom_left]
	if radii.max() > 0 and border_color.a > 0.0:
		var insets := [minf(border_width_left, 0.5), minf(border_width_top, 0.5), minf(border_width_right, 0.5), minf(border_width_bottom, 0.5)]
		fill_rect = rect.grow_individual(-insets[0], -insets[1], -insets[2], -insets[3])
		for corner in range(4):
			radii[corner] += minf(insets[corner], insets[(corner + 1) % 4])
	if draw_center and bg_color.a > 0.0 and fill_rect.has_area():
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		var corners := [fill_rect.position, Vector2(fill_rect.end.x, fill_rect.position.y), fill_rect.end, Vector2(fill_rect.position.x, fill_rect.end.y)]
		var directions := [Vector2.ONE, Vector2(-1, 1), -Vector2.ONE, Vector2(1, -1)]
		# Cover instead of stretching: paper grain keeps the same proportions.
		var texture_size := Vector2(paper.get_size())
		var scale_factor := maxf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
		var covered_size := texture_size * scale_factor
		for corner in range(4):
			var radius := minf(radii[corner], minf(fill_rect.size.x, fill_rect.size.y) * 0.5)
			var center: Vector2 = corners[corner] + directions[corner] * radius
			for step in range(9):
				var angle := PI + corner * PI * 0.5 + step * PI / 16.0
				var point := center + Vector2(cos(angle), sin(angle)) * radius
				points.append(point)
				uvs.append((point - rect.position + (covered_size - rect.size) * 0.5) / covered_size)
		var tint := Color.WHITE
		# Preserve darker tan roles while using the reference paper for panels.
		var base := base_color
		tint = Color(bg_color.r / base.r, bg_color.g / base.g, bg_color.b / base.b, bg_color.a)
		RenderingServer.canvas_item_add_polygon(canvas_item, points, PackedColorArray([tint]), uvs, paper.get_rid())
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
	rim.shadow_color = shadow_color
	rim.shadow_offset = shadow_offset
	rim.shadow_size = shadow_size
	rim.draw(canvas_item, rect)
