extends Area2D
## Tiro lançado (Acid Burst): a bola segue o caminho medido na gravação do original (meta.json "lob",
## tools/measure_lob.py) mas colide com o cenário de verdade. Onde bater (chão, parede), toca o
## respingo gravado ancorado no ponto de contato, com dano enquanto ele dura. Se o caminho gravado
## acaba no ar (o chão aqui é mais baixo que o da gravação), a bola continua caindo com a última
## velocidade mais GRAVITY.

const WeaponShot := preload("res://scripts/player/weapon_shot.gd")
const ANCHOR := WeaponShot.ANCHOR
const RADIUS := 5.0
const GRAVITY := 0.25     # px/frame² depois do fim do caminho gravado
const SPLASH := Vector2(32, 24)

var weapon: Dictionary
var charged := false
var second := false   # sempre false: só o tiro normal é lançado
var dir := 1
var damage := 2.0
var multiplier := 1.0
var _frames: Array
var _lob: Dictionary
var _i := 0                 # quadro da gravação
var _ball := Vector2.ZERO   # centro da bola, no espaço do nó
var _vel := Vector2.ZERO    # px/frame, depois do caminho gravado
var _contact := Vector2.INF # ponto do respingo, no espaço do nó
var _hit := {}
var _box := RectangleShape2D.new()
var _shape := CollisionShape2D.new()


func _ready() -> void:
	_frames = Weapons.frames(weapon).normal
	_lob = Weapons.frames(weapon).lob
	scale.x = dir
	_i = int(_lob.start)
	_ball = _path(0)
	_box.size = Vector2.ONE * RADIUS * 2.0
	_shape.shape = _box
	add_child(_shape)
	body_entered.connect(_on_body)


## Ponto j do caminho gravado no espaço do nó (pés do X na origem).
func _path(j: int) -> Vector2:
	var p: Array = _lob.path[j]
	return Vector2(p[0], p[1]) - ANCHOR


func _physics_process(_delta: float) -> void:
	_i += 1
	if _contact != Vector2.INF:
		if _i >= _frames.size():
			queue_free()
		queue_redraw()
		return
	var j := _i - int(_lob.start)
	var next: Vector2
	if j < _lob.path.size():
		next = _path(j)
		_vel = next - _ball
	else:
		_vel.y += GRAVITY
		next = _ball + _vel
	# Raio do centro atual até a borda da bola na próxima posição.
	var ahead := next + (next - _ball).normalized() * RADIUS
	var q := PhysicsRayQueryParameters2D.create(to_global(_ball), to_global(ahead))
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider is PhysicsBody2D and not (hit.collider is Player or hit.collider is Boss):
		_land(to_local(hit.position))
		return
	_ball = next
	_shape.position = _ball
	if not get_viewport_rect().grow(64).has_point(get_global_transform_with_canvas() * _ball):
		queue_free()
	queue_redraw()


func _land(at: Vector2) -> void:
	_contact = at
	_i = int(_lob.land)
	_hit.clear()
	_box.size = SPLASH
	_shape.position = at - Vector2(0, SPLASH.y / 2.0)


func _draw() -> void:
	if _i >= _frames.size():
		return
	var tex: Texture2D = _frames[_i]
	if _contact == Vector2.INF:
		# Bola: o quadro gravado já a tem no caminho; depois do caminho, desloca o último quadro.
		var j := mini(_i - int(_lob.start), _lob.path.size() - 1)
		draw_texture(_frames[int(_lob.start) + j], _ball - _path(j) - ANCHOR)
	else:
		var s: Array = _lob.splash
		draw_texture(tex, _contact - Vector2(s[0], s[1]))


func _on_body(b: Node) -> void:
	if b is Boss and not _hit.has(b):
		_hit[b] = true
		if weapon.has("col"):
			b.hit(weapon.col, multiplier)
		else:
			b.hit(-1, damage)
		if _contact == Vector2.INF:
			_land(_ball + Vector2(0, RADIUS))
