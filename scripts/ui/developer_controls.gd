extends VBoxContainer

signal changed
signal layout_changed

const UI = preload("res://scripts/ui/interface.gd")
const HANDLE = preload("res://assets/ui/slider_handle.svg")
const SELECTOR_ARROW = preload("res://assets/ui/selector_arrow.svg")
var game: VigilState
var category := "enemies"
var selected_kind := "basic"
var tabs: Dictionary = {}
var selector: OptionButton
var fields: VBoxContainer
var sliders: Dictionary = {}
var hint: Label
var detail: Label

func _ready() -> void:
	name = "DeveloperControls"
	add_theme_constant_override("separation", 12)
	var tab_row := HFlowContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	add_child(tab_row)
	for section in Balance.TUNING_FIELDS:
		var tab := UI.button(section.capitalize(), show_category.bind(section))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.autowrap_mode = TextServer.AUTOWRAP_OFF
		tab.add_theme_font_size_override("font_size", UI.type_size(14))
		tab.toggle_mode = true
		tab.add_theme_stylebox_override("pressed", UI.box(UI.GOLD))
		tab.add_theme_stylebox_override("hover_pressed", UI.box(UI.GOLD))
		tabs[section] = tab
		tab_row.add_child(tab)
	selector = OptionButton.new()
	selector.name = "BalanceUnit"
	selector.custom_minimum_size.y = UI.TARGET
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.add_theme_stylebox_override("normal", UI.box(UI.SURFACE))
	selector.add_theme_stylebox_override("hover", UI.box(UI.SURFACE))
	selector.add_theme_stylebox_override("pressed", UI.box(UI.GOLD))
	selector.add_theme_stylebox_override("focus", UI.focus_box())
	selector.add_theme_icon_override("arrow", SELECTOR_ARROW)
	selector.add_theme_constant_override("modulate_arrow", 0)
	selector.add_theme_color_override("font_color", UI.TEXT)
	selector.add_theme_color_override("font_hover_color", UI.TEXT)
	selector.add_theme_color_override("font_pressed_color", UI.TEXT)
	selector.item_selected.connect(func(index: int):
		selected_kind = selector.get_item_metadata(index)
		show_fields()
	)
	add_child(selector)
	hint = UI.paragraph("", 12)
	add_child(hint)
	fields = VBoxContainer.new()
	fields.add_theme_constant_override("separation", 16)
	add_child(fields)
	detail = UI.paragraph("", 12)
	add_child(detail)
	var reset_selected := UI.button("Reset selected type", func():
		game.reset_developer_balance(category, selected_kind)
		show_fields()
		changed.emit()
	)
	reset_selected.name = "ResetSelectedBalance"
	add_child(reset_selected)
	var reset_all := UI.button("Reset all balance values", func():
		game.reset_developer_balance()
		show_fields()
		changed.emit()
	)
	reset_all.name = "ResetAllBalance"
	add_child(reset_all)
	show_category(category)

func show_category(section: String) -> void:
	category = section
	for key in tabs:
		tabs[key].set_pressed_no_signal(key == category)
	selector.clear()
	var definitions := Balance.definitions(category)
	for kind in definitions:
		selector.add_item(definitions[kind].name)
		selector.set_item_metadata(selector.item_count - 1, kind)
	selector.select(0)
	selector.accessibility_name = "Choose " + ("enemy" if category == "enemies" else "tower") + " type"
	selected_kind = selector.get_item_metadata(0)
	hint.text = "Live changes · Auto-saved" if category == "enemies" else "Level 1 · Live changes · Auto-saved"
	detail.text = "Health changes keep each enemy's remaining health percentage." if category == "enemies" else "Upgrades scale from these values. Lower attack intervals fire faster. Blast radius 0 hits one target. Build cost also scales upgrades and refunds."
	if category == "rifts":
		selector.accessibility_name = "Choose rift type"
		hint.text = "Live changes · Auto-saved · Grass always has no effect"
	show_fields()

func show_fields() -> void:
	if category == "rifts":
		detail.text = Balance.rift_description(selected_kind, game.tuning) + " Set to 0 to disable. Health adjustments preserve remaining health percentage."
	sliders.clear()
	for child in fields.get_children():
		fields.remove_child(child)
		child.queue_free()
	for stat in Balance.TUNING_FIELDS[category]:
		add_slider(stat)
	# Scrolling follows keyboard focus; left/right remain available to sliders.
	call_deferred("refresh_focus")

func add_slider(stat: String) -> void:
	var descriptor: Dictionary = Balance.TUNING_FIELDS[category][stat]
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	fields.add_child(row)
	var label := UI.label("", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var adjustment := HBoxContainer.new()
	adjustment.add_theme_constant_override("separation", 8)
	row.add_child(adjustment)
	var slider := HSlider.new()
	slider.name = stat + "Slider"
	slider.min_value = descriptor.min
	slider.max_value = descriptor.max
	slider.step = descriptor.step
	slider.value = Balance.tuned_value(category, selected_kind, stat, game.tuning)
	slider.custom_minimum_size = Vector2(0, UI.TARGET)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	slider.scrollable = false
	slider.accessibility_name = Balance.definitions(category)[selected_kind].name + " " + descriptor.label
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(state, HANDLE)
	var track := UI.surface(UI.SURFACE, 2, 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", UI.surface(UI.GOLD, 2, 0))
	slider.add_theme_stylebox_override("grabber_area_highlight", UI.surface(UI.GOLD, 2, 0))
	slider.add_theme_stylebox_override("focus", UI.focus_box())
	var decrease := UI.button("−", func(): slider.value -= slider.step)
	decrease.custom_minimum_size.x = UI.TARGET
	decrease.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	decrease.accessibility_name = "Decrease " + slider.accessibility_name
	adjustment.add_child(decrease)
	adjustment.add_child(slider)
	var increase := UI.button("+", func(): slider.value += slider.step)
	increase.custom_minimum_size.x = UI.TARGET
	increase.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	increase.accessibility_name = "Increase " + slider.accessibility_name
	adjustment.add_child(increase)
	sliders[stat] = slider
	var baseline: float = Balance.definitions(category)[selected_kind][stat]
	var baseline_label := UI.paragraph("Default: " + format_value(baseline, descriptor), 12)
	row.add_child(baseline_label)
	label.text = descriptor.label + " · " + format_value(slider.value, descriptor)
	# Capture this row's identity so a removed control cannot edit a different type.
	var section := category
	var kind := selected_kind
	slider.value_changed.connect(func(value: float):
		if not slider.is_inside_tree():
			return
		if game.set_balance_stat(section, kind, stat, value):
			label.text = descriptor.label + " · " + format_value(value, descriptor)
			if section == "rifts":
				detail.text = Balance.rift_description(kind, game.tuning) + " Set to 0 to disable. Health adjustments preserve remaining health percentage."
			changed.emit()
	)

func refresh_focus() -> void:
	if is_inside_tree():
		layout_changed.emit()

static func format_value(value: float, descriptor: Dictionary) -> String:
	return String.num(value, 2).trim_suffix(".0") + descriptor.suffix
