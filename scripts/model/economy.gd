class_name VigilEconomy
extends RefCounted

var data: Dictionary

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
	data.towers[id] = {"id": id, "kind": kind, "region": region, "pad": pad, "level": 1, "earnings": 0.0, "cooldown": 0.0, "angle": 0.0}
	return id

func tower_at(region: String, pad: int) -> String:
	for id in data.towers:
		var t: Dictionary = data.towers[id]
		if t.region == region and t.pad == pad:
			return id
	return ""

func build(kind: String, region: String, pad: int) -> String:
	if not Balance.TOWERS.has(kind) or not data.regions.has(region) or pad < 0 or pad >= 4 or tower_at(region, pad) != "":
		return ""
	if not spend(Balance.TOWERS[kind].cost):
		return ""
	return _add_tower(kind, region, pad)

func upgrade(id: String, expected_level: int = -1) -> bool:
	if not data.towers.has(id):
		return false
	var t: Dictionary = data.towers[id]
	if expected_level != -1 and t.level != expected_level:
		return false
	if t.level >= Balance.MAX_TOWER_LEVEL or not spend(Balance.upgrade_cost(t)):
		return false
	t.level += 1
	return true

func traffic_cost(id: String) -> float:
	return ceil(Balance.TRAFFIC_BASE_COST * pow(Balance.TRAFFIC_COST_GROWTH, data.regions[id].traffic))

func sell(id: String, expected_level: int = -1) -> Dictionary:
	if not data.towers.has(id):
		return {}
	var tower: Dictionary = data.towers[id]
	if expected_level != -1 and tower.level != expected_level:
		return {}
	var refund := Balance.sell_refund(tower)
	var earnings: float = tower.earnings
	# Remove ownership and historical production before issuing the one-time payout.
	data.towers.erase(id)
	for region in data.regions.values():
		region.history.erase(id)
	data.balance = minf(Balance.MAX_MONEY, data.balance + refund + earnings)
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
	return true

func unlock(id: String, kind: String) -> bool:
	if not VigilWorld.has_rift(id) or not data.regions.has(id) or not Balance.UNLOCK_COSTS.has(kind) or kind in data.regions[id].unlocks:
		return false
	if not spend(Balance.UNLOCK_COSTS[kind]):
		return false
	data.regions[id].unlocks.append(kind)
	return true

func buy_automation() -> bool:
	if data.automation or not spend(Balance.AUTOMATION_COST):
		return false
	data.automation = true
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
