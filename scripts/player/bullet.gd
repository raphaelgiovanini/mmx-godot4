class_name Bullet extends Area2D
## Tiro de arma de verdade (melhoria sobre a gravação colada): movimento próprio, colisão com o cenário
## e com o chefe, brilho aditivo, rastro de partículas e impacto com HitFX. Ponto de partida = o
## comportamento do original; o visual é novo.
##   torpedo  Homing Torpedo (X1): acelera e persegue o chefe mais perto
##   wheel    Spin Wheel (X2): cai, rola pelo chão e mói o chefe por meio segundo
##   spark    faísca reta (carregado da Spin Wheel: 8 em leque)
##   ray      Ray Splasher (X3): bolinha de luz rápida

const WORLD_MASK := 1

var kind := "torpedo"
var weapon: Dictionary = {}
var charged := false
var velocity := Vector2.ZERO
var damage := 2.0
var color := Color.WHITE
var radius := 4.0
var life := 120          # frames
var _t := 0
var _grind := 0          # wheel: frames moendo o chefe
var _trail: CPUParticles2D


func _ready() -> void:
	add_to_group(&"wshot")
	material = HitFX.ADD
	z_index = 4
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	shape.shape = c
	add_child(shape)
	_trail = _make_trail()
	add_child(_trail)


func _physics_process(_delta: float) -> void:
	_t += 1
	life -= 1
	match kind:
		"torpedo":
			var target := _nearest_boss()
			var speed := minf(velocity.length() + 0.12, 4.5)
			if target:
				var want := (target.global_position + Vector2(0, -16) - global_position).angle()
				velocity = Vector2.from_angle(rotate_toward(velocity.angle(), want, 0.07)) * speed
			else:
				velocity = velocity.normalized() * speed
		"wheel":
			velocity.y = minf(velocity.y + 0.35, 5.0)
			var below := _ray(global_position, global_position + Vector2(0, radius + velocity.y + 1))
			if below:
				global_position.y = below.position.y - radius
				velocity.y = 0.0
			if _wall(Vector2(signf(velocity.x), 0)):
				_explode()
				return
	if _grind > 0:
		_grind -= 1
		_hit_bosses()
		if _grind == 0:
			_explode()
		queue_redraw()
		return
	global_position += velocity
	_hit_bosses()
	if not is_queued_for_deletion() and _grind == 0 and kind != "wheel" and _wall(velocity.normalized()):
		_explode()
		return
	if life <= 0:
		_explode()
	queue_redraw()


func _hit_bosses() -> void:
	for b in get_overlapping_bodies():
		if b is Boss and b.hp > 0:
			var col: int = weapon.get("col", -1)
			var landed: bool = b.hit(col + (9 if charged else 0), 1.0) if col >= 0 else b.hit(-1, damage)
			if not landed:
				continue
			if kind == "wheel" and _grind == 0:
				_grind = 30   # mói o chefe; cada acerto respeita a invencibilidade dele
				velocity = Vector2.ZERO
				HitFX.impact(get_parent(), global_position, color, false)
			elif kind != "wheel":
				_explode()
			return


func _explode() -> void:
	HitFX.impact(get_parent(), global_position, color, charged)
	_trail.emitting = false
	_trail.reparent(get_parent())
	_trail.finished.connect(_trail.queue_free)
	queue_free()


func _wall(dir: Vector2) -> bool:
	return _ray(global_position, global_position + dir * (radius + 2)) != {}


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return hit if hit and hit.collider is StaticBody2D and not hit.collider is Boss else {}   # Boss também é StaticBody2D


