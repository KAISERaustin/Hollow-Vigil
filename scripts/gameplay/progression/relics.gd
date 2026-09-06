extends RefCounted

# Each encounter's source coordinate is the permanent identity of its drop.
const DEFINITIONS := {
	"warden": {"name": "Warden’s Rootheart", "color": "a9d58b", "symbol": "root", "description": "Every 6 seconds, a primary shot roots its target for 0.75 seconds (0.35 for bosses). Each enemy can be rooted only once every 3 seconds."},
	"cindermaw": {"name": "Ember Fang", "color": "ffa568", "symbol": "fang", "description": "Consecutive attacks on the same primary target gain 8% attack speed, up to 40%. Resets when the target changes or attacks stop for 3 seconds."},
	"bell": {"name": "Tollstone", "color": "8ce3dc", "symbol": "bell", "description": "Every fourth attack echoes the primary shot at 50% base damage. The echo keeps its blast radius but triggers no specialization or relic effects."},
	"prior": {"name": "Eclipse Shard", "color": "d2adf3", "symbol": "eclipse", "description": "Every fifth attack empowers its primary shot: +50% damage and bypasses boss shields, armor and wards. Its blast shares this power; secondary arrows, chains and damage over time do not pierce."}
}

static func kind(data: Dictionary, tower: Dictionary) -> String:
	return data.get("relics", {}).get(tower.get("relic", ""), "")

static func owner(data: Dictionary, relic_id: String) -> String:
	if relic_id == "":
		return ""
	for tower in data.towers.values():
		if tower.get("relic", "") == relic_id:
			return tower.id
	return ""

static func migrate(data: Dictionary) -> void:
	if data.has("relics"):
		return
	data.relics = {}
	# Older progress receives each recorded victory once, without paying gold again.
	for records in [data.regions, data.get("castles", {})]:
		for source in records:
			var boss: Dictionary = records[source].get("boss", {})
			if boss.get("status", "") == "defeated" and DEFINITIONS.has(boss.get("kind", "")):
				data.relics[source] = boss.kind

static func award(data: Dictionary, source: String, boss_kind: String) -> bool:
	if not data.has("relics"):
		data.relics = {}
	if data.relics.has(source) or not DEFINITIONS.has(boss_kind):
		return false
	data.relics[source] = boss_kind
	return true

static func prepare(combat: VigilCombat, tower: Dictionary, target: Dictionary, stats: Dictionary) -> Dictionary:
	var relic_kind := kind(combat.data, tower)
	if relic_kind == "":
		return stats
	var result := stats.duplicate()
	var progress: Dictionary = combat.relic_progress.get(tower.id, {"attacks": 0, "target": -1, "stacks": 0, "last": -100.0, "root_ready": 0.0})
	progress.attacks += 1
	match relic_kind:
		"warden":
			if combat.simulation_time >= progress.root_ready:
				result.relic_root = true
				progress.root_ready = combat.simulation_time + 6.0
		"cindermaw":
			progress.stacks = mini(5, int(progress.stacks) + 1) if progress.target == target.id and combat.simulation_time - progress.last < 3.0 else 0
			result.period /= 1.0 + progress.stacks * 0.08
		"bell":
			result.relic_echo = int(progress.attacks) % 4 == 0
		"prior":
			result.relic_pierce = int(progress.attacks) % 5 == 0
	progress.target = target.id
	progress.last = combat.simulation_time
	combat.relic_progress[tower.id] = progress
	return result

static func root_target(combat: VigilCombat, shot: Dictionary, enemy: Dictionary) -> void:
	if not shot.get("relic_root", false) or enemy.id != shot.get("target_id", -1) or enemy.get("root_immune_until", 0.0) > combat.simulation_time:
		return
	enemy.root_until = combat.simulation_time + (0.35 if enemy.get("boss", false) else 0.75)
	enemy.root_immune_until = combat.simulation_time + 3.0
