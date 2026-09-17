extends RefCounted
## Reusable lesson definitions. The run supplies availability and encounter data.
const Unlocks = preload("res://scripts/content/nodes/campaign_unlocks.gd")
const ROLES := {
	"rapid": "Fast shots for steady damage.",
	"splash": "Blast groups of enemies at once.",
	"heavy": "Heavy hits with a long reach.",
	"electric": "Strike several enemies at once.",
	"ironspike": "Pierce enemies lined up on a road.",
	"moonwheel": "Hit enemies on the way out and back.",
	"caltrop_keep": "Lay traps on nearby roads. Traps do not block enemies.",
	"hex_lantern": "Support nearby towers and make cursed enemies take more damage."
}

static func lesson(id: String, title: String, body: String, rows: Array = []) -> Dictionary:
	return {"ids": [id], "title": title, "body": body, "rows": rows}

static func next(run: RefCounted, history: RefCounted) -> Dictionary:
	if run.phase != "planning": return {}
	if history.allows("construction"):
		return lesson("construction", "Build your defenses", "Stop enemies before they reach the core. Drag a tower from the bottom strip onto clear ground beside a road.", [
			{"kind": "rapid", "category": "towers", "name": "Drag → Place → Defend", "text": "Keep roads and portals clear. Towers need room and attack enemies within range."}])
	if run.game.data.towers.is_empty(): return {}
	if history.allows("waves"):
		return lesson("waves", "Ready for the first wave?", "Tap Start wave when your towers are ready. Defeat enemies to earn gold, then spend it on your defenses.", [
			{"kind": "basic", "category": "enemies", "name": "Protect the core", "text": "Enemies that get through damage the core. Use the information button to inspect waves; pause whenever you need time."}])
	if run.wave > 0 and history.allows("management"):
		return lesson("management", "Make your gold count", "Tap a tower to inspect it, move it, or sell it. Check the shown cost or refund before confirming.", [
			{"kind": "rapid", "category": "towers", "name": "Cover more of the road", "text": "Place towers where enemies stay in range longer. Mix tower types as you unlock them."}])
	return {}

static func milestone(run: RefCounted, history: RefCounted) -> Dictionary:
	var index := int(run.mission.index)
	if index > 24: return {}
	var id := "unlock/%d" % index
	if not history.allows(id): return {}
	if index == 24:
		return lesson(id, "Choose a specialization", "Tier 4 offers two branches for each tower. Inspect both before choosing: the branch is permanent for that tower.")
	var kind: String = Unlocks.ORDER[index % 8]
	var tier := int(index / 8.0) + 1
	if not run.game.economy.tower_available(kind, tier): return {}
	var title: String = Balance.TOWERS[kind].name
	var body := "Drag it from the tower strip to try it." if tier == 1 else "Tap a placed tower to inspect its next upgrade and gold cost. Upgrade when you are ready."
	return lesson(id, "New tower" if tier == 1 else "New tower upgrade", body, [
		{"category": "towers", "kind": kind, "tier": tier, "name": "%s · Tier %d" % [title, tier], "text": ROLES[kind]}])

static func encounters(run: RefCounted, history: RefCounted) -> Dictionary:
	var rows: Array = []
	var ids: Array = []
	var next_wave := int(run.wave)
	while next_wave < run.mission.waves.size() and run.mission.waves[next_wave].is_empty(): next_wave += 1
	if next_wave >= run.mission.waves.size(): return {}
	for group in run.mission.waves[next_wave]:
		var kind: String = group[0]
		var id := "enemy/" + kind
		if not history.allows(id) or id in ids: continue
		var boss: bool = Balance.BOSSES.has(kind)
		var definition: Dictionary = Balance.BOSSES[kind] if boss else Balance.ENEMIES.get(kind, {})
		if definition.is_empty(): continue
		ids.append(id)
		rows.append({"category": "bosses" if boss else "enemies", "kind": kind, "name": definition.name, "text": definition.get("description", "Check the wave details and prepare your defenses.")})
	if rows.is_empty(): return {}
	return {"ids": ids, "title": "New enemies ahead", "body": "These enemies appear in the next wave. You can prepare before starting it.", "rows": rows}
