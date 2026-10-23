extends Area2D
## Tiro de arma (Weapons.LIST) ou do braço da armadura: toca a gravação do original presa ao ponto
## do disparo, um quadro por frame (gravação com EVERY=1), com a caixa de dano no que estiver desenhado.
## Quando a gravação acaba com o tiro ainda na tela, os últimos LOOP quadros se repetem andando na
## velocidade medida até sair da tela; cada quadro repetido é deslocado para a borda da frente
## continuar a linha do movimento (sem voltar para trás a cada volta). Ao bater no chefe ou numa
## parede (raio na altura do meio do desenho), o tiro some com o impacto do buster no ponto do choque.
## ponytail: não persegue alvos (Homing Torpedo, Parasitic Bomb); trocar por comportamento próprio.

const Projectile := preload("res://scripts/player/projectile.gd")
const ANCHOR := Vector2(48, 120)
const LOOP := 8            # quadros repetidos depois do fim da gravação
const MARGIN := 16.0       # px além da borda da tela para sumir

var weapon: Dictionary
var charged := false
## Segundo tiro da carga dupla (Weapons.frames "second").
var second := false
var dir := 1
var damage := 2.0
## Multiplicador do personagem sobre a tabela do X1 (armas com "col"); as outras usam damage.
var multiplier := 1.0
var _list: Array
var _rects: Array
var _tick := 0
var _shift := 0.0          # deslocamento extra depois do fim da gravação
var _speed := 0.0
## Fim útil da gravação: depois do último quadro com o tiro visível (ele saiu da tela do SNES, que
## tem 256 px; a nossa é mais larga, então a continuação assume dali).
var _end := 0
var _box := RectangleShape2D.new()
var _shape := CollisionShape2D.new()


func _ready() -> void:
	var data := Weapons.frames(weapon)
	var i := 2 if second else (1 if charged and not data.charged.is_empty() else 0)
	_list = [data.normal, data.charged, data.second][i]
	_rects = data.rects[i]
	_shape.shape = _box
	add_child(_shape)
	body_entered.connect(_on_body)
	scale.x = dir
	if _list.is_empty():
		queue_free()
		return
	# Fim útil: o primeiro quadro que encosta na borda da tela do SNES (dali em diante o tiro está
	# cortado) ou, se ele some antes, o último quadro visível.
	_end = _rects.size()
	# Gravação que acaba com o tiro ainda na tela (a do X3 parou antes da borda): ele segue andando.
	var cut: bool = _rects[_end - 1].size != Vector2i.ZERO
	while _end > 1 and _rects[_end - 1].size == Vector2i.ZERO:
		_end -= 1
	var exits := cut
	for k in _end:
		if _rects[k].end.x >= data.edge - 1:
			_end = maxi(k, 1)
			exits = true
			break
	# Só continua andando o tiro que saiu pela borda; o que some antes (explode, se desfaz) some aqui.
	_speed = _measure_speed() if exits else 0.0


## Velocidade da frente do tiro nos últimos 4 quadros úteis da gravação (px/frame).
func _measure_speed() -> float:
	var n := _end
	if n < 5 or _rects[n - 5].size == Vector2i.ZERO:
		return 0.0
	return float(_rects[n - 1].end.x - _rects[n - 5].end.x) / 4.0


func _frame() -> int:
	if _tick < _end:
		return _tick
	var loop := mini(LOOP, _end)
	return _end - loop + (_tick - _end) % loop


## Deslocamento depois do fim: velocidade × frames extras, alinhando a frente do quadro repetido
## com a frente do último quadro gravado.
func _offset() -> float:
	var n := _end
	if _tick < n:
		return 0.0
	var k := _frame()
	var behind: float = _rects[n - 1].end.x - _rects[k].end.x if _rects[k].size != Vector2i.ZERO else 0.0
	return _speed * (_tick - n + 1) + behind


func _physics_process(_delta: float) -> void:
	_tick += 1
	if _tick >= _end:
		if _speed <= 0.5 or _offscreen():
			queue_free()
			return
	_shift = _offset()
	var r: Rect2i = _rects[_frame()]
	_shape.disabled = r.size == Vector2i.ZERO
	_box.size = Vector2(maxi(r.size.x, 1), maxi(r.size.y, 1))
	_shape.position = _local(Vector2(r.position) + Vector2(r.size) / 2.0)
	queue_redraw()
	if r.size != Vector2i.ZERO:
		var wall := _wall_ahead(r)
		if wall != Vector2.INF:
			_impact(wall)


## Ponto da textura gravada (pixels da janela) no espaço do nó.
func _local(at: Vector2) -> Vector2:
	return at - ANCHOR + Vector2(_shift, 0)


## Parede entre o meio e a frente do desenho, na altura do meio; INF se não há.
func _wall_ahead(r: Rect2i) -> Vector2:
	var mid := r.position.y + r.size.y / 2.0
	var q := PhysicsRayQueryParameters2D.create(to_global(_local(Vector2(r.position.x + r.size.x / 2.0, mid))),
		to_global(_local(Vector2(r.end.x, mid))))
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not (hit.collider is PhysicsBody2D) or hit.collider is Player or hit.collider is Boss:
		return Vector2.INF
	return hit.position


## Some com o impacto do buster (médio no tiro normal, carregado no carregado) no ponto do choque.
func _impact(at: Vector2) -> void:
	if is_queued_for_deletion():
		return
	var frames := Projectile._frames("x1")
	var anim: StringName = &"hit" if charged or second else &"medium_hit"
	if frames and frames.has_animation(anim):
		var fx := AnimatedSprite2D.new()
		fx.sprite_frames = frames
		fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fx.global_position = at
		get_parent().add_child(fx)
		fx.play(anim)
		fx.animation_finished.connect(fx.queue_free)
	queue_free()


## Saiu da tela: a caixa inteira além da borda (em pixels da tela, pela transformação do canvas).
func _offscreen() -> bool:
	var r: Rect2i = _rects[_frame()]
	var left := get_global_transform_with_canvas() * (Vector2(r.position) - ANCHOR + Vector2(_shift, 0))
	var right := get_global_transform_with_canvas() * (Vector2(r.end) - ANCHOR + Vector2(_shift, 0))
	var w := get_viewport_rect().size.x
	return minf(left.x, right.x) > w + MARGIN or maxf(left.x, right.x) < -MARGIN


func _draw() -> void:
	if _list.is_empty():
		return
	draw_texture(_list[_frame()], _local(Vector2.ZERO))


func _on_body(b: Node) -> void:
	if b is Boss:
		if weapon.has("col"):
			b.hit(weapon.col + (9 if charged else 0), multiplier)
		else:
			b.hit(-1, damage)
		# No rosto do chefe, do lado de onde o tiro veio (a caixa do tiro pode ser bem maior que ele).
		_impact((b as Node2D).global_position + Vector2(-dir * 12, -16))
