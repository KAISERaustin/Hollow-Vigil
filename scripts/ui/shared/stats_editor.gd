extends VBoxContainer

## Reusable save-draft editor for any Stats-owning content node.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Descriptions = preload("res://scripts/content/catalogs/stat_descriptions.gd")
const Stats = preload("res://scripts/content/catalogs/stats.gd")
var game: VigilState
var category := "enemies"
var kind := "basic"
var edited: Callable
var relayout: Callable
var group := "Stats"
var choosing := false
var full_page := false
var numbers: Array[SpinBox] = []
var body: VBoxContainer
var filter: LineEdit
var rows: Array[Dictionary] = []
var section_body: VBoxContainer
var added_section := false

func _ready() -> void:
	name = "StatsEditor"
	add_theme_constant_override("separation", 12)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for label in ["Stats", "Abilities", "Attributes"]:
		var button := UI.button(label, func():
			commit_fields()
			group = label
			choosing = false
			rebuild()
			call_deferred("reveal_editor")
		)
		button.name = label + "Tab"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	add_child(tabs)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	rebuild()

func commit_fields() -> void:
	for number in numbers:
		if is_instance_valid(number) and number.is_inside_tree(): number.apply()

func changed(candidate: Dictionary) -> void:
	if game.apply_balance(candidate):
		edited.call(category, kind, candidate.get(category, {}).get(kind, {}).keys())

func rebuild() -> void:
	numbers.clear()
	rows.clear()
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if choosing:
		body.add_child(UI.button("Back to enabled " + group.to_lower(), func(): choosing = false; rebuild()))
		filter = LineEdit.new()
		filter.name = "StatSearch"
		filter.placeholder_text = "Search " + group.to_lower()
		UI.style_entry(filter)
		filter.custom_minimum_size.y = UI.TARGET
		filter.accessibility_name = filter.placeholder_text
		filter.text_changed.connect(func(value: String):
			for row in rows: row.control.visible = value.to_lower() in row.label.to_lower()
		)
		body.add_child(filter)
		if group == "Stats": build_stat_catalog()
		else: build_capabilities(true)
	else:
		for added in [false, true]:
			added_section = added
			if added: body.add_child(UI.rule())
			section_body = VBoxContainer.new()
			section_body.name = "AddedRules" if added else "DefaultRules"
			section_body.add_theme_constant_override("separation", 12)
			body.add_child(UI.info_card(section_body, UI.ADDED_RULES if added else UI.SURFACE, 12))
			section_body.add_child(UI.heading(("Added " if added else "Default ") + group.to_lower(), 18))
			section_body.add_child(UI.paragraph("Extras added to this item." if added else "Built into this item. Required stats cannot be disabled; their values can be edited.", 14))
			if group == "Stats":
				for field in Stats.schema(category):
					if Stats.control(field) or Stats.schema(category)[field].get("group", "Stats") != "Stats": continue
					if Stats.baseline(category, kind).has(field) == added: continue
					if Stats.enabled(category, kind, field, game.tuning): add_stat(field)
			else: build_capabilities(false)
			if section_body.get_child_count() == 2:
				section_body.add_child(UI.paragraph("No added " + group.to_lower() + " yet." if added else "No default " + group.to_lower() + ".", 14))
		var add := UI.gold_button("Add " + {"Stats": "Stat", "Abilities": "Ability", "Attributes": "Attribute"}[group], func(): commit_fields(); choosing = true; rebuild(); call_deferred("reveal_editor"))
		add.name = {"Stats": "AddStat", "Abilities": "AddAbility", "Attributes": "AddAttribute"}[group]
		section_body.add_child(add)
		body.add_child(UI.paragraph("Changes stay in this draft until you press Save. Each tier and branch is independent.", 14))
	if relayout.is_valid(): relayout.call()
	if is_node_ready(): call_deferred("reveal_editor")

func reveal_editor() -> void:
	if full_page: return
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	var ancestor := get_parent()
	while ancestor != null and not ancestor is ScrollContainer: ancestor = ancestor.get_parent()
	if ancestor != null: ancestor.scroll_vertical += int(global_position.y - ancestor.global_position.y)

