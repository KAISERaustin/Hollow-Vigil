extends RefCounted

## Each artwork has its own replaceable image. Matching instances share the
## loaded texture; no entities, camera state or gameplay live in this component.
## Generated defaults come from tools/bake_actor_images.gd. The JSON catalog owns
## image paths, bounds and resolution, independently of gameplay configuration.
const SCALE := 2.0
const SIZE := Vector2i(2048, 1152)
const ENEMY_BOUNDS := Rect2(-24, -26, 48, 48)
const TOWER_BOUNDS := Rect2(-48, -76, 96, 96)
var textures: Dictionary = {}
var entries: Dictionary = {}

static func recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var index := 0
	for kind in Balance.ENEMIES:
		result.append({"key": "enemy/" + kind, "kind": kind, "family": "enemy",
			"bounds": ENEMY_BOUNDS, "region": Rect2((index % 21) * 96, (index / 21) * 96, 96, 96)})
		index += 1
	index = 0
	for kind in Balance.TOWERS:
		var tiers := [[1, ""], [2, ""], [3, ""]]
		for branch in Balance.BRANCHES[kind]: tiers.append([4, branch])
		for tier in tiers:
			for family in (["tower", "bow"] if kind == "ironspike" else ["tower"]):
				result.append({"key": "%s/%s/%d/%s" % [family, kind, tier[0], tier[1]],
					"family": family, "kind": kind, "level": tier[0], "branch": tier[1], "bounds": TOWER_BOUNDS,
					"region": Rect2((index % 10) * 192, 96 + (index / 10) * 192, 192, 192)})
				index += 1
	return result

func _init() -> void:
	# Headless simulation and native portraits need no GPU assets.
	var path := "res://assets/artwork/catalog.json"
	if FileAccess.file_exists(path):
		var catalog = JSON.parse_string(FileAccess.get_file_as_string(path))
		if catalog is Dictionary: entries = catalog

func invalidate() -> void:
	textures.clear()
	entries.clear()
	_init()

func draw(canvas: CanvasItem, key: String, at: Vector2, zoom: float) -> bool:
	if not entries.has(key): return false
	var entry: Dictionary = entries[key]
	if zoom > float(entry.get("pixels_per_unit", SCALE)): return false
	if not textures.has(key): textures[key] = load(entry.image)
	var texture: Texture2D = textures[key]
	if texture == null: return false
	var b: Array = entry.bounds
	canvas.draw_texture_rect(texture, Rect2(at + Vector2(b[0], b[1]) * zoom, Vector2(b[2], b[3]) * zoom), false)
	return true

func enemy(canvas: CanvasItem, kind: String, at: Vector2, zoom: float) -> void:
	if not draw(canvas, "enemy/" + kind, at, zoom):
		VigilTerrainArt.enemy(canvas, kind, at, zoom)

func tower(canvas: CanvasItem, kind: String, at: Vector2, zoom: float, level: int, branch: String, angle: float) -> void:
	if not draw(canvas, "tower/%s/%d/%s" % [kind, level, branch], at, zoom):
		VigilTerrainArt.sentinel(canvas, kind, at, zoom, level, branch, angle)
		return
	if kind == "ironspike":
		var pivot: Vector2 = Balance.PROJECTILES.ironspike.muzzle
		var rotation := angle + PI / 2.0
		canvas.draw_set_transform(at + (pivot - pivot.rotated(rotation)) * zoom, rotation, Vector2.ONE * zoom)
		draw(canvas, "bow/%s/%d/%s" % [kind, level, branch], Vector2.ZERO, 1.0)
		canvas.draw_set_transform(Vector2.ZERO)
