extends RefCounted

# Combat uses this flight duration to resolve damage when the visual arrives.
# Target identities track centers without retaining pooled enemy dictionaries.
static func shot(kind: String, origin: Vector2, target: Vector2, stats: Dictionary, target_id: int = -1, ballistic: bool = false) -> Dictionary:
	return Balance.Content.projectile(kind).shot(origin, target, stats, target_id, ballistic)
