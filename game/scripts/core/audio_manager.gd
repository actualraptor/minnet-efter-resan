extends Node
## Small audio facade: one-shot SFX (2D or positional), looping ambience layers
## and a crossfading music track. Missing files are skipped silently so the game
## keeps running while audio assets are still being produced.

const SFX_DIR := "res://assets/audio/sfx/"
const AMB_DIR := "res://assets/audio/ambience/"
const MUSIC_DIR := "res://assets/audio/music/"

var _cache: Dictionary = {}
var _ambience: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
	add_child(p)
	return p


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(path + ext):
			stream = load(path + ext)
			break
	_cache[path] = stream
	return stream


## Plays a one-shot. `name` may end with `_*` to pick a random variant 1..n.
func sfx(sound: String, volume_db: float = 0.0, pitch_jitter: float = 0.05, at: Variant = null) -> void:
	var stream := _resolve_variant(SFX_DIR, sound)
	if stream == null:
		return
	var p: Node
	if at is Vector3 and get_tree().current_scene:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.volume_db = volume_db
		p3.unit_size = 6.0
		p3.max_distance = 40.0
		p3.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
		get_tree().current_scene.add_child(p3)
		p3.global_position = at
		p3.play()
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream
		p2.volume_db = volume_db
		p2.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
		add_child(p2)
		p2.play()
		p = p2
	p.connect("finished", p.queue_free)


func _resolve_variant(dir: String, sound: String) -> AudioStream:
	if sound.ends_with("_*"):
		var base := sound.trim_suffix("_*")
		var variants: Array[AudioStream] = []
		for i in range(1, 9):
			var s := _load(dir + "%s_%d" % [base, i])
			if s:
				variants.append(s)
		return variants.pick_random() if not variants.is_empty() else null
	return _load(dir + sound)


## Starts (or retunes) a looping ambience layer, fading to `volume_db`.
func ambience(layer: String, volume_db: float = -8.0, fade: float = 2.0) -> void:
	var p: AudioStreamPlayer = _ambience.get(layer)
	if p == null:
		var stream := _load(AMB_DIR + layer)
		if stream == null:
			return
		_set_loop(stream)
		p = _make_player("Ambience")
		p.stream = stream
		p.volume_db = -60.0
		p.play()
		_ambience[layer] = p
	var tw := create_tween()
	tw.tween_property(p, "volume_db", volume_db, fade)


func music(track: String, volume_db: float = -14.0, fade: float = 3.0) -> void:
	var stream := _load(MUSIC_DIR + track)
	if stream == null:
		return
	_set_loop(stream)
	var next := _music_b if _music_current == _music_a else _music_a
	if _music_current and _music_current.stream == stream:
		return
	next.stream = stream
	next.volume_db = -50.0
	next.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(next, "volume_db", volume_db, fade)
	if _music_current:
		tw.tween_property(_music_current, "volume_db", -60.0, fade)
	_music_current = next


func music_volume(volume_db: float, fade: float = 2.0) -> void:
	if _music_current:
		create_tween().tween_property(_music_current, "volume_db", volume_db, fade)


func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_end = int(w.get_length() * w.mix_rate)
