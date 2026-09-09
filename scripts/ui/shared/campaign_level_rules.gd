extends VBoxContainer
## A sparse per-level draft, using the content catalog's shared field definitions.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Fields = preload("res://scripts/content/catalogs/levels.gd")
signal route_changed(title: String, item_open: bool)
var group := ""
var snapshot := {}
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
	route_changed.emit("Levels", false)
	show()
	add_child(UI.heading("Levels", 24))
	for index in Configuration.Catalog.COUNT:
		var title := "Level %d · %s" % [index + 1, Configuration.Catalog.level(index).name]
		var open := UI.button("Open", show_level.bind(index))
		open.name = "EditLevel%d" % index
		add_child(UI.action_row(title, open, "Open", level_preview(index)))

func level_preview(index: int) -> Control:
	var chapter: Dictionary = Configuration.Catalog.CHAPTERS[index / Configuration.Catalog.LEVELS_PER_CHAPTER]
	if chapter.has("map_art"):
		var picture := TextureRect.new()
		picture.texture = chapter.map_art
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(64, 64)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return picture
	return preload("res://scripts/ui/shared/content_portrait.gd").preview("rifts", chapter.style)

func show_level(index: int) -> void:
	snapshot = changes.duplicate(true)
	selected = index
	show_item()

func cancel_item() -> void:
	clear_body()
	changes = snapshot.duplicate(true)
	show_levels()

func navigate_back() -> void:
	if group.is_empty(): cancel_item()
	else: show_item()

func show_item() -> void:
	clear_body()
	group = ""
	var title := "Level %d · %s" % [selected + 1, Configuration.Catalog.level(selected).name]
	add_child(UI.heading(title, 24))
	add_child(level_preview(selected))
	add_child(UI.button("Reset", func():
		var defaults := Configuration.resolve(selected, {})
		changes[str(selected)] = {}
		for key in Fields.CONFIGURATION_FIELDS: changes[str(selected)][key] = defaults[key]
	))
	for label in ["Stats", "Abilities", "Attributes"]:
		add_child(UI.button(label, open_group.bind(label)))
	route_changed.emit(title, true)

func open_group(label: String) -> void:
	group = label
	if label == "Stats": show_stats(selected)
	else:
		clear_body()
		add_child(UI.paragraph("No editable " + label.to_lower() + " for this level."))
	route_changed.emit(label + " · Level " + str(selected + 1), true)

func show_stats(index: int) -> void:
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
