class_name Player
extends CharacterBody2D
## Movimento e tiro do jogador com os números da tabela de física do SNES (X1 = X3, ver docs/fisica.md).
## Toda a lógica roda em px/frame a 60 Hz, como no SNES; só a conversão final usa px/s.
## O visual é um nó filho trocável ("Visual") com show_state(pose, facing): sprite hoje, 2.5D depois.

signal character_changed(character: Dictionary)
signal died

enum State { IDLE, WALK, AIR, DASH, WALL_SLIDE }

# Tabela 86:B272 (X3) / 86:B9B1 (X1). Valor bruto / 256 = px por frame.
const WALK := 376.0 / 256.0        # linha 02
const DASH := 885.0 / 256.0        # linha 0A
const JUMP := 1363.0 / 256.0       # linha 03
const GRAVITY := 64.0 / 256.0      # campo grav das linhas de ar
const WALL_SLIDE := 512.0 / 256.0  # linha 09 (ySpd -512)

# Ainda NÃO medidos na ROM (docs/fisica.md, "o que falta"). Placeholders para jogar; trocar pelos reais.
# Velocidade dos tiros, lida no código das três ROMs (docs/tiros.md): lemon 4,0; médio e carregado 6,0.
const SHOT_SPEEDS := [1024.0 / 256.0, 1536.0 / 256.0, 1536.0 / 256.0]

const FALL_CAP := 5.75
const DASH_FRAMES := 32
const WALL_KICK_FRAMES := 8
const CHARGE_LEVELS := [30, 100]  # frames segurando para o médio e o carregado (X1 81:9869 e 81:98C2)
const CHARGE_LEVELS_X3 := [20, 80]  # X3 carrega mais rápido (docs/tiros.md, 04:AF00)
## Zero do X3 (recomp src/mmx_zero.c e docs/saber-zero.md): médio, carregado, combo de 2 tiros,
## e com 201+ o 3º aperto vira o golpe de sabre.
const ZERO_CHARGE := [21, 81, 141, 201]
const SHOT_POSE_FRAMES := 16
const ZSABER_FRAMES := 33     # 11 quadros do golpe a 20 fps
const ZSABER_WAVE_AT := 18    # 7º quadro (lâmina cheia): a onda sai
const AIRDASH_FRAMES := 24  # não medido na ROM do X2; placeholder
const BASE_HP := 16             # vida inicial do X no X1 (w_player_health começa em $10)
const INVULN_FRAMES := 60       # placeholder; o valor do X1 está em w_player_invinsCounter (7E0BD8)

const Projectile := preload("res://scripts/player/projectile.gd")
const WeaponShot := preload("res://scripts/player/weapon_shot.gd")
const LobShot := preload("res://scripts/player/lob_shot.gd")
const STING_FRAMES := 480

@export var visual_path: NodePath = ^"Visual"
## Ritmo do jogo: velocidades × pace, gravidade × pace² (o arco do pulo mantém a forma, só fica
## mais rápido). 1.0 = SNES. Ajustável no jogo (F1/F2) até achar a sensação do PS1.
@export var pace := 1.2
@export var character_id := "x"
## Buster do X escolhido pelo jogador (tecla B): sprites do X1, X2 ou X3.
@export var buster_style := "x1"
const BUSTER_STYLES := ["x1", "x2", "x3"]

