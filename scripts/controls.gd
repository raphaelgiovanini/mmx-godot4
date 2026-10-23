extends Node
## Mapa de controles criado em código: mais legível que InputEvents serializados no project.godot.
## Teclado no padrão do mmx8: S pula, D atira, A dash, TAB/Q trocam de arma (X), W abre o menu de armas, F = sabre (Zero; ↑+F Ryuenjin) ou especial do X (Hadouken; ↑+F Shoryuken; Giga cheia: Giga Crush).
## Controle: A pula, X atira, B/RT dash, RB/LB trocam. F1/F2 ajustam o ritmo. B (Select) troca o buster do X: X1/X2/X3. Esc/Enter (Start) abre o menu de pausa.

const KEYS := {
	&"left": [KEY_LEFT], &"right": [KEY_RIGHT], &"up": [KEY_UP], &"down": [KEY_DOWN],
	&"jump": [KEY_S], &"fire": [KEY_D, KEY_X], &"dash": [KEY_A, KEY_C, KEY_SHIFT],
	&"switch_next": [KEY_TAB, KEY_E], &"switch_prev": [KEY_Q],
	&"pace_down": [KEY_F1], &"pace_up": [KEY_F2], &"buster_next": [KEY_B], &"saber": [KEY_F], &"weapon_menu": [KEY_W],
	&"pause": [KEY_ESCAPE, KEY_ENTER, KEY_P],
	&"part_head": [KEY_1], &"part_body": [KEY_2], &"part_arms": [KEY_3], &"part_legs": [KEY_4],
}
const PAD := {
	&"left": [JOY_BUTTON_DPAD_LEFT], &"right": [JOY_BUTTON_DPAD_RIGHT],
	&"up": [JOY_BUTTON_DPAD_UP], &"down": [JOY_BUTTON_DPAD_DOWN],
	&"jump": [JOY_BUTTON_A], &"fire": [JOY_BUTTON_X], &"dash": [JOY_BUTTON_B],
	&"switch_next": [JOY_BUTTON_RIGHT_SHOULDER],
	&"switch_prev": [JOY_BUTTON_LEFT_SHOULDER], &"pace_down": [], &"pace_up": [],
	&"buster_next": [JOY_BUTTON_BACK], &"saber": [JOY_BUTTON_RIGHT_STICK], &"weapon_menu": [JOY_BUTTON_LEFT_STICK], &"pause": [JOY_BUTTON_START],
	&"part_head": [], &"part_body": [], &"part_arms": [], &"part_legs": [],
}


func _ready() -> void:
	for action: StringName in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for button: JoyButton in PAD[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	InputMap.action_add_event(&"dash", rt)
