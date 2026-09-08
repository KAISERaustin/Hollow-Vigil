class_name Battlefield
extends Control

const RegionQuery = preload("res://scripts/rendering/terrain/region_query.gd")
const CameraFraming = preload("res://scripts/rendering/camera_framing.gd")

const AttackEffects = preload("res://scripts/rendering/effects/attack_effects.gd")
const ConstructionEffect = preload("res://scripts/rendering/effects/construction_effect.gd")

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
var camera_framing := CameraFraming.new()
var zoom := 1.0
var unrestricted_camera := false
var show_health_numbers := false
var upgrade_range_preview: Dictionary = {}
var selected_tower := "":
	set(value):
		var changed := selected_tower != value
		selected_tower = value
		if changed:
			camera_framing.cancel()
			tower_selection_changed.emit()
		queue_redraw()
var selected_pad := -1
var moving_tower := ""
var selected_region := "0,0"
var preview_kind := ""
var build_preview := preload("res://scripts/rendering/build_preview.gd").new()
var show_expansion := false
var effect_offset := 0.0
var construction_effect := ConstructionEffect.new()
var upgrade_poofs: Array[Dictionary] = construction_effect.instances
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
	backdrop.color = background_color()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.show_behind_parent = true
	add_child(backdrop)
	terrain_layer = VigilTerrainLayer.new()
	terrain_layer.show_behind_parent = true
	add_child(terrain_layer)

func background_color() -> Color:
	return VigilTerrainArt.BACKDROP

func bind_upgrade_effects() -> void:
	var next_economy: VigilEconomy = state.economy if state != null else null
	if observed_economy == next_economy:
		return
	if observed_economy != null:
		observed_economy.tower_upgraded.disconnect(on_tower_upgraded)
		observed_economy.relic_changed.disconnect(on_tower_presentation_changed)
	observed_economy = next_economy
	if observed_economy != null:
		observed_economy.tower_upgraded.connect(on_tower_upgraded)
		observed_economy.relic_changed.connect(on_tower_presentation_changed)
	construction_effect.clear()

func on_tower_upgraded(region: String, pad: int, _kind: String) -> void:
	construction_effect.play(VigilWorld.pad_position(region, pad), observed_economy.tower_at(region, pad))
	queue_redraw()

func on_tower_presentation_changed(tower_id: String) -> void:
	# Sales and relocation already notify this shared presentation boundary.
	var tower: Dictionary = observed_economy.data.towers.get(tower_id, {})
	for i in range(upgrade_poofs.size() - 1, -1, -1):
		var fx: Dictionary = upgrade_poofs[i]
		if fx.owner_id == tower_id and (tower.is_empty() or VigilWorld.pad_position(tower.region, tower.pad) != fx.pos):
			construction_effect.remove(fx.pos)
	queue_redraw()

var simulation_rate := 1.0

func _process(delta: float) -> void:
	build_preview.refresh(self)
	advance_camera_framing(delta)
	enforce_camera_limits()
	bind_upgrade_effects()
	if upgrade_poofs.is_empty():
		return
	# Presentation uses wall time, including while campaign setup is paused.
	construction_effect.advance(delta)
	queue_redraw()

func draw_upgrade_poofs() -> void:
	for fx in upgrade_poofs:
		ConstructionEffect.draw(self, fx, screen(fx.pos), zoom)

func screen(pos: Vector2) -> Vector2:
	return (pos - camera) * zoom + size * 0.5

func world(pos: Vector2) -> Vector2:
	return (pos - size * 0.5) / zoom + camera

func frame_world_rect(content: Rect2, available: Rect2) -> void:
	if content.size.x <= 0.0 or content.size.y <= 0.0 or available.size.x <= 0.0 or available.size.y <= 0.0:
		return
	# Preserve zoom unless the subject is physically larger than the viewport.
	var fit_zoom := minf(available.size.x / content.size.x, available.size.y / content.size.y)
	var destination_zoom := minf(zoom, maxf(0.01 if unrestricted_camera else minimum_zoom(), fit_zoom))
	var on_screen := Rect2((content.position - camera) * destination_zoom + size * 0.5, content.size * destination_zoom)
	var destination := camera + CameraFraming.correction(on_screen, available) / destination_zoom
	if not unrestricted_camera:
		var bounds := camera_bounds()
		var half_view := size / (2.0 * destination_zoom)
		destination = destination.clamp(bounds.position + half_view, bounds.end - half_view)
	camera_framing.begin(camera, destination, zoom, destination_zoom)

