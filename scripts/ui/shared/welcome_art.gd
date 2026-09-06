extends Control

# Reusable, stateless presentation composed from the live game's art library.
# No simulated world or save state is created by a menu illustration.
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
@export_enum("crest", "battlefield") var illustration := "crest"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var zoom := minf(size.x / 400.0, size.y / 200.0)
	draw_set_transform(size * 0.5, 0, Vector2.ONE * zoom)
	if illustration == "crest":
		# A portal seal between two sentinels: the game's central promise.
		draw_line(Vector2(-174, 30), Vector2(174, 30), Art.INK, 3)
		Art.polygon(self, PackedVector2Array([Vector2(-86,-54), Vector2(86,-54), Vector2(74,40), Vector2(0,78), Vector2(-74,40)]), Art.GOLD, 4)
		Art.portal(self, Vector2(0, 4), 0.85, true)
		Art.sentinel(self, "rapid", Vector2(-127, 28), 1.25, 2)
		Art.sentinel(self, "heavy", Vector2(127, 28), 1.25, 2)
		for x in [-172, 172]:
			Art.polygon(self, PackedVector2Array([Vector2(x, -8),Vector2(x+7,0),Vector2(x,8),Vector2(x-7,0)]), Art.GOLD)
	else:
		# An authored vignette uses the same silhouettes and plus sockets as play.
		Art.polygon(self, PackedVector2Array([Vector2(-194,-62),Vector2(-80,-91),Vector2(38,-70) ,Vector2(182,-83),Vector2(194,57),Vector2(70,91),Vector2(-54,72),Vector2(-188,84)]), Art.ground_color("forest"), 3)
		var road := PackedVector2Array([Vector2(-187,40),Vector2(-115,40),Vector2(-115,-3),Vector2(90,-3),Vector2(90,46),Vector2(181,46)])
		draw_polyline(road, Art.INK, 25, true)
		draw_polyline(road, Art.ROAD, 20, true)
		for item in [["rapid",Vector2(-65, -25)],["splash",Vector2(7, 55)],["heavy",Vector2(135,-30)]]:
			draw_set_transform(size * 0.5 + item[1] * zoom, 0, Vector2.ONE * zoom * 0.7)
			Art.socket(self, Vector2.ZERO)
			Art.sentinel(self, item[0], Vector2.ZERO, 1.4, 2)
		draw_set_transform(size * 0.5, 0, Vector2.ONE * zoom)
		Art.portal(self, Vector2(-163, 24), 0.55, false)
		Art.portal(self, Vector2(174, 37), 0.55, true)
		Art.enemy(self, "basic", Vector2(-99,-2), 0.85)
		Art.enemy(self, "fast", Vector2(-22,-3), 0.85)
		Art.enemy(self, "heavy", Vector2(60,-3), 0.85)
		Art.scenery(self, "forest", Vector2(-143,-43), 35)
		Art.scenery(self, "drowned_crypt", Vector2(61,59), 32)
		Art.scenery(self, "forest", Vector2(-87,63), 28)
