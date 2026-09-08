extends RefCounted
## Four fixed visual states shared by construction and placed-tower panels.
const UI = preload("res://scripts/ui/shared/interface.gd")
const IMAGES = [
	preload("res://assets/ui/tower-levels/bubbles-1.png"),
	preload("res://assets/ui/tower-levels/bubbles-2.png"),
	preload("res://assets/ui/tower-levels/bubbles-3.png"),
	preload("res://assets/ui/tower-levels/bubbles-4.png"),
]

const BUBBLE_SHADER = preload("res://scripts/ui/shared/level_bubble.gdshader")
const REGIONS = [[[58, 121, 470, 465], [586, 120, 471, 466], [1115, 119, 472, 467], [1645, 119, 473, 467]], [[88, 134, 432, 426], [612, 134, 430, 426], [1134, 134, 430, 426], [1653, 134, 431, 426]], [[61, 119, 482, 479], [581, 119, 486, 480], [1104, 119, 487, 479], [1629, 119, 483, 479]], [[62, 114, 467, 465], [587, 114, 470, 465], [1116, 114, 468, 465], [1642, 114, 467, 465]]]

static func create(level: int, show_caption: bool = true, vertical: bool = false, square_size: float = 32.0) -> VBoxContainer:
	var current := clampi(level, 1, IMAGES.size())
	var column := VBoxContainer.new()
	column.name = "TowerLevelIndicator"
	column.set_meta("level", current)
	column.add_theme_constant_override("separation", 4)
	if show_caption:
		var caption := UI.label("Max level" if current == 4 else "Level %d / 4" % current, 14)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(caption)
	var row := BoxContainer.new()
	row.vertical = vertical
	row.name = "LevelSquares"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.accessibility_name = "Tower level %d of 4" % current
	column.add_child(row)
	for position in IMAGES.size():
		# Vertical progression grows upward; horizontal progression grows rightward.
		var index: int = IMAGES.size() - 1 - position if vertical else position
		var image := TextureRect.new()
		image.name = "Level%d" % (index + 1)
		image.custom_minimum_size = Vector2.ONE * square_size
		image.texture = IMAGES[current - 1]
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.accessibility_name = "Level %d %s" % [index + 1, "reached" if index < current else "not reached"]
		image.set_meta("earned", index < current)
		var region: Array = REGIONS[current - 1][index]
		var ink := ShaderMaterial.new()
		ink.shader = BUBBLE_SHADER
		ink.set_shader_parameter("source_region", Vector4(region[0] / 2172.0, region[1] / 724.0, region[2] / 2172.0, region[3] / 724.0))
		ink.set_shader_parameter("outline", float(UI.OUTLINE))
		image.material = ink
		row.add_child(image)
	return column
