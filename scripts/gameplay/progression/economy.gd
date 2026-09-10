class_name VigilEconomy
extends RefCounted

signal sound_requested(cue: String, position: Vector2)

signal relic_changed(tower_id: String)
signal tower_changed(tower_id: String)

signal tower_upgraded(region: String, pad: int, kind: String)

var data: Dictionary
var sale_rules: VigilContentNode
var placement_roads: Array = []
var placement_bounds := Rect2()

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

func spend(cost: float) -> bool:
	if not is_finite(cost) or cost <= 0.0 or data.balance < cost:
		return false
	data.balance = maxf(0.0, data.balance - cost)
	return true

func _add_tower(kind: String, region: String, pad: int) -> String:
	var id := str(data.next_tower)
	data.next_tower += 1
	indexed_tower_count = -1
	data.towers[id] = Balance.Content.tower(kind).create(id, region, pad)
	return id

func tower_at(region: String, pad: int) -> String:
	ensure_tower_index()
	return tower_cells.get(region, {}).get(pad, "")

func can_place(kind: String, region: String, pad: int) -> bool:
	var node := Balance.Content.tower(kind)
	if node == null or pad < 0 or pad > VigilWorld.MAX_GROUND_PAD:
		return false
	return node.can_place("ground", data.regions.has(region), tower_at(region, pad) != "") and (pad < 4 or ground_allowed(VigilWorld.pad_position(region, pad)))

func ground_allowed(point: Vector2, ignore_id: String = "") -> bool:
	return preload("res://scripts/content/nodes/ground_placement.gd").allowed(data, point, placement_roads, placement_bounds, ignore_id)

func build(kind: String, region: String, pad: int) -> String:
	if not can_place(kind, region, pad):
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
	if t.get("rebuild_remaining", 0.0) > 0.0 or t.level >= Balance.MAX_TOWER_LEVEL or not spend(Balance.upgrade_cost(t, tuning, branch)):
		return false
	t.level += 1
	if t.level == 4:
		t.branch = branch
	tower_changed.emit(id)
	var upgrade_sound: String = Balance.Content.tower(t.kind).rule("upgrade_sound", "")
	if upgrade_sound.is_empty():
		upgrade_sound = "menu_upgrade" if branch == "" else "upgrade_" + branch
	sound_requested.emit(upgrade_sound, Vector2.INF)
	tower_upgraded.emit(t.region, int(t.pad), t.kind)
	return true

func relocate(id: String, region: String, pad: int, expected_level: int = -1) -> bool:
	if not data.towers.has(id) or not can_place(data.towers[id].kind, region, pad):
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
	relic_changed.emit(id)
	sound_requested.emit("menu_move", Vector2.INF)
	tower.cooldown = 0.0
	# Old firing positions cannot demonstrate production at the new socket.
	clear_tower_history(id)
	return true

func set_sale_rules(definition: VigilContentNode) -> void:
	# Run-local attachment/replacement/removal; shared content stays immutable.
	sale_rules = definition

func sell_refund(tower: Dictionary) -> float:
	var refund := Balance.sell_refund(tower, tuning)
	if sale_rules != null:
		for entry in sale_rules.rule("components", []):
			if entry.component.has_method("sale_refund"):
				refund = entry.component.sale_refund(tower, tuning, refund, entry.config)
	return refund

func sell(id: String, expected_level: int = -1) -> Dictionary:
	if not data.towers.has(id):
		return {}
	var tower: Dictionary = data.towers[id]
	if expected_level != -1 and tower.level != expected_level:
		return {}
	var refund := sell_refund(tower)
	var earnings: float = tower.earnings
	# Remove ownership and historical production before issuing the one-time payout.
	data.towers.erase(id)
	relic_changed.emit(id)
	indexed_tower_count = -1
	clear_tower_history(id)
	data.balance = minf(Balance.MAX_MONEY, data.balance + refund + earnings)
	sound_requested.emit("menu_sell", Vector2.INF)
	return {"refund": refund, "earnings": earnings, "total": refund + earnings}

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

# Empty identity removes the equipped piece; replacing or selling never destroys it.
func equip_relic(id: String, relic_id: String, expected_current: String, expected_owner: String = "") -> bool:
	return false

func clear_tower_history(id: String) -> void:
	# Relearn production after combat power moves between towers.
	for region in data.regions.values():
		region.history.erase(id)
