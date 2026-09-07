extends "res://scripts/content/nodes/content_node.gd"

## Reusable, stateless Chapter presentation component. Layout belongs to the
## map instance; returning a copy keeps resized maps and sibling nodes isolated.
func presentation(config: Dictionary) -> Dictionary:
	return attributes().merged(config, true).duplicate(true)