func advance_camera_framing(delta: float) -> void:
	if not camera_framing.active:
		return
	camera = camera_framing.advance(delta)
	zoom = camera_framing.zoom
	enforce_camera_limits()
	camera_changed.emit()
	queue_redraw()

# Use an envelope so protruding tiles never produce restrictive corner cutouts.
func camera_bounds() -> Rect2:
	var bounds := Rect2(Vector2.ONE * -Balance.TILE * 0.5, Vector2.ONE * Balance.TILE)
	for id in state.data.regions:
		bounds = bounds.merge(Rect2(VigilWorld.center(id) - Vector2.ONE * Balance.TILE * 0.5, Vector2.ONE * Balance.TILE))
	return bounds.grow(2.0 * Balance.TILE + build_preview.camera_padding(self))

func minimum_zoom() -> float:
	var bounds := camera_bounds()
	return build_preview.minimum_zoom(self, maxf(minf(size.x, size.y) / (2.0 * Balance.TILE), maxf(size.x / bounds.size.x, size.y / bounds.size.y)))

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
	camera_framing.cancel()
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
				camera_framing.cancel()
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
			camera_framing.cancel()
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
		finish_mouse_gesture.call_deferred()
		if not Rect2(Vector2.ZERO, size).has_point(event.position - global_position):
			mouse_down = false
	if event is InputEventScreenTouch and not event.pressed:
		# GUI overlays can consume an inside release. Clean up after GUI dispatch,
		# so ordinary map taps still finish in _on_gui_input first.
		finish_touch_gesture.call_deferred(event.index)
		var local: Vector2 = event.position - global_position
		if not Rect2(Vector2.ZERO, size).has_point(local):
			touches.erase(event.index)
			gesture_consumed = true

func finish_mouse_gesture() -> void:
	mouse_down = false

func finish_touch_gesture(index: int) -> void:
	if touches.has(index):
		touches.erase(index)
		gesture_consumed = true

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		touches.clear()
		mouse_down = false
		gesture_consumed = true

func tap(pos: Vector2) -> void:
	if moving_tower != "":
		var destination := VigilWorld.ground_location(world(pos))
		relocation_picked.emit(destination.region, destination.pad)
		return
	for t in state.data.towers.values():
		if earnings_badge_visible(t) and earnings_rect(t).has_point(pos):
			earnings_picked.emit(t.id)
			return
	var point := world(pos)
	for tower in state.data.towers.values():
		if point.distance_to(VigilWorld.pad_position(tower.region, tower.pad)) < maxf(26.0, 25.0 / zoom):
			picked.emit(tower.region, tower.pad)
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

func earnings_badge_visible(_tower: Dictionary) -> bool:
	# Tower earnings are collected through the HUD; overhead badges stay hidden.
	return false

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

func update_view(_delta: float, tick_remainder: float = 0.0) -> void:
	effect_offset = tick_remainder
	queue_redraw()

func text_at(text: String, at: Vector2, pixels: int, color: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)

