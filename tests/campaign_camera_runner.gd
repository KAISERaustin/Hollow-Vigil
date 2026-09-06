extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	for index in range(20):
		var board := preload("res://scripts/campaign/board.gd").new()
		board.run = preload("res://scripts/campaign/run.gd").new(index)
		board.size = Vector2(390, 530)
		root.add_child(board)
		check(board is Battlefield, "Campaign inherits the original battlefield")
		for viewport in [Vector2(360, 300), Vector2(540, 650), Vector2(1200, 500)]:
			board.size = viewport
			board.reset_view()
			for direction in [Vector2.ONE, -Vector2.ONE, Vector2(1, -1), Vector2(-1, 1)]:
				board.camera = direction * 100000
				board.enforce_camera_limits()
				check(board.camera_bounds().grow(0.1).encloses(Rect2(board.world(Vector2.ZERO), viewport / board.zoom)), "Campaign viewport stays near the trail")
		board.reset_view()
		var pivot := board.size * 0.5
		var before := board.world(pivot)
		board.set_zoom(board.zoom * 1.25, pivot)
		check(board.world(pivot).is_equal_approx(before), "Zoom keeps its world anchor")
		var socket: Dictionary = board.run.mission.sockets[0]
		board.pick(board.screen(socket.position))
		check(board.selected == socket.index, "Authored socket remains selectable")
		board.tap(Vector2(-10000, -10000))
		check(board.selected == -1, "Empty tap clears selection")
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.position = pivot
		press.pressed = true
		board._on_gui_input(press)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = pivot + Vector2(30, 0)
		board._on_gui_input(drag)
		press.pressed = false
		press.position = drag.position
		board._on_gui_input(press)
		check(board.dragged and board.selected == -1 and board.touches.is_empty(), "Touch pan releases without selecting a socket")
		board.free()
	print("Campaign camera: %d failures" % failures)
	quit(1 if failures else 0)
