class_name VigilEconomy
extends RefCounted

signal sound_requested(cue: String, position: Vector2)

signal tower_upgraded(region: String, pad: int, kind: String)

var data: Dictionary
var tower_cells: Dictionary = {}
var indexed_tower_count := -1

func ensure_tower_index() -> void:
	if indexed_tower_count == data.towers.size():
		return
	tower_cells.clear()
	for id in data.towers:
		var tower: Dictionary = data.towers[id]
		if not tower_cells.has(tower.region):
			tower_cells[tower.region] = {}
		tower_cells[tower.region][int(tower.pad)] = id
	indexed_tower_count = data.towers.size()

func towers_in_regions(regions: Array[String]) -> Array[Dictionary]:
	ensure_tower_index()
	var result: Array[Dictionary] = []
	for region in regions:
		for id in tower_cells.get(region, {}).values():
			result.append(data.towers[id])
	# Tower IDs are assigned monotonically; preserve their original draw order.
	result.sort_custom(func(a, b): return int(a.id) < int(b.id))
	return result
var tuning: Dictionary:
	get: return data.settings.get("developer_balance", {})

func _init(shared_data: Dictionary) -> void:
	data = shared_data

func unclaimed() -> float:
	var total: float = data.reserve
	for t in data.towers.values():
		total = minf(Balance.MAX_MONEY, total + t.earnings)
	return total

func spend(cost: float) -> bool:
	if not is_finite(cost) or cost <= 0.0 or data.balance < cost:
		return false
	data.balance = maxf(0.0, data.balance - cost)
	return true

func _add_tower(kind: String, region: String, pad: int) -> String:
	var id := str(data.next_tower)
	data.next_tower += 1
	indexed_tower_count = -1
	data.towers[id] = {"id": id, "kind": kind, "region": region, "pad": pad, "level": 1, "earnings": 0.0, "cooldown": 0.0, "angle": 0.0, "rebuild_remaining": 0.0, "target_mode": "first"}
	return id

func tower_at(region: String, pad: int) -> String:
	ensure_tower_index()
	return tower_cells.get(region, {}).get(pad, "")

func needs_first_property() -> bool:
	# Saves created before onboarding was introduced remain unrestricted.
	return data.get("first_property_required", false)

func build(kind: String, region: String, pad: int) -> String:
	if needs_first_property():
		return ""
	if not Balance.TOWERS.has(kind) or not data.regions.has(region) or pad < 0 or pad >= 4 or tower_at(region, pad) != "":
		return ""
	if not spend(Balance.tuned_value("towers", kind, "cost", tuning)):
		return ""
	var id := _add_tower(kind, region, pad)
	sound_requested.emit("menu_build", Vector2.INF)
	return id

func upgrade(id: String, expected_level: int = -1, branch: String = "") -> bool:
	if not data.towers.has(id):
		return false
	var t: Dictionary = data.towers[id]
	if (t.level == 3 and not Balance.valid_branch(t.kind, branch)) or (t.level != 3 and branch != ""):
		return false
	if expected_level != -1 and t.level != expected_level:
		return false
	if t.get("rebuild_remaining", 0.0) > 0.0 or t.level >= Balance.MAX_TOWER_LEVEL or not spend(Balance.upgrade_cost(t, tuning)):
		return false
	t.level += 1
	if t.level == 4:
		t.branch = branch
	sound_requested.emit("menu_upgrade" if branch == "" else "upgrade_" + branch, Vector2.INF)
	tower_upgraded.emit(t.region, int(t.pad), t.kind)
	return true

func relocate(id: String, region: String, pad: int, expected_level: int = -1) -> bool:
	if not data.towers.has(id) or not data.regions.has(region) or pad < 0 or pad >= 4 or tower_at(region, pad) != "":
		return false
	var tower: Dictionary = data.towers[id]
	if tower.get("rebuild_remaining", 0.0) > 0.0 or (expected_level != -1 and tower.level != expected_level):
		return false
	if not spend(Balance.move_cost(tower, tuning)):
		return false
	indexed_tower_count = -1
	tower.region = region
	tower.pad = pad
	tower.rebuild_remaining = Balance.rebuild_seconds(tower, tuning)
	sound_requested.emit("menu_move", Vector2.INF)
	tower.cooldown = 0.0
	# Old firing positions cannot demonstrate production at the new socket.
	for source in data.regions.values():
		source.history.erase(id)
	return true

func traffic_cost(id: String) -> float:
	return ceil(Balance.TRAFFIC_BASE_COST * pow(Balance.TRAFFIC_COST_GROWTH, data.regions[id].traffic))

func sell(id: String, expected_level: int = -1) -> Dictionary:
	if not data.towers.has(id):
		return {}
	var tower: Dictionary = data.towers[id]
	if expected_level != -1 and tower.level != expected_level:
		return {}
	var refund := Balance.sell_refund(tower, tuning)
	var earnings: float = tower.earnings
	# Remove ownership and historical production before issuing the one-time payout.
	data.towers.erase(id)
	indexed_tower_count = -1
	for region in data.regions.values():
		region.history.erase(id)
	data.balance = minf(Balance.MAX_MONEY, data.balance + refund + earnings)
	sound_requested.emit("menu_sell", Vector2.INF)
	return {"refund": refund, "earnings": earnings, "total": refund + earnings}

func spawn_period(id: String) -> float:
	return Balance.traffic_period(data.regions[id].traffic)

func buy_traffic(id: String, expected_level: int = -1) -> bool:
	if not VigilWorld.has_rift(id) or not data.regions.has(id):
		return false
	var r: Dictionary = data.regions[id]
	if (expected_level != -1 and r.traffic != expected_level) or r.traffic >= Balance.MAX_TRAFFIC_LEVEL or not spend(traffic_cost(id)):
		return false
	r.traffic += 1
	sound_requested.emit("menu_traffic", Vector2.INF)
	return true

func unlock(id: String, kind: String) -> bool:
	if not VigilWorld.has_rift(id) or not data.regions.has(id) or not Balance.UNLOCK_COSTS.has(kind) or kind in data.regions[id].unlocks:
		return false
	if data.regions[id].get("style", "forest") == "castle_ruin":
		return false
	if not spend(Balance.UNLOCK_COSTS[kind]):
		return false
	data.regions[id].unlocks.append(kind)
	sound_requested.emit("menu_unlock", Vector2.INF)
	return true

func buy_automation() -> bool:
	if data.automation or not spend(Balance.AUTOMATION_COST):
		return false
	data.automation = true
	sound_requested.emit("menu_automation", Vector2.INF)
	return true

func collect(id: String = "") -> float:
	var amount := 0.0
	if id == "":
		amount = data.reserve
		data.reserve = 0.0
		for t in data.towers.values():
			amount += t.earnings
			t.earnings = 0.0
	elif data.towers.has(id):
		amount = data.towers[id].earnings
		data.towers[id].earnings = 0.0
	data.balance = minf(Balance.MAX_MONEY, data.balance + amount)
	return amount

func credit(id: String, amount: float) -> void:
	amount = Balance.safe(amount)
	if data.towers.has(id):
		data.towers[id].earnings = minf(Balance.MAX_MONEY, data.towers[id].earnings + amount)
	else:
		data.reserve = minf(Balance.MAX_MONEY, data.reserve + amount)
	data.lifetime_earnings = minf(Balance.MAX_MONEY, data.lifetime_earnings + amount)
