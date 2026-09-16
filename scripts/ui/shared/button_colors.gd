extends VBoxContainer
## Reusable palette choices; preference persistence belongs to the app.
const UI = preload("res://scripts/ui/shared/interface.gd")
signal palette_selected(key: String)

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	for key in UI.BUTTON_PALETTES:
		var palette: Dictionary = UI.BUTTON_PALETTES[key]
		var preview := Control.new()
		preview.custom_minimum_size = Vector2(48, 48)
		preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.draw.connect(func():
			preview.draw_style_box(UI.surface(palette.secondary, UI.BUTTON_OUTLINE, 0), Rect2(0, 0, 36, 28))
			preview.draw_style_box(UI.surface(palette.primary, UI.BUTTON_OUTLINE, 0), Rect2(12, 20, 36, 28))
		)
		var select := UI.button("Select", func(): palette_selected.emit(key))
		select.name = "Palette_" + key
		select.toggle_mode = true
		select.button_pressed = UI.button_palette == key
		var row := UI.action_row(palette.name, select, "Select", preview, palette.description)
		row.custom_minimum_size.y = 88
		select.custom_minimum_size.x = 104
		add_child(row)
