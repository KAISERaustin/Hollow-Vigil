extends RefCounted

const Content = preload("res://scripts/content/registry.gd")

static func run(t) -> void:
	for style in VigilWorld.ALL_STYLES:
		var portal := Content.portal(style)
		var costs := portal.unlock_costs()
		var base := portal.visual_parts(0, [])
		for mask in range(1 << costs.size()):
			var unlocks: Array = []
			for index in range(costs.size()):
				if mask & (1 << index): unlocks.append(costs.keys()[index])
			var before := unlocks.duplicate()
			var mix := portal.spawn_mix(unlocks)
			var previous := {}
			for level in range(Balance.MAX_TRAFFIC_LEVEL + 1):
				var parts := portal.visual_parts(level, unlocks)
				var shown: Array = parts.ornaments.map(func(part): return part.kind)
				t.check(shown == portal.available_kinds(unlocks), style + " ornaments exactly reflect available inhabitants")
				t.check(level == 0 or parts != previous, style + " each spawn-rate level adds a part")
				t.check(unlocks == before and portal.spawn_mix(unlocks) == mix, "Appearance never mutates attunements or probabilities")
				previous = parts
			unlocks.reverse()
			t.check(portal.visual_parts(12, unlocks) == previous, "Purchase order does not rearrange ornaments")
			t.check(portal.visual_parts(0, []) == base, "Another instance stays visually unchanged")
		var removed = portal.without_component("test/" + style, "appearance")
		t.check(removed.visual_parts(12, costs.keys()).ornaments.is_empty(), "Removing appearance removes ornaments")
		var attachment: Dictionary = portal.rule("components")[0]
		var restored = removed.with_component("test/restored/" + style, "appearance", attachment.component, attachment.config)
		t.check(restored.visual_parts(12, costs.keys()) == portal.visual_parts(12, costs.keys()), "Shared appearance supports reassignment")
		var copy := portal.visual_parts(12, costs.keys())
		copy.ornaments[0].motif = "invalid"
		t.check(portal.visual_parts(0, []) == base, "Resolved parts never modify the shared component")
		var game := VigilState.new(879)
		game.data.balance = 1.0e12
		game.expand("1,0")
		game.expand("2,0")
		game.data.regions["1,0"].style = style
		game.data.regions["2,0"].style = style
		for kind in costs: t.check(game.economy.unlock("1,0", kind), "Real attunement transaction succeeds")
		for level in range(Balance.MAX_TRAFFIC_LEVEL): t.check(game.economy.buy_traffic("1,0"), "Real traffic transaction succeeds")
		var snapshot := game.snapshot(1000.0)
		var region: Dictionary = snapshot.regions["1,0"]
		t.check(portal.visual_parts(region.traffic, region.unlocks) == portal.visual_parts(12, costs.keys()), "Visuals reconstruct from existing save fields")
		t.check(game.data.regions["2,0"].traffic == 0 and game.data.regions["2,0"].unlocks.is_empty(), "Upgraded appearance cannot spread to neighbors")
		t.check(game.snapshot(1000.0) == snapshot, "Appearance leaves all saved gameplay state intact")
	print("PASS GROUP: portal appearance, all rate levels and attunements, attachment removal and instance isolation")
