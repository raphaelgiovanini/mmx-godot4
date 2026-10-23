extends Node2D
## Visual provisório: um retângulo colorido por estado e um "olho" indicando a direção.
## Qualquer visual (sprite, modelo 3D) só precisa implementar show_state(state, facing).

const COLORS := {
	&"IDLE": Color("2a6fdb"), &"WALK": Color("3d8bff"), &"AIR": Color("79b8ff"),
	&"DASH": Color("00d0ff"), &"WALL_SLIDE": Color("8a6bff"),
}

var _state: StringName = &"IDLE"
var _facing := 1


func show_state(state: StringName, facing: int) -> void:
	if state == _state and facing == _facing:
		return
	_state = state
	_facing = facing
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-7, -30, 14, 30), COLORS.get(_state, Color.WHITE))
	draw_rect(Rect2(_facing * 3 - 1, -26, 3, 3), Color.WHITE)
