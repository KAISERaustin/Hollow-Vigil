class_name Battlefield
extends Control

const RegionQuery = preload("res://scripts/rendering/terrain/region_query.gd")

const AttackEffects = preload("res://scripts/rendering/effects/attack_effects.gd")

signal picked(region: String, pad: int)
signal relocation_picked(region: String, pad: int)
signal expansion_picked(region: String)
signal entrance_picked(region: String)
signal earnings_picked(tower_id: String)
signal core_picked
signal empty_picked
signal camera_changed
signal tower_selection_changed

var state: VigilState
var camera := Vector2.ZERO
var zoom := 1.0
var unrestricted_camera := false
var show_health_numbers := false
var selected_tower := "":
	set(value):
		var changed := selected_tower != value
		selected_tower = value
		if changed:
			tower_selection_changed.emit()
		queue_redraw()
var selected_pad := -1
var moving_tower := ""
var selected_region := "0,0"
var preview_kind := "rapid"
var show_expansion := false
var effect_offset := 0.0
var upgrade_poofs: Array[Dictionary] = []
var observed_economy: VigilEconomy
var mouse_down := false
var dragged := false
var start := Vector2.ZERO
var previous := Vector2.ZERO
var touches := {}
var gesture_consumed := false
var font := ThemeDB.fallback_font
var terrain_layer: VigilTerrainLayer
var frontier_cache: Dictionary = {}
var frontier_signature: Array = []

func expansion_frontier() -> Dictionary:
	var signature := [state, state.terrain_revision, state.data.seed, state.data.regions.size()]
	if frontier_signature != signature:
		frontier_signature = signature
		frontier_cache = VigilWorld.frontier(state.data.regions, int(state.data.seed))
	return frontier_cache
const GOLD := VigilTerrainArt.GOLD
const TEXT := VigilTerrainArt.PAPER
const EXPANSION_HIT_RADIUS := 38.0

func _ready() -> void:
	bind_upgrade_effects()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = VigilInterface.font(600)
	gui_input.connect(_on_gui_input)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var backdrop := ColorRect.new()
	backdrop.color = VigilTerrainArt.BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.show_behind_parent = true
	add_child(backdrop)
	terrain_layer = VigilTerrainLayer.new()
	terrain_layer.show_behind_parent = true
	add_child(terrain_layer)

func bind_upgrade_effects() -> void:
	if state == null or observed_economy == state.economy:
		return
	if observed_economy != null:
		observed_economy.tower_upgraded.disconnect(on_tower_upgraded)
	observed_economy = state.economy
	observed_economy.tower_upgraded.connect(on_tower_upgraded)
	upgrade_poofs.clear()

func on_tower_upgraded(region: String, pad: int, kind: String) -> void:
	upgrade_poofs.append({"pos": VigilWorld.pad_position(region, pad), "age": 0.0, "color": Color(Balance.TOWERS[kind].color)})
	queue_redraw()

func _process(delta: float) -> void:
	enforce_camera_limits()
	bind_upgrade_effects()
	if upgrade_poofs.is_empty():
		return
	for i in range(upgrade_poofs.size() - 1, -1, -1):
		upgrade_poofs[i].age += delta
		if upgrade_poofs[i].age >= 0.65:
			upgrade_poofs.remove_at(i)
	queue_redraw()

func draw_upgrade_poofs() -> void:
	for fx in upgrade_poofs:
		var progress: float = fx.age / 0.65
		var opacity := 1.0 - smoothstep(0.25, 1.0, progress)
		var center := screen(fx.pos + Vector2(0, -17))
		for i in range(9):
			var direction := Vector2.from_angle(TAU * i / 9.0)
			var offset := direction * (9.0 + progress * 28.0) + Vector2(0, -progress * 13.0)
			var radius := (8.0 + sin(progress * PI) * 5.0) * zoom
			draw_circle(center + offset * zoom, radius, Color(VigilTerrainArt.PAPER, opacity * 0.85))
			if i % 2 == 0:
				draw_circle(center + offset * zoom, 2.0 * zoom, Color(fx.color, opacity))

