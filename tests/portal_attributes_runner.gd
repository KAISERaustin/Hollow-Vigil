extends "res://tests/test_runner.gd"

func run() -> void:
	check_resistances()
	for style in Balance.portal_definitions():
		var tuning := {"rifts": {style: {"armor_percent": 25.0, "health_regen_percent": 10.0}}}
		check(Balance.valid_tuning(tuning), "Every portal accepts both attributes: " + style)
		var exported: Dictionary = preload("res://scripts/campaign/configuration.gd").gameplay_values(tuning)
		check(exported.rifts[style].armor_percent == 25.0 and exported.rifts[style].health_regen_percent == 10.0, "Export retains portal effects")
		var game := VigilState.new(123, "creative")
		check(game.apply_balance(tuning), "Apply portal attributes")
		game.combat.scripted_spawns = true
		game.data.towers["test"] = {"kind": "rapid", "level": 1}
		var path: Array[Vector2] = [Vector2(-10000, 0), Vector2(10000, 0)]
		for kind in ["basic", "lantern"]:
			var enemy := game.combat.spawn_on_path(kind, path, style)
			enemy.hp = enemy.max_hp * 0.5
			var before: float = enemy.hp
			game.combat.hit(enemy, 8.0, "test")
			check(is_equal_approx(enemy.hp, before - 6.0), "Portal armor affects different enemy types")
			before = enemy.hp
			game.data.towers.clear()
			game.combat.tick(0.1)
			var regen := 0.011 if style == "bloodmoon_sanctuary" else 0.01
			check(is_equal_approx(enemy.hp, before + enemy.max_hp * regen), "Combat applies regeneration without sharing health")
			game.data.towers["test"] = {"kind": "rapid", "level": 1}
		var other := "forest" if style != "forest" else "mourning_orchard"
		check(Balance.Content.portal(other).incoming_damage(8.0, tuning) == 8.0, "Unassigned portal unchanged")
		check(Balance.Content.portal(style).incoming_damage(8.0, {}) == 8.0, "Removing attributes restores damage")
		check(Balance.Content.portal(style).attribute("armor_percent") == 0.0, "Shared defaults unchanged")
		var detached = Balance.Content.portal(style).without_component("portal/test", "enemy_effects")
		check(detached.incoming_damage(8.0, tuning) == 8.0, "Removing component removes its behavior")
		var replaced = detached.with_component("portal/test", "enemy_effects", Balance.Content.catalog().get_node("attribute/portal_enemy_effects"), {"armor_percent": 50.0})
		check(replaced.incoming_damage(8.0, tuning) == 4.0 and Balance.Content.portal(style).incoming_damage(8.0, tuning) == 6.0, "Replacing component leaves source unchanged")
		var recipient := {"hp": 99.0, "max_hp": 100.0, "dead": false}
		Balance.Content.portal(style).advance_enemy(recipient, 2.0, tuning)
		check(recipient.hp == 100.0, "Regeneration capped at maximum health")
		var checkpoint_run = preload("res://scripts/campaign/run.gd").new(0, {"tuning": tuning}, "creative")
		var restored = preload("res://scripts/campaign/run.gd").from_checkpoint(checkpoint_run.checkpoint())
		check(restored != null and restored.game.tuning.rifts[style].armor_percent == 25.0, "Checkpoint retains portal rules")
		var index: int = Balance.portal_definitions().keys().find(style) * 5
		var boss_run = preload("res://scripts/campaign/run.gd").new(index, {"tuning": tuning, "waves": {"0": {"groups": [["ruined_king", 1, 0, 0.0, 1.0]]}}}, "creative")
		boss_run.start_wave()
		boss_run.tick(0.05)
		var boss: Dictionary = boss_run.game.combat.enemies[0]
		check(boss.get("portal_effect_style") == style, "Authored boss inherits source portal")
		boss.hp = boss.max_hp * 0.5
		boss_run.game.data.towers["test"] = {"kind": "rapid", "level": 1}
		var boss_before: float = boss.hp
		boss_run.game.combat.hit(boss, 8.0, "test")
		check(is_equal_approx(boss.hp, boss_before - 6.0), "Boss receives portal armor")
		boss_run.game.data.towers.clear()
		boss_before = boss.hp
		boss_run.game.combat.tick(0.1)
		check(is_equal_approx(boss.hp, boss_before + boss.max_hp * 0.01), "Boss receives portal regeneration")
	print("PORTAL ATTRIBUTES: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func check_resistances() -> void:
	const Effects = preload("res://scripts/content/nodes/attributes/portal_enemy_effects.gd")
	for style in Balance.portal_definitions():
		var values := {}
		for field in Effects.RESISTANCES: values[field] = 50.0
		var tuning := {"rifts": {style: values}}
		check(Balance.valid_tuning(tuning), "Four resistances validate on " + style)
		var exported: Dictionary = preload("res://scripts/campaign/configuration.gd").gameplay_values(tuning)
		for field in values:
			check(exported.rifts[style][field] == 50.0, "Resistance exported: " + field)
		var game := VigilState.new(123, "creative")
		game.apply_balance(tuning)
		game.combat.scripted_spawns = true
		var tower := Balance.Content.tower("electric").create("storm", "0,0", 0)
		game.data.towers.storm = tower
		var path: Array[Vector2] = [Vector2.ZERO, Vector2(0, 10000)]
		for kind in ["basic", "lantern"]:
			var enemy := game.combat.spawn_on_path(kind, path, style)
			for tier in range(1, 5):
				tower.level = tier
				tower.branch = "thunderseal" if tier == 4 else ""
				var stats := Balance.tower_stats(tower, game.tuning)
				var shot := game.combat.Projectiles.make_shot(game.combat, tower, Vector2.ZERO, enemy, stats)
				check(shot.damage_type == "electric", "Every Stormspire tier emits electric damage")
				enemy.hp = enemy.max_hp
				if tier == 4: enemy.charges = {tower.id: 4}
				var before: float = enemy.hp
				game.combat.resolve_shot(shot, enemy)
				var expected: float = stats.damage * 0.5 * (1.0 + stats.seal_damage if tier == 4 else 1.0)
				check(is_equal_approx(before - enemy.hp, expected), "Resistance reduces Stormspire hit and charged seal")
			for damage_type in ["physical", "poison", "fire"]:
				enemy.hp = enemy.max_hp
				game.combat.hit(enemy, 8.0, tower.id, "", damage_type == "fire", false, damage_type)
				check(is_equal_approx(enemy.max_hp - enemy.hp, 8.0), "Electric resistance does not affect " + damage_type)
			enemy.stun_until = 0.0
			enemy.slow_until = 100.0
			enemy.slow_percent = 40.0
			check(is_equal_approx(game.combat.enemy_speed(enemy), Balance.definition("enemies", kind, tuning).speed * Balance.rift_speed_multiplier(style, tuning) * 0.8), "Slow resistance reduces slow strength")
			enemy.gear_status = {}
			game.combat.Relics.add_status(enemy, tower.id, "test_poison", {"type": "dot", "damage": 8.0, "until": 100.0, "fire": false})
			var before: float = enemy.hp
			game.combat.Relics.advance(game.combat, 1.0)
			check(is_equal_approx(before - enemy.hp, 4.0), "Poison from electric tower uses poison resistance exactly once")
			check(is_equal_approx(game.combat.Relics.push_resistance(game.combat, enemy), 50.0), "Gear knockback uses portal resistance")
		var other := game.combat.spawn_on_path("basic", path, "mourning_orchard" if style != "mourning_orchard" else "forest")
		game.combat.hit(other, 8.0, tower.id)
		check(is_equal_approx(other.max_hp - other.hp, 8.0), "Other portal retains full electric damage")
		var replay = preload("res://scripts/campaign/run.gd").new(0, {"tuning": tuning}, "creative")
		var restored = replay.from_checkpoint(replay.checkpoint())
		check(restored != null and restored.game.tuning.rifts[style] == values, "Checkpoint retains four resistances")
		var boss := game.combat.Bosses.create(game.combat, "0,0", "ruined_king", path)
		boss.portal_effect_style = style
		var boss_before: float = boss.hp
		game.combat.hit(boss, 8.0, tower.id)
		check(is_equal_approx(boss_before - boss.hp, 4.0), "Portal electric resistance includes bosses")
		var immune := {"rifts": {style: {"electric_resistance": 100.0}}}
		game.data.towers.clear()
		game.apply_balance(immune)
		game.data.towers.storm = tower
		boss_before = boss.hp
		game.combat.hit(boss, 8.0, tower.id, "", false, true)
		check(boss.hp == boss_before, "100 percent electric resistance survives armor bypass")
		game.data.towers.clear()
		game.apply_balance({})
		game.data.towers.storm = tower
		boss_before = boss.hp
		game.combat.hit(boss, 8.0, tower.id)
		check(is_equal_approx(boss_before - boss.hp, 8.0), "Removing resistance updates live bosses")
	check_chain_lightning()

func check_chain_lightning() -> void:
	var game := VigilState.new(123, "creative")
	game.combat.scripted_spawns = true
	game.apply_balance({"rifts": {"forest": {"electric_resistance": 50.0}}, "towers": {"electric:tempest_web": {"targets": 1}}})
	var tower := Balance.Content.tower("electric").create("storm", "0,0", 0)
	tower.level = 4
	tower.branch = "tempest_web"
	game.data.towers.storm = tower
	var path: Array[Vector2] = [Vector2(-70, -70), Vector2(-70, 1000)]
	var first := game.combat.spawn_on_path("basic", path, "forest")
	var second := game.combat.spawn_on_path("basic", path, "forest")
	game.combat.tick(0.01)
	var losses := [first.max_hp - first.hp, second.max_hp - second.hp]
	losses.sort()
	check(is_equal_approx(losses[0], 1.75) and is_equal_approx(losses[1], 3.5), "Real Stormspire pulse and chain arc both resist electric damage")
