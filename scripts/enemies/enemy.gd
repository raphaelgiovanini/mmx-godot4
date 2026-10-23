class_name Enemy
extends Boss
## Inimigo comum da fase. Herda de Boss para que tiros, sabre e Giga Crush já o acertem (todos testam
## `is Boss` e o grupo "boss"); a barra de chefe ignora Enemy. Não bloqueia o jogador: encostar tira vida.
## Só age perto do jogador. Sprites do mmx8-16bit (tools/install_mmx8_enemies.py).
##   METOOL  anda até o jogador; de vez em quando se esconde no capacete (tiro ricocheteia)
##   BATTON  morcego: voa ondulando e mergulha no jogador
##   TURRET  canhão parado: atira reto ou na diagonal, conforme onde o jogador está
##   SPIKY   roda de espinhos: rola rápido e volta nas pontas da patrulha

enum Kind { METOOL, BATTON, TURRET, SPIKY }

const SHEETS := "res://assets/enemies/"
const WAKE := 230.0
const SHEET := {Kind.METOOL: "metool", Kind.BATTON: "batton", Kind.TURRET: "turret", Kind.SPIKY: "spiky"}
const SIZE := {Kind.METOOL: Vector2(20, 18), Kind.BATTON: Vector2(22, 18), Kind.TURRET: Vector2(24, 24), Kind.SPIKY: Vector2(28, 30)}
const HP := {Kind.METOOL: 3, Kind.BATTON: 2, Kind.TURRET: 6, Kind.SPIKY: 4}
## Altura do sprite para os pés ficarem na origem (fundo opaco da folha); BATTON fica centrado.
const FEET := {Kind.METOOL: -10, Kind.BATTON: 0, Kind.TURRET: -14, Kind.SPIKY: -18}
const ONCE := [&"defense", &"open", &"turn_to_diagonal", &"turn_to_horizontal", &"shot_horizontal", &"shot_diagonal"]

static var _sheets := {}

@export var kind := Kind.METOOL
@export var patrol := 64.0
@export var contact := 2

var _player: Player
var _origin := Vector2.ZERO
var _dir := -1
var _t := 0
var _dive := 0     # batton: frames restantes do mergulho
var _hide := 0     # metool: frames escondido no capacete
var _body := AnimatedSprite2D.new()


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
	shape.position.y = 0.0 if kind == Kind.BATTON else -box.size.y / 2
	add_child(shape)
	_body.sprite_frames = sheet(SHEET[kind])
	_body.position.y = FEET[kind]
	add_child(_body)
	_body.play({Kind.METOOL: &"walk", Kind.BATTON: &"idle", Kind.TURRET: &"shot_horizontal", Kind.SPIKY: &"walk"}[kind])
	_body.pause()
	defeated.connect(queue_free)


## SpriteFrames de uma folha do Aseprite (PNG + JSON): uma animação por tag, duração em ms.
static func sheet(name: String) -> SpriteFrames:
	if _sheets.has(name):
		return _sheets[name]
	var tex: Texture2D = load(SHEETS + name + ".png")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHEETS + name + ".json"))
	var list: Array = d["frames"] if d["frames"] is Array else d["frames"].values()
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for tag in d["meta"]["frameTags"]:
		var anim := StringName(tag["name"])
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 1000.0)
		sf.set_animation_loop(anim, not anim in ONCE)
		for i in range(tag["from"], tag["to"] + 1):
			var r: Dictionary = list[i]["frame"]
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(r["x"], r["y"], r["w"], r["h"])
			sf.add_frame(anim, at, list[i]["duration"])
	_sheets[name] = sf
	return sf


## Metool escondido: o tiro ricocheteia (some sem dano).
func hit(weapon_col: int, multiplier: float) -> bool:
	if _hide > 0:
		return true
	return super(weapon_col, multiplier)


func _physics_process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player")
		if _player == null:
			return
		_player.add_collision_exception_with(self)
	_t += 1
	_invuln = maxi(_invuln - 1, 0)
	_body.modulate = Color(4, 4, 4) if _invuln > invuln_frames - 3 else Color.WHITE
	if hp <= 0 or global_position.distance_to(_player.global_position) > WAKE:
		_body.pause()
		return
	if not _body.is_playing():
		_body.play()
	var to_player := _player.global_position - global_position
	match kind:
		Kind.METOOL:
			_metool(to_player)
		Kind.BATTON:
			_batton(to_player)
		Kind.TURRET:
			_turret(to_player)
		Kind.SPIKY:
			position.x += _dir * 1.6
			if absf(position.x - _origin.x) > patrol:
				position.x = _origin.x + signf(position.x - _origin.x) * patrol
				_dir = -_dir
			_face(_dir)
	if _hurtbox().intersects(Rect2(_player.global_position - Vector2(7, 30), Vector2(14, 30))):
		_player.take_damage(contact)


func _metool(to_player: Vector2) -> void:
	if _hide > 0:
		_hide -= 1
		if _hide == 0:
			_body.play(&"open")
			_body.animation_finished.connect(func(): _body.play(&"walk"), CONNECT_ONE_SHOT)
		return
	if _t % 150 == 0 and absf(to_player.x) < 120:
		_hide = 70
		_body.play(&"defense")
		return
	if _body.animation == &"walk":
		_dir = int(signf(to_player.x)) if absf(to_player.x) > 4 else _dir
		var nx := position.x + _dir * 0.6
		if absf(nx - _origin.x) <= patrol:
			position.x = nx
		_face(_dir)


func _batton(to_player: Vector2) -> void:
	var target := to_player + Vector2(0, -18)
	if _dive == 0 and absf(target.x) < 110 and _t % 120 == 0:
		_dive = 70
		_body.play(&"jump")
	if _dive > 0:
		_dive -= 1
		position += target.limit_length(1.6)
		if _dive == 0:
			_body.play(&"idle")
	else:
		position = position.move_toward(_origin + Vector2(sin(_t * 0.03) * 24, sin(_t * 0.06) * 10), 1.0)
	_face(int(signf(to_player.x)))


func _turret(to_player: Vector2) -> void:
	_face(int(signf(to_player.x)))
	if _t % 110 != 0:
		return
	var aim := to_player + Vector2(0, -16)
	var diagonal := aim.y < -absf(aim.x) * 0.4
	_body.play(&"shot_diagonal" if diagonal else &"shot_horizontal")
	var shot := EnemyShot.new()
	shot.position = position + Vector2(0, -14)
	shot.velocity = (Vector2(signf(aim.x), -1).normalized() if diagonal else Vector2(signf(aim.x), 0)) * 2.2
	get_parent().add_child(shot)


## As folhas do mmx8 olham para a esquerda.
func _face(dir: int) -> void:
	if dir != 0:
		_body.flip_h = dir > 0


func _hurtbox() -> Rect2:
	var s: Vector2 = SIZE[kind]
	return Rect2(global_position - Vector2(s.x / 2, s.y / 2 if kind == Kind.BATTON else s.y), s)


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
