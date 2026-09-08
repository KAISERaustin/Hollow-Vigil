extends Control

const Catalog = preload("res://scripts/campaign/catalog.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const MapArt = preload("res://scripts/ui/shared/biome_map_art.gd")
const Marker = preload("res://scripts/campaign/level_marker.gd")
const Content = preload("res://scripts/content/registry.gd")
const CHAPTER_HEIGHT := 960.0
const BAKE_WIDTH := 540.0
const FIRST_LEVEL_Y := 176.0
const LEVEL_SPACING := 164.0
const CHAPTER_NUMERALS := ["I", "II", "III", "IV", "V", "VI"]
signal level_picked(index: int)
var progress: RefCounted
var nodes: Array[Button] = []
var labels: Array[VBoxContainer] = []
var headings: Array[VBoxContainer] = []
var backgrounds: Array[Texture2D] = []

func _ready() -> void:
	name = "CampaignWorldMap"
	custom_minimum_size = Vector2(280, Catalog.CHAPTERS.size() * CHAPTER_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	for chapter in Catalog.CHAPTERS.size():
		backgrounds.append(chapter_presentation(chapter).get("background"))
		var heading := VBoxContainer.new()
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.add_theme_constant_override("separation", 4)
		heading.add_child(UI.label("CHAPTER " + CHAPTER_NUMERALS[chapter], UI.META, UI.TEXT))
		heading.add_child(UI.heading(Catalog.CHAPTERS[chapter].name, 24))
		var story := UI.label(Catalog.CHAPTERS[chapter].story, UI.META, UI.TEXT)
		story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.add_child(story)
		add_child(heading)
		headings.append(heading)
	for index in range(Catalog.COUNT):
		var button := Marker.new()
		button.number = index + 1
		button.completed = progress.level_completed(index)
		button.current = progress.unlocked(index) and index == progress.current_level()
		button.landscape_profile = chapter_presentation(int(index/5.0))
		var landmarks: Array = button.landscape_profile.get("landmarks",[])
		if index%5<4 and index%5<landmarks.size(): button.landmark_kind = landmarks[index%5]
		if index % 5 == 4:
			button.gate = Catalog.CHAPTERS[int(index / 5.0)].get("gate_art")
			button.gate_style = Catalog.CHAPTERS[int(index / 5.0)].style
		button.pressed.connect(func(): level_picked.emit(index))
		button.name = "CampaignLevel%d" % (index + 1)
		button.disabled = not progress.unlocked(index)
		button.accessibility_name = "Level %d: %s. %s" % [index + 1, Catalog.MISSIONS[index].name, "Current level" if button.current else ("Locked" if button.disabled else ("Completed" if button.completed else "Ready"))]
		add_child(button)
		nodes.append(button)
		var identity := VBoxContainer.new()
		identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		identity.add_theme_constant_override("separation", 4)
		var title := UI.heading(Catalog.MISSIONS[index].name, 14)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		identity.add_child(title)
		var detail := "Current" if button.current else ("Cleared · Lit" if button.completed else ("Locked" if button.disabled else "Ready"))
		if index % 5 == 4: detail += " · Boss"
		identity.add_child(UI.label(detail, UI.META, UI.TEXT))
		add_child(identity)
		labels.append(identity)
	resized.connect(arrange)
	for group in headings + labels:
		group.minimum_size_changed.connect(arrange)
	arrange()

func chapter_rect(chapter: int) -> Rect2:
	return Rect2(0, chapter * CHAPTER_HEIGHT, size.x, CHAPTER_HEIGHT)

func point(index: int) -> Vector2:
	var chapter := int(index / 5.0)
	var within := index % 5
	var x: float = [0.22, 0.74, 0.26, 0.70, 0.77][within]
	# A reversed middle bend gives neighboring biomes their own trail rhythm.
	if chapter % 2 == 1 and within < 4: x = 1.0 - x
	return Vector2(size.x * x, chapter * CHAPTER_HEIGHT + FIRST_LEVEL_Y + within * LEVEL_SPACING)

func arrange() -> void:
	for chapter in headings.size():
		headings[chapter].position = Vector2(UI.PADDING, chapter * CHAPTER_HEIGHT + 20)
		headings[chapter].size = Vector2(size.x - UI.PADDING * 2 - 28, 110)
	for index in range(nodes.size()):
		var boss := index % 5 == 4
		nodes[index].size = Vector2(80,120) if boss else Vector2(88,106)
		nodes[index].position = point(index) - nodes[index].size * 0.5
		var right := point(index).x < size.x * 0.5
		var start := point(index).x + 50 if right else float(UI.PADDING)
		var width := size.x - start - UI.PADDING if right else point(index).x - UI.PADDING - 50
		labels[index].position = Vector2(start, point(index).y - 22)
		labels[index].size = Vector2(width, 58)
		for label: Label in labels[index].get_children():
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if right else HORIZONTAL_ALIGNMENT_RIGHT
	queue_redraw()

func chapter_presentation(chapter: int) -> Dictionary:
	for attachment in Content.catalog().get_node("level/chapter/"+str(chapter)).rule("components",[]):
		if attachment.slot=="map_landscape": return attachment.component.presentation(attachment.config)
	return {}

func chapter_reserved(chapter: int) -> Array[Rect2]:
	# Offline baking and rendered clearance checks only; not used by arrange().
	var reserved: Array[Rect2] = [headings[chapter].get_rect()]
	for index in range(chapter*5,chapter*5+5):
		reserved.append(nodes[index].get_rect().grow(4))
		for label: Label in labels[index].get_children():
			var text_width := label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
			var rect := Rect2(labels[index].position+label.position,Vector2(minf(text_width,label.size.x),label.size.y))
			if label.horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT: rect.position.x+=label.size.x-rect.size.x
			reserved.append(rect)
	return reserved

func chapter_roads(chapter: int) -> Array[PackedVector2Array]:
	# Offline source geometry, scaled exactly like the image for validation.
	var roads: Array[PackedVector2Array] = []
	var first := chapter * 5
	var top := chapter * CHAPTER_HEIGHT
	var scale_x := size.x / BAKE_WIDTH
	if chapter > 0:
		var entrance := PackedVector2Array([Vector2(size.x - 16 * scale_x, top), Vector2(size.x - 16 * scale_x, top + 128)])
		var approach := Vector2(point(first).x + 48 * scale_x, top + 142)
		entrance.append_array(MapArt.curve(entrance[-1], approach, Vector2(size.x - 16 * scale_x, top + 142), approach + Vector2(24 * scale_x, 0)))
		entrance.append_array(MapArt.curve(approach, point(first), approach - Vector2(48 * scale_x, 0), point(first) - Vector2(0, 28)))
		roads.append(entrance)
	for index in range(first + 1, first + 5):
		roads.append(MapArt.between_markers(point(index - 1), point(index)))
	if chapter < Catalog.CHAPTERS.size() - 1:
		roads.append(MapArt.curve(point(first + 4), Vector2(size.x - 16 * scale_x, top + CHAPTER_HEIGHT)))
	return roads

func _draw() -> void:
	for chapter in backgrounds.size():
		var texture := backgrounds[chapter]
		if texture == null: continue
		var bounds := chapter_rect(chapter)
		var within := int(progress.data.completed_levels) - chapter * 5
		if within >= 5:
			draw_texture_rect_region(texture, bounds, Rect2(0, CHAPTER_HEIGHT, BAKE_WIDTH, CHAPTER_HEIGHT))
			continue
		draw_texture_rect_region(texture, bounds, Rect2(0, 0, BAKE_WIDTH, CHAPTER_HEIGHT))
		if progress.data.completed_levels < chapter * 5: continue
		# The lower half contains the same artwork with completed roads. Reveal
		# it through the current marker; scenery and bridge pixels are identical.
		var height := FIRST_LEVEL_Y + within * LEVEL_SPACING
		draw_texture_rect_region(texture, Rect2(bounds.position, Vector2(size.x, height)), Rect2(0, CHAPTER_HEIGHT, BAKE_WIDTH, height))
