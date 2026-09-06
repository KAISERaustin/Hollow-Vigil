extends VBoxContainer

signal changed
signal layout_changed

const UI = preload("res://scripts/ui/shared/interface.gd")
const SELECTOR_ARROW = preload("res://assets/ui/selector_arrow.svg")
var game: VigilState
var field: Battlefield
var category := "enemies"
var selected_kind := "basic"
var tabs: Dictionary = {}
var general: VBoxContainer
var category_list: VBoxContainer
var editor: VBoxContainer
var selector: OptionButton
var tier_selector: OptionButton
var selected_level := 1
var selected_branch := ""
var fields: VBoxContainer
var inputs: Dictionary = {}
var hint: Label
var detail: Label
var portrait: Control
var identity_title: Label
var description: Label

func _ready() -> void:
	name = "DeveloperControls"
	if not game.is_creative():
		return
	add_theme_constant_override("separation", 12)
	general = VBoxContainer.new()
	add_child(general)
	var add_gold := UI.button("Add 1,000,000 gold", func():
		game.add_developer_gold()
		changed.emit()
	)
	add_gold.name = "AddMillionGold"
	general.add_child(UI.action_row(add_gold.text, add_gold, "Add"))
	if field != null:
		var free_camera := UI.button("Unrestricted zoom and pan", func(): pass)
		free_camera.name = "UnrestrictedCamera"
		free_camera.toggle_mode = true
		free_camera.set_pressed_no_signal(field.unrestricted_camera)
		free_camera.toggled.connect(field.set_unrestricted_camera)
		free_camera.tooltip_text = "Bypass camera limits for this session. Turn off to restore the two-tile limits."
		general.add_child(UI.action_row(free_camera.text, free_camera, "Toggle"))
		var health_numbers := UI.button("Show enemy and boss health", func(): pass)
		health_numbers.name = "ShowHealthNumbers"
		health_numbers.toggle_mode = true
		health_numbers.set_pressed_no_signal(field.show_health_numbers)
		health_numbers.toggled.connect(func(enabled: bool):
			field.show_health_numbers = enabled
			field.queue_redraw()
		)
		general.add_child(UI.action_row(health_numbers.text, health_numbers, "Toggle"))
	category_list = VBoxContainer.new()
	category_list.name = "BalanceCategories"
	add_child(category_list)
	move_child(category_list, 0)
	for section in ["bosses", "rifts", "enemies", "towers", "gear"]:
		var tab := UI.button(section.capitalize(), show_category.bind(section))
		tab.name = section.capitalize() + "Category"
		tabs[section] = tab
		category_list.add_child(UI.action_row(tab.text, tab, "Open"))
	editor = VBoxContainer.new()
	editor.name = "BalanceEditor"
	editor.add_theme_constant_override("separation", 12)
	add_child(editor)
	var identity := PanelContainer.new()
	identity.name = "BalanceIdentity"
	identity.add_theme_stylebox_override("panel", UI.surface(UI.GOLD))
	editor.add_child(identity)
	var identity_stack := VBoxContainer.new()
	identity.add_child(identity_stack)
	identity_title = UI.paragraph("", UI.OBJECT_TITLE)
	identity_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity_title.add_theme_font_override("font", UI.font(700, true))
	identity_stack.add_child(identity_title)
	portrait = Control.new()
	portrait.name = "BalancePortrait"
	portrait.custom_minimum_size = Vector2(0, 144)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.draw.connect(draw_portrait)
	portrait.resized.connect(portrait.queue_redraw)
	identity_stack.add_child(portrait)
	description = UI.paragraph("", UI.CAPTION)
	description.name = "BalanceDescription"
	editor.add_child(description)
	selector = OptionButton.new()
	selector.name = "BalanceUnit"
	selector.get_popup().about_to_popup.connect(limit_dropdown.bind(selector))
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
		commit_fields()
		selected_kind = selector.get_item_metadata(index)
		populate_tiers()
		show_fields()
	)
	editor.add_child(selector)
	limit_dropdown(selector)
	selector.get_popup().shrink_width = false
	tier_selector = selector.duplicate(0)
	tier_selector.name = "BalanceTier"
	tier_selector.get_popup().about_to_popup.connect(limit_dropdown.bind(tier_selector))
	tier_selector.item_selected.connect(func(index: int):
		commit_fields()
		var choice: Dictionary = tier_selector.get_item_metadata(index)
		selected_level = choice.level
		selected_branch = choice.branch
		show_fields()
	)
	editor.add_child(tier_selector)
	limit_dropdown(tier_selector)
	tier_selector.get_popup().shrink_width = false
	hint = UI.paragraph("", 12)
	editor.add_child(hint)
	fields = VBoxContainer.new()
	fields.add_theme_constant_override("separation", 16)
	editor.add_child(fields)
	detail = UI.paragraph("", 12)
	editor.add_child(detail)
	var reset_selected := UI.button("Reset selected type / tier", func():
		commit_fields()
		game.reset_developer_balance(category, editing_kind())
		show_fields()
		changed.emit()
	)
	reset_selected.name = "ResetSelectedBalance"
	editor.add_child(UI.action_row(reset_selected.text, reset_selected, "Reset"))
	var reset_all := UI.button("Reset all balance values", func():
		commit_fields()
		game.reset_developer_balance()
		show_fields()
		changed.emit()
	)
	reset_all.name = "ResetAllBalance"
	editor.add_child(UI.action_row(reset_all.text, reset_all, "Reset"))
	show_categories()

