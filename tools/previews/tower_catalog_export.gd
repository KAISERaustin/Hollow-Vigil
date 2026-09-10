extends SceneTree

func _initialize() -> void:
	var rows := []
	for kind in Balance.TOWERS:
		var total := 0.0
		for level in [1, 2, 3]:
			var price: float = Balance.TOWERS[kind].cost if level == 1 else Balance.TOWER_UPGRADES[kind][level - 2].cost
			total += price
			rows.append({"kind": kind, "level": level, "branch": "", "price": price, "total": total, "stats": Balance.stats(kind, level)})
		for branch in Balance.BRANCHES[kind]:
			var price: float = Balance.BRANCHES[kind][branch].cost
			rows.append({"kind": kind, "level": 4, "branch": branch, "price": price, "total": total + price, "stats": Balance.stats(kind, 4, {}, branch)})
	for row in rows:
		row["description"] = Balance.tower_description(row.stats)
	FileAccess.open("res://artifacts/tower-catalog.json", FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	print("TOWER CATALOG: ", rows.size(), " stages exported")
	quit()
