extends Control

const Catalog = preload("res://scripts/campaign/catalog.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
signal level_picked(index: int)
var progress: RefCounted
var nodes: Array[Button] = []

func _ready() -> void:
	custom_minimum_size = Vector2(280, 1810)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in range(Catalog.COUNT):
		var button := UI.button(str(index + 1), func(): level_picked.emit(index), 48)
		button.name = "CampaignLevel%d" % (index + 1)
		button.disabled = not progress.unlocked(index)
		button.accessibility_name = "Level %d: %s. %s" % [index + 1, Catalog.MISSIONS[index].name, "Locked" if button.disabled else "%d of 3 medals" % progress.data.medals[index]]
		add_child(button)
		nodes.append(button)
	resized.connect(arrange)
	arrange()

func point(index: int) -> Vector2:
	var chapter := index / 5
	var within := index % 5
	var x := [0.22, 0.38, 0.70, 0.58, 0.25][within] as float
	return Vector2(size.x * x, chapter * 450 + 115 + within * 70)

func arrange() -> void:
	for index in range(nodes.size()):
		nodes[index].size = Vector2(48,48)
		nodes[index].position = point(index) - Vector2(24,24)
	queue_redraw()

func _draw() -> void:
	for chapter in range(4):
		var top := chapter * 450.0
		var palette := Art.ground_color(Catalog.CHAPTERS[chapter].style)
		draw_style_box(UI.surface(palette.lightened(0.1), 2, 22), Rect2(0, top, size.x, 435))
		draw_string(UI.font(600), Vector2(16, top + 28), "CHAPTER %s" % ["I", "II", "III", "IV"][chapter], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.MUTED)
		draw_string(UI.font(600,true), Vector2(16, top + 55), Catalog.CHAPTERS[chapter].name, HORIZONTAL_ALIGNMENT_LEFT, size.x-24, 20, UI.TEXT)
		for i in range(5):
			var index := chapter * 5 + i
			var at := point(index)
			if index > 0:
				var previous := point(index-1)
				var color := UI.GOLD if progress.data.medals[index-1] > 0 else palette.darkened(0.3)
				var road := PackedVector2Array([previous, Vector2(previous.x, (previous.y+at.y)*0.5), Vector2(at.x,(previous.y+at.y)*0.5), at])
				if i == 0:
					# Pass around the chapter heading, leaving its text unobstructed.
					road = PackedVector2Array([previous, Vector2(previous.x,previous.y+32), Vector2(size.x-10,previous.y+32), Vector2(size.x-10,at.y-34), Vector2(at.x,at.y-34), at])
				draw_polyline(road, color, 5, true)
			if progress.data.medals[index] > 0:
				draw_circle(at, 31, Color(0.88,0.71,0.4,0.15))
			var right := at.x < size.x*0.5
			var origin := Vector2(at.x+34 if right else 12, at.y-4)
			var width := size.x-origin.x-10 if right else at.x-46
			var title: String = Catalog.MISSIONS[index].name
			draw_string(UI.font(600), origin, title, HORIZONTAL_ALIGNMENT_LEFT, width, 12, UI.TEXT if progress.unlocked(index) else UI.MUTED)
			var medals := int(progress.data.medals[index])
			var detail := "●".repeat(medals) + "○".repeat(3-medals) if medals > 0 else ("BOSS" if i == 4 else ("Ready" if progress.unlocked(index) else "Locked"))
			draw_string(UI.font(400), origin+Vector2(0,20), detail, HORIZONTAL_ALIGNMENT_LEFT, width, 11, UI.GOLD if medals > 0 else UI.MUTED)
