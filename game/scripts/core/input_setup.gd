class_name InputSetup
extends RefCounted
## Registers default input actions in code so bindings live in one readable place
## (and remain rebindable later through InputMap).

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"run": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"interact": [KEY_E],
	"pause": [KEY_ESCAPE],
	"journal": [KEY_J, KEY_TAB],
	"cast_alt": [KEY_F],
	"summon": [KEY_Q],
	"spell_1": [KEY_1],
	"spell_2": [KEY_2],
	"spell_3": [KEY_3],
	"fly": [KEY_H],
	"descend": [KEY_CTRL, KEY_C],
	"interrupt": [KEY_X],
	"advance": [KEY_SPACE, KEY_ENTER, KEY_E],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
	"screenshot": [KEY_F12],
}

const MOUSE := {
	"aim": MOUSE_BUTTON_RIGHT,
	"cast": MOUSE_BUTTON_LEFT,
	"advance": MOUSE_BUTTON_LEFT,
}

const JOY_BUTTONS := {
	"jump": JOY_BUTTON_A,
	"interact": JOY_BUTTON_X,
	"advance": JOY_BUTTON_A,
	"cast": JOY_BUTTON_RIGHT_SHOULDER,
	"pause": JOY_BUTTON_START,
	"run": JOY_BUTTON_LEFT_STICK,
	"fly": JOY_BUTTON_Y,
	"descend": JOY_BUTTON_LEFT_SHOULDER,
}


static func ensure_actions() -> void:
	for action in KEYS:
		_add(action)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for action in MOUSE:
		_add(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE[action]
		InputMap.action_add_event(action, mb)
	for action in JOY_BUTTONS:
		_add(action)
		var jb := InputEventJoypadButton.new()
		jb.button_index = JOY_BUTTONS[action]
		InputMap.action_add_event(action, jb)
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)


static func _add(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


static func _add_axis(action: String, axis: JoyAxis, dir: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = dir
	InputMap.action_add_event(action, ev)
