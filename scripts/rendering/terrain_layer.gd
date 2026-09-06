class_name VigilTerrainLayer
extends Node2D

var chunks: Dictionary = {}
var visible_chunks: Dictionary = {}
var revision := -1
var model: VigilState
var seed_value := -1
var grid := preload("res://scripts/rendering/terrain_grid.gd").new()
var clouds := preload("res://scripts/rendering/terrain_clouds.gd").new()
var hidden_areas := preload("res://scripts/rendering/hidden_areas.gd").new()
var cloud_edges := preload("res://scripts/rendering/terrain_cloud_edges.gd").new()

func _init() -> void:
	add_child(clouds)
	add_child(hidden_areas)
	add_child(cloud_edges)
	add_child(grid)

func synchronize(state: VigilState, camera: Vector2, zoom: float, viewport_size: Vector2) -> void:
	position = viewport_size * 0.5 - camera * zoom
	scale = Vector2.ONE * zoom
	if model != state or revision != state.terrain_revision:
		var replace := model != state or seed_value != int(state.data.seed)
		model = state
		seed_value = int(state.data.seed)
		revision = state.terrain_revision
		for id in chunks.keys():
			if replace or not state.data.regions.has(id) or appearance(chunks[id].region) != appearance(state.data.regions[id]):
				chunks[id].free()
				chunks.erase(id)
		# A single overlay stays above every cached chunk, including new tiles,
		# while the battlefield's portals, enemies and controls remain above it.
		move_child(cloud_edges, -1)
		move_child(grid, -1)
		# The unified ruin ground masks the lattice only inside its footprint.
		move_child(hidden_areas, -1)
	var world_view := Rect2(camera - viewport_size * 0.5 / zoom, viewport_size / zoom)
	clouds.synchronize(world_view)
	hidden_areas.synchronize(state, world_view)
	cloud_edges.synchronize(state, world_view)
	grid.synchronize(world_view)
	var view := world_view.grow(170)
	var next_visible := {}
	for id in preload("res://scripts/rendering/region_query.gd").in_view(state.data.regions, view):
		if not chunks.has(id):
			var tile := VigilTerrainTile.new()
			tile.configure(state.data.regions[id].duplicate(true), state.data.seed)
			chunks[id] = tile
			add_child(tile)
			move_child(tile, cloud_edges.get_index())
		chunks[id].visible = true
		next_visible[id] = true
	for id in visible_chunks:
		if not next_visible.has(id) and chunks.has(id):
			chunks[id].visible = false
	visible_chunks = next_visible

func appearance(region: Dictionary) -> Array:
	return [region.get("style", "forest"), region.bend, region.get("road_version", 2)]
