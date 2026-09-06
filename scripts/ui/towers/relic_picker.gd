extends RefCounted

const UI = preload("res://scripts/ui/shared/interface.gd")
const Relics = preload("res://scripts/gameplay/progression/relics.gd")
const Art = preload("res://scripts/rendering/actors/relic_art.gd")

static func build(dialog) -> void:
	var data: Dictionary = dialog.app.game.data
	var equipped_kind := Relics.kind(data, data.towers[dialog.tower_id])
	dialog.equipment_summary.add_child(UI.label("Currently equipped", 14, UI.TEXT))
	var summary := PanelContainer.new()
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_theme_stylebox_override("panel", UI.surface(UI.SURFACE, 2, 10))
	dialog.equipment_summary.add_child(summary)
	var summary_stack := UI.margin(summary, 12)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 10)
	summary_stack.add_child(summary_row)
	if equipped_kind != "":
		var equipped_icon := Control.new()
		equipped_icon.custom_minimum_size = Vector2(32, 32)
		equipped_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		equipped_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		equipped_icon.draw.connect(func(): Art.draw(equipped_icon, equipped_kind, Vector2(16, 16)))
		summary_row.add_child(equipped_icon)
	var equipped_name := UI.heading("No equipment equipped" if equipped_kind == "" else Relics.DEFINITIONS[equipped_kind].name, 18)
	equipped_name.name = "EquippedRelicName"
	equipped_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipped_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipped_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	summary_row.add_child(equipped_name)
	if equipped_kind != "":
		var remove := UI.button("×", dialog.request_equipment_removal, 44)
		remove.name = "RemoveEquipment"
		remove.tooltip_text = "Remove equipment"
		remove.custom_minimum_size.x = 44
		remove.size_flags_horizontal = Control.SIZE_SHRINK_END
		remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		summary_row.add_child(remove)
	dialog.body.add_child(UI.heading("Inventory", 18))
	var grid := GridContainer.new()
	grid.name = "EquipmentGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	dialog.body.add_child(grid)
	var inventory: Dictionary = data.get("relics", {})
	for relic_id in inventory:
		var kind: String = inventory[relic_id]
		var button := UI.button("", func(): dialog.show_equipment_details(relic_id), 48)
		button.name = "Relic_" + relic_id
		button.tooltip_text = Relics.DEFINITIONS[kind].name
		button.accessibility_name = Relics.DEFINITIONS[kind].name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.draw.connect(func(): Art.draw(button, kind, button.size * 0.5))
		grid.add_child(button)
	for index in range(maxi(16, ceili(inventory.size() / 4.0) * 4) - inventory.size()):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(48, 48)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_stylebox_override("panel", UI.surface(UI.SURFACE, 2, 4))
		grid.add_child(slot)