var state: State = State.AIR
var facing := 1
## Velocidades em px/frame. vy positivo = para cima (convenção do SNES).
var vx := 0.0
var vy := 0.0
var dash_timer := 0
var kick_timer := 0
var kick_dir := 0
## Pulo saído de um dash mantém a velocidade de dash no ar.
var dash_momentum := false
var air_jumps_left := 0
var charge := 0
## Arma de chefe em uso (Weapons.LIST; 0 = buster). Só o X troca de arma.
var weapon_index := 0
var shot_pose := 0
## Gravação do braço com o segundo tiro guardado ("" = nenhum); sai no próximo aperto do tiro.
var second_shot := ""
## X3 (Tri/Gold): depois da cruz, o próximo aperto dá o golpe de Z-Saber com a onda.
var zsaber_ready := false
var zsaber_timer := 0   # frames restantes do golpe
## Combo do Zero (X3): 1 = falta o 2º tiro; -1 = falta o 2º tiro e depois o sabre (carga 201+);
## 2 = falta o sabre; 0 = nenhum.
var zero_combo := 0
var character: Dictionary = {}
## Peças de armadura do X, uma por encaixe ("" = sem peça; senão uma chave de Characters.ARMOR_SETS).
## Ignoradas nos outros personagens.
var parts := {"head": "", "body": "", "arm": "", "legs": ""}
## Chip do X3 ("", um encaixe, ou "gold" = Hyper Chip, todos). Só vale na peça Tri do mesmo encaixe.
var chip := ""
## Itens: Heart Tanks (+2 de vida máxima cada, até 8) e Sub-Tanks (cheio ou vazio; usar enche a vida).
## Começa com todos (pedido do dono, enquanto as fases não têm os itens para pegar).
var hearts := 8
var sub_tanks := [true, true, true, true]
var airdash_left := 0
var airdash_timer := 0
var airdash_up := false
## Vida de cada personagem, separada: trocar não cura nem divide. Transformação usa a do personagem base.
var hp := {}
var invuln := 0
## Chameleon Sting carregado: invencível por 480 frames, trocando a paleta a cada 6 (83:9B88, $37/$3A).
var sting := 0
## Escudo do corpo do X3 (84:CE41 e 84:87FA, bits de $1FFF): surge depois do 1º golpe. O normal tira
## mais 1 do golpe seguinte e se gasta; o do chip do corpo (Gold) tira 2 de todo golpe e não quebra.
enum Shield { NONE, READY, USED, CHIP }
var shield := Shield.NONE
## Giga Crush do X2: 9ª energia de arma ($1FCA), 28 unidades. Cada golpe recebido com o corpo soma
## 4 (88:D9A5, tabela 86:B0E6). Cheio, gasta tudo num ataque na tela inteira.
const GIGA_MAX := 28.0
const GIGA_PER_HIT := 4.0
const GIGA_FRAMES := 60   # placeholder: duração da pose não medida
const GIGA_DAMAGE := 4.0  # placeholder: dano por chefe não achado na ROM do X2
var giga := 0.0
var giga_t := 0
var shoryuken_t := 0   # subida do Shoryuken: o pulo não é cortado ao soltar o botão
const SpecialShot := preload("res://scripts/player/special_shot.gd")
const HADOUKEN_SPEED := 4.0     # placeholder: velocidade não medida
const SHORYUKEN_FRAMES := 30    # placeholder: duração da subida não medida
## Energia de cada arma (0..Weapons.MAX_ENERGY), do jogador: todos os personagens usam a mesma.
var energy := {}
var spawn_point := Vector2.ZERO
## Cena (vitória, teletransporte): sem controle, só mostra essa pose.
var cutscene_pose := &""
@onready var visual: Node = get_node_or_null(visual_path)
var saber := Saber.new(self)
var charge_fx: Node2D = preload("res://scripts/player/charge_fx.gd").new()


func _ready() -> void:
	add_to_group(&"player")
	spawn_point = global_position
	add_child(charge_fx)
	set_character(character_id)


## Chave da vida: cada personagem tem a sua.
func health_id() -> String:
	return character_id


## Arma copiada em uso. Só o buster por enquanto (energia infinita); as armas dos chefes entram aqui.
func current_weapon() -> Dictionary:
	if weapon_index > 0:
		var w: Dictionary = Weapons.LIST[weapon_index]
		return {"name": w.name, "energy": weapon_energy(w.id) / Weapons.MAX_ENERGY, "color": w.color}
	return {"name": "BUSTER", "energy": 1.0, "color": character.get("color", Color.WHITE).lightened(0.2)}


