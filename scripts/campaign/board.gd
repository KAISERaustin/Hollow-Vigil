extends Control

const Catalog = preload("res://scripts/campaign/catalog.gd")
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const EnemyArt = preload("res://scripts/rendering/actors/enemy_art.gd")
const BossArt = preload("res://scripts/rendering/actors/boss_art.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")
signal socket_picked(socket: int)
var run: RefCounted
var selected := -1
var interactive := true
var view_zoom := 1.0
var pan := Vector2.ZERO
var press := Vector2.ZERO
var previous := Vector2.ZERO
var dragging := false
var moved := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	accessibility_name = "Campaign battlefield. Tap a stone socket to build or manage a tower. Drag to pan; scroll to zoom."

func scale_factor() -> float:
	return minf(size.x / Catalog.BOARD.size.x, size.y / Catalog.BOARD.size.y) * view_zoom

func screen(point: Vector2) -> Vector2:
	return size * 0.5 + (point - Catalog.BOARD.get_center()) * scale_factor() + pan

func set_zoom(value: float) -> void:
	view_zoom = clampf(value, 1.0, 2.5)
	if view_zoom == 1.0:
		pan = Vector2.ZERO
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not interactive or run == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(view_zoom + 0.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(view_zoom - 0.15)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press = event.position
				previous = press
				dragging = true
				moved = false
			else:
				if dragging and not moved:
					pick(event.position)
				dragging = false
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		if press.distance_to(event.position) > 8:
			moved = true
		if moved and view_zoom > 1.0:
			pan += event.position - previous
			pan = pan.clamp(-size * (view_zoom - 1) * 0.5, size * (view_zoom - 1) * 0.5)
		previous = event.position
		queue_redraw()
		accept_event()

func pick(point: Vector2) -> void:
	var nearest := -1
	var distance := 26.0
	for socket in run.mission.sockets:
		var candidate := point.distance_to(screen(socket.position))
		if candidate < distance:
			distance = candidate
			nearest = socket.index
	if nearest >= 0:
		selected = nearest
		socket_picked.emit(nearest)
		queue_redraw()

func _draw() -> void:
	if run == null:
		return
	var mission: Dictionary = run.mission
	var z := scale_factor()
	var ground := Art.ground_color(mission.style)
	draw_rect(Rect2(Vector2.ZERO, size), ground.darkened(0.55))
	draw_style_box(UI.surface(ground.darkened(0.15), 2, 20), Rect2(screen(Catalog.BOARD.position), Catalog.BOARD.size * z))
	# Stable scenery is decorative; it never changes a road or build socket.
	for i in range(28):
		var at := Vector2(-285 + (i * 173 + mission.index * 31) % 570, -635 + (i * 113) % 750)
		var clear := true
		for route in mission.routes:
			for segment in range(1, route.size()):
				if at.distance_to(Geometry2D.get_closest_point_to_segment(at, route[segment - 1], route[segment])) < 45:
					clear = false
		for socket in mission.sockets:
			if at.distance_to(socket.position) < 55:
				clear = false
		if clear:
			Art.scenery(self, mission.style, screen(at), 27 * z)
	for route in mission.routes:
		var points := PackedVector2Array()
		for point in route:
			points.append(screen(point))
		draw_polyline(points, Art.INK, 37 * z, true)
		draw_polyline(points, Art.ROAD, 30 * z, true)
		for point in points:
			draw_circle(point, 15 * z, Art.ROAD)
		# Direction arrows make crossing roads and final approach unambiguous.
		for segment in range(1, route.size()):
			var vector: Vector2 = route[segment] - route[segment - 1]
			if vector.length() < 100:
				continue
			var middle := screen((route[segment] + route[segment - 1]) * 0.5)
			var direction := vector.normalized()
			var side := Vector2(-direction.y, direction.x)
			draw_polyline(PackedVector2Array([middle - direction * 7 * z + side * 6 * z, middle + direction * 3 * z, middle - direction * 7 * z - side * 6 * z]), Color("927f63"), maxf(1.2, 2 * z), true)
	if selected >= 0 and selected in mission.pads:
		var id: String = run.tower_at(selected)
		if not id.is_empty():
			var tower: Dictionary = run.game.data.towers[id]
			var radius: float = Balance.tower_stats(tower).range * z
			var at := screen(Catalog.socket(selected).position)
			draw_circle(at, radius, Color(1, 0.9, 0.5, 0.1))
			draw_arc(at, radius, 0, TAU, 64, UI.GOLD, 1.4, true)
	for socket in mission.sockets:
		var at := screen(socket.position)
		var id: String = run.tower_at(socket.index)
		draw_circle(at, maxf(12, 24 * z), Art.INK)
		draw_circle(at, maxf(10, 21 * z), Art.PAPER if socket.index != selected else Art.GOLD)
		if id.is_empty():
			draw_line(at - Vector2(5, 0), at + Vector2(5, 0), Color("776b56"), 1.5)
			draw_line(at - Vector2(0, 5), at + Vector2(0, 5), Color("776b56"), 1.5)
		else:
			var tower: Dictionary = run.game.data.towers[id]
			Art.sentinel(self, tower.kind, at, maxf(0.55, z), int(tower.level), tower.get("branch", ""))
	for lane in range(mission.routes.size()):
		var at := screen(mission.routes[lane][0])
		Art.portal(self, at, maxf(0.5, z * 0.9), false)
		draw_string(UI.font(600), at + Vector2(-5, -24 * maxf(0.6,z)), String.chr(65 + lane), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Art.PAPER)
	var home := screen(Catalog.CORE)
	Art.portal(self, home, maxf(0.65, z), true)
	for enemy in run.game.combat.enemies:
		if enemy.dead:
			continue
		var at := screen(enemy.pos)
		if enemy.get("boss", false):
			BossArt.draw(self, enemy, at, maxf(0.75,z))
		else:
			EnemyArt.draw(self, enemy.kind, at, maxf(0.6,z))
			if enemy.hp < enemy.max_hp:
				draw_line(at + Vector2(-10,-17), at + Vector2(10,-17), Art.INK, 4)
				draw_line(at + Vector2(-10,-17), at + Vector2(-10 + 20 * enemy.hp / enemy.max_hp,-17), Art.CORAL, 2)
	for fx in run.game.combat.effects:
		if fx.kind == "shot" and fx.has("from"):
			var elapsed: float = fx.max_life - fx.life
			var fraction := clampf(elapsed / maxf(0.001,fx.get("flight",0.0)),0,1)
			var at: Vector2 = fx.from.lerp(fx.pos,fraction)
			if fx.get("tower_kind", "") == "electric":
				draw_line(screen(fx.from), screen(fx.pos), Color(fx.get("color", "e0b568")), maxf(1.5, 3*z), true)
			else:
				draw_circle(screen(at), maxf(2,4*z), Color(fx.get("color","e0b568")))
		elif fx.kind in ["death", "escape"]:
			var color := Color(fx.color)
			color.a = fx.life / fx.max_life
			draw_arc(screen(fx.pos), (1.0 - fx.life / fx.max_life) * 24 * z, 0, TAU, 20, color, 2, true)
	for shot in run.game.combat.pending_shots:
		if shot.has("pos"):
			draw_circle(screen(shot.pos), maxf(2, 5*z), Art.GOLD)
