extends RefCounted

## Used only by the isolated profiling snapshot; never loaded by the game.
static var enabled := false
static var totals: Dictionary = {}
static var calls: Dictionary = {}

static func record(label: String, elapsed: int) -> void:
	if not enabled: return
	totals[label] = totals.get(label, 0) + elapsed
	calls[label] = calls.get(label, 0) + 1

static func reset() -> void:
	totals.clear()
	calls.clear()

static func report() -> Dictionary:
	return {"inclusive_usec": totals.duplicate(), "calls": calls.duplicate()}