func _nearest_boss() -> Node2D:
	var best: Node2D = null
	for b in get_tree().get_nodes_in_group(&"boss"):
		if b.hp > 0 and (best == null or b.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = b
	return best


func _make_trail() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.material = HitFX.ADD
	p.local_coords = false
	p.amount = {"torpedo": 24, "wheel": 18, "spark": 10, "ray": 8}[kind]
	p.lifetime = 0.35 if kind != "ray" else 0.15
	p.gravity = Vector2(0, -20) if kind == "torpedo" else Vector2(0, 120 if kind == "wheel" else 0)
	p.spread = 25.0 if kind == "torpedo" else 180.0
	p.direction = -velocity.normalized() if velocity != Vector2.ZERO else Vector2.LEFT
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 40.0 if kind != "wheel" else 70.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	var tip := Color("ffb347") if kind == "torpedo" else color
	ramp.colors = PackedColorArray([Color.WHITE, tip, Color(tip, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	p.color_ramp = ramp
	return p


func _draw() -> void:
	var a := velocity.angle() if velocity != Vector2.ZERO else 0.0
	match kind:
		"torpedo":
			# Corpo de torpedo com nariz claro e chama atrás.
			var f := Vector2.from_angle(a)
			var s := 0.75 if charged else 1.0
			_glow(Vector2.ZERO, 7.0 * s, color)
			var body := PackedVector2Array([f * 7 * s, f.rotated(2.4) * 4 * s, -f * 6 * s, f.rotated(-2.4) * 4 * s])
			draw_colored_polygon(body, Color("dfe6f0"))
			draw_circle(f * 4 * s, 1.6 * s, Color.WHITE)
			var flick := 3.0 + 2.0 * sin(_t * 1.3)
			draw_colored_polygon(PackedVector2Array([-f * 5 * s + f.orthogonal() * 2 * s, -f * (6 + flick) * s, -f * 5 * s - f.orthogonal() * 2 * s]), Color("ffb347"))
		"wheel":
			# Serra girando: dentes + miolo brilhante.
			_glow(Vector2.ZERO, radius + 4, color)
			var spin := _t * 0.45 * signf(velocity.x if velocity.x != 0 else 1.0)
			for i in 8:
				var d := Vector2.from_angle(spin + TAU * i / 8)
				draw_colored_polygon(PackedVector2Array([d * (radius + 3), d.rotated(0.35) * radius, d.rotated(-0.35) * radius]), Color("fff2b0"))
			draw_circle(Vector2.ZERO, radius, color)
			draw_circle(Vector2.ZERO, radius * 0.45, Color.WHITE)
		_:
			_glow(Vector2.ZERO, radius + 3, color)
			draw_circle(Vector2.ZERO, radius * 0.6, Color.WHITE)


func _glow(at: Vector2, r: float, c: Color) -> void:
	for i in 3:
		draw_circle(at, r * (1.0 + i * 0.3), Color(c, 0.14 / (i + 1)))


# ---------------------------------------------------------------- disparo de cada arma

## Dispara a arma `w` (normal ou carregada) a partir do canhão. Devolve false se a arma não tem
## versão de verdade (aí o jogador usa a gravação).
## Cor do brilho de cada arma (a do menu é clara demais para luz aditiva).
const GLOW := {"homing_torpedo": Color("6fb7ff"), "spin_wheel": Color("ffb020"), "ray_splasher": Color("ffe066")}


static func fire(w: Dictionary, charged_shot: bool, at: Vector2, dir: int, parent: Node, dmg: float) -> bool:
	var color: Color = GLOW.get(w.id, w.color)
	match w.id:
		"homing_torpedo":
			var n := 5 if charged_shot else 1
			for i in n:
				var b := _make("torpedo", w, charged_shot, at, Vector2(dir * 1.5, (i - (n - 1) / 2.0) * 0.9), color, dmg)
				parent.add_child(b)
		"spin_wheel":
			if charged_shot:
				for i in 8:
					parent.add_child(_make("spark", w, true, at, Vector2.from_angle(TAU * i / 8) * 4.0, color, dmg))
			else:
				var b := _make("wheel", w, false, at, Vector2(dir * 3.0, 0), color, dmg)
				b.radius = 6.0
				b.life = 180
				parent.add_child(b)
		"ray_splasher":
			# Rajada em leque: 8 bolinhas em 8 quadros (o carregado dobra e abre mais).
			var n := 16 if charged_shot else 8
			for i in n:
				var spread := deg_to_rad(randf_range(-14.0, 14.0) * (1.6 if charged_shot else 1.0))
				var b := _make("ray", w, charged_shot, at, Vector2(dir * 6.0, 0).rotated(spread * dir), color, dmg * 0.5)
				b.radius = 2.5
				b.life = 70
				parent.get_tree().create_timer(i * 2 / 60.0, false).timeout.connect(func():
					if is_instance_valid(parent):
						parent.add_child(b))
		_:
			return false
	return true


static func _make(k: String, w: Dictionary, ch: bool, at: Vector2, v: Vector2, c: Color, dmg: float) -> Bullet:
	var b := Bullet.new()
	b.kind = k
	b.weapon = w
	b.charged = ch
	b.velocity = v
	b.color = c
	b.damage = dmg
	b.global_position = at
	if k == "spark":
		b.radius = 3.0
		b.life = 60
	return b
