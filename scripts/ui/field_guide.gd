extends MarginContainer

signal close_requested

const UI = preload("res://scripts/ui/interface.gd")
const Catalog = preload("res://scripts/ui/info_catalog.gd")

var category := "towers"
var game: VigilState
var tabs: Dictionary = {}
var intro: Label
var hint: Label
var scroll: ScrollContainer
var cards: VBoxContainer

func _ready() -> void:
	for side in ["left", "top", "right", "bottom"]:
		add_theme_constant_override("margin_" + side, 16)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := UI.heading("Field guide", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UI.button("×", func(): close_requested.emit(), 48)
	close.name = "CloseGuide"
	close.tooltip_text = "Close field guide"
	close.accessibility_name = "Close field guide"
	close.custom_minimum_size.x = 48
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(close)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	layout.add_child(tab_row)
	var group := ButtonGroup.new()
	for id in Catalog.SECTIONS:
		var tab := UI.button(Catalog.SECTIONS[id].title, show_category.bind(id))
		tab.name = id.capitalize() + "Tab"
		tab.toggle_mode = true
		tab.button_group = group
		tab.add_theme_stylebox_override("pressed", UI.box(UI.GOLD))
		tab.add_theme_stylebox_override("hover_pressed", UI.box(UI.GOLD))
		tabs[id] = tab
		tab_row.add_child(tab)
	intro = UI.paragraph("")
	layout.add_child(intro)
	# Only cards scroll: navigation and close remain reachable as the catalog grows.
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.keyboard_scroll(scroll, "Field guide entries")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	cards = VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 12)
	scroll.add_child(cards)
	hint = UI.paragraph("", 12)
	layout.add_child(hint)
	show_category(category)

func show_category(id: String) -> void:
	if not Catalog.SECTIONS.has(id):
		return
	category = id
	for key in tabs:
		tabs[key].set_pressed_no_signal(key == category)
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	var entries := Catalog.entries(category, game.tuning if game != null else {})
	intro.text = "%d %s · %s" % [entries.size(), Catalog.SECTIONS[id].title.to_lower(), Catalog.SECTIONS[id].intro]
	hint.text = Catalog.SECTIONS[id].hint
	for entry in entries:
		cards.add_child(make_card(entry, category))
	scroll.scroll_vertical = 0

static func make_card(entry: Dictionary, section: String = "towers") -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.name = entry.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UI.content_box())
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	card.add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	body.add_child(header)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(48, 64)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(portrait)
	portrait.draw.connect(func():
		if section == "towers" and entry.id in ["rapid", "splash", "heavy"]:
			VigilTerrainArt.sentinel(portrait, entry.id, Vector2(22, 41), 0.9)
		elif section == "enemies" and entry.id in ["basic", "fast", "heavy"]:
			VigilTerrainArt.enemy(portrait, entry.id, Vector2(22, 30), 1.5)
		else:
			VigilTerrainArt.disk(portrait, Vector2(22, 28), 12, Color(entry.color), 3)
	)
	var identity := VBoxContainer.new()
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	var title := UI.heading(entry.name, 24)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", UI.TEXT)
	identity.add_child(title)
	if not entry.role.is_empty():
		identity.add_child(UI.paragraph(entry.role, 12))
	if not entry.description.is_empty():
		body.add_child(UI.paragraph(entry.description, 16))
	var grid := GridContainer.new()
	grid.columns = 2
	card.resized.connect(func(): grid.columns = 1 if card.size.x < 350 * UI.text_scale else 2)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for stat in entry.stats:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 4)
		grid.add_child(cell)
		cell.add_child(UI.paragraph(stat.label, 14))
		var value := UI.value(stat.value, 18)
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(value)
	return card
