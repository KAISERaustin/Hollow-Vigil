class_name VigilContentRegistry
extends RefCounted

## One discoverable tree for every gameplay content family. Stable IDs are
## namespaced (tower/heavy and enemy/heavy are intentionally different nodes).
const ContentNode = preload("res://scripts/content/nodes/content_node.gd")
const StatsNode = preload("res://scripts/content/nodes/stats_node.gd")
const TowerNode = preload("res://scripts/content/nodes/tower_node.gd")
const EnemyNode = preload("res://scripts/content/nodes/enemy_node.gd")
const BossNode = preload("res://scripts/content/nodes/boss_node.gd")
const GearNode = preload("res://scripts/content/nodes/gear_node.gd")
const LevelNode = preload("res://scripts/content/nodes/level_node.gd")
const RegionNode = preload("res://scripts/content/nodes/region_node.gd")
const PortalNode = preload("res://scripts/content/nodes/portal_node.gd")
const PortalVisualNode = preload("res://scripts/content/nodes/portal_visual_node.gd")
const PortalVisuals = preload("res://scripts/content/catalogs/portal_visuals.gd")
const ProjectileNode = preload("res://scripts/content/nodes/projectile_node.gd")
const WaveNode = preload("res://scripts/content/nodes/wave_node.gd")
const AbilityNode = preload("res://scripts/content/nodes/ability_node.gd")
const Towers = preload("res://scripts/content/catalogs/towers.gd")
const Actors = preload("res://scripts/content/catalogs/actors.gd")
const Gear = preload("res://scripts/content/catalogs/gear.gd")
const Attributes = preload("res://scripts/content/catalogs/attributes.gd")
const AttributeNode = preload("res://scripts/content/nodes/attribute_node.gd")
const World = preload("res://scripts/content/catalogs/world.gd")
const Levels = preload("res://scripts/content/catalogs/levels.gd")
const ChapterMaps = preload("res://scripts/content/catalogs/chapter_maps.gd")
const MapLandscapeNode = preload("res://scripts/content/nodes/map_landscape_node.gd")

const BOSS_TYPES := {
	"warden": preload("res://scripts/content/nodes/bosses/warden.gd"),
	"cindermaw": preload("res://scripts/content/nodes/bosses/cindermaw.gd"),
	"prior": preload("res://scripts/content/nodes/bosses/prior.gd")
}

static var _shared: VigilContentRegistry
var _nodes: Dictionary = {}
var _definitions: Dictionary = {}
var _tables: Dictionary = {}

static func catalog() -> VigilContentRegistry:
	if _shared == null:
		_shared = load("res://scripts/content/registry.gd").new()
	return _shared

func _init(include_builtins: bool = true) -> void:
	if include_builtins:
		_populate()

func register_node(entry: ContentNode, category: String = "", kind: String = "") -> bool:
	if entry == null or entry.id.is_empty() or _nodes.has(entry.id):
		return false
	if entry.parent != null and _nodes.get(entry.parent.id) != entry.parent:
		return false
	if category != "" and (kind.is_empty() or _definitions.get(category, {}).has(kind)):
		return false
	_nodes[entry.id] = entry
	if category != "":
		if not _definitions.has(category):
			_definitions[category] = {}
		_definitions[category][kind] = entry
		StatsNode.Stats.register_baseline(category, kind, entry.attributes())
		_tables.erase(category)
	return true

func get_node(id: String) -> ContentNode:
	return _nodes.get(id)

func find(category: String, kind: String) -> ContentNode:
	return _definitions.get(category, {}).get(kind)

func children(id: String) -> Array[ContentNode]:
	var result: Array[ContentNode] = []
	for entry in _nodes.values():
		if entry.parent != null and entry.parent.id == id:
			result.append(entry)
	return result

func descendants(id: String) -> Array[ContentNode]:
	var result: Array[ContentNode] = []
	for entry in _nodes.values():
		if entry.id != id and entry.is_a(id):
			result.append(entry)
	return result

func definitions(category: String) -> Dictionary:
	if _tables.has(category):
		return _tables[category]
	var result := {}
	for kind in _definitions.get(category, {}):
		result[kind] = _definitions[category][kind].attributes()
	ContentNode._freeze(result)
	_tables[category] = result
	return result

