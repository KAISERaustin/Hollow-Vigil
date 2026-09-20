@tool
extends Node2D
## Authoring-only preview. The external collider resource is the runtime source.
@export var tower_kind := "rapid"
@export var collider: Resource
var entry: Dictionary = {}
var artwork: Texture2D
var layer_entry: Dictionary = {}
var layer_artwork: Texture2D

func _ready() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/artwork/catalog.json"))
	entry = catalog.get("tower/" + tower_kind + "/1/", {})
	if not entry.is_empty(): artwork = load(entry.image)
	layer_entry = catalog.get(entry.get("rotating_layer", ""), {})
	if not layer_entry.is_empty(): layer_artwork = load(layer_entry.image)
	queue_redraw()

func _process(_delta: float) -> void:
	# Nested Shape2D Inspector edits need a fresh editor drawing too.
	queue_redraw()

func _draw() -> void:
	if artwork != null:
		var b: Array = entry.bounds
		draw_texture_rect(artwork, Rect2(b[0], b[1], b[2], b[3]), false)
	if layer_artwork != null:
		var b: Array = layer_entry.bounds
		draw_texture_rect(layer_artwork, Rect2(b[0], b[1], b[2], b[3]), false)
	if collider != null and collider.valid():
		draw_set_transform(collider.offset, deg_to_rad(collider.rotation_degrees))
		collider.shape.draw(get_canvas_item(), Color(0.3, 0.9, 0.7, 0.45))
		draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(-4, 0), Vector2(4, 0), Color.WHITE, 0.5)
	draw_line(Vector2(0, -4), Vector2(0, 4), Color.WHITE, 0.5)
	draw_string(ThemeDB.fallback_font, Vector2(-38, 37), name, HORIZONTAL_ALIGNMENT_CENTER, 76, 8, Color.WHITE)
