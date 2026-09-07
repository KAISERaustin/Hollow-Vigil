extends RefCounted
const Group = preload("res://scripts/content/nodes/build_group_node.gd")
const DEFINITIONS := {
	"enemies": {"name": "Enemies", "description": "Health, movement, rewards and other values for selected enemy types."},
	"bosses": {"name": "Bosses", "description": "Stats and abilities for selected boss types."},
	"towers": {"name": "Towers", "description": "Stats for selected tower types, including their upgrades and specializations."},
	"gear": {"name": "Gear", "description": "Values for selected equipment types."},
	"rifts": {"name": "Rifts", "description": "Effects for selected rift types."},
	"resources": {"name": "Starting resources", "description": "Starting gold and Campaign sanctuary flame."},
	"layout": {"name": "Tower layout and equipment", "description": "Placed towers, upgrades and equipment. Requires their placement tiles or level sockets."},
	"terrain": {"name": "Explored tiles", "description": "The explored Infinite map and its portal settings.", "game_type": "infinite"},
	"timing": {"name": "Wave timing and counts", "description": "Counts, delays and spawn intervals for each wave's groups.", "game_type": "campaign"},
	"composition": {"name": "Enemy types and entrances", "description": "Which enemies appear in each wave and which entrances they use.", "game_type": "campaign"},
	"rewards": {"name": "Wave rewards", "description": "Gold awarded when each wave is cleared.", "game_type": "campaign"}
}

static func populate(registry: RefCounted, parent: VigilContentNode) -> void:
	var family := Group.new("build_contents", parent, {"name": "Build contents"})
	registry.register_node(family)
	for key in DEFINITIONS:
		var attributes: Dictionary = DEFINITIONS[key].duplicate(true)
		var rules := {"game_type": attributes.get("game_type", "both"), "category": key if key in ["enemies", "bosses", "towers", "gear", "rifts"] else ""}
		registry.register_node(family.derive("build_contents/" + key, attributes, rules), "build_contents", key)
