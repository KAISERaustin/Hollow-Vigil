extends RefCounted

static func arm(tree: SceneTree, seconds: float = 180.0) -> void:
	tree.create_timer(seconds).timeout.connect(func():
		push_error("Test run timed out before completing. Inspect its log for script errors.")
		tree.quit(1)
	)
