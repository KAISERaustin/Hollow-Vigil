extends VBoxContainer
## The same mode choice can be composed into any Level family's setup screen.
const UI = preload("res://scripts/ui/shared/interface.gd")
signal selected(mode: String)

func configure(current: String, descriptions: Dictionary) -> void:
	add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var help := UI.paragraph(descriptions[current], 14)
	var group := ButtonGroup.new()
	for mode in ["creative", "survival"]:
		var button := UI.button(mode.capitalize(), func():
			help.text = descriptions[mode]
			selected.emit(mode)
		)
		button.name = "Mode" + mode.capitalize()
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = mode == current
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	add_child(help)