func screen(pos: Vector2) -> Vector2:
	return (pos - camera) * zoom + size * 0.5

func world(pos: Vector2) -> Vector2:
	return (pos - size * 0.5) / zoom + camera

# Use an envelope so protruding tiles never produce restrictive corner cutouts.
func camera_bounds() -> Rect2:
	var bounds := Rect2(Vector2.ONE * -Balance.TILE * 0.5, Vector2.ONE * Balance.TILE)
	for id in state.data.regions:
		bounds = bounds.merge(Rect2(VigilWorld.center(id) - Vector2.ONE * Balance.TILE * 0.5, Vector2.ONE * Balance.TILE))
	return bounds.grow(2.0 * Balance.TILE)

func minimum_zoom() -> float:
	var bounds := camera_bounds()
	return maxf(minf(size.x, size.y) / (2.0 * Balance.TILE), maxf(size.x / bounds.size.x, size.y / bounds.size.y))

func enforce_camera_limits() -> void:
	if unrestricted_camera or state == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var old_camera := camera
	var old_zoom := zoom
	zoom = clampf(zoom, minimum_zoom(), maxf(1.65, minimum_zoom()))
	var bounds := camera_bounds()
	var half_view := size / (2.0 * zoom)
	camera = camera.clamp(bounds.position + half_view, bounds.end - half_view)
	if camera != old_camera or zoom != old_zoom:
		camera_changed.emit()
		queue_redraw()

func set_unrestricted_camera(enabled: bool) -> void:
	unrestricted_camera = enabled and state != null and state.is_creative()
	enforce_camera_limits()

func set_zoom(value: float, pivot: Vector2) -> void:
	var before := world(pivot)
	zoom = clampf(value, 0.01, 100.0) if unrestricted_camera else clampf(value, minimum_zoom(), maxf(1.65, minimum_zoom()))
	camera += before - world(pivot)
	enforce_camera_limits()
	camera_changed.emit()
	queue_redraw()