static func tower(kind: String) -> TowerNode:
	var node := catalog().find("towers", kind) as TowerNode
	# Tier definitions are available through find(), but are never build kinds.
	return node if node != null and node.rule("base_kind", "").is_empty() else null

static func enemy(kind: String, is_boss: bool = false) -> EnemyNode:
	return catalog().find("bosses" if is_boss else "enemies", kind) as EnemyNode

static func boss(kind: String) -> BossNode:
	return catalog().find("bosses", kind) as BossNode

static func gear(kind: String) -> GearNode:
	return catalog().find("gear", kind) as GearNode

static func level(index: int) -> LevelNode:
	return catalog().find("levels", str(index)) as LevelNode

static func portal(style: String) -> PortalNode:
	return catalog().get_node("portal/" + style) as PortalNode

static func region(style: String) -> RegionNode:
	return catalog().get_node("region/" + style) as RegionNode

static func projectile(kind: String) -> ProjectileNode:
	return catalog().find("projectiles", kind) as ProjectileNode

static func wave(level_index: int, wave_index: int) -> WaveNode:
	return catalog().get_node("wave/" + str(level_index) + "/" + str(wave_index)) as WaveNode

static func ability(kind: String) -> AbilityNode:
	return catalog().find("abilities", kind) as AbilityNode

static func locks_target(mode: String) -> bool:
	var node := catalog().get_node("targeting/" + mode)
	return node != null and node.attribute("lock_target", false)

func _add(entry: ContentNode, category: String = "", kind: String = "") -> ContentNode:
	var registered := register_node(entry, category, kind)
	assert(registered, "Duplicate or invalid content node: " + entry.id)
	return entry

func _populate() -> void:
	var root := _add(ContentNode.new("content"))
	var stats_root := _add(StatsNode.new("stats", root))
	var entity := _add(StatsNode.new("entity", stats_root))
	for category in StatsNode.Stats.CATEGORIES:
		for field in StatsNode.Stats.schema(category):
			if not StatsNode.Stats.control(field):
				_add(ContentNode.new("stats/" + category + "/" + field, stats_root, StatsNode.Stats.schema(category)[field]), "stats", category + "/" + field)
	_add(TowerNode.new("tower", entity, {"targets": 1}, {"placement": "ground", "equipment_slots": ["relic"], "target_modes": ["first", "last", "most_hp"], "max_level": 4, "tuning_category": "towers"},
		{"level": 1, "earnings": 0.0, "cooldown": 0.0, "angle": 0.0, "rebuild_remaining": 0.0, "target_mode": "first"}))
	_add(EnemyNode.new("enemy", entity, {}, {"tuning_category": "enemies", "escape_damage": 1, "movement": "road", "authored_paths": true, "targetable": true}, {"segment": 1, "dead": false}))
	_add(BossNode.new("boss", get_node("enemy"), {}, {"tuning_category": "bosses", "escape_damage": 20, "movement": "patrol"}, {"boss": true, "path": [], "previous": "", "steps": 0, "toll_delayed": false}))
	_add(GearNode.new("gear", entity, {}, {"tuning_category": "gear", "slot": "relic", "equipped_on": "tower"}, {"attacks": 0, "target": -1, "last": -100.0, "components": {}}))
	_add(AttributeNode.new("attribute", root))
	for capability in StatsNode.Stats.Capabilities.ENEMY:
		_add(preload("res://scripts/content/nodes/enemy_capability.gd").new("enemy_ability/" + capability, get_node("attribute"), {}, {"behavior": capability}), "enemy_abilities", capability)
	for field in StatsNode.Stats.Capabilities.RESISTANCES:
		_add(preload("res://scripts/content/nodes/resistance_node.gd").new("resistance/" + field, get_node("attribute"), {}, {"stat": field}), "resistances", field)
	for kind in Attributes.TYPES:
		_add(Attributes.TYPES[kind].new("attribute/" + kind, get_node("attribute"), {}, Attributes.RULES.get(kind, {})), "attributes", kind)
	_add(ProjectileNode.new("projectile", root, {}, {}, {"kind": "shot"}))
	_add(AbilityNode.new("ability", root))
	_add(ContentNode.new("targeting", root))
	for mode in ["first", "last", "most_hp"]:
		_add(ContentNode.new("targeting/" + mode, get_node("targeting"), {"lock_target": mode == "most_hp"}))
	_populate_towers()
	_populate_actors()
	_populate_world(root)
	_populate_levels(root)
	preload("res://scripts/content/catalogs/build_groups.gd").populate(self, root)

