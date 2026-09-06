extends RefCounted

const UI = preload("res://scripts/ui/shared/interface.gd")

static func create(kind: String, title: String, cost: float, action: Callable, level: int = 1, branch: String = "") -> Button:
	var button := UI.button("", action, 88)
	button.accessibility_name = "%s · %s gold" % [title, Balance.money(cost)]
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)
	var portrait := Control.new()
	portrait.name = "TowerPortrait"
	portrait.custom_minimum_size = Vector2(64, 68)
	portrait.draw.connect(func():
		VigilTerrainArt.sentinel(portrait, kind, Vector2(portrait.size.x * 0.5, 55), 0.9, level, branch)
	)
	portrait.resized.connect(portrait.queue_redraw)
	row.add_child(portrait)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation", 4)
	row.add_child(copy)
	copy.add_child(UI.heading(title, 18))
	copy.add_child(UI.label("%s gold" % Balance.money(cost), 14))
	_ignore_mouse(margin)
	button.draw.connect(func(): copy.modulate.a = 0.45 if button.disabled else 1.0)
	return button

static func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_ignore_mouse(child)
