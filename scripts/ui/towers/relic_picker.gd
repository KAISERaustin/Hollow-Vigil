extends RefCounted

const UI = preload("res://scripts/ui/shared/interface.gd")
const Relics = preload("res://scripts/gameplay/progression/relics.gd")
const Art = preload("res://scripts/rendering/actors/relic_art.gd")

static func build(dialog) -> void:
	var data: Dictionary = dialog.app.game.data
	var equipped_kind := Relics.kind(data, data.towers[dialog.tower_id])
	dialog.equipment_summary.add_child(UI.heading("Currently equipped", 18))
	dialog.equipment_summary.add_theme_constant_override("separation", 8)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 8)
	dialog.equipment_summary.add_child(summary_row)
	if equipped_kind != "":
		var equipped_icon := Control.new()
		equipped_icon.custom_minimum_size = Vector2(32, 32)
		equipped_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		equipped_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		equipped_icon.draw.connect(func(): Art.draw(equipped_icon, equipped_kind, Vector2(16, 16)))
		summary_row.add_child(equipped_icon)
	var equipped_name := UI.label("No equipment equipped", 16) if equipped_kind == "" else UI.heading(Relics.DEFINITIONS[equipped_kind].name, 18)
	equipped_name.name = "EquippedRelicName"
	equipped_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipped_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipped_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	summary_row.add_child(equipped_name)
	if equipped_kind != "":
		var remove := UI.button("×", dialog.request_equipment_removal, 44)
		remove.name = "RemoveEquipment"
		remove.accessibility_description = "Remove equipment"
		remove.custom_minimum_size.x = 44
		remove.size_flags_horizontal = Control.SIZE_SHRINK_END
		remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		summary_row.add_child(remove)
	dialog.equipment_summary.add_child(UI.rule())
	dialog.body.add_child(UI.heading("Inventory", 18))
	var list := VBoxContainer.new()
	list.name = "EquipmentList"
	list.add_theme_constant_override("separation", 12)
	dialog.body.add_child(list)
	var inventory: Dictionary = data.get("relics", {})
	if inventory.is_empty():
		dialog.body.add_child(UI.paragraph("No equipment collected yet.", 14))
	for relic_id in inventory:
		var kind: String = inventory[relic_id]
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 8)
		list.add_child(entry)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		entry.add_child(row)
		var item_name := UI.heading(Relics.DEFINITIONS[kind].name, 16)
		item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(item_name)
		var button := UI.button("", func(): dialog.show_equipment_details(relic_id), UI.TARGET)
		button.custom_minimum_size = Vector2(UI.TARGET, UI.TARGET)
		button.name = "Relic_" + relic_id
		button.accessibility_description = Relics.DEFINITIONS[kind].name
		button.accessibility_name = Relics.DEFINITIONS[kind].name
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.draw.connect(func(): Art.draw(button, kind, button.size * 0.5))
		row.add_child(button)
		entry.add_child(UI.rule())
