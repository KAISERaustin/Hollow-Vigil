class_name VigilContentNode
extends RefCounted

## A reusable definition in the content tree, independent of the scene tree.
## Parents own shared attributes/rules/defaults; children override only differences.
## Runtime dictionaries remain owned by simulation services and save stores.

var id: String:
	get: return _id
var parent: VigilContentNode:
	get: return _parent
var _id: String
var _parent: VigilContentNode
var _attributes: Dictionary
var _rules: Dictionary
var _defaults: Dictionary

func _init(key: String = "", ancestor: VigilContentNode = null, attribute_values: Dictionary = {}, rules: Dictionary = {}, defaults: Dictionary = {}) -> void:
	_id = key
	_parent = ancestor
	_attributes = _inherit(ancestor._attributes if ancestor != null else {}, attribute_values)
	_rules = _inherit(ancestor._rules if ancestor != null else {}, rules)
	_defaults = _inherit(ancestor._defaults if ancestor != null else {}, defaults)
	_freeze(_attributes)
	_freeze(_rules)
	_freeze(_defaults)

static func _inherit(base: Dictionary, changes: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in changes:
		if changes[key] is Dictionary and result.get(key) is Dictionary:
			result[key] = _inherit(result[key], changes[key])
		else:
			result[key] = _copy(changes[key])
	return result

static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

static func _freeze(value: Variant) -> void:
	if value is Dictionary or value is Array:
		for child in value.values() if value is Dictionary else value:
			_freeze(child)
		value.make_read_only()

func is_a(ancestor_id: String) -> bool:
	var cursor: VigilContentNode = self
	while cursor != null:
		if cursor.id == ancestor_id:
			return true
		cursor = cursor.parent
	return false

func attributes() -> Dictionary:
	return _attributes.duplicate(true)

func attribute(key: String, fallback: Variant = null) -> Variant:
	return _copy(_attributes.get(key, fallback))

func rule(key: String, fallback: Variant = null) -> Variant:
	return _copy(_rules.get(key, fallback))

func definition(tuning: Dictionary = {}) -> Dictionary:
	var result := attributes()
	result.merge(tuning.get(_rules.get("tuning_category", ""), {}).get(_rules.get("kind", ""), {}), true)
	return result

func make_record(fields: Dictionary = {}) -> Dictionary:
	return _inherit(_defaults, fields)

func derive(key: String, attribute_values: Dictionary = {}, rules: Dictionary = {}, defaults: Dictionary = {}) -> VigilContentNode:
	# Preserve the family implementation when adding another data-only subtype.
	return get_script().new(key, self, attribute_values, rules, defaults)