## Troca de arma (TAB/Q no jogo, menu W). Todos os personagens usam as armas dos chefes.
func set_weapon(i: int) -> void:
	if sting > 0:
		return   # como no X1: com o Sting carregado ativo (0C31) a troca de arma fica travada
	weapon_index = posmod(i, Weapons.LIST.size())
	_refresh_palette()
	character_changed.emit(character)


## Todos mudam de cor com a arma, como o X nos originais (SpriteVisual.set_palette).
func _refresh_palette() -> void:
	var id: String = Weapons.LIST[weapon_index].id if weapon_index > 0 else ""
	if sting > 0:
		id = "sting_%d" % ((STING_FRAMES - sting) / 6 % 8)
	if visual and visual.has_method(&"set_palette"):
		visual.set_palette(id)


func weapon_energy(id: String) -> float:
	return energy.get(id, Weapons.MAX_ENERGY)


func max_hp() -> int:
	return count("max_hp", BASE_HP) + hearts * 2


func take_damage(amount: int) -> void:
	if invuln > 0 or sting > 0 or giga_t > 0:
		return
	var id := health_id()
	hp[id] = maxi(0, hp.get(id, max_hp()) - _reduced(amount))
	invuln = INVULN_FRAMES
	Sfx.play(self, "DAMAGE")
	if hp[id] == 0:
		die()


## ponytail: sem animação de morte; volta ao checkpoint (spawn_point) com a barra cheia.
func die() -> void:
	Sfx.play(self, "X_DIE")
	hp[health_id()] = max_hp()
	shield = Shield.NONE
	global_position = spawn_point
	vx = 0.0
	vy = 0.0
	died.emit()


## Dano depois da armadura, como cada jogo faz na ROM (X1 84:9D41 arredonda para cima pelo stat).
func _reduced(amount: int) -> int:
	if part("body") == "giga":
		# X2 88:DA15: −1 (mínimo 1) e mais −1 se ficar 5 ou mais; o golpe enche o Giga Crush.
		giga = minf(giga + GIGA_PER_HIT, GIGA_MAX)
		var g := maxi(amount - 1, 1)
		return g - 1 if g >= 5 else g
	if part("body") == "tri":
		# X3 84:CE41: metade arredondando para baixo, menos o escudo; nunca menos que 1.
		var t := amount >> 1
		match shield:
			Shield.READY:
				t -= 1
				shield = Shield.USED
			Shield.CHIP:
				t -= 2
			Shield.NONE:
				shield = Shield.CHIP if has_chip("body") else Shield.READY
		return maxi(t, 1)
	if part("body") == "light":
		return ceili(amount / 2.0)   # X1 84:9D41: metade arredondando para cima
	return amount


## Especial da tecla F (no original: comandos de botão). Corpo Giga cheio: Giga Crush. Hadouken só com a
## armadura do X1 completa e Shoryuken com a do X2 completa, os dois com a vida cheia (81:A0EA).
func x_special_name() -> String:
	if part("body") == "giga" and giga >= GIGA_MAX:
		return "GIGA CRUSH"
	if hp.get(health_id(), max_hp()) < max_hp():
		return ""
	if full_set("light"):
		return "HADOUKEN"
	if full_set("giga"):
		return "SHORYUKEN"
	return ""


func _x_special() -> void:
	var move := x_special_name()
	if move == "" or giga_t > 0:
		return
	if move == "GIGA CRUSH":
		_giga_crush()
		return
	var s := SpecialShot.new()
	s.dir = facing
	if move == "SHORYUKEN":
		s.frames_name = "shoryuken"
		s.follow = self
		s.offset = Vector2(14, -20)
		s.life = SHORYUKEN_FRAMES
		vy = JUMP * 1.3
		invuln = SHORYUKEN_FRAMES
		shoryuken_t = SHORYUKEN_FRAMES
		state = State.AIR
	else:
		s.frames_name = "hadouken"
		s.speed = HADOUKEN_SPEED
		s.position = global_position + Vector2(25 * facing, -20)   # 83:8DDB: 25 px à frente, 3 acima do centro (pés −17)
		shot_pose = SHOT_POSE_FRAMES
	get_parent().add_child(s)


