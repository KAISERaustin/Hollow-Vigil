extends VBoxContainer
## One checklist for both modes; never mutates the source game or shared definitions.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Build = preload("res://scripts/persistence/reusable_build.gd")
signal changed
var game_type := "infinite"
var selection := {}

func _ready() -> void:
	name = "ContentsChecklist"
	add_theme_constant_override("separation", UI.GAP)
	selection = Build.grouped_contents(game_type, selection)
	rebuild()

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for key in Build.GROUPS.OPTIONS:
		var option: Dictionary = Build.GROUPS.OPTIONS[key]
		var members := Build.all_contents(game_type, key)
		if members.is_empty(): continue
		var title: String = option.get(game_type + "_name", option.name)
		var choice := check_box(title, selection.has_all(members.keys()), func(enabled: bool):
			if enabled: selection.merge(members.duplicate(true), true)
			else:
				for member in members: selection.erase(member)
			changed.emit()
		)
		choice.name = "Contents_" + key
		add_child(choice)
		add_child(UI.paragraph(option.get(game_type + "_description", option.description)))

static func check_box(title: String, checked: bool, callback: Callable) -> CheckBox:
	var choice := CheckBox.new()
	choice.text = title
	choice.accessibility_name = title
	choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice.custom_minimum_size.y = UI.TARGET
	choice.button_pressed = checked
	choice.toggled.connect(callback)
	return choice
