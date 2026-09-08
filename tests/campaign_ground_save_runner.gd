extends "res://tests/test_runner.gd"

const Run = preload("res://scripts/campaign/run.gd")
const Slots = preload("res://scripts/persistence/campaign_slots.gd")

func run() -> void:
	var slots := Slots.new()
	slots.base_path = "user://campaign-ground-save-" + str(Time.get_ticks_usec())
	for mode in ["survival", "creative"]:
		var saved := slots.create(0, mode, "Ground save regression")
		for index in Run.Catalog.COUNT:
			var battle := Run.new(index, {}, mode)
			battle.game.data.balance = 100000
			for region in battle.game.data.regions:
				var built := false
				for y in range(-130, 131, 40):
					for x in range(-130, 131, 40):
						var point := VigilWorld.center(region) + Vector2(x, y)
						if built or not battle.game.economy.ground_allowed(point): continue
						var location := VigilWorld.ground_location(point)
						built = not battle.game.economy.build("rapid", location.region, location.pad).is_empty()
			for phase in ["planning", "wave", "between_waves"]:
				if phase == "wave": battle.start_wave()
				if phase == "between_waves":
					battle.phase = "planning"
					battle.wave = 1
				saved.completed = index
				saved.checkpoint = battle.checkpoint()
				var label := "%s level %d %s" % [mode, index + 1, phase]
				check(slots.save_slot(0, saved), label + " saves legal ground towers")
				var loaded := slots.summary(0)
				var restored := Run.from_checkpoint(loaded.get("checkpoint", {}))
				check(restored != null, label + " resumes from disk")
				if restored != null:
					check(JSON.parse_string(JSON.stringify(restored.game.data.towers)) == JSON.parse_string(JSON.stringify(battle.game.data.towers)), label + " restores every tower")
					check(restored.wave == battle.wave and restored.phase == battle.phase and restored.game.data.balance == battle.game.data.balance, label + " restores wave and gold")
			var invalid := saved.duplicate(true)
			var tower: Dictionary = invalid.checkpoint.state.towers.values()[0]
			var portal := VigilWorld.ground_location(battle.mission.routes[0][0])
			tower.region = portal.region
			tower.pad = portal.pad
			check(not slots.save_slot(0, invalid), "Illegal portal placement remains rejected")
			check(slots.summary(0).sequence == saved.sequence, "Rejected save preserves previous checkpoint")
		check(slots.delete_slot(0), "Remove isolated fixture")
	print("CAMPAIGN GROUND SAVE: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