func _giga_crush() -> void:
	giga = 0.0
	giga_t = GIGA_FRAMES
	var screen := get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	for b in get_tree().get_nodes_in_group(&"boss"):
		if screen.has_point(b.global_position):
			b.hit(-1, GIGA_DAMAGE)
	# Clarão na tela inteira.
	var layer := CanvasLayer.new()
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	add_child(layer)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, GIGA_FRAMES / 60.0)
	tw.tween_callback(layer.queue_free)


## Peça do encaixe (só o X usa armadura).
func part(slot: String) -> String:
	return parts[slot] if character_id == "x" else ""


## Chip do X3 ligado no encaixe: só sobre a peça Tri dele.
func has_chip(slot: String) -> bool:
	return part(slot) == "tri" and (chip == "gold" or chip == slot)


func full_set(id: String) -> bool:
	return Characters.SLOTS.all(func(k): return part(k) == id)


## Armadura montada das peças: visual do corpo (Gold com o Hyper Chip), tiro do braço e dashes das pernas.
func armor() -> Dictionary:
	if character_id != "x":
		return {}
	var a := {"stats": {}}
	if part("body") != "":
		a.skin = "x_gold" if chip == "gold" and part("body") == "tri" else Characters.ARMOR_SETS[part("body")].skin
	if part("arm") != "":
		a.buster = Characters.ARMOR_SETS[part("arm")].buster
		a.arm = Characters.ARMOR_SETS[part("arm")].arm
	match part("legs"):
		"giga":
			a.stats.airdash = 1
		"tri":
			a.stats.airdash = 2 if has_chip("legs") else 1
			a.stats.updash = 1
	return a


## X do X1: sem pernas não há dash e sem braço não carrega arma, como no X1 (buster do X1 escolhido).
func _x1_body() -> bool:
	return character_id == "x" and buster() == "x1"


## Dash no chão: no X1 só com as pernas.
func can_dash() -> bool:
	return not _x1_body() or part("legs") != ""


## Carregar arma especial: no X1 só com o braço.
func can_charge_weapon() -> bool:
	return not _x1_body() or part("arm") != ""


## Altura do canhão acima dos pés (o do Zero é mais alto que o do X).
func muzzle_y() -> float:
	return character.get("muzzle_y", -18.0)


## Multiplicador: personagem × armadura (1.0 quando nenhum define).
func stat(name: String) -> float:
	return character.get("stats", {}).get(name, 1.0) * armor().get("stats", {}).get(name, 1.0)


## Quantidade (dash no ar, pulos extras, tiros na tela): a armadura substitui o personagem.
func count(name: String, default: int) -> int:
	return int(armor().get("stats", {}).get(name, character.get("stats", {}).get(name, default)))


func set_character(id: String) -> void:
	character = Characters.by_id(id)
	character_id = character.id
	second_shot = ""
	zsaber_ready = false
	zero_combo = 0
	if not hp.has(health_id()):
		hp[health_id()] = max_hp()
	_refresh_visual()


## Armadura inteira de uma vez ("" tira tudo; "gold" = Tri com o Hyper Chip).
func set_armor(id: String) -> void:
	for k in Characters.SLOTS:
		parts[k] = "tri" if id == "gold" else id
	chip = "gold" if id == "gold" else ""
	refresh_armor()


## Depois de trocar peças ou chip: zera o escudo e o tiro guardado e atualiza o visual.
func refresh_armor() -> void:
	shield = Shield.NONE
	second_shot = ""
	zsaber_ready = false
	_refresh_visual()


