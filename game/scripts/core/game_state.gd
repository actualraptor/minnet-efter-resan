extends Node
## Global narrative/game state: flags, quests, relationships, memory events,
## world date and save/load. Deliberately the ONLY large singleton; systems such
## as spells, dialogue and the flower field are scene nodes that report here.

signal flag_changed(flag: String, value: Variant)
signal quest_changed(quest_id: String, state: String)
signal memory_recorded(memory: Dictionary)
signal spell_cast(spell_id: String, origin: Vector3, target: Vector3)
signal toast(text: String)
signal inventory_changed
signal spells_changed
signal time_advanced(hours: float)

const SAVE_VERSION := 1
const SAVE_PATH := "user://save_slot_1.json"

## Stable IDs for the protagonist and the cast. Keep in sync with docs/lore/CHARACTER_BIBLE.md.
const PROTAGONIST_ID := "char_freyja"

const DEFAULT_SPELLS: Array = ["spell_field_of_flowers", "spell_zoltraak", "spell_barrier", "spell_zoltraak_original"]
const HOTBAR_SLOTS := 9
const SEASONS := ["spring", "summer", "autumn", "winter"]
const DAYS_PER_SEASON := 30
## How fast the world's clock runs: in-game minutes per real second (12 per real
## minute: the meadow goes from golden hour to dusk in about twenty minutes).
const MINUTES_PER_SECOND := 0.2

var flags: Dictionary = {}
var quests: Dictionary = {}
## Each relationship: {affinity:int, trust:int, notes:Array[String]}
var relationships: Dictionary = {}
## Structured, append-only memory events (see docs/design/MEMORY_EVENTS.md).
var memories: Array[Dictionary] = []
## The calendar is simple for milestone 001: year, season, day, hour.
var world_date: Dictionary = {"year": 1031, "season": "spring", "day": 14, "hour": 16.0}
## Satchel: item id -> count (definitions in data/items/items.json).
var inventory: Dictionary = {}
## Spells she knows, and which one sits on number keys 1-9 ("" = empty slot).
var known_spells: Array = DEFAULT_SPELLS.duplicate()
var hotbar: Array = _default_hotbar()

## Systems that own persistent sub-state register a provider so save/load stays
## decoupled: provider must implement `save_state() -> Dictionary` and
## `load_state(data: Dictionary) -> void`.
var _providers: Dictionary = {}
var _game_time := 0.0
var _clock_carry := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.ensure_actions()


func _process(delta: float) -> void:
	if not get_tree().paused:
		_game_time += delta
		_clock_carry += delta * MINUTES_PER_SECOND / 60.0
		if _clock_carry >= 1.0 / 60.0:
			advance_time(_clock_carry)
			_clock_carry = 0.0
	RenderingServer.global_shader_parameter_set("game_time", _game_time)


func game_time() -> float:
	return _game_time


# --- Flags -------------------------------------------------------------------

func set_flag(flag: String, value: Variant = true) -> void:
	if flags.get(flag) == value:
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func flag(flag: String, default: Variant = null) -> Variant:
	return flags.get(flag, default)


# --- Quests ------------------------------------------------------------------

func set_quest(quest_id: String, state: String) -> void:
	if quests.get(quest_id, "") == state:
		return
	quests[quest_id] = state
	quest_changed.emit(quest_id, state)


func quest(quest_id: String) -> String:
	return quests.get(quest_id, "none")


# --- Satchel, spells and time ----------------------------------------------------

static func _default_hotbar() -> Array:
	var h: Array = DEFAULT_SPELLS.duplicate()
	h.resize(HOTBAR_SLOTS)
	for i in HOTBAR_SLOTS:
		if h[i] == null:
			h[i] = ""
	return h


