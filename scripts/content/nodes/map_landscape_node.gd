extends "res://scripts/content/nodes/content_node.gd"

## Reusable, stateless Chapter presentation component. Static backgrounds are
## baked offline; copied recipes share immutable textures, not mutable state.
func presentation(config: Dictionary) -> Dictionary:
	return attributes().merged(config, true).duplicate(true)