func _refresh_visual() -> void:
	if visual and visual.has_method(&"set_character"):
		visual.set_character(armor().get("skin", character_id))
	if charge_fx.is_inside_tree():
		_refresh_palette()
	character_changed.emit(character)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"switch_next") or event.is_action_pressed(&"switch_prev"):
		set_weapon(weapon_index + (1 if event.is_action_pressed(&"switch_next") else -1))
	elif event.is_action_pressed(&"saber") and character_id == "x":
		_x_special()
	elif event.is_action_pressed(&"buster_next"):
		buster_style = BUSTER_STYLES[(BUSTER_STYLES.find(buster_style) + 1) % BUSTER_STYLES.size()]
		character_changed.emit(character)
	elif event.is_action_pressed(&"pace_up") or event.is_action_pressed(&"pace_down"):
		pace = clampf(pace + (0.05 if event.is_action_pressed(&"pace_up") else -0.05), 0.5, 2.0)
		character_changed.emit(character)


func _physics_process(_delta: float) -> void:
	if cutscene_pose != &"":
		if visual:
			visual.show_state(cutscene_pose, facing)
			visual.visible = true
		return
	if giga_t > 0:
		giga_t -= 1   # Giga Crush: o X fica parado e invencível
		return
	var dir := int(Input.get_axis(&"left", &"right"))
	# Golpe de sabre no chão segura o Zero no lugar (o do dash continua deslizando).
	if saber.busy() and state in [State.IDLE, State.WALK]:
		dir = 0
	match state:
		State.IDLE, State.WALK:
			_ground(dir)
		State.DASH:
			_dash(dir)
		State.AIR, State.WALL_SLIDE:
			_air(dir)
	_buster()
	saber.tick_frame()

	velocity = Vector2(vx, -vy) * pace * Engine.physics_ticks_per_second
	move_and_slide()
	# Bater a cabeça zera a subida.
	if is_on_ceiling() and vy > 0.0:
		vy = 0.0
	invuln = maxi(invuln - 1, 0)
	shoryuken_t = maxi(shoryuken_t - 1, 0)
	if sting > 0:
		sting -= 1
		if sting % 6 == 0:
			_refresh_palette()   # próxima cor do ciclo; no último frame volta à paleta da arma
	if visual:
		visual.show_state(_pose(), facing)
		# Pisca enquanto invencível depois de levar dano.
		visual.visible = invuln == 0 or shoryuken_t > 0 or (invuln / 3) % 2 == 0


func _walk() -> float: return WALK * stat("speed")
func _dash_speed() -> float: return DASH * stat("dash")
func _jump_speed() -> float: return JUMP * stat("jump")
## Durações em frames encurtam com o ritmo, para o dash cobrir a mesma distância.
func _frames(n: int) -> int: return maxi(1, roundi(n / pace))


func _ground(dir: int) -> void:
	if not is_on_floor():
		_enter_air(false)
		return
	air_jumps_left = count("air_jumps", 0)
	airdash_left = count("airdash", 0)
	airdash_timer = 0
	if dir != 0:
		facing = dir
	vx = dir * _walk()
	vy = 0.0
	state = State.WALK if dir != 0 else State.IDLE
	if Input.is_action_just_pressed(&"jump"):
		_jump(false)
	elif Input.is_action_just_pressed(&"dash") and can_dash():
		Sfx.play(self, "DASH")
		state = State.DASH
		dash_timer = _frames(DASH_FRAMES)


func _dash(dir: int) -> void:
	dash_timer -= 1
	if not is_on_floor():
		_enter_air(true)
		return
	if Input.is_action_just_pressed(&"jump"):
		_jump(true)
		return
	# Solta o botão, vira para trás ou acaba o tempo: volta ao chão.
	if dash_timer <= 0 or not Input.is_action_pressed(&"dash") or dir == -facing:
		state = State.IDLE
		_ground(dir)
		return
	vx = facing * _dash_speed()
	vy = 0.0


