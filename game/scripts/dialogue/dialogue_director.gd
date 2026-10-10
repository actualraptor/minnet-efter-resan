class_name DialogueDirector
extends Node
## Stages conversations: locks the player, turns participants to each other,
## frames whoever is speaking with an over-the-shoulder shot, routes emotes and
## dialogue events, then hands the camera back.

static var instance: DialogueDirector

signal conversation_started(dialogue_id: String)
signal conversation_finished(dialogue_id: String)

@export var dialogue_box_path: NodePath

var runner: DialogueRunner
var box: DialogueBox
var _npc: NPC
var _player: Player
var _cam: Camera3D
var _prev_cam: Camera3D
var _cam_tween: Tween
var _participants: Dictionary = {}


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	runner = DialogueRunner.new()
	runner.name = "Runner"
	add_child(runner)
	box = get_node(dialogue_box_path) as DialogueBox
	box.runner = runner
	runner.line_shown.connect(_on_line)
	runner.finished.connect(_on_finished)
	_cam = Camera3D.new()
	_cam.name = "DialogueCamera"
	_cam.fov = 50.0


func start_conversation(id: String, npc: NPC, player: Node) -> bool:
	if runner.active:
		return false
	_npc = npc
	_player = player as Player
	_participants = {GameState.PROTAGONIST_ID: _player}
	if npc:
		_participants[npc.character_id] = npc
	if _player:
		_player.lock_input()
	if npc and _player:
		npc.begin_talk(_player)
		_player.face_towards(npc.global_position)
		_prev_cam = get_viewport().get_camera_3d()
		if _cam.get_parent() == null:
			get_tree().current_scene.add_child(_cam)
		_cam.global_transform = _prev_cam.global_transform if _prev_cam else _cam.global_transform
		_cam.current = true
	if not runner.start(id, {"npc": npc}):
		_restore()
		return false
	Audio.music_volume(-20.0, 1.0)
	conversation_started.emit(id)
	return true


## Narration or self-talk without a partner (intro, thoughts).
func start_monologue(id: String, player: Node) -> bool:
	return start_conversation(id, null, player)


func _on_line(line: Dictionary, _info: Dictionary) -> void:
	var speaker_id: String = line.get("speaker", "")
	var speaker: Node = _participants.get(speaker_id)
	if speaker and line.has("emote"):
		if speaker is NPC:
			(speaker as NPC).play(StringName(line["emote"]))
		elif speaker is Player:
			(speaker as Player).emote(line["emote"])
	# Painted-face expressions and lip flap for whoever speaks (if they have a face rig).
	if speaker and "face" in speaker and speaker.face:
		var f: FaceController = speaker.face
		f.set_expression(line.get("face", "neutral"))
		f.talk(0.25 + String(line.get("text", "")).length() / 48.0)
	if _player and speaker != _player and _player.face:
		_player.face.stop_talking()
	if _npc and _player:
		_player.set_look_target(_npc, Vector3(0, _npc.head_height, 0))
	if _npc and _player and speaker_id != "narrator":
		var speaking: Node3D = _npc if speaker == _npc else _player
		var listening: Node3D = _player if speaking == _npc else _npc
		_frame(speaking, listening)


func _head(n: Node3D) -> Vector3:
	if n is NPC:
		return (n as NPC).head_position()
	return n.global_position + Vector3(0, 1.6, 0)


func _frame(speaker: Node3D, listener: Node3D) -> void:
	var s := _head(speaker)
	var l := _head(listener)
	var dir := (s - l)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var side := dir.cross(Vector3.UP).normalized()
	# Over the player's free (left, +X) shoulder, never through the staff.
	if listener is Player:
		var lx := (listener as Player).model.global_basis.x
		lx.y = 0.0
		if lx.length() > 0.01 and side.dot(lx.normalized()) < 0.0:
			side = -side
	var want := l - dir * 1.35 + side * 1.05 + Vector3.UP * 0.18
	# Keep the shot out of walls: pull toward the speaker if blocked.
	var space := _cam.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(s, want, 1)
	var exclude: Array[RID] = []
	for n in [speaker, listener]:
		if n is CollisionObject3D:
			exclude.append((n as CollisionObject3D).get_rid())
	q.exclude = exclude
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		want = s.lerp(hit["position"], 0.85)
	var xf := Transform3D(Basis(), want).looking_at(s.lerp(l, 0.15) + Vector3.UP * 0.02, Vector3.UP)
	if _cam_tween:
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.tween_property(_cam, "global_transform", xf, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_finished(id: String) -> void:
	_restore()
	Audio.music_volume(-14.0, 2.0)
	conversation_finished.emit(id)


func _restore() -> void:
	if _npc:
		_npc.end_talk()
	if _prev_cam:
		_prev_cam.current = true
	if _player:
		_player.set_look_target(null)
		if _player.face:
			_player.face.stop_talking()
			_player.face.set_expression("neutral")
		_player.unlock_input()
		_player.emote("Idle")
	_npc = null
	_participants.clear()
