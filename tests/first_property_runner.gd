extends SceneTree

var checks := 0
var failures := 0
const SAVE_PATH := "user://first-property-test.save"

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func clean_save() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SAVE_PATH + suffix):
			DirAccess.remove_absolute(SAVE_PATH + suffix)

func run() -> void:
	clean_save()
	var game := VigilState.new(123)
	game.save_path = SAVE_PATH
	check(not game.load_save(1000.0) and game.economy.needs_first_property(), "First launch requires a property")
	var before := game.data.duplicate(true)
	for kind in Balance.TOWERS:
		for pad in range(4):
			check(game.economy.build(kind, "0,0", pad) == "" and game.data == before, "No starting tower can spend the 280 gold")
	check(not game.expand("5,5") and game.economy.needs_first_property(), "Invalid property does not unlock towers")
	game.data.balance = 0.0
	check(not game.expand("1,0") and game.economy.needs_first_property(), "Failed purchase does not unlock towers")
	game.data.balance = Balance.STARTING_GOLD
	check(game.save(1000.0), "Pending requirement can be saved")
	var loaded := VigilState.new(321)
	loaded.save_path = SAVE_PATH
	check(loaded.load_save(1000.0) and loaded.economy.needs_first_property(), "Reopening before purchase keeps the lock")
	check(loaded.expand("1,0") and loaded.data.balance == 180.0 and not loaded.economy.needs_first_property(), "First property leaves 180 gold and unlocks towers")
	check(loaded.save(1000.0) and game.load_save(1000.0) and not game.economy.needs_first_property(), "Unlock survives reopening before any tower is built")
	var id := game.economy.build("rapid", "0,0", 0)
	check(id != "", "Tower purchase succeeds after property purchase")
	check(not game.economy.sell(id).is_empty() and not game.economy.needs_first_property(), "Selling all towers never repeats onboarding")
	check(game.save(1000.0) and loaded.load_save(1000.0) and not loaded.economy.needs_first_property(), "Unlock survives saving with no towers")
	check(loaded.reset_progress() and loaded.data.balance == 280.0 and loaded.economy.needs_first_property(), "Reset restores starting gold and the requirement")
	check(game.load_save() and game.economy.needs_first_property() and game.economy.build("rapid", "0,0", 0) == "", "Reset requirement survives reopening")
	var legacy := VigilState.new(456).snapshot(1000.0)
	legacy.erase("first_property_required")
	clean_save()
	check(game.storage.write(SAVE_PATH, legacy) and game.load_save(1000.0), "Existing save without onboarding field still loads")
	check(not game.economy.needs_first_property() and game.economy.build("rapid", "0,0", 0) != "", "Existing core-only saves remain unrestricted")
	legacy.first_property_required = "true"
	check(not game.storage.valid_data(legacy), "Malformed requirement is rejected")
	clean_save()
	print("RESULT: %d first-property checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