func give_item(id: String, count := 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + count
	inventory_changed.emit()


func take_item(id: String, count := 1) -> void:
	inventory[id] = maxi(0, int(inventory.get(id, 0)) - count)
	if inventory[id] == 0:
		inventory.erase(id)
	inventory_changed.emit()


func has_item(id: String) -> bool:
	return int(inventory.get(id, 0)) > 0


func knows_spell(id: String) -> bool:
	return id in known_spells


## Adds a spell to the book and to the first free number key.
func learn_spell(id: String) -> void:
	if knows_spell(id):
		return
	known_spells.append(id)
	var free := hotbar.find("")
	if free >= 0:
		hotbar[free] = id
	spells_changed.emit()


## Puts a spell on a number key (0-based slot); "" clears it. A spell sits on one
## key only: binding it elsewhere moves it, and the old occupant swaps back.
func bind_spell(slot: int, id: String) -> void:
	if slot < 0 or slot >= HOTBAR_SLOTS or (id != "" and not knows_spell(id)):
		return
	var from := hotbar.find(id) if id != "" else -1
	if from >= 0:
		hotbar[from] = hotbar[slot]
	hotbar[slot] = id
	spells_changed.emit()


## Waiting / studying: the clock and calendar move on. (No day/night cycle yet;
## the meadow stays in golden hour.)
func advance_time(hours: float) -> void:
	var h := float(world_date["hour"]) + hours
	while h >= 24.0:
		h -= 24.0
		world_date["day"] = int(world_date["day"]) + 1
		if int(world_date["day"]) > DAYS_PER_SEASON:
			world_date["day"] = 1
			var s := SEASONS.find(str(world_date["season"])) + 1
			if s >= SEASONS.size():
				s = 0
				world_date["year"] = int(world_date["year"]) + 1
			world_date["season"] = SEASONS[s]
	world_date["hour"] = h
	time_advanced.emit(hours)


func format_clock() -> String:
	var h := float(world_date["hour"])
	return "%02d:%02d" % [int(h), int((h - floorf(h)) * 60.0)]


# --- Relationships -------------------------------------------------------------

func relationship(char_id: String) -> Dictionary:
	if not relationships.has(char_id):
		relationships[char_id] = {"affinity": 0, "trust": 0, "notes": []}
	return relationships[char_id]


func change_affinity(char_id: String, amount: int, note: String = "") -> void:
	var rel := relationship(char_id)
	rel["affinity"] = int(rel["affinity"]) + amount
	if note != "":
		(rel["notes"] as Array).append(note)


func affinity(char_id: String) -> int:
	return int(relationship(char_id)["affinity"])


# --- Memory events -------------------------------------------------------------

## Records a compact structured memory. `memory` must contain at least `id`.
## Missing common fields are filled in so every event is self-describing.
func record_memory(memory: Dictionary) -> void:
	if has_memory(memory.get("id", "")):
		return
	var m := memory.duplicate(true)
	m["schema"] = 1
	m["world_date"] = world_date.duplicate()
	m["recorded_by"] = PROTAGONIST_ID
	if not m.has("participants"):
		m["participants"] = [PROTAGONIST_ID]
	memories.append(m)
	memory_recorded.emit(m)


func has_memory(memory_id: String) -> bool:
	for m in memories:
		if m.get("id") == memory_id:
			return true
	return false


func get_memory(memory_id: String) -> Dictionary:
	for m in memories:
		if m.get("id") == memory_id:
			return m
	return {}


# --- Save / load ---------------------------------------------------------------

func register_provider(key: String, provider: Object) -> void:
	_providers[key] = provider


func unregister_provider(key: String) -> void:
	_providers.erase(key)


func build_save() -> Dictionary:
	var data := {
		"version": SAVE_VERSION,
		"flags": flags,
		"quests": quests,
		"relationships": relationships,
		"memories": memories,
		"world_date": world_date,
		"inventory": inventory,
		"known_spells": known_spells,
		"hotbar": hotbar,
		"systems": {},
	}
	for key in _providers:
		var p: Object = _providers[key]
		if is_instance_valid(p):
			data["systems"][key] = p.call("save_state")
	return data


func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not open save file: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(build_save(), "\t"))
	toast.emit("Journal saved.")
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is corrupt.")
		return false
	apply_save(_migrate(parsed))
	toast.emit("Journal loaded.")
	return true


func apply_save(data: Dictionary) -> void:
	flags = data.get("flags", {})
	quests = data.get("quests", {})
	relationships = data.get("relationships", {})
	memories.clear()
	for m in data.get("memories", []):
		memories.append(m)
	world_date = data.get("world_date", world_date)
	inventory = data.get("inventory", {})
	known_spells = data.get("known_spells", DEFAULT_SPELLS.duplicate())
	hotbar = data.get("hotbar", _default_hotbar())
	spells_changed.emit()
	inventory_changed.emit()
	var systems: Dictionary = data.get("systems", {})
	for key in systems:
		if _providers.has(key) and is_instance_valid(_providers[key]):
			_providers[key].call("load_state", systems[key])
	for q in quests:
		quest_changed.emit(q, quests[q])


## Upgrades older save dictionaries in place. Add a branch per version bump.
func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 0))
	if v > SAVE_VERSION:
		push_warning("Save is from a newer version (%d); loading best-effort." % v)
	data["version"] = SAVE_VERSION
	return data


func reset() -> void:
	flags.clear()
	quests.clear()
	relationships.clear()
	memories.clear()
	world_date = {"year": 1031, "season": "spring", "day": 14, "hour": 16.0}
	inventory.clear()
	known_spells = DEFAULT_SPELLS.duplicate()
	hotbar = _default_hotbar()


func format_date() -> String:
	return "Day %d of %s, Year %d  ·  %s" % [world_date["day"], str(world_date["season"]).capitalize(), world_date["year"], format_clock()]
