extends "res://tests/test_runner.gd"

func run() -> void:
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
