extends RefCounted

const Content = preload("res://scripts/content/registry.gd")
const Catalog = preload("res://scripts/campaign/catalog.gd")

static func run(t) -> void:
	inheritance(t)
	content_coverage(t)
	tower_instances(t)
	actor_instances(t)
	level_instances(t)
	print("PASS GROUP: content hierarchy, derived types, shared rules, isolated instances and catalogs")

static func inheritance(t) -> void:
	var input := {"combat": {"damage": 10, "period": 1.0}, "tags": ["entity"]}
	var parent := Content.ContentNode.new("base", null, input, {"placement": "plus"}, {"history": {}, "effects": []})
	var child := parent.derive("child", {"combat": {"damage": 20}, "tags": ["tower"]})
	input.combat.period = 9.0
	t.check(child.is_a("base") and child.is_a("child") and not parent.is_a("child"), "Content ancestry is directional and includes self")
	t.check(child.attribute("combat") == {"damage": 20, "period": 1.0}, "Children override one nested attribute and inherit siblings")
	t.check(parent.attribute("combat").damage == 10 and child.rule("placement") == "plus", "Deriving a subtype preserves parent attributes and shared placement")
	t.check(child.attribute("tags") == ["tower"], "Child arrays replace parent arrays deliberately")
	var snapshot := child.attributes()
	snapshot.combat.damage = 99
	var record := child.make_record()
	record.history["test"] = 7
	record.effects.append("slow")
	t.check(child.attribute("combat").damage == 20 and child.make_record().history.is_empty() and child.make_record().effects.is_empty(), "Definition copies and live records cannot mutate future instances")
	var registry := Content.new(false)
	t.check(not registry.register_node(child), "Registration rejects an unregistered parent")
	t.check(registry.register_node(parent) and registry.register_node(child, "samples", "child"), "Registry accepts a parent before its child")
	t.check(not registry.register_node(child) and not registry.register_node(parent.derive("other"), "samples", "child"), "Duplicate IDs and duplicate category keys cannot overwrite content")
	t.check(registry.get_node("missing") == null and registry.find("samples", "missing") == null, "Unknown content resolves explicitly to null")
	t.check(registry.children("base") == [child] and registry.descendants("base") == [child], "Registry supports direct-child and descendant discovery")
	var definitions := registry.definitions("samples")
	t.check(definitions.is_read_only() and definitions.child.combat.is_read_only(), "Shared catalog views are recursively read only")
	t.check(registry.register_node(parent.derive("sibling"), "samples", "sibling") and registry.definitions("samples").has("sibling"), "Adding content invalidates the category cache")

static func content_coverage(t) -> void:
	var registry := Content.catalog()
	for family in ["tower", "enemy", "boss", "gear", "projectile", "ability", "region", "portal", "socket", "landmark", "level", "wave", "targeting"]:
		t.check(registry.get_node(family) != null and not registry.descendants(family).is_empty(), "Registered content family: " + family)
	for category in ["towers", "enemies", "bosses", "gear", "rifts"]:
		for kind in Balance.definitions(category):
			var node := registry.find(category, kind)
			t.check(node != null and node.attributes() == Balance.definitions(category)[kind], "Runtime content resolves from a node: " + category + "/" + kind)
	t.check(Content.tower("heavy") != Content.enemy("heavy"), "Tower and enemy IDs cannot collide")
	for kind in Balance.BOSSES:
		t.check(Content.boss(kind).is_a("boss") and Content.boss(kind).is_a("enemy") and Content.boss(kind) is Content.EnemyNode, "Boss inherits enemy behavior: " + kind)
	for kind in Balance.ENEMIES:
		t.check(not Content.enemy(kind).is_a("boss"), "Ordinary enemy does not acquire boss defenses")
	for style in VigilWorld.ALL_STYLES:
		t.check(Content.portal(style).enemy_kinds() == Balance.portal_kinds(style), "Portal subtype supplies its spawn family")
		t.check(Content.region(style).create("1,0", "0,0", 0, 24.0).style == style, "Terrain subtype stamps saved region style")
	t.check(Content.portal("mourning_orchard").accepts("briarling") and not Content.portal("mourning_orchard").accepts("basic"), "Exclusive portal rejects a foreign enemy family")
	t.check(Content.locks_target("most_hp") and not Content.locks_target("first") and not Content.locks_target("last"), "Only Most HP inherits a persistent target lock")

