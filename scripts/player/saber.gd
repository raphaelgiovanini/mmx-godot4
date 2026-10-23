class_name Saber
extends Node
## Z-Saber do Zero (tecla F). Tempos e dano do mod "Saber Zero" do MegaManXSNESRecomp
## (docs/saber-zero.md lá), os mesmos do Saber.gd do mmx8. Sprites do mmx8 (tools/install_saber.py).
## Chão: combo saber_a > saber_b > saber_c. Ar, parede e dash: golpe único.
## Golpes especiais: ↑+F no chão = Ryuenjin (sobe girando o sabre, invencível);
## tiro carregado e F em até 27 frames = golpe final (16 de dano, combo de carga do X3);
## Black Zero: o 3º golpe solta a onda do sabre.

# start/active/recovery em frames de 60 Hz; chain = frame a partir do qual o próximo do combo sai;
# buffer = frame a partir do qual um aperto fica guardado; dmg/boss = dano normal/em chefe (recomp).
const ATTACKS := {
	"saber_a": {"start": 4, "active": 8, "recovery": 18, "chain": 12, "buffer": 4, "dmg": 3, "boss": 1, "box": Vector2(40, 34)},
	"saber_b": {"start": 0, "active": 12, "recovery": 18, "chain": 12, "buffer": 0, "dmg": 3, "boss": 1, "box": Vector2(40, 34)},
	"saber_c": {"start": 0, "active": 14, "recovery": 25, "chain": -1, "buffer": 99, "dmg": 8, "boss": 2, "box": Vector2(48, 40)},
	"saber_air": {"start": 4, "active": 8, "recovery": 6, "chain": -1, "buffer": 99, "dmg": 3, "boss": 1, "box": Vector2(40, 44)},
	"saber_wall": {"start": 0, "active": 12, "recovery": 8, "chain": -1, "buffer": 99, "dmg": 3, "boss": 1, "box": Vector2(40, 40)},
	"saber_dash": {"start": 2, "active": 10, "recovery": 18, "chain": -1, "buffer": 99, "dmg": 3, "boss": 1, "box": Vector2(48, 30)},
	"finisher": {"start": 0, "active": 14, "recovery": 25, "chain": -1, "buffer": 99, "dmg": 16, "boss": 6, "box": Vector2(52, 44), "anim": "saber_c"},
	"ryuenjin": {"start": 0, "active": 25, "recovery": 0, "chain": -1, "buffer": 99, "dmg": 8, "boss": 3, "box": Vector2(30, 56), "anim": "saber_air"},
}
const COMBO := {"saber_a": "saber_b", "saber_b": "saber_c"}
const Projectile := preload("res://scripts/player/projectile.gd")
const FINISHER_WINDOW := 27
const WAVE_DAMAGE := 4         # boss_wave_damage do recomp
const WAVE_SPEED := 5.5        # px/frame
const RYU_JUMP := 5.5          # px/frame para cima, perde GRAVITY por frame

var player: Player
var current := ""
var tick := 0
var queued := false
var finisher := 0              # > 0: janela do golpe final aberta
var _hit: Area2D
var _hit_done := {}


func _init(p: Player) -> void:
	player = p


func uses_saber() -> bool:
	return player.character.get("melee", "") == "saber"


## Chamado pelo Player depois do tiro carregado.
func open_finisher() -> void:
	if uses_saber():
		finisher = FINISHER_WINDOW


## 3º aperto do combo do Zero (X3): o golpe de sabre do fim do combo.
func start_finisher() -> void:
	if uses_saber() and current == "":
		_start("finisher")


## Golpe em andamento (o Player troca a pose e trava o andar no chão).
func busy() -> bool:
	return current != ""


func anim() -> StringName:
	return StringName(ATTACKS[current].get("anim", current))


func tick_frame() -> void:
	finisher = maxi(finisher - 1, 0)
	if not uses_saber():
		_end()
		return
	if Input.is_action_just_pressed(&"saber"):
		if current != "":
			if tick >= ATTACKS[current].buffer:
				queued = true
		elif finisher > 0:
			finisher = 0
			_start("finisher")
		elif Input.is_action_pressed(&"up") and player.is_on_floor():
			_start("ryuenjin")
		else:
			_start(_context())
	if current == "":
		return
	var a: Dictionary = ATTACKS[current]
	tick += 1
	if current == "ryuenjin":
		player.invuln = maxi(player.invuln, 2)
	if tick == a.start + 1:
		_open_hitbox(a)
	if _hit and tick > a.start + a.active:
		_close_hitbox()
	if queued and a.chain >= 0 and tick >= a.chain and COMBO.has(current):
		_start(COMBO[current])
		return
	# Golpe aéreo termina ao pousar; os outros pelo tempo total.
	if (current == "saber_air" and tick > 2 and player.is_on_floor()) or tick >= a.start + a.active + a.recovery:
		_end()


func _context() -> String:
	if player.state == Player.State.WALL_SLIDE:
		return "saber_wall"
	if player.state == Player.State.DASH:
		return "saber_dash"
	if not player.is_on_floor():
		return "saber_air"
	return "saber_a"


func _start(kind: String) -> void:
	_close_hitbox()
	current = kind
	tick = 0
	queued = false
	player.charge_fx.play("saber_%d" % (1 + ["saber_b", "saber_wall"].count(kind) + int(kind in ["saber_c", "saber_dash", "finisher", "ryuenjin"]) * 2))
	if kind == "ryuenjin":
		player.vy = RYU_JUMP
		player.state = Player.State.AIR
	if kind == "saber_c" and player.character_id == "zero_black":
		_wave()


func _end() -> void:
	_close_hitbox()
	current = ""
	queued = false


func _open_hitbox(a: Dictionary) -> void:
	_hit = Area2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = a.box
	shape.shape = box
	_hit.add_child(shape)
	_hit_done = {}
	_hit.body_entered.connect(_on_body.bind(a))
	player.add_child(_hit)
	_hit.position = Vector2(player.facing * (a.box.x / 2 + 4), -18)


func _close_hitbox() -> void:
	if _hit:
		_hit.queue_free()
		_hit = null


## Cada golpe acerta cada alvo uma vez. weapon_col -1 = fora da tabela do X1: o dano vai inteiro
## no multiplicador (dano do recomp em chefe × stats.damage do personagem).
func _on_body(b: Node, a: Dictionary) -> void:
	if b is Boss and not _hit_done.has(b):
		_hit_done[b] = true
		b.hit(-1, a.boss * player.stat("damage"))


func _wave() -> void:
	var w := Projectile.new()
	w.level = 2
	w.dir = player.facing
	w.speed = WAVE_SPEED * player.pace
	w.weapon_col = -1
	w.multiplier = WAVE_DAMAGE * player.stat("damage")
	w.color = Color("ff4fd0")
	w.position = player.global_position + Vector2(player.facing * 24, player.muzzle_y())
	player.get_parent().add_child(w)