func _populate_towers() -> void:
	for kind in Towers.TOWERS:
		var attachments := []
		for slot in Towers.ATTACHMENTS.get(kind, {}):
			attachments.append({"slot": slot, "component": find("attributes", Towers.ATTACHMENTS[kind][slot]), "config": {}})
		var branch_attachments := {}
		for branch in Towers.BRANCHES[kind]:
			branch_attachments[branch] = {}
			for slot in Towers.ATTACHMENTS.get(branch, {}):
				branch_attachments[branch][slot] = find("attributes", Towers.ATTACHMENTS[branch][slot])
		var tower_type := TowerNode.new("tower/" + kind, get_node("tower"), Towers.TOWERS[kind],
			{"kind": kind, "components": attachments, "branch_attachments": branch_attachments, "upgrade_sound": Towers.UPGRADE_SOUNDS.get(kind, ""), "upgrades": Towers.TOWER_UPGRADES[kind], "branches": Towers.BRANCHES[kind], "abilities": Towers.ABILITIES, "multipliers": Towers.BRANCH_STAT_MULTIPLIERS})
		_add(tower_type, "towers", kind)
		_add(ProjectileNode.new("projectile/" + kind, get_node("projectile"), Towers.PROJECTILES[kind], {"kind": kind}), "projectiles", kind)
		var previous: ContentNode = tower_type
		for tier in [2, 3]:
			var stats := tower_type.scaled_stats(tier)
			stats.cost = Towers.TOWER_UPGRADES[kind][tier - 2].cost
			previous = _add(TowerNode.new("tower/" + kind + "/" + str(tier), previous, stats, {"kind": kind + ":" + str(tier), "base_kind": kind, "level": tier}, {"level": tier}), "towers", kind + ":" + str(tier))
		for branch in Towers.BRANCHES[kind]:
			var stats := tower_type.scaled_stats(4, {}, branch)
			stats.cost = Towers.BRANCHES[kind][branch].cost
			_add(TowerNode.new("tower/" + kind + "/" + branch, previous, stats, {"kind": kind + ":" + branch, "base_kind": kind, "branch": branch, "level": 4, "components": tower_type.at_level(4, branch).rule("components")}, {"level": 4, "branch": branch}), "towers", kind + ":" + branch)
			var components := []
			for component in Towers.COMPONENTS.get(branch, []):
				components.append({"slot": component, "component": find("attributes", component), "config": {}})
			_add(AbilityNode.new("ability/" + branch, get_node("ability"), Towers.ABILITIES[branch], {"tower": kind, "components": components}), "abilities", branch)

func _populate_actors() -> void:
	for family in Actors.FAMILIES:
		var parent := _add(EnemyNode.new("enemy/" + family, get_node("enemy"), {}, {"portal_style": family, "art": "orchard" if family == "mourning_orchard" else "classic"}))
		var kinds: Array = Actors.FAMILIES[family]
		for kind in kinds:
			var rules: Dictionary = Actors.ENEMY_RULES.get(kind, {}).merged({"kind": kind, "scripted": kind in Actors.CAMPAIGN_KINDS, "escort": kind in Actors.ESCORT_KINDS, "death_cue": "death_" + kind})
			rules.merge(Actors.PRESENTATION.get(kind, {}), true)
			_add(EnemyNode.new("enemy/" + kind, parent, Actors.ENEMIES[kind], rules), "enemies", kind)
	for kind in Actors.BOSSES:
		_add(BOSS_TYPES.get(kind, BossNode).new("boss/" + kind, get_node("boss"), Actors.BOSSES[kind], {"kind": kind, "presentation": Actors.BOSS_PRESENTATION.get(kind, {}), "drop": "gear/" + kind, "drops": Gear.BOSS_DROPS[kind]}), "bosses", kind)
	for kind in Gear.GEAR:
		var components := []
		for attribute_kind in Gear.ATTRIBUTES[kind]:
			components.append({"slot": attribute_kind, "component": get_node("attribute/" + attribute_kind), "config": {}})
		_add(GearNode.new("gear/" + kind, get_node("gear"), Gear.GEAR[kind], {"kind": kind, "presentation": Gear.PRESENTATION[kind], "components": components}), "gear", kind)

