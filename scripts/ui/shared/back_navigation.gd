extends RefCounted
## One Back transition per viewport input batch, shared by every menu owner.

class Transition extends Node:
	var blocked_through_frame := -1
	var dispatching := false

	func run(action: Callable) -> void:
		# System Back can delegate to a dialog's on-screen Back action.
		if dispatching:
			action.call()
			return
		if Engine.get_process_frames() <= blocked_through_frame: return
		# Let the replacement page complete layout before it can receive Back.
		blocked_through_frame = Engine.get_process_frames() + 1
		dispatching = true
		action.call()
		dispatching = false

static func invoke(source: Control, action: Callable) -> void:
	# queue_free leaves old buttons alive until the end of the frame. Their
	# queued signals must never navigate a replacement page or a hidden menu.
	if not is_instance_valid(source) or not source.is_inside_tree() or not source.is_visible_in_tree() or source.is_queued_for_deletion(): return
	if source is BaseButton and source.disabled: return
	if not action.is_valid(): return
	var viewport := source.get_viewport()
	var transition := viewport.get_node_or_null("BackNavigation") as Transition
	if transition == null:
		transition = Transition.new()
		transition.name = "BackNavigation"
		viewport.add_child(transition)
	transition.run(action)

static func protect(button: Button) -> void:
	if button.has_meta("back_navigation_protected"): return
	button.set_meta("back_navigation_protected", true)
	for connection in button.pressed.get_connections():
		var action: Callable = connection.callable
		button.pressed.disconnect(action)
		button.pressed.connect(invoke.bind(button, action))
