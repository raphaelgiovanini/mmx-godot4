class_name ChillPenguin
extends Boss
## Chill Penguin (X1) lutando, com as poses gravadas no Mesen (assets/bosses/chill_penguin/poses/).
## Golpes do original: tiro de gelo, deslizar de barriga, sopro que cria estátuas de gelo e pulo;
## depois de alguns golpes, nevasca que empurra o X para a parede. Tempos e velocidades são
## placeholders (a IA da ROM ainda não foi desmontada); dano por arma continua o da tabela do X1.

const POSES := "res://assets/bosses/chill_penguin/poses/pose_%03d.png"
const ANIMS := {
	&"idle": [[15, 16], 4], &"aim": [[13], 1], &"throw": [[14], 1], &"dive": [[20], 1],
	&"slide": [[21, 22], 10], &"breath": [[65, 66, 67, 68, 69, 70], 12], &"jump": [[6], 1],
	&"fall": [[7], 1], &"land": [[8, 9], 10], &"blizzard": [[51, 52, 53, 54], 8], &"statue": [[72], 1],
}
const FLOOR_Y := 176.0
const BODY_HALF := 20.0     # o corpo fica a 20 px da borda de trás das poses (olham para a esquerda)
const GRAVITY := 0.25
const CONTACT := 4
const SLIDE_SPEED := 4.5

enum State { INTRO, IDLE, SHOOT, DIVE, SLIDE, BREATH, JUMP, LAND, BLIZZARD }

## Limites da arena (x mínimo e máximo do corpo).
@export var arena := Vector2(3024, 3376)

var _state := State.INTRO
var _t := 0
var _facing := -1
var _vel := Vector2.ZERO
var _shots := 0
var _moves := 0
var _player: Player


func _ready() -> void:
	super()
	_sprite.position.y = 0
	_sprite.frame_changed.connect(_anchor)
	_sprite.animation_changed.connect(_anchor)
	_set_state(State.INTRO, 70)


func _frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for anim in ANIMS:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, ANIMS[anim][1])
		for n in ANIMS[anim][0]:
			sf.add_frame(anim, load(POSES % n))
	return sf


## Pés na origem e o corpo (não a pose inteira) centrado, para as poses não tremerem.
func _anchor() -> void:
	var tex := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex == null:
		return
	var s := tex.get_size()
	_sprite.offset = Vector2((BODY_HALF - s.x / 2) * -_facing, -s.y / 2)
	_sprite.flip_h = _facing > 0


func _set_state(s: State, frames: int) -> void:
	_state = s
	_t = frames
	var anim: StringName = {State.INTRO: &"idle", State.IDLE: &"idle", State.SHOOT: &"aim", State.DIVE: &"dive",
		State.SLIDE: &"slide", State.BREATH: &"breath", State.JUMP: &"jump", State.LAND: &"land",
		State.BLIZZARD: &"blizzard"}[s]
	_sprite.play(anim)
	_anchor()


func _physics_process(delta: float) -> void:
	super(delta)
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player")
		if _player:
			_player.add_collision_exception_with(self)
	if hp <= 0 or _player == null:
		return
	_t -= 1
	match _state:
		State.INTRO, State.LAND:
			if _t <= 0:
				_set_state(State.IDLE, randi_range(30, 55))
		State.IDLE:
			_face_player()
			if _t <= 0:
				_choose()
		State.SHOOT:
			if _t == 12:
				_sprite.play(&"throw")
				_spawn(IceShot.new(), Vector2(_facing * 26, -14))
			if _t <= 0:
				_shots -= 1
				if _shots > 0:
					_set_state(State.SHOOT, 34)
				else:
					_set_state(State.IDLE, 30)
		State.DIVE:
			if _t <= 0:
				_set_state(State.SLIDE, 999)
		State.SLIDE:
			position.x += _facing * SLIDE_SPEED
			for b in get_tree().get_nodes_in_group(&"boss"):
				if b is IceStatue and absf(b.global_position.x - global_position.x) < 24:
					b.hit(-1, 99)
			if position.x <= arena.x or position.x >= arena.y:
				position.x = clampf(position.x, arena.x, arena.y)
				_set_state(State.LAND, 24)
		State.BREATH:
			if _t % 8 == 0:
				_spawn(Mist.new(), Vector2(_facing * 30, -16), _facing)
			if _t == 20:
				for d in [44, 84]:
					var x := clampf(position.x + _facing * d, arena.x, arena.y)
					var st := IceStatue.new()
					st.position = Vector2(x, FLOOR_Y)
					get_parent().add_child(st)
			if _t <= 0:
				_set_state(State.IDLE, 40)
		State.JUMP:
			_vel.y += GRAVITY
			position += _vel
			position.x = clampf(position.x, arena.x, arena.y)
			if _vel.y > 0 and _sprite.animation != &"fall":
				_sprite.play(&"fall")
			if position.y >= FLOOR_Y:
				position.y = FLOOR_Y
				_set_state(State.LAND, 14)
		State.BLIZZARD:
			# Vento na direção para onde ele olha: empurra o X (respeitando as paredes).
			_player.move_and_collide(Vector2(_facing * 1.1, 0))
			if _t % 3 == 0:
				_spawn(Snow.new(), Vector2(-_facing * 220, randf_range(-150, 0)), _facing)
			if _t <= 0:
				_set_state(State.IDLE, 40)
	if _hurtbox().intersects(Rect2(_player.global_position - Vector2(7, 30), Vector2(14, 30))):
		_player.take_damage(CONTACT)


