extends Control

const Catalog = preload("res://scripts/campaign/catalog.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const Marker = preload("res://scripts/campaign/level_marker.gd")
signal level_picked(index: int)
var progress: RefCounted
var nodes: Array[Button] = []

func _ready() -> void:
	custom_minimum_size = Vector2(280, 1810)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in range(Catalog.COUNT):
		var button := Marker.new()
		button.number = index + 1
		button.completed = index < progress.data.completed_levels
		if index % 5 == 4:
			button.gate = Catalog.CHAPTERS[int(index / 5.0)].gate_art
		button.pressed.connect(func(): level_picked.emit(index))
		button.name = "CampaignLevel%d" % (index + 1)
		button.disabled = not progress.unlocked(index)
		button.accessibility_name = "Level %d: %s. %s" % [index + 1, Catalog.MISSIONS[index].name, "Locked" if button.disabled else ("Completed" if index < progress.data.completed_levels else "Ready")]
		add_child(button)
		nodes.append(button)
	resized.connect(arrange)
	arrange()

func point(index: int) -> Vector2:
	var chapter := int(index / 5.0)
	var within := index % 5
	var x := [0.22, 0.42, 0.70, 0.30, 0.80][within] as float
	return Vector2(size.x * x, chapter * 450 + (370 if within == 4 else 115 + within * 70))

func arrange() -> void:
	for index in range(nodes.size()):
		nodes[index].size = Vector2(80,120) if index % 5 == 4 else Vector2(54,54)
		nodes[index].position = point(index) - nodes[index].size * 0.5
	queue_redraw()

func _draw() -> void:
	for chapter in range(4):
		var top := chapter * 450.0
		var palette := Art.ground_color(Catalog.CHAPTERS[chapter].style)
		var panel := Rect2(0, top, size.x, 435)
		draw_style_box(UI.surface(palette.lightened(0.1), 2, 22), panel)
		# Chapter artwork shares the authored map coordinates; keep the frame
		# visible and draw all navigation and labels over the background.
		var background: Texture2D = Catalog.CHAPTERS[chapter].get("map_art")
		if background != null:
			draw_texture_rect(background, panel.grow(-2), false)
		draw_string(UI.font(600), Vector2(16, top + 28), "CHAPTER %s" % ["I", "II", "III", "IV"][chapter], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.MUTED)
		draw_string(UI.font(600,true), Vector2(16, top + 55), Catalog.CHAPTERS[chapter].name, HORIZONTAL_ALIGNMENT_LEFT, size.x-24, 20, UI.TEXT)
		for i in range(5):
			var index := chapter * 5 + i
			var at := point(index)
			if index > 0:
				var previous := point(index-1)
				var color := UI.GOLD if index <= progress.data.completed_levels else palette.darkened(0.3)
				var road := PackedVector2Array([previous, Vector2(previous.x, (previous.y+at.y)*0.5), Vector2(at.x,(previous.y+at.y)*0.5), at])
				if i == 0:
					# Pass around the chapter heading, leaving its text unobstructed.
					road = PackedVector2Array([previous, Vector2(previous.x,previous.y+32), Vector2(size.x-10,previous.y+32), Vector2(size.x-10,at.y-34), Vector2(at.x,at.y-34), at])
				draw_polyline(road, color, 5, true)
			var right := at.x < size.x*0.5
			var origin := Vector2(at.x+34 if right else 12.0, at.y-4)
			if i == 4:
				origin = Vector2(16, top + 391)
			var width := size.x-origin.x-10 if right else at.x-46
			var title: String = Catalog.MISSIONS[index].name
			draw_string(UI.font(600), origin, title, HORIZONTAL_ALIGNMENT_LEFT, width, 12, UI.TEXT if progress.unlocked(index) else UI.MUTED)
			var completed: bool = index < progress.data.completed_levels
			var detail := "Cleared · Lit" if completed else ("BOSS" if i == 4 else ("Ready" if progress.unlocked(index) else "Locked"))
			draw_string(UI.font(400), origin+Vector2(0,20), detail, HORIZONTAL_ALIGNMENT_LEFT, width, 11, UI.TEXT if completed else UI.MUTED)
