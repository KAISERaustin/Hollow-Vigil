extends RefCounted
## Four fixed visual states shared by construction and placed-tower panels.
const UI = preload("res://scripts/ui/shared/interface.gd")
const IMAGES = [
	preload("res://assets/ui/tower-levels/level-1.svg"),
	preload("res://assets/ui/tower-levels/level-2.svg"),
	preload("res://assets/ui/tower-levels/level-3.svg"),
	preload("res://assets/ui/tower-levels/level-4.svg"),
]

static func create(level: int) -> VBoxContainer:
	var current := clampi(level, 1, IMAGES.size())
	var column := VBoxContainer.new()
	column.name = "TowerLevelIndicator"
	column.set_meta("level", current)
	column.add_theme_constant_override("separation", 4)
	var caption := UI.label("Max level" if current == 4 else "Level %d / 4" % current, 14)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	var image := TextureRect.new()
	image.name = "LevelSquares"
	image.texture = IMAGES[current - 1]
	image.custom_minimum_size = Vector2(152, 32)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.accessibility_name = "Tower level %d of 4" % current
	column.add_child(image)
	return column