func _on_gui_input(event: InputEvent) -> void:
	# Buttons use Godot's emulated mouse; the map handles physical touches itself.
	if event is InputEventMouse and event.device == -1:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			set_zoom(zoom * 1.1, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			set_zoom(zoom / 1.1, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_down = true
				dragged = false
				start = event.position
				previous = start
			elif mouse_down:
				mouse_down = false
				if not dragged:
					tap(event.position)
	elif event is InputEventMouseMotion and mouse_down:
		if event.position.distance_to(start) > 10.0:
			dragged = true
		if dragged:
			camera -= (event.position - previous) / zoom
			enforce_camera_limits()
			camera_changed.emit()
		previous = event.position
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 1:
				start = event.position
				dragged = false
				gesture_consumed = false
			else:
				gesture_consumed = true
		elif touches.has(event.index):
			if touches.size() == 1 and not dragged and not gesture_consumed and not event.canceled:
				tap(event.position)
			touches.erase(event.index)
	elif event is InputEventScreenDrag and touches.has(event.index):
		var old: Vector2 = touches[event.index]
		if touches.size() >= 2:
			var other: Vector2 = old
			for id in touches:
				if id != event.index:
					other = touches[id]
					break
			var distance := old.distance_to(other)
			if distance > 5.0:
				set_zoom(zoom * event.position.distance_to(other) / distance, (event.position + other) * 0.5)
			gesture_consumed = true
		else:
			if event.position.distance_to(start) > 10.0:
				dragged = true
			if dragged:
				camera -= (event.position - old) / zoom
				enforce_camera_limits()
				camera_changed.emit()
		touches[event.index] = event.position
	elif event is InputEventMagnifyGesture:
		set_zoom(zoom * event.factor, event.position)
	queue_redraw()

# Releases outside the map still end gestures, without placing anything under HUD controls.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if not Rect2(Vector2.ZERO, size).has_point(event.position - global_position):
			mouse_down = false
	if event is InputEventScreenTouch and not event.pressed:
		var local: Vector2 = event.position - global_position
		if not Rect2(Vector2.ZERO, size).has_point(local):
			touches.erase(event.index)
			gesture_consumed = true

func tap(pos: Vector2) -> void:
	if moving_tower != "":
		var destination := world(pos)
		for id in state.data.regions:
			for pad in range(4):
				if destination.distance_to(VigilWorld.pad_position(id, pad)) < maxf(26.0, 25.0 / zoom):
					relocation_picked.emit(id, pad)
					return
		return
	for t in state.data.towers.values():
		if earnings_badge_visible(t) and earnings_rect(t).has_point(pos):
			earnings_picked.emit(t.id)
			return
	var point := world(pos)
	for id in state.data.regions:
		for pad in range(4):
			if point.distance_to(VigilWorld.pad_position(id, pad)) < maxf(26.0, 25.0 / zoom):
				picked.emit(id, pad)
				return
	if core_is_visible() and pos.distance_to(screen(VigilWorld.CORE_POSITION)) <= maxf(36.0 * zoom, 22.0):
		core_picked.emit()
		return
	# Prefer the closest visible control if a densely surrounded frontier crowds
	# the touch padding at minimum zoom. A button's center always belongs to it.
	var nearest := ""
	var is_entrance := false
	var distance := INF
	for id in state.data.regions:
		if not VigilWorld.has_rift(id, state.data.regions, int(state.data.seed)):
			continue
		var gate: Vector2 = screen(state.paths[id][0])
		var candidate := pos.distance_to(gate) / entrance_hit_radius()
		if candidate < 1.0 and candidate < distance:
			nearest = id
			is_entrance = true
			distance = candidate
	for id in VigilWorld.frontier(state.data.regions, int(state.data.seed)):
		var c := screen(expansion_marker(id))
		var candidate := pos.distance_to(c) / (EXPANSION_HIT_RADIUS * zoom)
		if candidate < 1.0 and candidate < distance:
			nearest = id
			is_entrance = false
			distance = candidate
	if nearest != "":
		if is_entrance:
			entrance_picked.emit(nearest)
		else:
			expansion_picked.emit(nearest)
		return
	# Invisible collection padding must not steal taps from map controls.
	for t in state.data.towers.values():
		if earnings_badge_visible(t) and earnings_rect(t).grow(9.0 * zoom).has_point(pos):
			earnings_picked.emit(t.id)
			return
	empty_picked.emit()

func entrance_scale() -> float:
	# Keep the artwork the same size relative to its tile at every zoom.
	return zoom

func entrance_hit_radius() -> float:
	return 32.0 * entrance_scale()

func expansion_marker(id: String) -> Vector2:
	# Anchor both drawing and hit testing to the future territory's center.
	return VigilWorld.center(id)

func earnings_badge_visible(t: Dictionary) -> bool:
	return t.earnings >= 1.0 and not state.data.towers.has(selected_tower)

func earnings_local_rect(t: Dictionary) -> Rect2:
	# Fixed map-space placement above the tower; never compensate for camera zoom.
	var text := "+" + Balance.money(t.earnings)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 18.0
	return Rect2(Vector2(-width / 2.0, -68), Vector2(width, 23))

func earnings_rect(t: Dictionary) -> Rect2:
	var rect := earnings_local_rect(t)
	var anchor := screen(VigilWorld.pad_position(t.region, t.pad))
	return Rect2(anchor + rect.position * zoom, rect.size * zoom)

func core_is_visible() -> bool:
	return Rect2(Vector2.ZERO, size).has_point(screen(VigilWorld.CORE_POSITION))

func update_view(delta: float, tick_remainder: float = 0.0) -> void:
	effect_offset = tick_remainder
	queue_redraw()

func text_at(text: String, at: Vector2, pixels: int, color: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)

func centered(text: String, at: Vector2, pixels: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	text_at(text, at - Vector2(width * 0.5, 0), pixels, color)

func _draw() -> void:
	if state == null:
		return
	if terrain_layer != null:
		terrain_layer.synchronize(state, camera, zoom, size)
	var visible := Rect2(Vector2(-100, -100), size + Vector2(200, 200))
	var world_view := Rect2(world(visible.position), visible.size / zoom)
	var visible_regions := RegionQuery.in_view(state.data.regions, world_view, Balance.TILE * 0.5)
	for id in visible_regions:
		var c := screen(VigilWorld.center(id))
		if not visible.intersects(Rect2(c - Vector2.ONE * 150.0 * zoom, Vector2.ONE * 300.0 * zoom)):
			continue
		draw_region(state.data.regions[id])
	# Draw portals after every tile, so newly purchased terrain cannot cover them.
	for id in visible_regions:
		if VigilWorld.has_rift(id, state.data.regions, int(state.data.seed)) and visible.has_point(screen(state.paths[id][0])):
			draw_entrance(id)
	for id in RegionQuery.in_view(expansion_frontier(), world_view):
		var c := screen(expansion_marker(id))
		if not visible.has_point(c):
			continue
		draw_set_transform(c, 0, Vector2.ONE * zoom)
		VigilTerrainArt.disk(self, Vector2.ZERO, 24.0, GOLD if show_expansion else VigilTerrainArt.PAPER, 4.0)
		draw_line(-Vector2(7, 0), Vector2(7, 0), Color.BLACK, 3.0, true)
		draw_line(-Vector2(0, 7), Vector2(0, 7), Color.BLACK, 3.0, true)
		centered(Balance.money(Balance.expansion_cost(state.data.regions.size())) + " g", Vector2(0, 43), 13, GOLD)
		draw_set_transform(Vector2.ZERO)
	draw_core()
	var range_pos := Vector2.ZERO
	var range_radius := 0.0
	if state.data.towers.has(selected_tower):
		var t: Dictionary = state.data.towers[selected_tower]
		range_pos = VigilWorld.pad_position(t.region, t.pad)
		range_radius = Balance.tower_stats(t, state.tuning).range
	elif selected_pad >= 0:
		range_pos = VigilWorld.pad_position(selected_region, selected_pad)
		range_radius = Balance.tuned_value("towers", preview_kind, "range", state.tuning)
	if range_radius > 0.0:
		# A single outline keeps the range preview uncluttered.
		draw_arc(screen(range_pos), range_radius * zoom, 0, TAU, 72, GOLD, 1.5, true)
	for patch in state.combat.burning_ground:
		var center := screen(patch.pos)
		if not visible.grow(patch.radius*zoom).has_point(center):
			continue
		draw_circle(center, patch.radius*zoom, Color(0.3,0.16,0.10,0.35))
		draw_arc(center,patch.radius*zoom,0,TAU,40,Color("f19b57"),2*zoom,true)
		for index in range(9):
			var ember: Vector2 = center + Vector2.from_angle(index*2.4)*sqrt(index/9.0)*patch.radius*zoom
			draw_line(ember,ember+Vector2(2,-5-sin(state.combat.simulation_time*5+index)*2)*zoom,VigilTerrainArt.GOLD,2*zoom,true)
	for e in state.combat.visible_enemies(world_view):
		if visible.has_point(screen(e.pos)):
			draw_enemy(e)
	for t in state.economy.towers_in_regions(visible_regions):
		if visible.has_point(screen(VigilWorld.pad_position(t.region, t.pad))):
			draw_tower(t)
	draw_upgrade_poofs()
	for fx in state.combat.effects:
		var fade: float = fx.life / fx.max_life
		var color := Color(fx.color)
		var p := screen(fx.pos)
		if fx.kind == "shot":
			var origin := screen(fx.from)
			if visible.intersects(Rect2(origin, Vector2.ZERO).expand(p).grow((fx.radius + 30.0) * zoom)):
				AttackEffects.draw(self, fx, origin, p, zoom, effect_offset)
		elif fx.kind == "relic_drop":
			preload("res://scripts/rendering/actors/relic_art.gd").draw(self, fx.relic_kind, p + Vector2(0, -25 - (1.0 - fade) * 25) * zoom, zoom * (0.9 + fade * 0.4))
		elif fx.kind == "shard_fade":
			var tip: Vector2 = p + fx.direction * (1.0-fade)*35*zoom
			draw_line(tip,tip+fx.direction*7*zoom,Color(color,fade),2*zoom,true)
		elif fx.kind == "seal":
			draw_arc(p,(1.0-fade)*35*zoom,0,TAU,32,Color(color,fade),3*zoom,true)
			draw_circle(p,8*fade*zoom,Color(VigilTerrainArt.PAPER,fade))
		elif fx.kind == "escape":
			draw_arc(p, (7.0 + fade * 18.0) * zoom, 0, TAU, 32, VigilTerrainArt.MINT, 2.0 * zoom, true)
		else:
			draw_arc(p, (1.0 - fade) * 12.0 * zoom, 0, TAU, 20, color, 2.0 * zoom, true)


func draw_region(region: Dictionary) -> void:
	# Terrain is cached behind this interactive layer; only + glyphs redraw.
	for pad in range(4):
		if state.economy.tower_at(region.id, pad) != "":
			continue
		var p := screen(VigilWorld.pad_position(region.id, pad))
		if moving_tower != "":
			draw_circle(p, 22.0 * zoom, Color(GOLD, 0.22))
			draw_arc(p, 22.0 * zoom, 0, TAU, 32, GOLD, 2, true)
		var radius := 5.0
		var width := 2.5
		draw_line(p - Vector2(radius, 0), p + Vector2(radius, 0), Color.BLACK, width, true)
		draw_line(p - Vector2(0, radius), p + Vector2(0, radius), Color.BLACK, width, true)

func draw_entrance(id: String) -> void:
	var gate := screen(VigilWorld.center(id))
	var z := entrance_scale()
	preload("res://scripts/rendering/actors/rift_art.gd").draw(self, state.data.regions[id].get("style", "forest"), gate, z)

func draw_core() -> void:
	var gate := screen(VigilWorld.CORE_POSITION)
	if not Rect2(Vector2.ZERO, size).grow(60.0 * zoom).has_point(gate):
		return
	VigilTerrainArt.portal(self, gate, zoom, true)

func draw_tower(t: Dictionary) -> void:
	var p := screen(VigilWorld.pad_position(t.region, t.pad))
	var z := zoom
	VigilTerrainArt.sentinel(self, t.kind, p, z, int(t.level), t.get("branch", ""))
	var relic_kind := preload("res://scripts/gameplay/progression/relics.gd").kind(state.data, t)
	if relic_kind != "":
		preload("res://scripts/rendering/actors/relic_art.gd").draw(self, relic_kind, p + Vector2(20, -17) * z, z * 0.8)

	if t.get("branch", "") == "doomstone":
		var stacks: int = state.combat.curses.get(t.id, {}).get("stacks", 0)
		for y in [-38,-27,-16]:
			VigilTerrainArt.shape(self,[Vector2(-5,0),Vector2(0,-4),Vector2(5,0),Vector2(0,4)],p+Vector2(0,y)*z,Vector2.ONE*z,Color("c282bb").lerp(VigilTerrainArt.PAPER,stacks/5.0),1.5*z)
	if t.get("rebuild_remaining", 0.0) > 0.0:
		# Scaffolding and a persistent timer distinguish an inactive tower.
		draw_set_transform(p, 0, Vector2.ONE * zoom)
		for x in [-24.0, 24.0]:
			draw_line(Vector2(x, 4), Vector2(x, -44), GOLD, 3, true)
		for y in [-12.0, -36.0]:
			draw_line(Vector2(-27, y), Vector2(27, y), GOLD, 3, true)
		draw_line(Vector2(-24, 4), Vector2(24, -36), GOLD, 2, true)
		var label := "Rebuild " + Balance.rebuild_time_text(t.rebuild_remaining)
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16
		draw_style_box(pill(GOLD, Color.BLACK, 3), Rect2(Vector2(-width * 0.5, 12), Vector2(width, 24)))
		centered(label, Vector2(0, 29), 12, Color.BLACK)
		draw_set_transform(Vector2.ZERO)
	if earnings_badge_visible(t):
		var label := "+" + Balance.money(t.earnings)
		var rect := earnings_local_rect(t)
		# Apply the same map transform as the tower, including its overhead spacing.
		draw_set_transform(p, 0, Vector2.ONE * zoom)
		draw_style_box(pill(GOLD, Color.BLACK, 3), rect)
		centered(label, Vector2(rect.get_center().x, rect.position.y + 16), 12, Color.BLACK)
		draw_set_transform(Vector2.ZERO)

static func pill(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	return s

func draw_enemy(e: Dictionary) -> void:
	var p := screen(e.pos)
	var z := zoom
	if e.get("boss", false):
		preload("res://scripts/rendering/actors/boss_art.gd").draw(self, e, p, z)
		z *= preload("res://scripts/rendering/actors/boss_art.gd").SIZE_SCALE
	else:
		VigilTerrainArt.enemy(self, e.kind, p, z)
	if e.get("slow_until", 0.0) > state.combat.simulation_time:
		draw_arc(p, 15*z, 0, TAU, 24, Color("96d6e6"), 2*z, true)
		for index in range(6):
			var tip := p + Vector2.from_angle(index*TAU/6)*17*z
			draw_line(tip, tip+Vector2(0,-5)*z,Color("96d6e6"),2*z,true)
	var charge := 0
	for amount in e.get("charges", {}).values():
		charge = maxi(charge, int(amount))
	for index in range(charge):
		draw_circle(p+Vector2(-9+index*6,-30)*z,2*z,Color("b3b5f1"))
	for index in range(int(e.get("curse_stacks", 0))):
		draw_line(p+Vector2(-10+index*5,16)*z,p+Vector2(-8+index*5,20)*z,Color("c282bb"),2*z,true)
	if e.get("root_until", 0.0) > state.combat.simulation_time:
		draw_arc(p, 17*z, 0, TAU, 24, Color("a9d58b"), 2*z, true)
		for side in [-1, 1]:
			draw_polyline(PackedVector2Array([p+Vector2(side*20,6)*z, p+Vector2(side*9,-2)*z, p+Vector2(side*15,-13)*z]), Color("a9d58b"), 2*z, true)
	if e.get("stun_until", 0.0) > state.combat.simulation_time:
		draw_arc(p,18*z,0,TAU,24,VigilTerrainArt.PAPER,2*z,true)
	var rift_style: String = e.get("rift_style", "forest")
	if Balance.rift_strength(rift_style, state.tuning) > 0.0:
		preload("res://scripts/rendering/actors/rift_art.gd").enemy_mark(self, rift_style, p, z)
	if e.hp < e.max_hp and not e.get("boss", false):
		var from := p + Vector2(-9, -23 * z)
		draw_line(from, from + Vector2(18, 0), Color.BLACK, 4)
		draw_line(from, from + Vector2(18 * e.hp / e.max_hp, 0), VigilTerrainArt.MINT, 2)

	if show_health_numbers and state.is_creative():
		var label := "%s / %s HP" % [String.num(e.hp, 1).trim_suffix(".0"), String.num(e.max_hp, 1).trim_suffix(".0")]
		var font := ThemeDB.fallback_font
		var at := p + Vector2(-font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5, -38 * z)
		draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
