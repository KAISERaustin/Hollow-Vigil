extends VBoxContainer
## Reusable feed body; the owning menu supplies scrolling and fixed actions.
const UI = preload("res://scripts/ui/shared/interface.gd")
var service: Node
var refresh_button: Button
var more_button: Button
var feedback: Label
var rows: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", UI.GAP)
	feedback = UI.paragraph("")
	feedback.name = "ChangeLogStatus"
	add_child(feedback)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", UI.CARD_GAP)
	add_child(rows)
	more_button = UI.button("Load older changes", func(): await service.load_page())
	more_button.name = "ChangeLogMore"
	add_child(more_button)
	service.changed.connect(refresh)
	refresh()

func refresh() -> void:
	refresh_button.disabled = service.busy
	more_button.disabled = service.busy
	more_button.visible = service.has_more
	feedback.text = service.status
	feedback.visible = not service.status.is_empty()
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for entry in service.entries:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", UI.CARD_GAP)
		column.add_child(UI.paragraph(entry.change_date, UI.META))
		column.add_child(UI.paragraph(entry.summary))
		rows.add_child(UI.info_card(column, UI.PANEL, UI.CARD_PADDING))
