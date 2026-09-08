extends RefCounted
## Four fixed visual states shared by construction and placed-tower panels.
const UI = preload("res://scripts/ui/shared/interface.gd")
const IMAGES = [
	preload("res://assets/ui/tower-levels/stage-1.png"),
	preload("res://assets/ui/tower-levels/stage-2.png"),
	preload("res://assets/ui/tower-levels/stage-3.png"),
	preload("res://assets/ui/tower-levels/stage-4.png"),
]

static func create(level: int, show_caption: bool = true, vertical: bool = false) -> VBoxContainer:
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
	for index in IMAGES.size():
		var square := PanelContainer.new()
		square.name = "Level%d" % (index + 1)
		square.custom_minimum_size = Vector2(32, 32)
		square.add_theme_stylebox_override("panel", UI.surface(UI.GOLD if index < current else UI.SURFACE, UI.OUTLINE, 4))
		square.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(square)
		var image := TextureRect.new()
		image.name = "LevelArtwork"
		image.texture = IMAGES[index] if index < current else null
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.accessibility_name = "Level %d %s" % [index + 1, "reached" if index < current else "not reached"]
		square.add_child(image)
	return column
