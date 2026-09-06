extends RefCounted

const UI = preload("res://scripts/ui/shared/interface.gd")
const Relics = preload("res://scripts/gameplay/progression/relics.gd")
const Art = preload("res://scripts/rendering/actors/relic_art.gd")

static func build(dialog) -> void:
	var data: Dictionary = dialog.app.game.data
	var equipped_kind := Relics.kind(data, data.towers[dialog.tower_id])
	var summary := PanelContainer.new()
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_theme_stylebox_override("panel", UI.surface(UI.SURFACE, 2, 10))
	dialog.equipment_summary.add_child(summary)
	var summary_stack := UI.margin(summary, 12)
	summary_stack.add_child(UI.label("Currently equipped", 14, UI.TEXT))
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 10)
	summary_stack.add_child(summary_row)
	if equipped_kind != "":
		var equipped_icon := Control.new()
		equipped_icon.custom_minimum_size = Vector2(32, 32)
		equipped_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		equipped_icon.draw.connect(func(): Art.draw(equipped_icon, equipped_kind, Vector2(16, 16)))
		summary_row.add_child(equipped_icon)
	var equipped_name := UI.heading("No equipment equipped" if equipped_kind == "" else Relics.DEFINITIONS[equipped_kind].name, 18)
	equipped_name.name = "EquippedRelicName"
	equipped_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipped_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_row.add_child(equipped_name)
	if equipped_kind != "":
		var remove := UI.button("×", dialog.request_equipment_removal, 44)
		remove.name = "RemoveEquipment"
		remove.tooltip_text = "Remove equipment"
		remove.custom_minimum_size.x = 44
		remove.size_flags_horizontal = Control.SIZE_SHRINK_END
		summary_row.add_child(remove)
	dialog.body.add_child(UI.heading("Your equipment", 18))
	dialog.body.add_child(UI.paragraph("Choose equipment for this tower. Replaced equipment returns to your inventory.", 14))
	var group := ButtonGroup.new()
	for kind in Relics.DEFINITIONS:
		var definition: Dictionary = Relics.DEFINITIONS[kind]
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_theme_stylebox_override("panel", UI.surface(UI.SURFACE, 2, 10))
		dialog.body.add_child(card)
		var stack := UI.margin(card, 12)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		stack.add_child(row)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.draw.connect(func(): Art.draw(icon, kind, Vector2(16,16)))
		row.add_child(icon)
		var title := UI.heading(definition.name, 18)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		stack.add_child(UI.paragraph(Relics.description(kind, dialog.app.game.tuning), 14))
		var found := false
		for relic_id in data.get("relics", {}):
			if data.relics[relic_id] != kind:
				continue
			found = true
			var owner := Relics.owner(data, relic_id)
			var text: String = "Equipment available"
			if owner == dialog.tower_id:
				text = "Currently equipped"
			elif owner != "":
				text = "Transfer from " + Balance.tower_stats(data.towers[owner], dialog.app.game.tuning).name
			add_choice(dialog, group, relic_id, text, owner, stack)
		if not found:
			stack.add_child(UI.paragraph("Defeat " + Balance.BOSSES[kind].name + " to discover this relic.", 14))

static func add_choice(dialog, group: ButtonGroup, relic_id: String, text: String, owner: String, parent: Node = null) -> void:
	var button := UI.button(text, func():
		dialog.relic_choice = relic_id
		dialog.relic_owner = owner
	, 52)
	button.name = "Relic_" + ("empty" if relic_id == "" else relic_id)
	button.add_theme_font_size_override("font_size", UI.type_size(14))
	button.toggle_mode = true
	button.button_group = group
	button.add_theme_stylebox_override("pressed", UI.box(UI.GOLD))
	button.add_theme_stylebox_override("hover_pressed", UI.box(UI.GOLD))
	button.button_pressed = dialog.relic_choice == relic_id
	(parent if parent != null else dialog.body).add_child(UI.action_row(text, button, "Select"))
