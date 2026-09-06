extends RefCounted
## Let gestures reach the owning scroll container, including on newly built cards.
## Godot cancels a child button's press once its ancestor starts a touch drag.

static func attach(scroll: ScrollContainer) -> void:
	if not scroll.child_entered_tree.is_connected(prepare_branch):
		scroll.child_entered_tree.connect(prepare_branch)
	for child in scroll.get_children():
		prepare_branch(child)

static func prepare_branch(node: Node) -> void:
	# Nested scroll areas and text editors own their own input and gestures.
	if node is ScrollContainer or node is LineEdit or node is TextEdit or node is Range:
		return
	# Custom previews can set their input filter in _ready(). Apply after that.
	if not node.is_node_ready():
		var ready_callback := prepare_branch.bind(node)
		if not node.ready.is_connected(ready_callback):
			node.ready.connect(ready_callback, CONNECT_ONE_SHOT)
		return
	if node is Control and node.mouse_filter == Control.MOUSE_FILTER_STOP:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	if not node.child_entered_tree.is_connected(prepare_branch):
		node.child_entered_tree.connect(prepare_branch)
	for child in node.get_children():
		prepare_branch(child)