func _air(dir: int) -> void:
	if is_on_floor() and vy <= 0.0:
		Sfx.play(self, "LAND", -6.0)
		dash_momentum = false
		state = State.IDLE
		_ground(dir)
		return

	# Soltar o pulo corta a subida (comportamento do X; confirmar o valor exato na ROM).
	if vy > 0.0 and not Input.is_action_pressed(&"jump") and saber.current != "ryuenjin" and shoryuken_t == 0:
		vy = 0.0

	# Dash no ar (armaduras do X2 em diante): reto, sem gravidade, até soltar ou acabar o tempo.
	if airdash_timer > 0:
		airdash_timer -= 1
		if not Input.is_action_pressed(&"dash"):
			airdash_timer = 0
		vx = 0.0 if airdash_up else facing * _dash_speed()
		vy = _dash_speed() if airdash_up else 0.0
		state = State.AIR
		return
	if Input.is_action_just_pressed(&"dash") and airdash_left > 0:
		airdash_left -= 1
		airdash_timer = _frames(AIRDASH_FRAMES)
		# Pernas do X3: ↑ + dash no ar sobe reto.
		airdash_up = Input.is_action_pressed(&"up") and count("updash", 0) > 0
		if dir != 0:
			facing = dir
		vx = 0.0 if airdash_up else facing * _dash_speed()
		vy = _dash_speed() if airdash_up else 0.0
		return

	var wall := _wall_side()
	if Input.is_action_just_pressed(&"jump"):
		if wall != 0:
			_wall_jump(wall)
			return
		if air_jumps_left > 0:
			air_jumps_left -= 1
			_jump(dash_momentum)
			return

	var speed := _dash_speed() if dash_momentum else _walk()
	if kick_timer > 0:
		kick_timer -= 1
		vx = kick_dir * speed
	else:
		if dir != 0:
			facing = dir
		vx = dir * speed

	vy = maxf(vy - GRAVITY * pace, -FALL_CAP)

	# Desliza só caindo, encostado e apertando para a parede.
	if wall != 0 and dir == wall and vy <= 0.0:
		state = State.WALL_SLIDE
		dash_momentum = false
		vy = -WALL_SLIDE
		facing = -wall
	else:
		state = State.AIR


## O primeiro frame do pulo sobe JUMP inteiro; a gravidade começa no frame seguinte.
## A ordem exata no SNES (velocidade antes ou depois da gravidade) ainda não foi conferida na ROM.
func _jump(from_dash: bool) -> void:
	Sfx.play(self, "JUMP")
	dash_momentum = from_dash
	vy = _jump_speed()
	state = State.AIR


func _enter_air(from_dash: bool) -> void:
	dash_momentum = from_dash
	vy = 0.0
	state = State.AIR


func _wall_jump(wall: int) -> void:
	Sfx.play(self, "JUMP")
	dash_momentum = Input.is_action_pressed(&"dash")
	kick_dir = -wall
	kick_timer = _frames(WALL_KICK_FRAMES)
	facing = -wall
	vx = kick_dir * (_dash_speed() if dash_momentum else _walk())
	vy = _jump_speed()
	state = State.AIR


## -1 parede à esquerda, 1 à direita, 0 nenhuma. Testa 1 px ao lado em vez de confiar em is_on_wall(),
## que só vale no frame em que houve colisão.
func _wall_side() -> int:
	for side in [-1, 1]:
		if test_move(global_transform, Vector2(side, 0)):
			return side
	return 0


## Buster do X: apertar atira o tiro simples; segurar carrega; soltar dispara o médio ou o carregado.
func _buster() -> void:
	shot_pose = maxi(shot_pose - 1, 0)
	if saber.busy():
		return
	if zsaber_timer > 0:
		zsaber_timer -= 1
		if zsaber_timer == ZSABER_FRAMES - ZSABER_WAVE_AT:
			_zsaber_wave()
		return
	if Input.is_action_just_pressed(&"fire"):
		charge = 0
		if second_shot != "":
			var w := {"id": second_shot, "game": "x1"}
			if Weapons.frames(w).replaces:
				for s in get_tree().get_nodes_in_group(&"wshot"):
					if s.weapon.get("id") == second_shot and not s.second:
						s.queue_free()
			_spawn_replay(w, true, true)
			second_shot = ""
			if Weapons.frames(w).replaces:
				zsaber_ready = true   # X3: depois da cruz, o próximo aperto é o Z-Saber
		elif zsaber_ready:
			_zsaber()
		elif zero_combo != 0:
			_zero_combo_press()
		else:
			_shoot(0)
	elif Input.is_action_pressed(&"fire") and (weapon_index == 0 or can_charge_weapon()):
		charge += 1
	elif charge > 0:
		var levels := charge_levels()
		var level := 2 if charge >= levels[1] else (1 if charge >= levels[0] else -1)
		if saber.uses_saber() and charge >= ZERO_CHARGE[2]:
			zero_combo = 1 if charge < ZERO_CHARGE[3] else -1   # -1: combo com sabre guardado
		charge = 0
		if level > 0:
			_shoot(level)
		if level == 2:
			saber.open_finisher()


