extends RefCounted

const Content = preload("res://scripts/content/registry.gd")
const Illustration = preload("res://scripts/rendering/actors/gear/illustration.gd")
const FAMILIES := {
	"warden": preload("res://scripts/rendering/actors/gear/forest.gd"),
	"cindermaw": preload("res://scripts/rendering/actors/gear/forge.gd"),
	"bell": preload("res://scripts/rendering/actors/gear/crypt.gd"),
	"prior": preload("res://scripts/rendering/actors/gear/sanctuary.gd"),
	"ruined_king": preload("res://scripts/rendering/actors/gear/royal.gd"),
	"mourning_matriarch": preload("res://scripts/rendering/actors/gear/orchard.gd")
}

# Each Gear node supplies its identity and motif. The same native illustration
# renders collection portraits, developer choices, equipped badges and drops.
static func draw(canvas: CanvasItem, kind: String, center: Vector2, scale_value: float = 1.0) -> void:
	var gear := Content.gear(kind)
	if gear == null:
		return
	var presentation: Dictionary = gear.rule("presentation", {})
	var family: String = presentation.get("boss", "")
	if FAMILIES.has(family):
		FAMILIES[family].draw(Illustration.new(canvas, center, scale_value), presentation.symbol)
