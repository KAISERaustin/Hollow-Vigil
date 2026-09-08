extends VBoxContainer
## A sparse per-level draft, using the content catalog's shared field definitions.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Fields = preload("res://scripts/content/catalogs/levels.gd")
var setup: Callable
var changes := {}
var selected := -1
var numbers: Array[SpinBox] = []

func _ready() -> void:
	add_theme_constant_override("separation", 12)

func clear_body() -> void:
	commit_fields()
	numbers.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()

func show_levels() -> void:
	clear_body()
	selected = -1
	show()
	add_child(UI.heading("Levels", 24))
	for index in Configuration.Catalog.COUNT:
		var title := "Level %d · %s" % [index + 1, Configuration.Catalog.level(index).name]
		var open := UI.button("Open", show_level.bind(index))
		open.name = "EditLevel%d" % index
		add_child(UI.action_row(title, open, "Open"))

func show_level(index: int) -> void:
	clear_body()
	selected = index
	var rules: Dictionary = setup.call(index).overrides.duplicate(true)
	rules.merge(changes.get(str(index), {}), true)
	var mission := Configuration.resolve(index, rules)
	add_child(UI.heading("Level %d · %s" % [index + 1, mission.name], 24))
	add_child(UI.paragraph("Starting gold and lives apply when starting this level. Before the first wave, they also update your current attempt. Enemies reaching the end cost lives; zero lives ends the attempt."))
	for key in Fields.CONFIGURATION_FIELDS:
		var limits: Dictionary = Fields.CONFIGURATION_FIELDS[key]
		var number := SpinBox.new()
		number.name = "LevelRule_" + key
		number.min_value = limits.min
		number.max_value = limits.max
		number.step = limits.step
		number.value = mission[key]
		number.value_changed.connect(func(value: float):
			if not changes.has(str(index)): changes[str(index)] = {}
			changes[str(index)][key] = value
		)
		numbers.append(number)
		add_child(UI.number_row("Level lives" if key == "flame" else limits.label, number))
	add_child(UI.paragraph("Gold per cleared wave is the default reward. Individual rewards and enemy spawns can be edited in Waves."))

func commit_fields() -> void:
	for number in numbers: number.apply()