func build_stat_catalog() -> void:
	for field in Stats.schema(category):
		if Stats.control(field) or field in ["arrow_count", "fan_angle"] or Stats.schema(category)[field].get("group", "Stats") != "Stats": continue
		var descriptor: Dictionary = Stats.schema(category)[field]
		var enabled := Stats.enabled(category, kind, field, game.tuning)
		var label: String = descriptor.label
		var requirement: String = descriptor.get("requires", "")
		var button := UI.button(label + (" · Enabled" if enabled else " · Add"), func():
			var candidate := game.tuning
			if not requirement.is_empty(): candidate = Stats.attach(candidate, category, kind, requirement)
			candidate = Stats.edit(candidate, category, kind, "enabled_" + field, 1)
			candidate = Stats.edit(candidate, category, kind, field, Stats.value(category, kind, field, candidate))
			changed(candidate)
			choosing = false
			rebuild()
		)
		button.name = "AddStat_" + field
		button.disabled = enabled
		add_choice(label, Descriptions.field(Stats, category, kind, field, game.tuning), button)

func build_capabilities(catalog: bool) -> void:
	if group == "Attributes" and category != "towers":
		for field in Stats.Capabilities.RESISTANCES:
			if not catalog and Stats.baseline(category, kind).has(field) == added_section: continue
			var enabled := Stats.enabled(category, kind, field, game.tuning)
			if not catalog and enabled: add_stat(field)
			if catalog:
				var label: String = Stats.Capabilities.RESISTANCES[field]
				var add := UI.button(label + (" · Enabled" if enabled else " · Add"), func():
					changed(Stats.edit(Stats.edit(game.tuning, category, kind, "enabled_" + field, 1), category, kind, field, Stats.value(category, kind, field, game.tuning)))
					choosing = false
					rebuild()
				)
				add.name = "AddStat_" + field
				add.disabled = enabled
				add_choice(label, Descriptions.field(Stats, category, kind, field, game.tuning), add)
	for ability in Stats.capabilities(category):
		if not catalog and (ability in Stats.Capabilities.defaults(category, kind)) == added_section: continue
		var descriptor: Dictionary = Stats.capabilities(category)[ability]
		if descriptor.group != group: continue
		var enabled := Stats.ability_enabled(category, kind, ability, game.tuning)
		if not catalog and not enabled: continue
		var label: String = descriptor.name
		var button := UI.button(label + (" · Enabled" if catalog and enabled else (" · Add" if catalog else " · Disable")), func():
			commit_fields()
			changed(Stats.attach(game.tuning, category, kind, ability, catalog))
			choosing = false
			rebuild()
		)
		button.name = ("AddAbility_" if catalog else "DisableAbility_") + ability
		button.disabled = catalog and enabled
		if catalog:
			add_choice(label, Descriptions.ability(Stats, category, kind, ability, game.tuning), button)
		else:
			section_body.add_child(button)
		if not catalog:
			for field in descriptor.fields:
				if Stats.enabled(category, kind, field, game.tuning) or not game.tuning.get(category, {}).get(kind, {}).has("enabled_" + field): add_stat(field)

func add_stat(field: String) -> void:
	var descriptor: Dictionary = Stats.schema(category)[field]
	var number := SpinBox.new()
	number.name = field + "Value"
	number.min_value = descriptor.min
	number.max_value = descriptor.max
	number.step = descriptor.step
	number.value = Stats.value(category, kind, field, game.tuning)
	number.accessibility_name = descriptor.label
	var label: String = descriptor.label + "\nDefault: " + String.num(Stats.default_value(category, kind, field), 2).trim_suffix(".0") + descriptor.suffix
	section_body.add_child(UI.number_row(label, number))
	numbers.append(number)
	number.value_changed.connect(func(value: float): changed(Stats.edit(game.tuning, category, kind, field, value)))
	if field not in Stats.REQUIRED:
		var disable := UI.button("Disable " + descriptor.label, func():
			commit_fields()
			changed(Stats.edit(game.tuning, category, kind, "enabled_" + field, 0))
			rebuild()
		)
		disable.name = "DisableStat_" + field
		section_body.add_child(disable)

func add_choice(title: String, description: String, button: Button) -> void:
	var row := UI.action_row(title, button, "Enabled" if button.disabled else "Select", null, description)
	row.name = button.name + "Row"
	button.accessibility_name = ("Enabled: " if button.disabled else "Select: ") + title + ". " + description
	var copy := row.get_child(0) as VBoxContainer
	copy.add_theme_constant_override("separation", 8)
	copy.get_child(0).add_theme_font_override("font", UI.font(700))
	var detail := copy.get_child(1) as Label
	detail.add_theme_font_size_override("font_size", 14)
	copy.minimum_size_changed.connect(func(): row.custom_minimum_size.y = maxf(64, copy.get_combined_minimum_size().y + 16))
	body.add_child(row)
	rows.append({"control": row, "label": title + " " + description})
