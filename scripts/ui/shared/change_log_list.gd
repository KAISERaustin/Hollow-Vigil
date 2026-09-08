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
	rows.name = "ChangeLogSections"
	rows.add_theme_constant_override("separation", UI.GAP * 2)
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
	var sections := {}
	for entry in service.entries:
		var date: String = entry.change_date
		if not sections.has(date):
			var section := VBoxContainer.new()
			section.add_theme_constant_override("separation", UI.GAP)
			var title := UI.heading(date_title(date), 22)
			title.name = "ChangeDate"
			section.add_child(title)
			rows.add_child(section)
			sections[date] = section
		sections[date].add_child(bullet_row(entry.summary))

static func bullet_row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.CARD_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var bullet := UI.label("•", 18)
	bullet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(bullet)
	var copy := UI.paragraph(text, 18)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	return row

static func date_title(date: String) -> String:
	var parts := date.split("-")
	if parts.size() != 3: return date
	var month := int(parts[1])
	var day := int(parts[2])
	if month < 1 or month > 12 or day < 1 or day > 31: return date
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	var suffix := "th"
	if day % 100 not in [11, 12, 13]:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(day % 10, "th")
	var title := "%s %d%s" % [months[month - 1], day, suffix]
	if int(parts[0]) != int(Time.get_date_dict_from_system().year): title += ", " + parts[0]
	return title