func _populate_world(root: ContentNode) -> void:
	var world := _add(ContentNode.new("world", root))
	var presentation := _add(ContentNode.new("presentation", root))
	var portal_visual := _add(PortalVisualNode.new("presentation/portal", presentation, {}, {"rate_parts": PortalVisuals.RATE_PARTS, "max_level": 12}))
	var portal_effects := _add(preload("res://scripts/content/nodes/attributes/portal_enemy_effects.gd").new("attribute/portal_enemy_effects", get_node("attribute")))
	_add(RegionNode.new("region", world, {}, {}, World.REGION_DEFAULTS))
	_add(PortalNode.new("portal", world, {}, {"tuning_category": "rifts", "exclusive": true, "allow_escorts": true}))
	var socket := _add(ContentNode.new("socket", world, {}, {"occupants": ["tower"], "capacity": 1}))
	_add(ContentNode.new("socket/plus", socket, {"name": "Tower socket", "positions": World.PADS}, {"kind": "plus"}))
	var landmark := _add(ContentNode.new("landmark", world))
	for kind in World.LANDMARKS:
		_add(ContentNode.new("landmark/" + kind, landmark, World.LANDMARKS[kind]))
	for style in World.ALL_STYLES:
		_add(RegionNode.new("region/" + style, get_node("region"), {}, {"kind": style, "portal": "portal/" + style, "boss": World.BIOME_BOSSES[style]}))
		var config: Dictionary = World.PORTALS[style]
		var attributes: Dictionary = World.RIFTS.get(style, {"name": config.name}).duplicate(true)
		attributes.merge({"armor_percent": 0.0, "health_regen_percent": 0.0})
		var rules: Dictionary = config.merged({"kind": style, "enemy_kinds": Actors.FAMILIES[style]})
		var ornaments := {}
		for kind in Actors.FAMILIES[style]:
			ornaments[kind] = PortalVisuals.ORNAMENTS[kind]
		rules["components"] = [{"slot": "appearance", "component": portal_visual, "config": {"order": Actors.FAMILIES[style], "ornaments": ornaments, "mounts": PortalVisuals.PIT_MOUNTS if style == "castle_ruin" else PortalVisuals.MOUNTS}}]
		rules.components.append({"slot": "enemy_effects", "component": portal_effects, "config": {}})
		_add(PortalNode.new("portal/" + style, get_node("portal"), attributes, rules), "rifts", style)

func _populate_levels(root: ContentNode) -> void:
	var level_root := _add(LevelNode.new("level", root))
	var campaign := _add(LevelNode.new("level/campaign", level_root, {}, {"finite_waves": true, "expansion": false, "max_health": Levels.MAX_HEALTH, "components": [{"slot": "setup_refund", "component": get_node("attribute/investment_refund"), "config": {"ratio": 1.0}}]}))
	_add(LevelNode.new("level/session", campaign, Levels.SESSION, {"kind": "start", "tuning_category": "session"}), "session", "start")
	for mode in ["creative", "survival"]:
		_add(LevelNode.new("level/campaign/" + mode, campaign, {}, {"developer_controls": mode == "creative"}))
	var wave_root := _add(WaveNode.new("wave", root))
	var landscape := _add(MapLandscapeNode.new("presentation/map_landscape", root))
	for chapter in range(Levels.CHAPTERS.size()):
		_add(LevelNode.new("level/chapter/" + str(chapter), campaign, {}, {"chapter": Levels.CHAPTERS[chapter],
			"components": campaign.rule("components", []) + [{"slot": "map_landscape", "component": landscape, "config": ChapterMaps.PROFILES[Levels.CHAPTERS[chapter].style]}]}))
	for index in range(Levels.MISSIONS.size()):
		var attributes: Dictionary = Levels.MISSIONS[index].duplicate(true)
		attributes.index = index
		attributes.chapter = int(index / 5.0)
		attributes.style = Levels.CHAPTERS[int(index / 5.0)].style
		attributes.reward = 35 + index * 4
		attributes.tuning = {}
		_add(LevelNode.new("level/" + str(index), get_node("level/chapter/" + str(int(index / 5.0))), attributes), "levels", str(index))
		for wave_index in range(attributes.waves.size()):
			_add(WaveNode.new("wave/" + str(index) + "/" + str(wave_index), wave_root, {"groups": attributes.waves[wave_index]}, {"level": index, "wave": wave_index}))