func _choose() -> void:
	_moves += 1
	if _moves % 5 == 0:
		_set_state(State.BLIZZARD, 150)
		return
	match randi() % 4:
		0:
			_shots = randi_range(2, 3)
			_set_state(State.SHOOT, 34)
		1:
			_set_state(State.DIVE, 14)
		2:
			_set_state(State.BREATH, 72)
		3:
			var target := _player.global_position.x
			_vel = Vector2(clampf((target - position.x) / 60.0, -3.0, 3.0), -6.5)
			_set_state(State.JUMP, 999)


func _face_player() -> void:
	var f := -1 if _player.global_position.x < global_position.x else 1
	if f != _facing:
		_facing = f
		_anchor()


func _hurtbox() -> Rect2:
	return Rect2(global_position - Vector2(16, 32), Vector2(32, 32))


func _spawn(n: Node2D, at: Vector2, dir := 0) -> void:
	n.position = position + at
	if dir != 0:
		n.set(&"dir", dir)
	elif n is IceShot:
		n.dir = _facing
	get_parent().add_child(n)


static func _player_box(tree: SceneTree) -> Rect2:
	var p: Player = tree.get_first_node_in_group(&"player")
	return Rect2(p.global_position - Vector2(7, 30), Vector2(14, 30)) if p else Rect2()


## Pedaço de gelo: voa reto, quica uma vez no chão e se quebra na parede ou no X (2 de dano).
class IceShot extends Node2D:
	var dir := -1
	var _vy := -1.2
	var _life := 200

	func _physics_process(_delta: float) -> void:
		position += Vector2(dir * 2.6, _vy)
		_vy += 0.06
		if position.y >= FLOOR_Y - 6 and _vy > 0:
			position.y = FLOOR_Y - 6
			_vy = -_vy * 0.6
		_life -= 1
		var box := ChillPenguin._player_box(get_tree())
		var hit := box.has_point(global_position)
		if hit:
			get_tree().get_first_node_in_group(&"player").take_damage(2)
		var q := PhysicsPointQueryParameters2D.new()
		q.position = global_position
		var wall := get_world_2d().direct_space_state.intersect_point(q).any(func(h): return h.collider is StaticBody2D and not h.collider is Boss)
		if hit or wall or _life <= 0:
			HitFX.impact(get_parent(), global_position, Color("bfefff"), false)
			queue_free()
		rotation += 0.2 * dir
		queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(0, -6), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0)])
		draw_colored_polygon(pts, Color("bfefff"))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color("3d8fd0"), 1.0)
		draw_line(Vector2(-2, -2), Vector2(1, -4), Color.WHITE, 1.0)


## Sopro gelado: nuvem que avança e some; tira 2 se encostar.
class Mist extends Node2D:
	var dir := -1
	var _t := 0

	func _physics_process(_delta: float) -> void:
		_t += 1
		position.x += dir * 2.0
		position.y += sin(_t * 0.3) * 0.4
		if ChillPenguin._player_box(get_tree()).grow(4).has_point(global_position):
			get_tree().get_first_node_in_group(&"player").take_damage(2)
		if _t > 40:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 0.6 * (1.0 - _t / 40.0)
		draw_circle(Vector2.ZERO, 5 + _t * 0.2, Color(0.85, 0.95, 1.0, a))
		draw_circle(Vector2(3, -2), 3, Color(1, 1, 1, a))


## Floco da nevasca: só visual, atravessa a arena com o vento.
class Snow extends Node2D:
	var dir := -1
	var _t := 0

	func _physics_process(_delta: float) -> void:
		_t += 1
		position += Vector2(dir * 4.0, 1.2)
		if _t > 110:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 1.5, Color(1, 1, 1, 0.85))


## Estátua de gelo do sopro: bloqueia o caminho, quebra com 3 tiros ou com o deslizar do pinguim.
class IceStatue extends Boss:
	func _ready() -> void:
		show_bar = false
		respawn = false
		max_hp = 3
		invuln_frames = 4
		damage = {}
		super()
		_sprite.position.y = 0
		_sprite.offset.y = -16
		defeated.connect(queue_free)

	func _frames() -> SpriteFrames:
		var sf := SpriteFrames.new()
		sf.remove_animation(&"default")
		sf.add_animation(&"idle")
		sf.add_frame(&"idle", load(POSES % 72))
		return sf
