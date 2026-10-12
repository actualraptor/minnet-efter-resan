class_name ItemLibrary
extends RefCounted
## Satchel item definitions from data/items/items.json:
## {id: {name, kind: book|scroll, desc, teaches: spell id, consumed: bool}}.

const PATH := "res://data/items/items.json"
static var _items: Dictionary = {}


static func get_item(id: String) -> Dictionary:
	if _items.is_empty():
		var d: Variant = DialogueRunner._read_json(PATH)
		_items = d if d is Dictionary else {}
	return _items.get(id, {})
