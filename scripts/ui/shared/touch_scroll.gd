extends RefCounted
## Let gestures reach the owning scroll container, including on newly built cards.
## Godot cancels a child button's press once its ancestor starts a touch drag.

static func attach(scroll: ScrollContainer) -> void:
	var callback := prepare_branch.bind(scroll)
	if not scroll.child_entered_tree.is_connected(callback):
		scroll.child_entered_tree.connect(callback)
	for child in scroll.get_children():
		prepare_branch(child, scroll)

static func prepare_branch(node: Node, scroll: ScrollContainer) -> void:
	# Layouts can move out of a scroll container (for example into a battlefield).
	# Old observers must never change input routing outside their owning scroll.
	if not is_instance_valid(scroll) or not scroll.is_ancestor_of(node):
		return
	# Nested scroll areas and text editors own their own input and gestures.
	if node is ScrollContainer or node is LineEdit or node is TextEdit or node is Range:
		return
	# Custom previews can set their input filter in _ready(). Apply after that.
	if not node.is_node_ready():
		var ready_callback := prepare_branch.bind(node, scroll)
		if not node.ready.is_connected(ready_callback):
			node.ready.connect(ready_callback, CONNECT_ONE_SHOT)
		return
	if node is Control and node.mouse_filter == Control.MOUSE_FILTER_STOP:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
		# Restore the original filter when a prepared control leaves this tree.
		node.tree_exiting.connect(func():
			if node.mouse_filter == Control.MOUSE_FILTER_PASS:
				node.mouse_filter = Control.MOUSE_FILTER_STOP
		, CONNECT_ONE_SHOT)
	var callback := prepare_branch.bind(scroll)
	if not node.child_entered_tree.is_connected(callback):
		node.child_entered_tree.connect(callback)
	for child in node.get_children():
		prepare_branch(child, scroll)
