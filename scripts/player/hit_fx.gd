class_name HitFX
## Sensação de acerto (melhoria sobre os originais): faíscas e anel de luz no ponto do impacto, uma pausa
## curta no jogo inteiro (hitstop) e a câmera tremendo. `strong` = golpe carregado.

const ADD := preload("res://scripts/player/hit_fx_material.tres")


static func impact(parent: Node, pos: Vector2, color: Color, strong: bool) -> void:
	var sparks := CPUParticles2D.new()
	sparks.global_position = pos
	sparks.material = ADD
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 22 if strong else 10
	sparks.lifetime = 0.35
	sparks.spread = 180.0
	sparks.gravity = Vector2(0, 260)
	sparks.initial_velocity_min = 90.0
	sparks.initial_velocity_max = 240.0 if strong else 160.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.5
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color.WHITE, color, Color(color, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	sparks.color_ramp = ramp
	parent.add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
	var ring := Ring.new()
	ring.color = color
	ring.max_radius = 22.0 if strong else 12.0
	ring.global_position = pos
	parent.add_child(ring)
	hitstop(parent.get_tree(), 0.07 if strong else 0.035)
	shake(parent.get_viewport(), 3.0 if strong else 1.5, 0.18 if strong else 0.1)


## Congela o jogo por `seconds` reais (o tempo do motor quase para).
static func hitstop(tree: SceneTree, seconds: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	tree.create_timer(seconds, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


static func shake(viewport: Viewport, amount: float, seconds: float) -> void:
	var cam := viewport.get_camera_2d()
	if cam == null:
		return
	var tw := cam.create_tween().set_ignore_time_scale(true)
	var steps := 6
	for i in steps:
		var a := amount * (1.0 - float(i) / steps)
		tw.tween_property(cam, "offset", Vector2(randf_range(-a, a), randf_range(-a, a)), seconds / steps)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.02)


## Anel de luz que abre e some.
class Ring extends Node2D:
	var color := Color.WHITE
	var max_radius := 12.0
	var _t := 0.0

	func _ready() -> void:
		material = HitFX.ADD
		z_index = 5

	func _process(delta: float) -> void:
		_t += delta / 0.22
		if _t >= 1.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := max_radius * (0.3 + 0.7 * _t)
		draw_arc(Vector2.ZERO, r, 0, TAU, 24, Color(color, 1.0 - _t), 2.0 * (1.0 - _t) + 0.5, true)
		draw_circle(Vector2.ZERO, r * 0.45 * (1.0 - _t), Color(1, 1, 1, 0.8 * (1.0 - _t)))