func limit_dropdown(option: OptionButton) -> void:
	# Set this before the first popup layout; about_to_popup alone runs too late
	# to constrain its initial minimum height and screen placement.
	var viewport_size := get_viewport_rect().size
	option.get_popup().max_size = Vector2i(int(viewport_size.x), mini(UI.TARGET * 6, int(viewport_size.y)))

func commit_fields() -> void:
	for number in inputs.values():
		if is_instance_valid(number) and number.is_inside_tree():
			number.apply()

func show_categories() -> void:
	commit_fields()
	editor.hide()
	general.show()
	category_list.show()
	refresh_focus()

func show_category(section: String) -> void:
	commit_fields()
	category = section
	category_list.hide()
	general.hide()
	editor.show()
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
	if category == "gear":
		selector.accessibility_name = "Choose gear type"
		hint.text = "Live changes · Auto-saved"
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
	refresh_identity()
	if category == "towers":
		hint.text = "Tier %d · Live changes · Auto-saved" % selected_level
		detail.text = "Edit this tier independently. Costs are for building tier 1 or purchasing the selected upgrade. Specialization effects appear below combat stats."
	if category == "bosses":
		detail.text = "Counter: " + Balance.BOSSES[selected_kind].weakness + ". Values override these defaults. Health, shields, wards and timers preserve their remaining proportion. Rewards apply on defeat."
	if category == "gear":
		detail.text = "Changes apply to equipped gear on its next attack. Active root cooldowns keep their remaining proportion. Shots already in flight keep their launch damage."
	if category == "rifts":
		detail.text = Balance.rift_description(selected_kind, game.tuning) + " Set to 0 to disable. Health adjustments preserve remaining health percentage."
	inputs.clear()
	for child in fields.get_children():
		fields.remove_child(child)
		child.queue_free()
	for stat in Balance.fields_for(category, editing_kind()):
		add_number(stat)
	# Scrolling follows focus as players move between exact-value fields.
	call_deferred("refresh_focus")

func refresh_identity() -> void:
	var definition: Dictionary = Balance.definitions(category)[editing_kind()]
	identity_title.text = definition.name
	match category:
		"enemies": description.text = definition.description
		"towers":
			identity_title.text = Balance.TOWERS[selected_kind].name + " · Tier " + str(selected_level)
			description.text = Balance.tower_description(Balance.stats(selected_kind, selected_level, game.tuning, selected_branch))
			if selected_branch != "":
				identity_title.text = Balance.BRANCHES[selected_kind][selected_branch].name + " · Tier 4"
		"rifts": description.text = Balance.rift_description(selected_kind, game.tuning)
		"gear": description.text = preload("res://scripts/gameplay/progression/relics.gd").description(selected_kind, game.tuning)
		"bosses":
			var summaries := {
				"warden": "A forest guardian protected by a regenerating root shield. Fire can burn away its protection and suppress regrowth.",
				"cindermaw": "An armored fire spirit in a broken vessel. It hastens when wounded; frost can quench its rage.",
				"bell": "A haunted bell that periodically summons escorts. Delaying its tolls keeps the procession under control.",
				"prior": "A spectral prior protected by regenerating wards. Curses can bypass its defenses and suppress regrowth."
			}
			description.text = summaries[selected_kind] + " Counter: " + definition.weakness + "."
	portrait.accessibility_name = identity_title.text + " portrait"
	portrait.queue_redraw()

func draw_portrait() -> void:
	var center := portrait.size * 0.5
	match category:
		"enemies": VigilEnemyArt.draw(portrait, selected_kind, center + Vector2(0, 10), 3.0)
		"bosses": preload("res://scripts/rendering/actors/boss_art.gd").portrait(portrait, selected_kind, center + Vector2(0, 5), 1.1)
		"rifts": preload("res://scripts/rendering/actors/rift_art.gd").draw(portrait, selected_kind, center + Vector2(0, 20), 1.8)
		"gear": preload("res://scripts/rendering/actors/relic_art.gd").draw(portrait, selected_kind, center, 3.6)
		"towers": VigilTerrainArt.sentinel(portrait, selected_kind, center + Vector2(0, 46), 1.7, selected_level, selected_branch)

func add_number(stat: String) -> void:
	var descriptor: Dictionary = Balance.field_limits(category, editing_kind(), stat)
	var number := SpinBox.new()
	number.name = stat + "Value"
	number.min_value = descriptor.min
	number.max_value = descriptor.max
	number.step = descriptor.step
	number.value = current_value(stat)
	number.accessibility_name = Balance.definitions(category)[editing_kind()].name + " " + descriptor.label
	inputs[stat] = number
	var baseline: float = Balance.definitions(category)[editing_kind()][stat]
	var title: String = descriptor.label + "\nDefault: " + format_value(baseline, descriptor)
	fields.add_child(UI.number_row(title, number))
	# Capture this row's identity so a removed control cannot edit a different type.
	var section := category
	var kind := editing_kind()
	number.value_changed.connect(func(value: float):
		if not number.is_inside_tree():
			return
		var accepted := game.set_tower_tier_stat(kind, stat, value) if section == "towers" else game.set_balance_stat(section, kind, stat, value)
		if accepted:
			refresh_identity()
			if section == "rifts":
				detail.text = Balance.rift_description(kind, game.tuning) + " Set to 0 to disable. Health adjustments preserve remaining health percentage."
			changed.emit()
		else:
			number.set_value_no_signal(current_value(stat))
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
