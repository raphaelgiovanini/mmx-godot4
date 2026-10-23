extends Area2D
## Tiro do buster. Com `style` ("x1", "x2", "x3") usa os quadros originais da folha de referência
## (tools/cut_buster_sheet.py → assets/shots/<style>/shots.json): formação, voo e impacto de cada nível.
## Sem esses quadros, usa o buster do mmx8 (assets/shots/mmx8, com o rastro de partículas de lá);
## sem nenhum dos dois, desenha um círculo na cor do personagem.

const SIZES := [3.0, 6.0, 10.0]  # raio de colisão: lemon, médio, carregado
const ROOT := "res://assets/shots/"
const FPS := 30.0
const MMX8 := "mmx8"
const MMX8_ANIMS := ["lemon", "medium", "charged"]
const MMX8_FPS := [1000.0 / 42.0, 1000.0 / 36.0, 1000.0 / 36.0]   # ms por quadro nos .json do mmx8

static var _cache := {}

var level := 0
var dir := 1
var speed := 0.0  # px/frame
var damage := 1.0
## Coluna da arma na tabela de dano do X1 (86:EF37): 0 simples, 1 médio, 3 carregado.
var weapon_col := 0
## Multiplicador do personagem/armadura sobre o dano da tabela.
var multiplier := 1.0
var color := Color.YELLOW
var style := ""
var _life := 90


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = SIZES[level]
	shape.shape = circle
	add_child(shape)
	# Some ao bater no cenário; o carregado nasce encostado no próprio jogador, que é ignorado.
	body_entered.connect(_on_body)
	var frames := _frames(style)
	var mmx8 := _frames(MMX8)
	if mmx8 and not frames:
		var anim: StringName = MMX8_ANIMS[level]
		var shot := AnimatedSprite2D.new()
		shot.sprite_frames = mmx8
		shot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shot.flip_h = dir < 0
		shot.speed_scale = MMX8_FPS[level] / FPS
		add_child(shot)
		shot.play(anim)
		shot.frame = randi() % mmx8.get_frame_count(anim)
		add_child(_trail())
	elif frames:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.flip_h = dir < 0
		add_child(sprite)
		if level == 0:
			sprite.play(&"lemon")
		else:
			# Médio e carregado: a formação toca uma vez, depois o voo em loop.
			var prefix := "medium_" if level == 1 else ""
			sprite.play(prefix + "form")
			sprite.animation_finished.connect(func(): sprite.play(prefix + "fly"))


## Rastro do mmx8 (src/Effects/Materials/buster_*_particle(s).tres) atrás do tiro, para trás:
## lemon 4 pontos laranja; médio 4 pontos verde → laranja; carregado 12 rastros brancos (follow_shot,
## 2×2 quadros) numa caixa 10×30, freando.
func _trail() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = Vector2((-8 if level == 2 else -10) * dir, 0)
	p.amount = 12 if level == 2 else 4
	p.lifetime = 0.6 if level == 2 else 0.54
	p.lifetime_randomness = 0.33
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(5, 15 if level == 2 else 3)
	p.direction = Vector2(-dir, 0)
	p.spread = 0.0
	p.gravity = Vector2.ZERO
	var v := 250.0 if level == 2 else 200.0
	p.initial_velocity_min = v * 0.9
	p.initial_velocity_max = v
	var ramp := Gradient.new()
	if level == 2:
		p.damping_min = 250.0
		p.damping_max = 250.0
		p.scale_amount_min = 0.0
		p.scale_amount_max = 1.0
		p.texture = Assets.texture(ROOT + MMX8 + "/follow_shot.png")
		p.anim_speed_min = 1.0
		p.anim_speed_max = 1.0
		var m := CanvasItemMaterial.new()
		m.particles_animation = true
		m.particles_anim_h_frames = 2
		m.particles_anim_v_frames = 2
		p.material = m
		ramp.offsets = PackedFloat32Array([0.47, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	else:
		p.color = Color(0.973, 0.973, 0.973)
		var start := Color(0.0, 0.996, 0.018, 1.0) if level == 1 else Color(0.941, 0.565, 0.376, 1.0)
		var orange := Color(0.941, 0.565, 0.376)
		if level == 1:
			ramp.offsets = PackedFloat32Array([0.0, 1.0])
			ramp.colors = PackedColorArray([start, Color(orange, 0.0)])
		else:
			ramp.offsets = PackedFloat32Array([0.0, 0.806, 1.0])
			ramp.colors = PackedColorArray([start, Color(orange, 0.194), Color(orange, 0.0)])
	p.color_ramp = ramp
	return p


func _on_body(b: Node) -> void:
	if b is Player:
		return
	if b is Boss:
		if b.hit(weapon_col, multiplier):
			_impact()
		return
	_impact()


## Impacto do nível do tiro (anéis/estrela da folha) no lugar do tiro, que some.
func _impact() -> void:
	var frames := _frames(style)
	var anim: StringName = ["lemon_hit", "medium_hit", "hit"][level]
	if frames and frames.has_animation(anim):
		var fx := AnimatedSprite2D.new()
		fx.sprite_frames = frames
		fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fx.flip_h = dir < 0
		fx.global_position = global_position
		get_parent().add_child(fx)
		fx.play(anim)
		fx.animation_finished.connect(fx.queue_free)
	queue_free()


func _physics_process(_delta: float) -> void:
	position.x += dir * speed
	_life -= 1
	if _life <= 0:
		queue_free()


func _draw() -> void:
	if _frames(style) or _frames(MMX8):
		return
	var r: float = SIZES[level]
	if level == 0:
		draw_circle(Vector2.ZERO, r, Color("fff27a"))
	else:
		draw_circle(Vector2.ZERO, r + 2, color.lightened(0.3))
		draw_circle(Vector2.ZERO, r, Color.WHITE)


## SpriteFrames de um estilo, montado uma vez. null se o estilo não existe ou não foi instalado
## (tools/install_shots.py).
static func _frames(name: String) -> SpriteFrames:
	if name == "":
		return null
	if _cache.has(name):
		return _cache[name]
	var dir_path := ROOT + name
	var meta = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join("shots.json")))
	var frames: SpriteFrames = null
	if meta != null:
		frames = SpriteFrames.new()
		frames.remove_animation(&"default")
		for anim: String in meta:
			frames.add_animation(anim)
			frames.set_animation_speed(anim, FPS)
			frames.set_animation_loop(anim, not (anim.ends_with("form") or anim.ends_with("hit")))
			for file: String in meta[anim]:
				var tex := Assets.texture(dir_path.path_join(file))
				if tex:
					frames.add_frame(anim, tex)
	_cache[name] = frames
	return frames