## Tiro guardado esperando o próximo aperto (2º tiro da carga dupla ou combo do Zero).
func has_stored_shot() -> bool:
	return second_shot != "" or zsaber_ready or zero_combo != 0


## Aperto do tiro com o combo do Zero aberto: 2º tiro; depois, com a carga 201+, o golpe de sabre,
## que só sai sem tiros dele na tela (como no X3). O aperto não vira tiro simples enquanto o combo vale.
func _zero_combo_press() -> void:
	if abs(zero_combo) == 1:
		_shoot(2)
		zero_combo = 2 if zero_combo == -1 else 0
	elif get_tree().get_nodes_in_group(&"zshot").is_empty():
		zero_combo = 0
		saber.start_finisher()



func _shoot(level: int) -> void:
	if weapon_index > 0:
		_shoot_weapon(level)
		return
	if level == 2 and _arm_shot() != "":
		var arm := {"id": _arm_shot(), "game": "x1"}
		_spawn_replay(arm, true)
		# Carga dupla (X2/X3): o segundo tiro fica guardado até o próximo aperto, como no original.
		# No X3 ele substitui o primeiro (a bola que vira a cruz).
		if not Weapons.frames(arm).second.is_empty():
			second_shot = _arm_shot()
		return
	var max_shots := count("max_shots", 3)
	if level == 0 and get_tree().get_nodes_in_group(&"lemon").size() >= max_shots:
		return
	var shot := Projectile.new()
	shot.level = level
	# No deslize o X atira para longe da parede, para o lado em que está virado.
	shot.dir = facing
	shot.speed = SHOT_SPEEDS[level] * pace
	shot.damage = (1.0 + level * 1.5) * stat("damage")
	shot.weapon_col = [0, 1, 3][level]
	shot.multiplier = stat("damage") * (stat("charged") if level == 2 else 1.0)
	shot.color = character.get("color", Color.WHITE)
	shot.style = buster()
	shot.position = global_position + Vector2(facing * 16, muzzle_y())
	if level == 0:
		shot.add_to_group(&"lemon")
	elif saber.uses_saber():
		shot.add_to_group(&"zshot")
	get_parent().add_child(shot)
	shot_pose = SHOT_POSE_FRAMES
	charge_fx.play(["LEMON", "MEDIUM_SHOT", "BUSTER_CHARGED"][level])


## Golpe de Z-Saber do X3: o X com a armadura faz o golpe (animação "zsaber" de x_tri/x_gold, montada
## das camadas da folha por tools/cut_x3_saber.py: 11 quadros a 20 fps, a lâmina já desenhada) e a
## onda (assets/shots/zsaber) sai no quadro da lâmina cheia.
func _zsaber() -> void:
	zsaber_ready = false
	zsaber_timer = ZSABER_FRAMES
	charge_fx.play("BUSTER_CHARGED")


func _zsaber_wave() -> void:
	var wave := Projectile.new()
	wave.level = 2
	wave.dir = facing
	wave.speed = SHOT_SPEEDS[2] * pace
	wave.weapon_col = 3
	wave.multiplier = stat("damage") * stat("charged")
	wave.style = "zsaber"
	wave.position = global_position + Vector2(facing * 24, muzzle_y())
	get_parent().add_child(wave)


