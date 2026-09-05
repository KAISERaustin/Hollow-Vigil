extends RefCounted

static func run(suite: SceneTree) -> void:
	var g := VigilState.new(779)
	g.data.balance = 10000.0
	g.expand("1,0")
	var id := g.economy.build("rapid", "0,0", 0)
	var other := g.economy.build("splash", "1,0", 1)
	for i in range(5):
		g.economy.upgrade(id)
	suite.check(Balance.sell_refund(g.data.towers[id]) == 334.0, "Level-six refund is half the build price plus every rounded upgrade cost")
	g.economy.credit(id, 17.5)
	g.economy.credit(other, 9.0)
	for region in g.data.regions.values():
		region.history = {id: 60.0, other: 20.0}
		region.history_time = 60.0
	var before: Dictionary = g.data.duplicate(true)
	suite.check(g.economy.sell(id, 5).is_empty() and g.data == before, "Stale sale level cannot remove or pay for a tower")
	suite.check(g.economy.sell("missing").is_empty() and g.data == before, "Missing tower cannot be sold")
	var result := g.economy.sell(id, 6)
	suite.check(result == {"refund": 334.0, "earnings": 17.5, "total": 351.5}, "Sale includes every stored gold fraction")
	suite.check(g.data.balance == before.balance + 351.5 and not g.data.towers.has(id), "Sale atomically removes the tower and pays once")
	suite.check(g.data.lifetime_earnings == before.lifetime_earnings and g.data.kills == before.kills, "Refund is not counted as combat earnings or kills")
	suite.check(g.data.towers[other] == before.towers[other], "Sale preserves other towers and their uncollected earnings")
	for region in g.data.regions.values():
		suite.check(not region.history.has(id) and region.history[other] == 20.0, "Sale removes only its own historical production")
	var sold: Dictionary = g.data.duplicate(true)
	suite.check(g.economy.sell(id, 6).is_empty() and not g.economy.upgrade(id, 6) and g.economy.collect(id) == 0.0 and g.data == sold, "Repeated sale and stale tower actions cannot pay again")
	suite.check(g.storage.valid_data(g.data), "Sold tower leaves a valid save without dangling history")
	g.data.last_accounted = 1000.0
	g.apply_offline(1060.0)
	suite.check(g.data.reserve == 0.0 and not g.data.towers.has(id), "Sold tower cannot generate offline reserve gold or reappear")
	var rebuilt := g.economy.build("heavy", "0,0", 0)
	suite.check(rebuilt != "" and rebuilt != id and g.data.towers[rebuilt].level == 1, "Sale frees the socket for a fresh, separately identified tower")
	for kind in Balance.TOWERS:
		suite.check(Balance.sell_refund({"kind": kind, "level": 1}) == floor(Balance.TOWERS[kind].cost * 0.5), "Unupgraded %s refunds half its build price" % kind)
	print("PASS GROUP: tower sale refunds, stale actions, production cleanup, offline safety, and rebuilding")
