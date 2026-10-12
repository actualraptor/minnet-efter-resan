class_name DialogueRunner
extends Node
## Runs JSON dialogue files from res://data/dialogue/. Format (see
## docs/narrative/DIALOGUE_FORMAT.md):
##   entries: [{if?, node}]  first matching entry starts the conversation
##   nodes: {id: {lines: [Line], choices?: [Choice], goto?: id}}
##   Line: {id, speaker, text, voice?, emote?, if?, do?: [Action], pause?}
##   Choice: {id, text, if?, goto?, do?: [Action]}
## Actions: "flag:name[=value]", "quest:id=state", "affinity:char_id:+n", "item:id",
##          "event:name", "memory:id" (records via the current scene hook).
## Every line has a stable `id`; translations use it as the msgid and voice
## files default to res://assets/audio/voice/<id>.ogg when present.

signal started(dialogue_id: String)
signal line_shown(line: Dictionary, speaker: Dictionary)
signal choices_shown(choices: Array)
signal finished(dialogue_id: String)
signal event_fired(event_name: String, dialogue_id: String)

const DIALOGUE_DIR := "res://data/dialogue/"
const CAST_PATH := "res://data/characters/cast.json"

var active := false
var dialogue_id := ""
var context: Dictionary = {}

var _cache: Dictionary = {}
var _cast: Dictionary = {}
var _queue: Array = []
var _node: Dictionary = {}
var _awaiting_choice := false
var _voice: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	var cast: Variant = _read_json(CAST_PATH)
	if cast is Dictionary:
		_cast = cast


func speaker_info(speaker_id: String) -> Dictionary:
	return _cast.get(speaker_id, {"name": speaker_id, "color": "#ffffff"})


func load_dialogue(id: String) -> Dictionary:
	if not _cache.has(id):
		var d: Variant = _read_json(DIALOGUE_DIR + id + ".json")
		_cache[id] = d if d is Dictionary else {}
	return _cache[id]


func start(id: String, ctx: Dictionary = {}) -> bool:
	if active:
		return false
	var d := load_dialogue(id)
	if d.is_empty():
		push_warning("Dialogue not found: %s" % id)
		return false
	var entry_node := ""
	for e in d.get("entries", []):
		if eval_condition(e.get("if", "")):
			entry_node = e["node"]
			break
	if entry_node == "":
		return false
	active = true
	dialogue_id = id
	context = ctx
	started.emit(id)
	_enter_node(entry_node)
	return true


func _enter_node(node_id: String) -> void:
	var d := load_dialogue(dialogue_id)
	_node = d.get("nodes", {}).get(node_id, {})
	if _node.is_empty():
		push_warning("Dialogue %s: missing node %s" % [dialogue_id, node_id])
		_end()
		return
	_queue = (_node.get("lines", []) as Array).duplicate()
	advance()


## Shows the next line, the node's choices, or follows/ends the node.
func advance() -> void:
	if not active or _awaiting_choice:
		return
	while not _queue.is_empty():
		var line: Dictionary = _queue.pop_front()
		if not eval_condition(line.get("if", "")):
			continue
		_run_actions(line.get("do", []))
		if not active:
			return
		_show_line(line)
		return
	var choices: Array = []
	for c in _node.get("choices", []):
		if eval_condition(c.get("if", "")):
			var cc: Dictionary = c.duplicate()
			cc["text"] = localize(c.get("id", ""), c.get("text", ""))
			choices.append(cc)
	if not choices.is_empty():
		_awaiting_choice = true
		choices_shown.emit(choices)
		return
	if _node.has("goto"):
		_enter_node(_node["goto"])
		return
	_end()


func choose(choice: Dictionary) -> void:
	if not _awaiting_choice:
		return
	_awaiting_choice = false
	GameState.set_flag("chose." + str(choice.get("id", "")), true)
	_run_actions(choice.get("do", []))
	if not active:
		return
	if choice.has("goto"):
		_enter_node(choice["goto"])
	else:
		_end()


func _show_line(line: Dictionary) -> void:
	var shown := line.duplicate()
	shown["text"] = interpolate(localize(line.get("id", ""), line.get("text", "")))
	var info := speaker_info(line.get("speaker", ""))
	_play_voice(line)
	line_shown.emit(shown, info)


func _play_voice(line: Dictionary) -> void:
	_voice.stop()
	var path: String = line.get("voice", "")
	if path == "":
		path = "res://assets/audio/voice/%s.ogg" % line.get("id", "")
	if ResourceLoader.exists(path):
		_voice.stream = load(path)
		_voice.play()


func stop() -> void:
	if active:
		_end()


func _end() -> void:
	var id := dialogue_id
	active = false
	_awaiting_choice = false
	_queue.clear()
	_voice.stop()
	dialogue_id = ""
	finished.emit(id)


# --- Text -----------------------------------------------------------------------

func localize(line_id: String, fallback: String) -> String:
	if line_id != "":
		var t := tr(line_id)
		if t != line_id:
			return t
	return fallback


## Replaces {flag_name} with GameState flag values (e.g. {flowers_counted}).
func interpolate(text: String) -> String:
	if not text.contains("{"):
		return text
	var vals := {}
	for k in GameState.flags:
		vals[k] = str(GameState.flags[k])
	return text.format(vals)


# --- Conditions & actions ---------------------------------------------------------

func eval_condition(cond: String) -> bool:
	if cond.strip_edges() == "":
		return true
	var expr := Expression.new()
	if expr.parse(cond) != OK:
		push_warning("Bad dialogue condition '%s': %s" % [cond, expr.get_error_text()])
		return false
	var result: Variant = expr.execute([], GameState, false)
	if expr.has_execute_failed():
		push_warning("Dialogue condition failed '%s'" % cond)
		return false
	return bool(result)


func _run_actions(actions: Array) -> void:
	for a in actions:
		var s := str(a)
		var kind := s.get_slice(":", 0)
		var rest := s.substr(kind.length() + 1)
		match kind:
			"flag":
				if rest.contains("="):
					GameState.set_flag(rest.get_slice("=", 0), _parse_value(rest.get_slice("=", 1)))
				else:
					GameState.set_flag(rest, true)
			"quest":
				GameState.set_quest(rest.get_slice("=", 0), rest.get_slice("=", 1))
			"affinity":
				var parts := rest.split(":")
				GameState.change_affinity(parts[0], int(parts[1]), dialogue_id)
			"item":
				GameState.give_item(rest)
				GameState.toast.emit("Received: " + str(ItemLibrary.get_item(rest).get("name", rest)))
			"event", "memory":
				event_fired.emit(s, dialogue_id)
			"end":
				_end()
				return
			_:
				push_warning("Unknown dialogue action: %s" % s)


func _parse_value(v: String) -> Variant:
	if v == "true":
		return true
	if v == "false":
		return false
	if v.is_valid_int():
		return int(v)
	if v.is_valid_float():
		return float(v)
	return v


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("JSON error in %s line %d: %s" % [path, j.get_error_line(), j.get_error_message()])
		return null
	return j.data