static func tower_instances(t) -> void:
	var registry := Content.new()
	# A new Pike subtype reuses Ashneedle's existing combat/upgrade mechanics.
	# This private registry keeps example content out of shipped menus and saves.
	var pike = registry.get_node("tower/rapid").derive("tower/pike", {"name": "Pike", "damage": 12.0}, {"kind": "pike"})
	t.check(registry.register_node(pike, "towers", "pike") and pike is Content.TowerNode, "New named tower subtypes reuse the family's implementation")
	t.check(pike.create("99", "1,0", 0).kind == "pike" and pike.stats(2).damage == 10.0, "Derived tower constructs its own identity and inherits authored upgrade stats")
	t.check(pike.stats(1).damage == 12.0 and Content.tower("rapid").stats(1).damage == 6.0, "Derived tower attributes do not retune their parent")
	for kind in Balance.TOWERS:
		var node := Content.tower(kind)
		t.check(node.can_place("plus", true, false), "Every tower fits a free owned plus socket")
		t.check(not node.can_place("road", true, false) and not node.can_place("plus", false, false) and not node.can_place("plus", true, true), "Tower family rejects wrong surface, unowned land and occupied sockets")
		for child in registry.descendants("tower/" + kind):
			if child.id == "tower/pike":
				continue
			var tower = child.create("5", "1,0", 2)
			t.check(tower.kind == kind and tower.level == child.rule("level"), "Tier instances retain save kind and acquire their inherited level")
			t.check(child.stats() == Balance.tower_stats(tower), "Tier nodes resolve through base scaling exactly once")
		for gear_kind in Balance.GEAR:
			t.check(node.can_equip(Content.gear(gear_kind)) and Content.gear(gear_kind).can_equip_on(node), "All existing relics fit the shared tower equipment slot")
	var game := t.legacy_core_fixture(91345)
	var balance: float = game.data.balance
	t.check(game.economy.build("missing", "0,0", 0) == "" and game.economy.build("rapid", "0,0", 4) == "" and game.data.balance == balance, "Invalid node placement never spends gold")
	var id := game.economy.build("rapid", "0,0", 0)
	t.check(id != "" and not game.economy.can_place("heavy", "0,0", 0), "Economy uses inherited placement and reserves the plus socket")
	t.check(not Content.gear("warden").can_equip_on(Content.enemy("basic")), "Gear rejects a non-tower recipient")

static func actor_instances(t) -> void:
	var route: Array[Vector2] = [Vector2.ZERO, Vector2(100, 0)]
	for kind in Balance.ENEMIES:
		var pooled := {"boss": true, "shield": 600.0, "slow_until": 99.0, "charges": {"1": 5}}
		var node := Content.enemy(kind)
		node.create_into(pooled, 17, "1,0", route, "forest")
		t.check(pooled.hp == Balance.ENEMIES[kind].hp and pooled.id == 17 and pooled.kind == kind and not pooled.dead and pooled.segment == 1, "Enemy subtype inherits fresh runtime identity, health and movement")
		t.check(not pooled.has("boss") and not pooled.has("shield") and not pooled.has("slow_until") and not pooled.has("charges"), "Pooled records cannot leak boss or status effects")
		var tuned := {"enemies": {kind: {"hp": 100.0}}}
		node.create_into({}, 18, "1,0", route, "ashen_forge", tuned, 1.25)
		t.check(pooled.hp == Balance.ENEMIES[kind].hp and node.definition().hp == Balance.ENEMIES[kind].hp, "Tuned spawning leaves earlier enemies and shared definitions independent")
	for kind in Balance.BOSSES:
		var node := Content.boss(kind)
		var enemy := node.create_encounter(20, "2,0", Vector2.ZERO)
		t.check(enemy.boss and node.escape_damage() == 20 and enemy.hp == Balance.BOSSES[kind].hp, "Boss construction inherits enemy fields and encounter-specific state")
		t.check(Content.catalog().get_node(node.rule("drop")) == Content.gear(kind), "Boss drop references its registered gear subtype")
	var warden := Content.boss("warden").create_encounter(20, "2,0", Vector2.ZERO)
	t.check(Content.boss("warden").absorb_damage(warden, 100.0, "", true) == 0.0 and warden.shield == 400.0, "Warden subtype consumes its shield with fire weakness")
	var prior := Content.boss("prior").create_encounter(21, "2,0", Vector2.ZERO)
	t.check(Content.boss("prior").absorb_damage(prior, 100.0, "doomstone", false) == 100.0 and prior.wards == 3, "Prior subtype allows ward-bypassing specialization")
	var bell := Content.gear("bell")
	var first := bell.make_record()
	var second := bell.make_record()
	for attack in range(4):
		var stats := bell.prepare(first, 1, float(attack), {"damage": 10.0, "period": 1.0})
		t.check(stats.relic_echo == (attack == 3), "Relic subtype fires its effect on the fourth attack")
	t.check(second.attacks == 0, "Gear counters belong to one equipped instance")

static func level_instances(t) -> void:
	for index in range(Catalog.COUNT):
		var node := Content.level(index)
		t.check(node.is_a("level/campaign") and node.is_a("level"), "Each mission inherits finite campaign level rules")
		var layout := node.layout()
		layout.waves[0][0][1] = 999
		t.check(node.layout().waves[0][0][1] != 999, "One run cannot mutate authored waves")
		for wave in range(node.attribute("waves").size()):
			var schedule := Content.wave(index, wave).schedule()
			for spawn in range(1, schedule.size()):
				var a: Dictionary = schedule[spawn - 1]
				var b: Dictionary = schedule[spawn]
				t.check(a.at < b.at or (a.at == b.at and a.order < b.order), "Wave nodes preserve stable simultaneous spawn order")
	t.check(Content.level(-1) == null and Content.level(Catalog.COUNT) == null, "Out-of-range levels do not construct an invalid mission")
	t.check(Content.catalog().get_node("level/creative").rule("developer_controls") and not Content.catalog().get_node("level/survival").rule("developer_controls"), "Creative and Survival inherit world rules and override editor access")