func centered(text: String, at: Vector2, pixels: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	text_at(text, at - Vector2(width * 0.5, 0), pixels, color)

func selected_range() -> float:
	if state == null:
		return 0.0
	if state.data.towers.has(selected_tower):
		var tower: Dictionary = state.data.towers[selected_tower]
		if upgrade_range_preview.get("id", "") == selected_tower and upgrade_range_preview.get("level", -1) == tower.level:
			tower = tower.duplicate(true)
			tower.level = mini(int(tower.level) + 1, Balance.MAX_TOWER_LEVEL)
			tower.branch = upgrade_range_preview.branch
		return Balance.tower_stats(tower, state.tuning, state.data.relics).range
	if selected_pad >= 0 and Balance.TOWERS.has(preview_kind):
		return Balance.Content.tower(preview_kind).stats(1, state.tuning).range
	return 0.0

static func tower_draws_before(a: Dictionary, b: Dictionary) -> bool:
	var a_pos := VigilWorld.pad_position(a.region, a.pad)
	var b_pos := VigilWorld.pad_position(b.region, b.pad)
	# Paint north first, then east first within a row: southwest stays in front.
	if a_pos.y != b_pos.y:
		return a_pos.y < b_pos.y
	if a_pos.x != b_pos.x:
		return a_pos.x > b_pos.x
	return int(a.id) < int(b.id)

func _draw() -> void:
	if state == null:
		return
	draw_map()
	var visible_rect := Rect2(Vector2(-100, -100), size + Vector2(200, 200))
	var world_view := Rect2(world(visible_rect.position), visible_rect.size / zoom)
	var visible_regions := RegionQuery.in_view(state.data.regions, world_view, Balance.TILE * 0.5)
	var range_pos := Vector2.ZERO
	var range_radius := selected_range()
	if state.data.towers.has(selected_tower):
		var t: Dictionary = state.data.towers[selected_tower]
		range_pos = VigilWorld.pad_position(t.region, t.pad)
	elif selected_pad >= 0:
		range_pos = VigilWorld.pad_position(selected_region, selected_pad)
	if range_radius > 0.0:
		# A single outline keeps the range preview uncluttered.
		draw_arc(screen(range_pos), range_radius * zoom, 0, TAU, 72, GOLD, 1.5, true)
	for patch in state.combat.burning_ground + state.combat.effect_fields:
		var center := screen(patch.pos)
		if not visible_rect.grow(patch.radius*zoom).has_point(center):
			continue
		draw_circle(center, patch.radius*zoom, Color(0.3,0.16,0.10,0.35))
		draw_arc(center,patch.radius*zoom,0,TAU,40,Color("f19b57"),2*zoom,true)
		for index in range(9):
			var ember: Vector2 = center + Vector2.from_angle(index*2.4)*sqrt(index/9.0)*patch.radius*zoom
			draw_line(ember,ember+Vector2(2,-5-sin(state.combat.simulation_time*5+index)*2)*zoom,VigilTerrainArt.GOLD,2*zoom,true)
	for e in state.combat.visible_enemies(world_view):
		if visible_rect.has_point(screen(e.pos)):
			draw_enemy(e)
	var visible_towers := state.economy.towers_in_regions(visible_regions)
	visible_towers.sort_custom(tower_draws_before)
	for t in visible_towers:
		if visible_rect.has_point(screen(VigilWorld.pad_position(t.region, t.pad))):
			draw_tower(t)
	build_preview.draw(self)
	preload("res://scripts/rendering/effects/tower_component_art.gd").draw(self)
	draw_upgrade_poofs()
	for fx in state.combat.effects:
		var fade: float = fx.life / fx.max_life
		var color := Color(fx.color)
		var p := screen(fx.pos)
		if fx.kind == "shot":
			var origin := screen(fx.from)
			if visible_rect.intersects(Rect2(origin, Vector2.ZERO).expand(p).grow((fx.radius + 30.0) * zoom)):
				AttackEffects.draw(self, fx, origin, p, zoom, effect_offset)
		elif fx.kind == "relic_drop":
			preload("res://scripts/rendering/actors/relic_art.gd").draw(self, fx.relic_kind, p + Vector2(0, -25 - (1.0 - fade) * 25) * zoom, zoom * (0.9 + fade * 0.4))
		elif fx.kind == "shard_fade":
			var tip: Vector2 = p + fx.direction * (1.0-fade)*35*zoom
			draw_line(tip,tip+fx.direction*7*zoom,Color(color,fade),2*zoom,true)
		elif fx.kind == "seal":
			draw_arc(p,(1.0-fade)*35*zoom,0,TAU,32,Color(color,fade),3*zoom,true)
			draw_circle(p,8*fade*zoom,Color(VigilTerrainArt.PAPER,fade))
		elif fx.kind == "gear_stun":
			draw_arc(p, (1.0 - fade) * fx.radius * zoom, 0, TAU, 40, Color(color, fade), 2.0 * zoom, true)
		elif fx.kind == "escape":
			draw_arc(p, (7.0 + fade * 18.0) * zoom, 0, TAU, 32, VigilTerrainArt.MINT, 2.0 * zoom, true)
		else:
			draw_arc(p, (1.0 - fade) * 12.0 * zoom, 0, TAU, 20, color, 2.0 * zoom, true)


func draw_map() -> void:
	if terrain_layer != null:
		terrain_layer.synchronize(state, camera, zoom, size)
	var visible_rect := Rect2(Vector2(-100, -100), size + Vector2(200, 200))
	var world_view := Rect2(world(visible_rect.position), visible_rect.size / zoom)
	var visible_regions := RegionQuery.in_view(state.data.regions, world_view, Balance.TILE * 0.5)
	for id in visible_regions:
		var c := screen(VigilWorld.center(id))
		if not visible_rect.intersects(Rect2(c - Vector2.ONE * 150.0 * zoom, Vector2.ONE * 300.0 * zoom)):
			continue
		draw_region(state.data.regions[id])
	# Draw portals after every tile, so newly purchased terrain cannot cover them.
	for id in visible_regions:
		if VigilWorld.has_rift(id, state.data.regions, int(state.data.seed)) and visible_rect.has_point(screen(state.paths[id][0])):
			draw_entrance(id)
	for id in RegionQuery.in_view(expansion_frontier(), world_view):
		var c := screen(expansion_marker(id))
		if not visible_rect.has_point(c):
			continue
		draw_set_transform(c, 0, Vector2.ONE * zoom)
		VigilTerrainArt.disk(self, Vector2.ZERO, 24.0, GOLD if show_expansion else VigilTerrainArt.PAPER, 4.0)
		draw_line(-Vector2(7, 0), Vector2(7, 0), Color.BLACK, 3.0, true)
		draw_line(-Vector2(0, 7), Vector2(0, 7), Color.BLACK, 3.0, true)
		centered(Balance.money(Balance.expansion_cost(state.data.regions.size())) + " g", Vector2(0, 43), 13, GOLD)
		draw_set_transform(Vector2.ZERO)
	draw_core()


func draw_region(_region: Dictionary) -> void:
	pass

func draw_entrance(id: String) -> void:
	var gate := screen(VigilWorld.center(id))
	var z := entrance_scale()
	var region: Dictionary = state.data.regions[id]
	preload("res://scripts/rendering/actors/rift_art.gd").draw(self, region.get("style", "forest"), gate, z, int(region.get("traffic", 0)), region.get("unlocks", []))

func draw_core() -> void:
	var gate := screen(VigilWorld.CORE_POSITION)
	if not Rect2(Vector2.ZERO, size).grow(60.0 * zoom).has_point(gate):
		return
	preload("res://scripts/rendering/actors/rift_art.gd").draw_core(self, gate, zoom)

var actor_images := preload("res://scripts/rendering/actors/actor_images.gd").new()

func draw_tower(t: Dictionary) -> void:
	if construction_effect.conceals(VigilWorld.pad_position(t.region, t.pad)):
		return
	var p := screen(VigilWorld.pad_position(t.region, t.pad))
	var z := zoom
	actor_images.tower(self, t.kind, p, z, int(t.level), t.get("branch", ""), float(t.angle))
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

static func pill(bg: Color, border: Color, radius: int) -> StyleBox:
	var s := VigilInterface.box(bg, border, radius)
	s.set_border_width_all(VigilInterface.OUTLINE)
	s.set_corner_radius_all(radius)
	return s

func draw_enemy(e: Dictionary) -> void:
	var p := screen(e.pos)
	var z := zoom
	if e.get("boss", false):
		preload("res://scripts/rendering/actors/boss_art.gd").draw(self, e, p, z)
		z *= preload("res://scripts/rendering/actors/boss_art.gd").SIZE_SCALE
	else:
		actor_images.enemy(self, e.kind, p, z)
	preload("res://scripts/rendering/effects/affliction_art.gd").draw(self, e, p, z, state.combat.simulation_time)
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
		var health_font := ThemeDB.fallback_font
		var at := p + Vector2(-health_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5, -38 * z)
		draw_string_outline(health_font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		draw_string(health_font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
