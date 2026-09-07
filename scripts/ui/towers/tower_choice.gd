extends RefCounted

const UI = preload("res://scripts/ui/shared/interface.gd")

static func create(kind: String, title: String, cost: float, action: Callable, level: int = 1, branch: String = "") -> Button:
	var button := UI.button("", action, 56)
	button.accessibility_name = "%s · %s gold" % [title, UI.exact_money(cost)]
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var portrait := Control.new()
	portrait.name = "TowerPortrait"
	portrait.custom_minimum_size = Vector2(36, 44)
	portrait.draw.connect(func():
		# Tower art extends roughly from -42 to +12 around its ground anchor.
		var center := portrait.size * 0.5 + Vector2(0, 7.5)
		VigilTerrainArt.sentinel(portrait, kind, center, 0.5, level, branch)
	)
	portrait.resized.connect(portrait.queue_redraw)
	row.add_child(portrait)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation", 0)
	row.add_child(copy)
	copy.add_child(UI.heading(title, 16))
	copy.add_child(UI.label("%s gold" % UI.exact_money(cost), 13))
	_ignore_mouse(margin)
	button.draw.connect(func(): copy.modulate.a = 0.45 if button.disabled else 1.0)
	return button

static func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_ignore_mouse(child)

## Shared base-tower catalog; hosts retain placement and transaction ownership.
static func build_list(tuning: Dictionary, action: Callable, selected_kind: String = "", balance: float = INF, prefix: String = "Build_") -> VBoxContainer:
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	for kind in Balance.TOWERS:
		var definition := Balance.definition("towers", kind, tuning)
		var button := create(kind, definition.name, definition.cost, action.bind(kind))
		button.name = prefix + kind
		button.set_meta("tower_kind", kind)
		button.disabled = balance < definition.cost
		button.toggle_mode = not selected_kind.is_empty()
		button.set_pressed_no_signal(selected_kind == kind)
		choices.add_child(button)
	return choices
