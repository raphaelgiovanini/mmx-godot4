class_name Enemy
extends Boss
## Inimigo comum da fase. Herda de Boss para que tiros, sabre e Giga Crush já o acertem (todos testam
## `is Boss` e o grupo "boss"); a barra de chefe ignora Enemy. Desenhado em código, sem sprites.
## Não bloqueia o jogador: encostar tira vida. Só age perto do jogador (fora da tela fica parado).
##   WALKER  anda de um lado para o outro dentro de `patrol`
##   FLYER   paira e mergulha no jogador quando ele chega perto
##   TURRET  parado, atira bolas de energia na direção do jogador

enum Kind { WALKER, FLYER, TURRET }

const WAKE := 230.0
const SIZE := {Kind.WALKER: Vector2(22, 22), Kind.FLYER: Vector2(18, 12), Kind.TURRET: Vector2(22, 16)}
const HP := {Kind.WALKER: 4, Kind.FLYER: 2, Kind.TURRET: 6}
const OUTLINE := Color8(16, 16, 24)

@export var kind := Kind.WALKER
@export var patrol := 64.0
@export var contact := 2

var _player: Player
var _origin := Vector2.ZERO
var _dir := -1
var _t := 0
var _dive := 0     # flyer: frames restantes do mergulho


func _ready() -> void:
	add_to_group(&"boss")
	respawn = false
	invuln_frames = 6
	damage = {0: 1, 1: 2, 2: 4, 3: 4, 4: 8}
	max_hp = HP[kind]
	hp = max_hp
	_origin = position
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = SIZE[kind]
	shape.shape = box
	shape.position.y = -box.size.y / 2
	add_child(shape)
	defeated.connect(queue_free)


func _physics_process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player")
		if _player == null:
			return
		_player.add_collision_exception_with(self)
	_t += 1
	_invuln = maxi(_invuln - 1, 0)
	modulate = Color(4, 4, 4) if _invuln > invuln_frames - 3 else Color.WHITE
	if hp <= 0 or global_position.distance_to(_player.global_position) > WAKE:
		queue_redraw()
		return
	match kind:
		Kind.WALKER:
			position.x += _dir * 0.75
			if absf(position.x - _origin.x) > patrol:
				position.x = _origin.x + signf(position.x - _origin.x) * patrol
				_dir = -_dir
		Kind.FLYER:
			var to_player := _player.global_position + Vector2(0, -18) - global_position
			if _dive == 0 and absf(to_player.x) < 110 and _t % 150 == 0:
				_dive = 70
			if _dive > 0:
				_dive -= 1
				position += to_player.limit_length(1.6)
			else:
				position = position.move_toward(_origin + Vector2(0, sin(_t * 0.06) * 10), 1.0)
		Kind.TURRET:
			if _t % 110 == 0:
				var shot := EnemyShot.new()
				shot.position = position + Vector2(0, -12)
				shot.velocity = (_player.global_position + Vector2(0, -16) - global_position).normalized() * 2.0
				get_parent().add_child(shot)
	if _hurtbox().intersects(_player_box()):
		_player.take_damage(contact)
	queue_redraw()


func _hurtbox() -> Rect2:
	var s: Vector2 = SIZE[kind]
	return Rect2(global_position - Vector2(s.x / 2, s.y), s)


func _player_box() -> Rect2:
	return Rect2(_player.global_position - Vector2(7, 30), Vector2(14, 30))


func _draw() -> void:
	var step := (_t / 8) % 2
	match kind:
		Kind.WALKER:
			# Mecha de patrulha: corpo azul-aço, visor vermelho e pernas alternando.
			var face := float(_dir)
			for leg in [-6, 4]:
				var lift := 2 if (step == 0) == (leg < 0) else 0
				draw_rect(Rect2(leg - 1, -8 - lift, 5, 8 + lift), OUTLINE)
				draw_rect(Rect2(leg, -8 - lift, 3, 7 + lift), Color8(90, 100, 120))
			draw_rect(Rect2(-11, -23, 22, 16), OUTLINE)
			draw_rect(Rect2(-10, -22, 20, 14), Color8(72, 112, 176))
			draw_rect(Rect2(-10, -22, 20, 4), Color8(120, 168, 232))
			draw_rect(Rect2(face * 3 - 4, -18, 8, 4), Color8(248, 56, 48))
			draw_rect(Rect2(face * 3 - 2, -17, 3, 2), Color8(255, 220, 200))
		Kind.FLYER:
			# Drone-morcego: corpo roxo, asas batendo, olho amarelo.
			var flap := -6.0 if step == 0 else 2.0
			for side in [-1, 1]:
				draw_colored_polygon(PackedVector2Array([Vector2(side * 4, -8), Vector2(side * 14, -8 + flap), Vector2(side * 10, -2)]), Color8(150, 90, 200))
			draw_circle(Vector2(0, -6), 7, OUTLINE)
			draw_circle(Vector2(0, -6), 6, Color8(110, 60, 160))
			draw_circle(Vector2(0, -7), 2.5, Color8(255, 230, 80))
		Kind.TURRET:
			# Canhão de cúpula: base cinza, cano mirando o jogador.
			var aim := Vector2.LEFT
			if _player:
				aim = (_player.global_position + Vector2(0, -16) - (global_position + Vector2(0, -10))).normalized()
			draw_line(Vector2(0, -10), Vector2(0, -10) + aim * 13, OUTLINE, 6)
			draw_line(Vector2(0, -10), Vector2(0, -10) + aim * 12, Color8(160, 160, 176), 4)
			draw_circle(Vector2(0, -8), 8, OUTLINE)
			draw_circle(Vector2(0, -8), 7, Color8(200, 120, 40))
			draw_rect(Rect2(-11, -5, 22, 5), OUTLINE)
			draw_rect(Rect2(-10, -4, 20, 4), Color8(110, 110, 124))
			var glow := 0.5 + 0.5 * sin(_t * 0.15)
			draw_circle(Vector2(0, -9), 2.5, Color(1, 0.3 + glow * 0.5, 0.2))


## Bola de energia do TURRET: some na parede ou depois de 3 s; tira 2 de vida.
class EnemyShot extends Node2D:
	var velocity := Vector2.ZERO
	var _life := 180

	func _physics_process(_delta: float) -> void:
		position += velocity
		_life -= 1
		var q := PhysicsPointQueryParameters2D.new()
		q.position = global_position
		var hits := get_world_2d().direct_space_state.intersect_point(q)
		var wall := hits.any(func(h): return h.collider is StaticBody2D and not h.collider is Boss)
		var player: Player = get_tree().get_first_node_in_group(&"player")
		if player and Rect2(player.global_position - Vector2(7, 30), Vector2(14, 30)).has_point(global_position):
			player.take_damage(2)
			wall = true
		if wall or _life <= 0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 5, Color(1, 0.5, 0.1, 0.35))
		draw_circle(Vector2.ZERO, 3, Color(1, 0.75, 0.3))
		draw_circle(Vector2.ZERO, 1.5, Color.WHITE)
