extends RefCounted

const COUNT = preload("res://scripts/content/catalogs/levels.gd").COUNT
const LEGACY_COUNT = preload("res://scripts/content/catalogs/levels.gd").LEGACY_COUNT
const LEVELS_PER_CHAPTER = preload("res://scripts/content/catalogs/levels.gd").LEVELS_PER_CHAPTER
const MAX_HEALTH = preload("res://scripts/content/catalogs/levels.gd").MAX_HEALTH
const BOARD = preload("res://scripts/content/catalogs/levels.gd").BOARD
const CORE = preload("res://scripts/content/catalogs/levels.gd").CORE
const CHAPTERS = preload("res://scripts/content/catalogs/levels.gd").CHAPTERS
const MISSIONS = preload("res://scripts/content/catalogs/levels.gd").MISSIONS

static func level(index: int) -> Dictionary:
	var node := Balance.Content.level(index)
	if node == null:
		return {}
	var result := node.layout()
	result.sockets = []
	for socket_id in result.pads:
		result.sockets.append(socket(int(socket_id)))
	return result

static func socket(index: int) -> Dictionary:
	var column := index % 4
	var row := int(index / 4.0)
	var region := Vector2i(-1 if column == 0 else (1 if column == 3 else 0), -2 if row == 0 else (-1 if row < 3 else 0))
	var pad := (1 if column in [0, 2] else 0) + (2 if row in [0, 2] else 0)
	return {"region": VigilWorld.key(region), "pad": pad, "position": VigilWorld.pad_position(VigilWorld.key(region), pad), "index": index}
