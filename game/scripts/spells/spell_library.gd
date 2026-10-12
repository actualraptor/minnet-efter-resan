class_name SpellLibrary
extends RefCounted
## Every spell she can put on a number key, by id. (The Solstråk firing modes
## are modes of the one spell, not separate entries.) Add new spells here.

const FILES := {
	"spell_field_of_flowers": "field_of_flowers",
	"spell_zoltraak": "zoltraak",
	"spell_barrier": "barrier",
	"spell_zoltraak_original": "zoltraak_original",
	"spell_stain_free": "stain_free",
}

static var _cache: Dictionary = {}


static func get_def(id: String) -> SpellDefinition:
	if not FILES.has(id):
		return null
	if not _cache.has(id):
		_cache[id] = load("res://data/spells/%s.tres" % FILES[id]) as SpellDefinition
	return _cache[id]


static func all_ids() -> Array:
	return FILES.keys()
