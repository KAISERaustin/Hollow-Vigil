extends VBoxContainer

signal changed
signal layout_changed

const UI = preload("res://scripts/ui/shared/interface.gd")
const HANDLE = preload("res://assets/ui/slider_handle.svg")
const SELECTOR_ARROW = preload("res://assets/ui/selector_arrow.svg")
var game: VigilState
var field: Battlefield
var category := "enemies"
var selected_kind := "basic"
var tabs: Dictionary = {}
var selector: OptionButton
var tier_selector: OptionButton
var selected_level := 1
var selected_branch := ""
var fields: VBoxContainer
var sliders: Dictionary = {}
var hint: Label
var detail: Label

func _ready() -> void:
	name = "DeveloperControls"
	add_theme_constant_override("separation", 12)
	var add_gold := UI.button("Add 1,000,000 gold", func():
		game.data.balance = minf(Balance.MAX_MONEY, game.data.balance + 1_000_000.0)
		changed.emit()
	)
	add_gold.name = "AddMillionGold"
	add_child(add_gold)
	if field != null:
		var free_camera := UI.button("Unrestricted zoom and pan", func(): pass)
		free_camera.name = "UnrestrictedCamera"
		free_camera.toggle_mode = true
		free_camera.set_pressed_no_signal(field.unrestricted_camera)
		free_camera.toggled.connect(field.set_unrestricted_camera)
		free_camera.tooltip_text = "Bypass camera limits for this session. Turn off to restore the two-tile limits."
		add_child(free_camera)
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
		populate_tiers()
		show_fields()
	)
	add_child(selector)
	tier_selector = selector.duplicate(0)
	tier_selector.name = "BalanceTier"
	tier_selector.item_selected.connect(func(index: int):
		var choice: Dictionary = tier_selector.get_item_metadata(index)
		selected_level = choice.level
		selected_branch = choice.branch
		show_fields()
	)
	add_child(tier_selector)
	hint = UI.paragraph("", 12)
	add_child(hint)
	fields = VBoxContainer.new()
	fields.add_theme_constant_override("separation", 16)
	add_child(fields)
	detail = UI.paragraph("", 12)
	add_child(detail)
	var reset_selected := UI.button("Reset selected type / tier", func():
		game.reset_developer_balance(category, editing_kind())
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
	var definitions: Dictionary = Balance.TOWERS if category == "towers" else Balance.definitions(category)
	for kind in definitions:
		selector.add_item(definitions[kind].name)
		selector.set_item_metadata(selector.item_count - 1, kind)
	selector.select(0)
	selector.accessibility_name = "Choose " + ("enemy" if category == "enemies" else "tower") + " type"
	selected_kind = selector.get_item_metadata(0)
	hint.text = "Live changes · Auto-saved" if category == "enemies" else "Level 1 · Live changes · Auto-saved"
	detail.text = "Health changes keep each enemy's remaining health percentage." if category == "enemies" else "Upgrades scale from these values. Lower attack intervals fire faster. Blast radius 0 hits one target. Build cost also scales upgrades and refunds."
	if category == "bosses":
		selector.accessibility_name = "Choose boss type"
		hint.text = "Live changes · Auto-saved"
	if category == "rifts":
		selector.accessibility_name = "Choose rift type"
		hint.text = "Live changes · Auto-saved · Grass always has no effect"
	populate_tiers()
	show_fields()

func editing_kind() -> String:
	return Balance.tier_key(selected_kind, selected_level, selected_branch) if category == "towers" else selected_kind

func populate_tiers() -> void:
	tier_selector.clear()
	tier_selector.visible = category == "towers"
	selected_level = 1
	selected_branch = ""
	if category != "towers":
		return
	for level in range(1, 4):
		tier_selector.add_item("Tier " + str(level))
		tier_selector.set_item_metadata(tier_selector.item_count - 1, {"level": level, "branch": ""})
	for branch in Balance.BRANCHES[selected_kind]:
		tier_selector.add_item("Tier 4 · " + Balance.BRANCHES[selected_kind][branch].name)
		tier_selector.set_item_metadata(tier_selector.item_count - 1, {"level": 4, "branch": branch})
	tier_selector.select(0)
	tier_selector.accessibility_name = "Choose tower upgrade tier or specialization"

func show_fields() -> void:
	if category == "towers":
		hint.text = "Tier %d · Live changes · Auto-saved" % selected_level
		detail.text = "Edit this tier independently. Costs are for building tier 1 or purchasing the selected upgrade. Specialization effects appear below combat stats."
	if category == "bosses":
		detail.text = "Counter: " + Balance.BOSSES[selected_kind].weakness + ". Sliders override these defaults. Health, shields, wards and timers preserve their remaining proportion. Rewards apply on defeat."
	if category == "rifts":
		detail.text = Balance.rift_description(selected_kind, game.tuning) + " Set to 0 to disable. Health adjustments preserve remaining health percentage."
	sliders.clear()
	for child in fields.get_children():
		fields.remove_child(child)
		child.queue_free()
	for stat in Balance.fields_for(category, editing_kind()):
		add_slider(stat)
	# Scrolling follows keyboard focus; left/right remain available to sliders.
	call_deferred("refresh_focus")

func add_slider(stat: String) -> void:
	var descriptor: Dictionary = Balance.field_limits(category, editing_kind(), stat)
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
	slider.value = current_value(stat)
	slider.custom_minimum_size = Vector2(0, UI.TARGET)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	slider.scrollable = false
	slider.accessibility_name = Balance.definitions(category)[editing_kind()].name + " " + descriptor.label
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
	var baseline: float = Balance.definitions(category)[editing_kind()][stat]
	var baseline_label := UI.paragraph("Default: " + format_value(baseline, descriptor), 12)
	row.add_child(baseline_label)
	var number := SpinBox.new()
	number.name = stat + "Value"
	number.min_value = slider.min_value
	number.max_value = slider.max_value
	number.step = slider.step
	number.value = slider.value
	number.custom_minimum_size.y = UI.TARGET
	number.accessibility_name = slider.accessibility_name + " exact value"
	var entry := number.get_line_edit()
	entry.add_theme_stylebox_override("normal", UI.box(UI.SURFACE))
	entry.add_theme_stylebox_override("focus", UI.focus_box())
	entry.add_theme_color_override("font_color", UI.TEXT)
	entry.add_theme_color_override("caret_color", UI.TEXT)
	entry.add_theme_font_size_override("font_size", UI.type_size(14))
	row.add_child(number)
	number.value_changed.connect(func(value: float): slider.value = value)
	slider.value_changed.connect(func(value: float): number.set_value_no_signal(value))
	label.text = descriptor.label + " · " + format_value(slider.value, descriptor)
	# Capture this row's identity so a removed control cannot edit a different type.
	var section := category
	var kind := editing_kind()
	slider.value_changed.connect(func(value: float):
		if not slider.is_inside_tree():
			return
		var accepted := game.set_tower_tier_stat(kind, stat, value) if section == "towers" else game.set_balance_stat(section, kind, stat, value)
		if accepted:
			label.text = descriptor.label + " · " + format_value(value, descriptor)
			if section == "rifts":
				detail.text = Balance.rift_description(kind, game.tuning) + " Set to 0 to disable. Health adjustments preserve remaining health percentage."
			changed.emit()
	)

func current_value(stat: String) -> float:
	if category == "towers" and stat != "cost":
		return Balance.stats(selected_kind, selected_level, game.tuning, selected_branch)[stat]
	if category == "towers" and stat == "cost" and selected_level > 1:
		return Balance.upgrade_cost({"kind": selected_kind, "level": selected_level - 1}, game.tuning, selected_branch)
	return Balance.tuned_value(category, editing_kind(), stat, game.tuning)

func refresh_focus() -> void:
	if is_inside_tree():
		layout_changed.emit()

static func format_value(value: float, descriptor: Dictionary) -> String:
	return String.num(value, 2).trim_suffix(".0") + descriptor.suffix
