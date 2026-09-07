extends Battlefield

const Catalog = preload("res://scripts/campaign/catalog.gd")
signal socket_picked(socket: int)
var run: RefCounted
var selected := -1
var interactive := true
var landscape: Node2D
var trail_bounds := Rect2()
var view_zoom: float:
	get:
		return zoom / overview_zoom()

func background_color() -> Color:
	# Fractional camera transforms can leave a pixel between clipped tiles.
	# A continuous ground underlay keeps those seams in the mission's palette.
	return VigilTerrainArt.ground_color(run.mission.style)

func _ready() -> void:
	state = run.game
	trail_bounds = Rect2(Catalog.CORE, Vector2.ZERO)
	for route in run.mission.routes:
		for point in route:
			trail_bounds = trail_bounds.expand(point)
	for socket in run.mission.sockets:
		trail_bounds = trail_bounds.expand(socket.position)
	trail_bounds = trail_bounds.grow(55)
	super._ready()
	clear_selection()
	# The original cached terrain renderer accepts authored geometry. Only the
	# roads and sockets differ; all ground, scenery and actor art stays shared.
	terrain_layer.hide()
	landscape = Node2D.new()
	landscape.show_behind_parent = true
	add_child(landscape)
	# Paint the temporary build-preview camera margin before opening any menu.
	var bounds := camera_bounds().grow(2.0 * Balance.TILE)
	for y in range(floori(bounds.position.y / Balance.TILE), ceili(bounds.end.y / Balance.TILE) + 1):
		for x in range(floori(bounds.position.x / Balance.TILE), ceili(bounds.end.x / Balance.TILE) + 1):
			var id := VigilWorld.key(Vector2i(x, y))
			var center := VigilWorld.center(id)
			var pads: Array = []
			for socket in run.mission.sockets:
				if Rect2(center - Vector2.ONE * Balance.TILE * 0.5, Vector2.ONE * Balance.TILE).has_point(socket.position):
					pads.append(socket.position - center)
			var tile := VigilTerrainTile.new()
			tile.configure({"id": id, "style": run.mission.style}, state.data.seed, {"roads": run.mission.routes, "pads": pads, "render_roads": false})
			landscape.add_child(tile)
	var roads := preload("res://scripts/rendering/terrain/road_layer.gd").new()
	roads.configure(run.mission.routes)
	landscape.add_child(roads)
	resized.connect(_resize_view)
	reset_view()
	accessibility_name = "Campaign battlefield. Tap a socket to build or manage. Drag to explore, pinch or scroll to zoom."

func overview_zoom() -> float:
	return maxf(0.01, minf(size.x / maxf(1, trail_bounds.size.x), size.y / maxf(1, trail_bounds.size.y)))

func minimum_zoom() -> float:
	var bounds := camera_bounds()
	return build_preview.minimum_zoom(self, maxf(overview_zoom(), maxf(size.x / bounds.size.x, size.y / bounds.size.y)))

func camera_bounds() -> Rect2:
	return trail_bounds.grow(300 + build_preview.camera_padding())

func reset_view() -> void:
	camera = trail_bounds.get_center()
	zoom = minimum_zoom()
	enforce_camera_limits()
	queue_redraw()

func _resize_view() -> void:
	if not interactive:
		reset_view()
	else:
		enforce_camera_limits()
	queue_redraw()

func _on_gui_input(event: InputEvent) -> void:
	if interactive:
		super._on_gui_input(event)

func pick(point: Vector2) -> void:
	tap(point)

func tap(point: Vector2) -> void:
	var nearest := -1
	var distance := maxf(25, 26 * zoom)
	for socket in run.mission.sockets:
		var candidate := point.distance_to(screen(socket.position))
		if candidate < distance:
			distance = candidate
			nearest = socket.index
	if nearest >= 0:
		socket_picked.emit(nearest)
	else:
		empty_picked.emit()

func select_socket(index: int) -> void:
	selected = index
	var socket := Catalog.socket(index)
	selected_region = socket.region
	selected_pad = socket.pad
	selected_tower = run.tower_at(index)
	tower_selection_changed.emit()
	queue_redraw()

func clear_selection() -> void:
	selected = -1
	selected_pad = -1
	selected_region = ""
	selected_tower = ""
	tower_selection_changed.emit()
	queue_redraw()

func earnings_badge_visible(_tower: Dictionary) -> bool:
	return false

func draw_map() -> void:
	if landscape == null:
		return
	landscape.position = size * 0.5 - camera * zoom
	landscape.scale = Vector2.ONE * zoom
	for lane in range(run.mission.routes.size()):
		var at := screen(run.mission.routes[lane][0])
		var wave_index := mini(int(run.wave), run.mission.waves.size() - 1)
		preload("res://scripts/rendering/actors/rift_art.gd").draw_wave(self, run.mission.style, at, zoom, run.mission.waves[wave_index], lane)
		if run.can_author():
			centered(String.chr(65 + lane), at + Vector2(0, -64 * zoom), 13, TEXT)
	preload("res://scripts/rendering/actors/rift_art.gd").draw_core(self, screen(Catalog.CORE), zoom)
