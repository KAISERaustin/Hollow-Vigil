extends RefCounted
## Immutable milestone definitions; each run owns its earned progress separately.
const ORDER := ["rapid", "splash", "heavy", "electric", "ironspike", "moonwheel", "caltrop_keep", "hex_lantern"]
const CHAPTER_SIZE := 8

static func required(kind: String, tier: int = 1) -> int:
	var offset := ORDER.find(kind)
	if offset < 0 or tier < 1 or tier > 4: return 49
	# Existing specializations remain available after the teaching chapters.
	return 24 if tier == 4 else (tier - 1) * CHAPTER_SIZE + offset

static func available(completed: int, kind: String, tier: int = 1) -> bool:
	return completed >= required(kind, tier)

static func reason(kind: String, tier: int = 1) -> String:
	var milestone := required(kind, tier)
	return "Unlocks at chapter %d, level %d" % [int(milestone / float(CHAPTER_SIZE)) + 1, milestone % CHAPTER_SIZE + 1]

static func introduction(index: int) -> String:
	if index < 0 or index >= 24: return ""
	var kind: String = ORDER[index % CHAPTER_SIZE]
	var title: String = preload("res://scripts/content/catalogs/towers.gd").TOWERS[kind].name
	return "%s · Tier %d unlocked" % [title, int(index / float(CHAPTER_SIZE)) + 1]