## Tempos de carga do jogo do buster em uso: X3 mais rápido que X1/X2.
func charge_levels() -> Array:
	if saber.uses_saber():
		return ZERO_CHARGE.slice(0, 2)
	return CHARGE_LEVELS_X3 if buster() == "x3" else CHARGE_LEVELS


## Carregado do braço da armadura.
func _arm_shot() -> String:
	return armor().get("arm", "")


func _spawn_replay(w: Dictionary, charged: bool, second := false) -> void:
	var shot := WeaponShot.new()
	shot.weapon = w
	shot.charged = charged
	shot.second = second
	shot.dir = facing
	shot.damage = Weapons.DAMAGE[1] * stat("damage") * stat("charged")
	shot.position = global_position + Vector2(0, muzzle_y() + 18)
	shot.add_to_group(&"wshot")
	get_parent().add_child(shot)
	shot_pose = SHOT_POSE_FRAMES
	charge_fx.play("CHARGED_SHOT")


func _shoot_weapon(level: int) -> void:
	var shots := get_tree().get_nodes_in_group(&"wshot")
	if level < 2 and shots.size() >= count("max_shots", 3):
		return
	var w: Dictionary = Weapons.LIST[weapon_index]
	if level == 2 and not can_charge_weapon():
		return   # X1 sem o braço: arma especial não carrega
	var cost: float = Weapons.COST.get(w.id, Weapons.COST_DEFAULT)[1 if level == 2 else 0]
	if weapon_energy(w.id) <= 0.0:
		return   # sem energia não sai tiro
	energy[w.id] = maxf(weapon_energy(w.id) - cost, 0.0)
	if level == 2 and w.id == "chameleon_sting":
		# Carregado não é tiro: o personagem fica invencível e troca de cor, andando normalmente.
		sting = STING_FRAMES
		_refresh_palette()
		charge_fx.play("CHARGED_SHOT")
		return
	# Armas refeitas como tiro de verdade (Bullet); as outras ainda tocam a gravação.
	if Bullet.fire(w, level == 2, global_position + Vector2(facing * 16, muzzle_y()), facing, get_parent(),
			Weapons.DAMAGE[1 if level == 2 else 0] * stat("damage")):
		shot_pose = SHOT_POSE_FRAMES
		charge_fx.play("LEMON" if level < 2 else "CHARGED_SHOT")
		return
	# Tiro lançado (Acid Burst): bola com colisão de verdade; os outros tocam a gravação.
	var shot: Area2D = LobShot.new() if level < 2 and not Weapons.frames(w).lob.is_empty() else WeaponShot.new()
	shot.weapon = w
	shot.charged = level == 2
	shot.dir = facing
	shot.damage = Weapons.DAMAGE[1 if level == 2 else 0] * stat("damage")
	shot.multiplier = stat("damage") * (stat("charged") if level == 2 else 1.0)
	# A gravação é presa aos pés do X; desloca pela diferença de altura do canhão.
	shot.position = global_position + Vector2(0, muzzle_y() + 18)
	shot.add_to_group(&"wshot")
	get_parent().add_child(shot)
	shot_pose = SHOT_POSE_FRAMES
	charge_fx.play("LEMON" if level < 2 else "CHARGED_SHOT")


## Estilo de sprite do tiro do personagem atual ("" = círculo provisório).
func buster() -> String:
	var style: String = armor().get("buster", character.get("buster", ""))
	return buster_style if style == "select" else style


func _pose() -> StringName:
	if saber.busy():
		return saber.anim()
	if zsaber_timer > 0:
		return &"zsaber"
	match state:
		State.IDLE:
			return &"shot" if shot_pose > 0 else &"idle"
		State.WALK:
			return &"walk"
		State.DASH:
			return &"dash"
		State.WALL_SLIDE:
			return &"slide"
	if airdash_timer > 0:
		return &"jump" if airdash_up else &"airdash"
	if kick_timer > 0:
		return &"walljump"
	return &"jump" if vy > 0.0 else &"fall"

