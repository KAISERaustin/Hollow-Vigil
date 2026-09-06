extends RefCounted

## Connected, visible biome patches after castle/orchard overlays. Cluster
## identity depends only on terrain and seed, never on which tiles are owned.
const Areas = preload("res://scripts/world/hidden_areas.gd")
const CACHE_LIMIT := 4096
static var _cache: Dictionary = {}

static func at(id: String, seed_value: int) -> Dictionary:
	var cache_key := str(seed_value) + ":" + id
	if _cache.has(cache_key):
		return _cache[cache_key]
	var style := VigilWorld.region_style(id, seed_value)
	var cells: Array[Vector2i] = [VigilWorld.coord(id)]
	var seen := {cells[0]: true}
	var head := 0
	while head < cells.size():
		var cell := cells[head]
		head += 1
		for direction in VigilWorld.DIRS:
			var neighbor: Vector2i = cell + direction
			if not seen.has(neighbor) and VigilWorld.region_style(VigilWorld.key(neighbor), seed_value) == style:
				seen[neighbor] = true
				cells.append(neighbor)
	cells.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var boss_tile := ""
	var best := 0x7fffffffffffffff
	for cell in cells:
		var tile := VigilWorld.key(cell)
		if tile == "0,0":
			continue
		var score := absi(("biome-boss:" + str(seed_value) + ":" + tile).hash())
		if boss_tile == "" or score < best:
			best = score
			boss_tile = tile
	# Keep the existing castle threshold and Orchard entrance as their sites.
	if style == "castle_ruin":
		boss_tile = Areas.gate(Areas.sector_for(cells[0]), seed_value).id
	elif style == "mourning_orchard":
		boss_tile = VigilWorld.Orchard.gate(seed_value)
	cells.make_read_only()
	var result := {"id": VigilWorld.key(cells[0]), "style": style, "cells": cells, "boss_tile": boss_tile}
	result.make_read_only()
	if _cache.size() + cells.size() > CACHE_LIMIT:
		_cache.clear()
	for cell in cells:
		_cache[str(seed_value) + ":" + VigilWorld.key(cell)] = result
	return result
