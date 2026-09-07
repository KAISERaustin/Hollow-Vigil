extends VBoxContainer
## One checklist for both modes; never mutates the source game or shared definitions.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Build = preload("res://scripts/persistence/reusable_build.gd")
signal changed
var game_type := "infinite"
var selection := {}
var expanded := {}

func _ready() -> void:
	name = "ContentsChecklist"
	add_theme_constant_override("separation", UI.GAP)
	rebuild()

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var all_selected := true
	for group in Build.groups(game_type):
		var key: String = group.id.get_slice("/", 1)
		if key in Build.STAT_GROUPS:
			all_selected = all_selected and selection.get(key, []).size() == group.types().size()
		else: all_selected = all_selected and selection.get(key, false)
	var select_all := check_box("Select all", all_selected, func(enabled: bool):
		selection = Build.all_contents(game_type) if enabled else {}
		changed.emit()
		rebuild()
	)
	select_all.name = "SelectAllContents"
	add_child(select_all)
	add_child(UI.heading("Stats", 18))
	for group in Build.groups(game_type):
		var key: String = group.id.get_slice("/", 1)
		if key not in Build.STAT_GROUPS:
			var choice := check_box(group.attribute("name"), selection.get(key, false), func(enabled: bool):
				if enabled: selection[key] = true
				else: selection.erase(key)
				changed.emit()
				rebuild()
			)
			choice.name = "Contents_" + key
			add_child(choice)
			add_child(UI.paragraph(group.attribute("description")))
			continue
		var kinds: Array = group.types()
		var picked: Array = selection.get(key, [])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UI.GAP)
		add_child(row)
		var title: String = group.attribute("name")
		var check := check_box(title, picked.size() == kinds.size(), func(enabled: bool):
			if enabled: selection[key] = kinds.duplicate()
			else: selection.erase(key)
			changed.emit()
			rebuild()
		)
		check.name = "Contents_" + key
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(check)
		var expand := UI.button("Hide" if expanded.get(key, false) else "Types", func():
			expanded[key] = not expanded.get(key, false)
			rebuild()
		)
		expand.name = "ExpandContents_" + key
		expand.accessibility_name = "Show individual " + title.to_lower() + " types"
		expand.custom_minimum_size.x = 80
		expand.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(expand)
		add_child(UI.paragraph("%d of %d types selected. %s" % [picked.size(), kinds.size(), group.attribute("description")]))
		if expanded.get(key, false):
			for kind in kinds:
				var choice := check_box(Balance.definitions(key)[kind].name, kind in picked, func(enabled: bool):
					var next: Array = selection.get(key, []).duplicate()
					if enabled and kind not in next: next.append(kind)
					elif not enabled: next.erase(kind)
					if next.is_empty(): selection.erase(key)
					else: selection[key] = next
					changed.emit()
					rebuild()
				)
				choice.name = "Contents_" + key + "_" + kind
				add_child(choice)

static func check_box(title: String, checked: bool, callback: Callable) -> CheckBox:
	var choice := CheckBox.new()
	choice.text = title
	choice.accessibility_name = title
	choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice.custom_minimum_size.y = UI.TARGET
	choice.button_pressed = checked
	choice.toggled.connect(callback)
	return choice
