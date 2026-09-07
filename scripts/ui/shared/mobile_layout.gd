extends Node
## Attachable layout observer for notches, rotation and overlay keyboards.
## Each screen owns its observer; removing the screen removes all polling state.
const UI = preload("res://scripts/ui/shared/interface.gd")
var host: Control
var previous := Rect2()
var layout_revision := 0

static func attach(control: Control) -> void:
	if control.has_node("MobileLayout"): return
	var observer := new()
	observer.name = "MobileLayout"
	observer.host = control
	control.add_child(observer)

func _ready() -> void:
	previous = UI.safe_rect(host)
	set_process(OS.has_feature("mobile"))

func _process(_delta: float) -> void:
	if not host.is_visible_in_tree(): return
	var current := UI.safe_rect(host)
	if current.is_equal_approx(previous): return
	previous = current
	layout_revision += 1
	host.resized.emit()
	reveal_after_layout(layout_revision)

func reveal_after_layout(revision: int) -> void:
	# Container sizes and scroll ranges update asynchronously. Revealing during
	# keyboard animation with the previous range makes the form jump back and forth.
	await get_tree().process_frame
	await get_tree().process_frame
	if revision == layout_revision and is_instance_valid(host) and host.is_visible_in_tree():
		reveal_focus()

func reveal_focus() -> void:
	var focus := host.get_viewport().gui_get_focus_owner()
	if focus == null or not host.is_ancestor_of(focus): return
	var parent := focus.get_parent()
	while parent != null and parent != host:
		if parent is ScrollContainer: parent.ensure_control_visible(focus)
		parent = parent.get_parent()
