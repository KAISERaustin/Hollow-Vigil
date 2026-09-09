extends "res://scripts/ui/developer/developer_controls.gd"
## Full-page navigation over the shared content editors.
signal route_changed(title: String, item_open: bool)
signal item_started
signal item_cancelled
var route := "categories"
var listing: VBoxContainer
var item_menu: VBoxContainer
var snapshot := {}

func _ready() -> void:
	listing = VBoxContainer.new()
	listing.add_theme_constant_override("separation", 12)
	add_child(listing)
	item_menu = VBoxContainer.new()
	item_menu.add_theme_constant_override("separation", 12)
	add_child(item_menu)
	super._ready()

func show_categories() -> void:
	super.show_categories()
	listing.hide()
	item_menu.hide()
	route = "categories"
	route_changed.emit("Edit rules", false)

func show_category(section: String) -> void:
	commit_fields()
	category = section
	editor.hide()
	category_list.hide()
	general.hide()
	item_menu.hide()
	for child in listing.get_children():
		listing.remove_child(child)
		child.queue_free()
	var definitions: Dictionary = Balance.TOWERS if category == "towers" else editor_definitions()
	for kind in definitions:
		var button := UI.button("Open", open_item.bind(section, kind))
		button.name = "RuleItem_" + kind
		var row := UI.action_row(definitions[kind].name, button, "Open", Portrait.preview(category, kind))
		row.custom_minimum_size.y = 76
		listing.add_child(row)
	listing.show()
	route = "list"
	route_changed.emit(category_title(category), false)

func open_item(section: String, kind: String) -> void:
	snapshot = game.tuning.duplicate(true)
	item_started.emit()
	super.show_category(section)
	selected_kind = kind
	populate_tiers()
	show_fields()
	show_item()

func show_item() -> void:
	commit_fields()
	listing.hide()
	editor.hide()
	for child in item_menu.get_children():
		item_menu.remove_child(child)
		child.queue_free()
	item_menu.add_child(UI.heading(identity_title.text, 24))
	item_menu.add_child(Portrait.preview(category, selected_kind, selected_level, selected_branch))
	item_menu.add_child(UI.button("Reset", func():
		game.reset_developer_balance(category, editing_kind())
		rules_edited.emit(category, editing_kind(), Balance.Stats.schema(category).keys() if category in Balance.Stats.CATEGORIES else selected_fields().keys())
		show_fields()
		show_item()
	))
	for group in ["Stats", "Abilities", "Attributes"]:
		var button := UI.button(group, open_group.bind(group))
		button.name = group + "Menu"
		item_menu.add_child(button)
	item_menu.show()
	route = "item"
	route_changed.emit(identity_title.text, true)

func open_group(group: String) -> void:
	commit_fields()
	show_fields()
	item_menu.hide()
	editor.show()
	for child in editor.get_children(): child.hide()
	fields.show()
	if category == "gear" and group == "Stats":
		description.show()
		editor.move_child(description, 0)
	if category == "towers": tier_selector.show()
	if is_instance_valid(stats_editor):
		stats_editor.full_page = true
		stats_editor.group = group
		stats_editor.get_child(0).hide()
		stats_editor.rebuild()
	elif category == "rifts":
		for child in fields.get_children():
			fields.remove_child(child)
			child.queue_free()
		inputs.clear()
		if group == "Attributes":
			fields.add_child(UI.paragraph("Applies to every enemy and boss from this portal type. Armor reduces incoming damage; regeneration restores a percentage of maximum health each second. Set 0 to remove an effect. Regeneration adds to the built-in portal effect."))
			add_number("armor_percent")
			add_number("health_regen_percent")
		elif group == "Stats" and selected_fields().has("strength"):
			fields.add_child(UI.paragraph(Balance.rift_description(selected_kind, game.tuning)))
			add_number("strength")
		else:
			fields.add_child(UI.paragraph("Enemy armor and health regeneration are available under Attributes."))
	elif group != "Stats":
		for child in fields.get_children(): child.hide()
		fields.add_child(UI.paragraph("No editable " + group.to_lower() + " for this item."))
	route = group
	route_changed.emit(group + " · " + identity_title.text, true)

func show_fields() -> void:
	super.show_fields()
	if route in ["Stats", "Abilities", "Attributes"] and is_instance_valid(stats_editor):
		stats_editor.full_page = true
		stats_editor.group = route
		stats_editor.get_child(0).hide()
		stats_editor.rebuild()

func save_item() -> void:
	commit_fields()
	show_category(category)

func cancel_item() -> void:
	commit_fields()
	game.apply_balance(snapshot)
	item_cancelled.emit()
	show_category(category)

func navigate_back() -> void:
	if route in ["Stats", "Abilities", "Attributes"] and is_instance_valid(stats_editor) and stats_editor.choosing:
		stats_editor.choosing = false
		stats_editor.rebuild()
		return
	match route:
		"list": show_categories()
		"item": cancel_item()
		_: show_item()
